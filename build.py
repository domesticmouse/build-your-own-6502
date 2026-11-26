#!/usr/bin/env python3
"""Compile Markdown course lessons and reference sheets into static HTML."""

from __future__ import annotations

import argparse
import html
import re
import shutil
import sys
from pathlib import Path

import yaml
from markdown_it import MarkdownIt

COURSE_NAME = "Build Your Own 6502"
MISSION_BADGE = "6502 on Tang Nano 20K"

FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.DOTALL)
ATTR_RE = re.compile(r'([A-Za-z0-9_-]+)="([^"]*)"')
BLANK_RE = re.compile(r"\{\{blank:([^}]+)\}\}")
SIDENOTE_RE = re.compile(r"\{\{sidenote:(.*?)\}\}", re.DOTALL)
HEADING_ANCHOR_RE = re.compile(
    r"<h([1-6])>(.*?)\s*\{#([A-Za-z0-9_-]+)\}\s*</h\1>", re.DOTALL
)
BARE_TEX_MACRO_RE = re.compile(
    r"(?<!\\)\\(?:approx|pm|Omega|times|le|ge|frac|neq|cdot|rightarrow|leftarrow)\b"
)
MD_LINK_RE = re.compile(r"(!?\[[^\]]*\]\()([^)#\s]+\.md)(#[^)\s]+)?(\))")


def parse_frontmatter(text: str, path: Path) -> tuple[dict, str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise ValueError(f"{path}: missing YAML frontmatter")
    data = yaml.safe_load(match.group(1))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: frontmatter must be a YAML mapping")
    return data, text[match.end() :]


def parse_attrs(raw: str, context: str) -> dict[str, str]:
    stripped = raw.strip()
    if stripped.startswith("{") or "}" in stripped:
        raise ValueError(f"{context}: curly-brace attributes are forbidden; use space-separated key=\"value\"")
    attrs: dict[str, str] = {}
    pos = 0
    for m in ATTR_RE.finditer(stripped):
        between = stripped[pos : m.start()].strip()
        if between:
            raise ValueError(f"{context}: malformed attributes near {between!r}")
        attrs[m.group(1)] = m.group(2)
        pos = m.end()
    trailing = stripped[pos:].strip()
    if trailing:
        raise ValueError(f"{context}: malformed trailing attributes {trailing!r}")
    return attrs


def render_inline_md(md: MarkdownIt, text: str) -> str:
    return md.renderInline(text)


def extract_directives_and_code(
    body: str,
    md: MarkdownIt,
    source_path: Path,
    root_dir: Path,
    errors: list[str],
    interactive_flags: dict[str, bool],
) -> tuple[str, dict[str, str]]:
    """Extract custom ::: directives and fenced code blocks before md.render()."""
    placeholders: dict[str, str] = {}
    counter = 0

    def next_token(rendered_html: str) -> str:
        nonlocal counter
        token = f"<!--BLOCK_PLACEHOLDER_{counter}-->"
        counter += 1
        placeholders[token] = rendered_html
        return f"\n\n{token}\n\n"

    def render_code_figure(lang: str, caption: str, code_text: str, is_exercise: bool = False) -> str:
        if lang == "mermaid":
            cap_html = f"<figcaption>{html.escape(caption)}</figcaption>" if caption else ""
            return (
                f'<figure class="mermaid-figure">'
                f'<pre class="mermaid">{html.escape(code_text)}</pre>'
                f"{cap_html}</figure>"
            )

        if is_exercise:
            parts: list[str] = []
            last = 0
            blank_count = 0
            for bm in BLANK_RE.finditer(code_text):
                parts.append(html.escape(code_text[last : bm.start()]))
                raw_spec = bm.group(1)
                parts_right = raw_spec.rsplit("|", 3)
                if len(parts_right) == 4 and parts_right[3].strip().isdigit():
                    answer, hint, placeholder, width = parts_right
                else:
                    spec = raw_spec.split("|")
                    answer = spec[0] if len(spec) > 0 else ""
                    hint = spec[1] if len(spec) > 1 else ""
                    placeholder = spec[2] if len(spec) > 2 else "???"
                    width = spec[3] if len(spec) > 3 else str(max(4, len(placeholder) + 2))
                blank_count += 1
                parts.append(
                    f'<input type="text" class="blank-input" '
                    f'aria-label="Code blank {blank_count}" '
                    f'data-answer="{html.escape(answer, quote=True)}" '
                    f'data-hint="{html.escape(render_inline_md(md, hint), quote=True)}" '
                    f'placeholder="{html.escape(placeholder, quote=True)}" '
                    f'style="width: {int(width) + 2}ch;">'
                )
                last = bm.end()
            parts.append(html.escape(code_text[last:]))
            if blank_count == 0:
                errors.append(f"{source_path}: :::exercise code block has no {{{{blank:...}}}} tokens")
            inner = "".join(parts)
        else:
            inner = html.escape(code_text)

        cls = f' class="language-{html.escape(lang)}"' if lang else ""
        cap_html = f'<div class="code-caption">{html.escape(caption)}</div>' if caption else ""
        return f'<div class="code-figure">{cap_html}<pre tabindex="0"><code{cls}>{inner}</code></pre></div>'

    lines = body.splitlines()
    out_lines: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # Fenced code block outside directives
        fence_match = re.match(r"^```([A-Za-z0-9_-]*)(.*)$", line)
        if fence_match:
            lang = fence_match.group(1).strip()
            raw_attr = fence_match.group(2)
            attrs = parse_attrs(raw_attr, f"{source_path}:{i + 1}")
            caption = attrs.get("caption", "")
            code_lines: list[str] = []
            i += 1
            while i < len(lines) and not re.match(r"^```\s*$", lines[i]):
                code_lines.append(lines[i])
                i += 1
            if i >= len(lines):
                errors.append(f"{source_path}: unclosed code fence starting near line {i + 1}")
            code_text = "\n".join(code_lines)
            if lang == "mermaid":
                interactive_flags["mermaid"] = True
            out_lines.append(next_token(render_code_figure(lang, caption, code_text)))
            i += 1
            continue

        # Custom ::: directives (supporting nested :::prompts inside :::exercise)
        dir_match = re.match(r"^:::(callout-warn|callout-success|callout|teacher-prompt|exercise|verify|quiz)(?:\s+(.*))?$", line)
        if dir_match:
            kind = dir_match.group(1)
            raw_attr = dir_match.group(2) or ""
            attrs = parse_attrs(raw_attr, f"{source_path}:{i + 1}")
            inner_lines: list[str] = []
            depth = 1
            i += 1
            while i < len(lines):
                cur = lines[i]
                if re.match(r"^:::(prompts|[a-z-]+)(?:\s+.*)?$", cur):
                    depth += 1
                elif cur.strip() == ":::":
                    depth -= 1
                    if depth == 0:
                        break
                inner_lines.append(cur)
                i += 1
            if depth != 0:
                errors.append(f"{source_path}: unclosed :::{kind} directive")

            if kind in {"callout", "callout-warn", "callout-success"}:
                title = attrs.get("title", "Note")
                variant = ""
                if kind == "callout-warn":
                    variant = " callout-warn"
                elif kind == "callout-success":
                    variant = " callout-success"
                inner_text = rewrite_and_validate_links("\n".join(inner_lines), source_path, root_dir, errors)
                inner_html = md.render(inner_text)
                rendered = (
                    f'<aside class="callout{variant}">'
                    f'<div class="callout-title">{html.escape(title)}</div>'
                    f"{inner_html}</aside>"
                )
                out_lines.append(next_token(rendered))
            elif kind == "teacher-prompt":
                title = attrs.get("title", "Ask Your AI Teacher")
                inner_text = rewrite_and_validate_links("\n".join(inner_lines), source_path, root_dir, errors)
                inner_html = md.render(inner_text)
                rendered = (
                    f'<aside class="teacher-prompt">'
                    f'<div class="teacher-prompt-title">{html.escape(title)}</div>'
                    f"{inner_html}</aside>"
                )
                out_lines.append(next_token(rendered))
            elif kind == "exercise":
                ex_id = attrs.get("id", "")
                title = attrs.get("title", "Interactive Lab")
                badge = attrs.get("badge", "Skill Practice")
                if not ex_id:
                    errors.append(f"{source_path}: :::exercise missing id")

                # Split out :::prompts block and fenced code block
                prompts_yaml: list[str] = []
                in_prompts = False
                prose_before: list[str] = []
                code_html = ""
                j = 0
                while j < len(inner_lines):
                    cur = inner_lines[j]
                    if cur.strip() == ":::prompts":
                        in_prompts = True
                        j += 1
                        continue
                    if in_prompts:
                        if cur.strip() == ":::":
                            in_prompts = False
                        else:
                            prompts_yaml.append(cur)
                        j += 1
                        continue
                    fm = re.match(r"^```([A-Za-z0-9_-]*)(.*)$", cur)
                    if fm:
                        f_lang = fm.group(1).strip()
                        f_attrs = parse_attrs(fm.group(2), f"{source_path} exercise {ex_id}")
                        c_lines: list[str] = []
                        j += 1
                        while j < len(inner_lines) and not re.match(r"^```\s*$", inner_lines[j]):
                            c_lines.append(inner_lines[j])
                            j += 1
                        code_html = render_code_figure(
                            f_lang, f_attrs.get("caption", ""), "\n".join(c_lines), is_exercise=True
                        )
                        j += 1
                        continue
                    prose_before.append(cur)
                    j += 1

                if not prompts_yaml:
                    errors.append(f"{source_path}: :::exercise {ex_id} missing mandatory :::prompts block")
                    prompts_data = {}
                else:
                    prompts_data = yaml.safe_load("\n".join(prompts_yaml)) or {}
                if "hint" not in prompts_data or "success" not in prompts_data:
                    errors.append(f"{source_path}: :::exercise {ex_id} :::prompts must define hint and success")

                if not code_html:
                    errors.append(f"{source_path}: :::exercise {ex_id} missing fenced code block")

                prose_html = md.render("\n".join(prose_before))
                rendered = (
                    f'<section class="interactive-panel" id="{html.escape(ex_id)}" data-exercise '
                    f'data-hint="{html.escape(render_inline_md(md, str(prompts_data.get("hint", ""))), quote=True)}" '
                    f'data-success="{html.escape(render_inline_md(md, str(prompts_data.get("success", ""))), quote=True)}">'
                    f'<div class="panel-header"><h3 class="panel-title">{html.escape(title)}</h3>'
                    f'<span class="panel-badge">{html.escape(badge)}</span></div>'
                    f"{prose_html}{code_html}"
                    f'<div class="panel-actions">'
                    f'<button type="button" class="btn btn-primary" data-action="check">Check Answer</button>'
                    f'<button type="button" class="btn" data-action="hint">Show Hint</button>'
                    f'<button type="button" class="btn" data-action="reset">Reset</button>'
                    f"</div>"
                    f'<div class="panel-feedback" aria-live="polite" hidden></div>'
                    f"</section>"
                )
                out_lines.append(next_token(rendered))
            elif kind == "verify":
                v_id = attrs.get("id", "verify")
                title = attrs.get("title", "Verification Lab")
                badge = attrs.get("badge", "Terminal Gate")

                prose_and_code: list[str] = []
                checklist_items: list[str] = []
                j = 0
                while j < len(inner_lines):
                    cur = inner_lines[j]
                    fm = re.match(r"^```([A-Za-z0-9_-]*)(.*)$", cur)
                    if fm:
                        f_lang = fm.group(1).strip()
                        f_attrs = parse_attrs(fm.group(2), f"{source_path} verify {v_id}")
                        c_lines: list[str] = []
                        j += 1
                        while j < len(inner_lines) and not re.match(r"^```\s*$", inner_lines[j]):
                            c_lines.append(inner_lines[j])
                            j += 1
                        prose_and_code.append(
                            render_code_figure(f_lang, f_attrs.get("caption", ""), "\n".join(c_lines))
                        )
                        j += 1
                        continue
                    cb_match = re.match(r"^\s*-\s+\[\s*\]\s+(.*)$", cur)
                    if cb_match:
                        checklist_items.append(cb_match.group(1))
                    else:
                        prose_and_code.append(cur)
                    j += 1

                # Render any remaining prose lines (skipping raw code figure html lines)
                body_chunks: list[str] = []
                text_buf: list[str] = []
                for item in prose_and_code:
                    if item.startswith('<div class="code-figure">'):
                        if text_buf:
                            body_chunks.append(md.render("\n".join(text_buf)))
                            text_buf.clear()
                        body_chunks.append(item)
                    else:
                        text_buf.append(item)
                if text_buf:
                    body_chunks.append(md.render("\n".join(text_buf)))

                checklist_html_parts: list[str] = []
                for idx, item_text in enumerate(checklist_items):
                    cb_id = f"{v_id}-item-{idx}"
                    checklist_html_parts.append(
                        f'<label class="verify-item" for="{html.escape(cb_id)}">'
                        f'<input type="checkbox" id="{html.escape(cb_id)}" class="verify-check visually-hidden-fallback">'
                        f"<span>{render_inline_md(md, item_text)}</span></label>"
                    )
                checklist_html = (
                    f'<div class="verify-list">{"".join(checklist_html_parts)}</div>'
                    if checklist_html_parts
                    else ""
                )
                rendered = (
                    f'<section class="interactive-panel" id="{html.escape(v_id)}" data-verify>'
                    f'<div class="panel-header"><h3 class="panel-title">{html.escape(title)}</h3>'
                    f'<span class="panel-badge">{html.escape(badge)}</span></div>'
                    f'{"".join(body_chunks)}{checklist_html}</section>'
                )
                out_lines.append(next_token(rendered))
            elif kind == "quiz":
                q_id = attrs.get("id", "quiz")
                title = attrs.get("title", "Retrieval Practice")
                badge = attrs.get("badge", "Quiz")
                questions = yaml.safe_load("\n".join(inner_lines))
                if not isinstance(questions, list) or not questions:
                    errors.append(f"{source_path}: :::quiz {q_id} must contain a YAML list of questions")
                    questions = []

                q_blocks: list[str] = []
                for qi, q in enumerate(questions):
                    prompt = q.get("question", "")
                    wrong_hint = q.get("wrong_hint", "")
                    options = q.get("options", [])
                    if len(options) != 4:
                        errors.append(f"{source_path}: :::quiz {q_id} question {qi + 1} must have 4 options")
                    word_counts = [len(str(opt.get("text", "")).split()) for opt in options]
                    if len(set(word_counts)) != 1:
                        errors.append(
                            f"{source_path}: :::quiz {q_id} question {qi + 1} options do not have equal word counts: {word_counts}"
                        )
                    correct_count = sum(1 for opt in options if opt.get("correct") is True)
                    if correct_count != 1:
                        errors.append(
                            f"{source_path}: :::quiz {q_id} question {qi + 1} must have exactly 1 correct option"
                        )
                    opt_html = []
                    for opt in options:
                        letter = str(opt.get("letter", ""))
                        text_val = str(opt.get("text", ""))
                        is_ok = "true" if opt.get("correct") is True else "false"
                        explain = str(opt.get("explain", ""))
                        opt_html.append(
                            f'<button type="button" class="quiz-option" '
                            f'data-correct="{is_ok}" data-explain="{html.escape(render_inline_md(md, explain), quote=True)}">'
                            f'<span class="quiz-letter">{html.escape(letter)}</span>'
                            f"<span>{html.escape(text_val)}</span></button>"
                        )
                    q_blocks.append(
                        f'<div class="quiz-question" data-wrong-hint="{html.escape(render_inline_md(md, wrong_hint), quote=True)}">'
                        f'<p class="quiz-question-prompt">{qi + 1}. {render_inline_md(md, prompt)}</p>'
                        f'<div class="quiz-options">{"".join(opt_html)}</div>'
                        f'<div class="quiz-explain" aria-live="polite" hidden></div></div>'
                    )

                rendered = (
                    f'<section class="interactive-panel" id="{html.escape(q_id)}" data-quiz>'
                    f'<div class="panel-header"><h3 class="panel-title">{html.escape(title)}</h3>'
                    f'<span class="panel-badge">{html.escape(badge)}</span></div>'
                    f'{"".join(q_blocks)}'
                    f'<div class="panel-actions"><button type="button" class="btn" data-action="reset-quiz">Reset Quiz</button></div>'
                    f'<div class="panel-feedback" aria-live="polite" hidden></div></section>'
                )
                out_lines.append(next_token(rendered))

            i += 1
            continue

        out_lines.append(line)
        i += 1

    return "\n".join(out_lines), placeholders


def protect_inline_code_and_math(
    text: str, interactive_flags: dict[str, bool]
) -> tuple[str, dict[str, str]]:
    """Protect inline `code` and $$...$$ / $...$ math before md.render()."""
    tokens: dict[str, str] = {}
    idx = 0

    def store(val: str) -> str:
        nonlocal idx
        key = f"\uE000INLINEPROTECTED{idx}\uE001"
        idx += 1
        tokens[key] = val
        return key

    # 1. Protect inline code spans (`...` or `` `... ``) per CommonMark backtick-count matching
    code_re = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)", re.DOTALL)
    text = code_re.sub(lambda m: store(f"<code>{html.escape(m.group(2).strip())}</code>"), text)

    # 2. Protect display math ($$...$$)
    display_math_re = re.compile(r"\$\$(.+?)\$\$", re.DOTALL)

    def sub_display_math(m: re.Match[str]) -> str:
        interactive_flags["math"] = True
        return store(f"$${m.group(1)}$$")

    text = display_math_re.sub(sub_display_math, text)

    # 3. Protect inline math ($...$) — avoid escaped \$ or currency like $50 followed by space
    inline_math_re = re.compile(r"(?<!\\)\$(?!\s)([^$\n]+?)(?<!\s)\$")

    def sub_inline_math(m: re.Match[str]) -> str:
        interactive_flags["math"] = True
        return store(f"${m.group(1)}$")

    text = inline_math_re.sub(sub_inline_math, text)
    return text, tokens


def rewrite_sidenotes(text: str, md: MarkdownIt) -> str:
    note_counter = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal note_counter
        note_counter += 1
        note_id = f"sidenote-{note_counter}"
        note_html = render_inline_md(md, m.group(1).strip())
        return (
            f'<span class="sidenote-wrapper">'
            f'<span class="sidenote-number" aria-hidden="true"></span>'
            f'<button type="button" class="sidenote-toggle" aria-expanded="false" '
            f'aria-controls="{note_id}">note {note_counter}</button>'
            f'<span class="sidenote" id="{note_id}">{note_html}</span>'
            f"</span>"
        )

    return SIDENOTE_RE.sub(repl, text)


def target_output_rel(src_path: Path, root_dir: Path) -> Path:
    rel = src_path.relative_to(root_dir)
    if rel == Path("reference/GLOSSARY.md"):
        return Path("reference/glossary.html")
    return rel.with_suffix(".html")


def rewrite_and_validate_links(
    text: str, src_path: Path, root_dir: Path, errors: list[str]
) -> str:
    def repl(m: re.Match[str]) -> str:
        prefix, target, anchor, suffix = m.group(1), m.group(2), m.group(3) or "", m.group(4)
        if re.match(r"^[a-z]+://", target):
            return m.group(0)
        resolved = (src_path.parent / target).resolve()
        if not resolved.exists():
            errors.append(f"{src_path}: broken internal link {target!r}")
            return m.group(0)
        if resolved.suffix == ".md":
            out_rel = target_output_rel(resolved, root_dir)
            from_out_dir = target_output_rel(src_path, root_dir).parent
            rel_href = Path(
                *([".."] * len(from_out_dir.parts)), out_rel
            ).as_posix()
            # Compute proper relative path between output HTML files
            try:
                rel_href = Path(
                    os_relpath(out_rel, from_out_dir)
                ).as_posix()
            except ValueError:
                rel_href = out_rel.as_posix()
            return f"{prefix}{rel_href}{anchor}{suffix}"
        return m.group(0)

    return MD_LINK_RE.sub(repl, text)


def os_relpath(target: Path, start: Path) -> str:
    import os
    return os.path.relpath(target.as_posix(), start.as_posix() or ".")


def enhance_tables(html_text: str) -> str:
    caption_counter = 0

    # Replace preceding "Table: Caption" paragraphs with <div class="table-caption" id="...">
    def cap_repl(m: re.Match[str]) -> str:
        nonlocal caption_counter
        caption_counter += 1
        cap_id = f"table-cap-{caption_counter}"
        return f'<div class="table-caption" id="{cap_id}">{m.group(1)}</div>\n<table data-cap="{cap_id}"'

    html_text = re.sub(
        r"<p>Table:\s*(.*?)</p>\s*<table",
        cap_repl,
        html_text,
        flags=re.DOTALL,
    )

    table_re = re.compile(r"<table([^>]*)>(.*?)</table>", re.DOTALL)

    def tbl_repl(m: re.Match[str]) -> str:
        attrs_raw, inner = m.group(1), m.group(2)
        cap_match = re.search(r'data-cap="([^"]+)"', attrs_raw)
        aria_attr = (
            f'aria-labelledby="{cap_match.group(1)}"'
            if cap_match
            else 'aria-label="Data table"'
        )
        clean_attrs = re.sub(r'\s*data-cap="[^"]+"', "", attrs_raw)
        inner = re.sub(r"<th>", '<th scope="col">', inner)
        return (
            f'<div class="table-wrapper" tabindex="0" role="region" {aria_attr}>'
            f'<table class="ref-table"{clean_attrs}>{inner}</table></div>'
        )

    return table_re.sub(tbl_repl, html_text)


def strip_lesson_prefix(badge: str) -> str:
    return re.sub(r"^Lesson\s+\d+\s*•\s*", "", badge.strip())


def build_nav_html(
    page_kind: str,
    meta: dict,
    lessons: list[dict],
    refs: list[dict],
    rel_root: str,
) -> str:
    if page_kind == "index":
        crumbs = '<span aria-current="page">Index</span>'
    elif page_kind == "lesson":
        num = meta["num"]
        crumbs = (
            f'<a href="{rel_root}index.html">Index</a>'
            f'<span aria-hidden="true">›</span>'
            f'<span aria-current="page">Lesson {num}</span>'
        )
    else:
        crumbs = (
            f'<a href="{rel_root}index.html">Index</a>'
            f'<span aria-hidden="true">›</span>'
            f'<span aria-current="page">{html.escape(meta.get("nav_label", meta["title"]))}</span>'
        )

    pager_html = ""
    if page_kind == "lesson":
        idx = meta["index"]
        prev_link = (
            f'<a href="{rel_root}{lessons[idx - 1]["out_rel"]}" '
            f'title="{html.escape(lessons[idx - 1]["title"], quote=True)}">← Prev</a>'
            if idx > 0
            else '<span class="nav-disabled">← Prev</span>'
        )
        next_link = (
            f'<a href="{rel_root}{lessons[idx + 1]["out_rel"]}" '
            f'title="{html.escape(lessons[idx + 1]["title"], quote=True)}">Next →</a>'
            if idx + 1 < len(lessons)
            else '<span class="nav-disabled">Next →</span>'
        )
        pager_html = f'<span class="nav-pager-group">{prev_link}<span class="nav-sep">·</span>{next_link}</span>'

    ref_links = []
    for ref in refs:
        current = ' aria-current="page"' if page_kind == "ref" and ref["nav_id"] == meta.get("nav_id") else ""
        ref_links.append(
            f'<a class="nav-ref-link" href="{rel_root}{ref["out_rel"]}"{current}>'
            f'{html.escape(ref.get("nav_label", ref["title"]))}</a>'
        )

    return (
        '<header class="site-header"><nav class="course-nav" aria-label="Primary">'
        f'<div class="nav-breadcrumbs">{crumbs}</div>'
        '<div class="nav-controls">'
        f"{pager_html}"
        f'{"".join(ref_links)}'
        f'<span class="mission-badge">{html.escape(MISSION_BADGE)}</span>'
        "</div></nav></header>"
    )


def build_lesson_pager_html(meta: dict, lessons: list[dict], rel_root: str) -> str:
    idx = meta["index"]
    prev_card = "<div></div>"
    if idx > 0:
        p = lessons[idx - 1]
        prev_card = (
            f'<a class="pager-card is-prev" href="{rel_root}{p["out_rel"]}">'
            f'<span class="pager-label">← Previous • Lesson {p["num"]}</span>'
            f'<span class="pager-title">{html.escape(p["title"])}</span></a>'
        )
    next_card = "<div></div>"
    if idx + 1 < len(lessons):
        n = lessons[idx + 1]
        next_card = (
            f'<a class="pager-card is-next" href="{rel_root}{n["out_rel"]}">'
            f'<span class="pager-label">Next • Lesson {n["num"]} →</span>'
            f'<span class="pager-title">{html.escape(n["title"])}</span></a>'
        )
    return f'<nav class="lesson-pager" aria-label="Lesson pagination">{prev_card}{next_card}</nav>'


def build_lesson_cards_html(lessons: list[dict], md: MarkdownIt) -> str:
    cards = []
    for lesson in lessons:
        badge_topic = strip_lesson_prefix(lesson.get("badge", ""))
        meta_line = f'LESSON {lesson["num"]}' + (f" • {badge_topic}" if badge_topic else "")
        card = lesson.get("card", {})
        title_html = render_inline_md(md, card.get("title", lesson["title"]))
        summary_html = render_inline_md(md, card.get("summary", lesson.get("subtitle", "")))
        cards.append(
            f'<a class="lesson-card" href="{lesson["out_rel"]}">'
            f'<span class="lesson-card-meta">{html.escape(meta_line)}</span>'
            f'<span class="lesson-card-title">{title_html}</span>'
            f'<span class="lesson-card-summary">{summary_html}</span></a>'
        )
    return f'<div class="card-grid">{"".join(cards)}</div>'


def build_reference_cards_html(refs: list[dict], md: MarkdownIt) -> str:
    cards = []
    for ref in refs:
        card = ref.get("card", {})
        title_html = render_inline_md(md, card.get("title", ref["title"]))
        summary_html = render_inline_md(md, card.get("summary", ref.get("subtitle", "")))
        cards.append(
            f'<a class="lesson-card" href="{ref["out_rel"]}">'
            f'<span class="lesson-card-meta">REFERENCE</span>'
            f'<span class="lesson-card-title">{title_html}</span>'
            f'<span class="lesson-card-summary">{summary_html}</span></a>'
        )
    return f'<div class="card-grid">{"".join(cards)}</div>'


def render_page_shell(
    meta: dict,
    body_html: str,
    nav_html: str,
    pager_html: str,
    rel_root: str,
    needs_math: bool,
    needs_mermaid: bool,
) -> str:
    katex_head = ""
    katex_scripts = ""
    if needs_math:
        katex_head = (
            '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">\n'
        )
        katex_scripts = (
            '<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>\n'
            '<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>\n'
        )

    mermaid_script = (
        '<script defer src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>\n'
        if needs_mermaid
        else ""
    )

    prism_scripts = (
        '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css">\n'
        '<script defer src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-core.min.js"></script>\n'
        '<script defer src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/plugins/autoloader/prism-autoloader.min.js"></script>\n'
        '<script defer src="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/plugins/keep-markup/prism-keep-markup.min.js"></script>\n'
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>{html.escape(meta["page_title"])}</title>
  {katex_head}{prism_scripts}<link rel="stylesheet" href="{rel_root}assets/style.css">
  {mermaid_script}{katex_scripts}<script defer src="{rel_root}assets/course.js"></script>
</head>
<body>
  <a class="skip-link" href="#main-content">Skip to main content</a>
  {nav_html}
  <main class="page-main">
    <article class="lesson-article">
      <header class="lesson-header">
        <div class="lesson-badge">{html.escape(meta.get("badge", ""))}</div>
        <h1 id="main-content" tabindex="-1">{html.escape(meta["title"])}</h1>
        <p class="lesson-subtitle">{html.escape(meta.get("subtitle", ""))}</p>
      </header>
      {body_html}
      {pager_html}
    </article>
  </main>
  <footer class="site-footer">
    <span>{html.escape(COURSE_NAME)} • Gate by Gate on Tang Nano 20K</span>
  </footer>
</body>
</html>
"""


def validate_rendered_html(out_path: Path, full_html: str, errors: list[str]) -> None:
    if any(tok in full_html for tok in ("\uE000", "INLINEPROTECTED", "BLOCK_PLACEHOLDER_")):
        errors.append(f"{out_path}: unreplaced placeholder token leaked into HTML")
    if re.search(r"<[1-6]\b", full_html):
        errors.append(f"{out_path}: malformed heading tag <[1-6] found")
    if re.search(r"\{#[A-Za-z0-9_-]+\}", full_html):
        errors.append(f"{out_path}: raw {{#...}} anchor token leaked into HTML")

    for pre_match in re.finditer(r"<pre\b[^>]*><code\b[^>]*>(.*?)</code></pre>", full_html, re.DOTALL):
        code_inner = pre_match.group(1)
        if re.search(r"<(?:p|h[1-6]|pre)\b", code_inner):
            errors.append(f"{out_path}: HTML block tag leaked inside <pre><code>")

    # Strip <pre>...</pre>, <code>...</code>, and $...$ / $$...$$ before checking bare TeX macros
    prose_only = re.sub(r"<pre\b.*?</pre>", " ", full_html, flags=re.DOTALL)
    prose_only = re.sub(r"<code\b.*?</code>", " ", prose_only, flags=re.DOTALL)
    prose_only = re.sub(r"\$\$.*?\$\$", " ", prose_only, flags=re.DOTALL)
    prose_only = re.sub(r"(?<!\\)\$[^$\n]+\$", " ", prose_only)
    bare = BARE_TEX_MACRO_RE.search(prose_only)
    if bare:
        errors.append(f"{out_path}: un-delimited TeX macro {bare.group(0)!r} found in prose")

    prose_text = re.sub(r"<script\b.*?</script>", " ", prose_only, flags=re.DOTALL)
    prose_text = re.sub(r"<style\b.*?</style>", " ", prose_text, flags=re.DOTALL)
    prose_text = re.sub(r"<[^>]+>", " ", prose_text)
    if re.search(r"\*\*[^\s*][^*\n]*?\*\*", prose_text):
        errors.append(f"{out_path}: unrendered bold Markdown (**...**) found in prose")
    if re.search(r"`[^`\n]+`", prose_text):
        errors.append(f"{out_path}: unrendered inline code Markdown (`...`) found in prose")

    if ("$" in prose_only and re.search(r"\$[^$\n]+\$", full_html)) and "katex.min.js" not in full_html:
        errors.append(f"{out_path}: math delimiters present without KaTeX assets")


def compile_markdown(
    src_path: Path,
    root_dir: Path,
    md: MarkdownIt,
    errors: list[str],
) -> tuple[dict, str, dict[str, bool]]:
    raw = src_path.read_text(encoding="utf-8")
    meta, body = parse_frontmatter(raw, src_path)
    interactive_flags = {"math": False, "mermaid": False}

    body, block_tokens = extract_directives_and_code(
        body, md, src_path, root_dir, errors, interactive_flags
    )
    body, inline_tokens = protect_inline_code_and_math(body, interactive_flags)
    body = rewrite_and_validate_links(body, src_path, root_dir, errors)
    body = rewrite_sidenotes(body, md)

    rendered = md.render(body)
    rendered = HEADING_ANCHOR_RE.sub(r'<h\1 id="\3">\2</h\1>', rendered)
    rendered = enhance_tables(rendered)

    for token, val in inline_tokens.items():
        rendered = rendered.replace(token, val)
    for token, val in block_tokens.items():
        rendered = rendered.replace(token, val)

    return meta, rendered, interactive_flags


def main() -> int:
    parser = argparse.ArgumentParser(description="Build static HTML course site.")
    parser.add_argument("--out-dir", type=Path, default=Path("."), help="Output directory")
    parser.add_argument("--check", action="store_true", help="Fail on validation errors")
    args = parser.parse_args()

    root_dir = Path.cwd().resolve()
    out_dir = args.out_dir.resolve()
    md = MarkdownIt("commonmark", {"html": True, "typographer": False}).enable(["table", "strikethrough"])
    errors: list[str] = []

    lessons_meta: list[dict] = []
    for idx, lesson_path in enumerate(sorted((root_dir / "lessons").glob("[0-9][0-9][0-9][0-9]-*.md"))):
        meta, body_html, flags = compile_markdown(lesson_path, root_dir, md, errors)
        num_match = re.match(r"^(\d{4})-", lesson_path.name)
        meta["num"] = num_match.group(1) if num_match else f"{idx + 1:04d}"
        meta["index"] = idx
        meta["out_rel"] = target_output_rel(lesson_path, root_dir).as_posix()
        meta["src_path"] = lesson_path
        meta["body_html"] = body_html
        meta["flags"] = flags
        lessons_meta.append(meta)

    refs_meta: list[dict] = []
    ref_files = sorted((root_dir / "reference").glob("*.md"))
    # Put Glossary first if present, then others alphabetically
    ref_files.sort(key=lambda p: (0 if p.name == "GLOSSARY.md" else 1, p.name))
    for ref_path in ref_files:
        meta, body_html, flags = compile_markdown(ref_path, root_dir, md, errors)
        meta["out_rel"] = target_output_rel(ref_path, root_dir).as_posix()
        meta["src_path"] = ref_path
        meta["body_html"] = body_html
        meta["flags"] = flags
        refs_meta.append(meta)

    index_path = root_dir / "index.md"
    index_meta, index_body, index_flags = compile_markdown(index_path, root_dir, md, errors)
    index_body = index_body.replace(
        "{{widget:lesson-cards}}", build_lesson_cards_html(lessons_meta, md)
    )
    index_body = index_body.replace(
        "{{widget:reference-cards}}", build_reference_cards_html(refs_meta, md)
    )

    pages_to_write: list[tuple[Path, str]] = []

    index_html = render_page_shell(
        index_meta,
        index_body,
        build_nav_html("index", index_meta, lessons_meta, refs_meta, ""),
        "",
        "",
        index_flags["math"],
        index_flags["mermaid"],
    )
    pages_to_write.append((out_dir / "index.html", index_html))

    for lesson in lessons_meta:
        nav_html = build_nav_html("lesson", lesson, lessons_meta, refs_meta, "../")
        pager_html = build_lesson_pager_html(lesson, lessons_meta, "../")
        full_html = render_page_shell(
            lesson,
            lesson["body_html"],
            nav_html,
            pager_html,
            "../",
            lesson["flags"]["math"],
            lesson["flags"]["mermaid"],
        )
        pages_to_write.append((out_dir / lesson["out_rel"], full_html))

    for ref in refs_meta:
        nav_html = build_nav_html("ref", ref, lessons_meta, refs_meta, "../")
        full_html = render_page_shell(
            ref,
            ref["body_html"],
            nav_html,
            "",
            "../",
            ref["flags"]["math"],
            ref["flags"]["mermaid"],
        )
        pages_to_write.append((out_dir / ref["out_rel"], full_html))

    for out_path, content in pages_to_write:
        validate_rendered_html(out_path, content, errors)

    if args.check and errors:
        for err in errors:
            print(f"[ERROR] {err}", file=sys.stderr)
        return 1

    if out_dir != root_dir:
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / ".nojekyll").write_text("", encoding="utf-8")
        assets_dst = out_dir / "assets"
        if assets_dst.exists():
            shutil.rmtree(assets_dst)
        shutil.copytree(root_dir / "assets", assets_dst)

    for out_path, content in pages_to_write:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(content, encoding="utf-8")
        print(f"[BUILT] {out_path.relative_to(out_dir)}")

    if errors:
        for err in errors:
            print(f"[WARN] {err}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
