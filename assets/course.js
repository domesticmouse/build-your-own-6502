(() => {
  "use strict";

  function initCodeAccessibility() {
    document.querySelectorAll(".code-figure pre, pre").forEach((pre) => {
      if (!pre.hasAttribute("tabindex")) {
        pre.setAttribute("tabindex", "0");
      }
    });
  }

  function initMermaidAndMath() {
    if (window.mermaid) {
      window.mermaid.initialize({ startOnLoad: true, theme: "dark" });
    }
    if (window.renderMathInElement) {
      window.renderMathInElement(document.body, {
        delimiters: [
          { left: "$$", right: "$$", display: true },
          { left: "$", right: "$", display: false }
        ],
        ignoredTags: ["script", "noscript", "style", "textarea", "pre", "code", "option"]
      });
    }
  }

  function initSidenotes() {
    document.querySelectorAll(".sidenote-toggle").forEach((btn) => {
      btn.addEventListener("click", () => {
        const targetId = btn.getAttribute("aria-controls");
        const note = targetId ? document.getElementById(targetId) : null;
        if (!note) return;
        const expanded = btn.getAttribute("aria-expanded") === "true";
        btn.setAttribute("aria-expanded", String(!expanded));
        note.classList.toggle("is-open", !expanded);
      });
    });
  }

  function normalizeAnswer(val) {
    return val.trim().replace(/\s+/g, " ");
  }

  function initExercises() {
    document.querySelectorAll("[data-exercise]").forEach((panel) => {
      const inputs = Array.from(panel.querySelectorAll(".blank-input"));
      const checkBtn = panel.querySelector("[data-action='check']");
      const hintBtn = panel.querySelector("[data-action='hint']");
      const resetBtn = panel.querySelector("[data-action='reset']");
      const feedback = panel.querySelector(".panel-feedback");
      const hintText = panel.dataset.hint || "";
      const successText = panel.dataset.success || "All blanks verified!";

      function setFeedback(kind, msg) {
        if (!feedback) return;
        feedback.hidden = false;
        feedback.className = `panel-feedback is-${kind}`;
        feedback.textContent = msg;
      }

      if (checkBtn) {
        checkBtn.addEventListener("click", () => {
          let allCorrect = true;
          let firstHint = "";
          inputs.forEach((input) => {
            const expectedRaw = input.dataset.answer || "";
            const accepted = expectedRaw.split("||").map(normalizeAnswer);
            const actual = normalizeAnswer(input.value);
            const ok = accepted.includes(actual);
            input.classList.toggle("is-correct", ok);
            input.classList.toggle("is-wrong", !ok);
            if (!ok) {
              allCorrect = false;
              if (!firstHint && input.dataset.hint) {
                firstHint = input.dataset.hint;
              }
            }
          });
          if (allCorrect) {
            setFeedback("success", successText);
          } else {
            setFeedback("error", firstHint || "One or more blanks need another look.");
          }
        });
      }

      if (hintBtn) {
        hintBtn.addEventListener("click", () => {
          setFeedback("hint", hintText || "Review the code blocks above.");
        });
      }

      if (resetBtn) {
        resetBtn.addEventListener("click", () => {
          inputs.forEach((input) => {
            input.value = "";
            input.classList.remove("is-correct", "is-wrong");
          });
          if (feedback) {
            feedback.hidden = true;
            feedback.textContent = "";
          }
        });
      }
    });
  }

  function initQuizzes() {
    document.querySelectorAll("[data-quiz]").forEach((panel) => {
      const questions = Array.from(panel.querySelectorAll(".quiz-question"));
      const summary = panel.querySelector(".panel-feedback");
      const resetBtn = panel.querySelector("[data-action='reset-quiz']");

      function updateScore() {
        const answered = questions.filter((q) => q.dataset.answered === "true").length;
        const correct = questions.filter((q) => q.dataset.correct === "true").length;
        if (summary && answered === questions.length && questions.length > 0) {
          summary.hidden = false;
          summary.className =
            correct === questions.length
              ? "panel-feedback is-success"
              : "panel-feedback is-hint";
          summary.textContent = `Score: ${correct} / ${questions.length} correct.`;
        }
      }

      questions.forEach((q) => {
        const buttons = Array.from(q.querySelectorAll(".quiz-option"));
        const explain = q.querySelector(".quiz-explain");
        const wrongHint = q.dataset.wrongHint || "";

        buttons.forEach((btn) => {
          btn.addEventListener("click", () => {
            const isCorrect = btn.dataset.correct === "true";
            buttons.forEach((b) => b.classList.remove("is-selected", "is-correct", "is-wrong"));
            btn.classList.add("is-selected", isCorrect ? "is-correct" : "is-wrong");
            q.dataset.answered = "true";
            q.dataset.correct = String(isCorrect);
            if (explain) {
              explain.hidden = false;
              explain.textContent = isCorrect
                ? btn.dataset.explain || "Correct."
                : `${btn.dataset.explain || "Not quite."} ${wrongHint}`.trim();
            }
            updateScore();
          });
        });
      });

      if (resetBtn) {
        resetBtn.addEventListener("click", () => {
          questions.forEach((q) => {
            delete q.dataset.answered;
            delete q.dataset.correct;
            q.querySelectorAll(".quiz-option").forEach((b) => {
              b.classList.remove("is-selected", "is-correct", "is-wrong");
            });
            const explain = q.querySelector(".quiz-explain");
            if (explain) {
              explain.hidden = true;
              explain.textContent = "";
            }
          });
          if (summary) {
            summary.hidden = true;
            summary.textContent = "";
          }
        });
      }
    });
  }

  function initVerifyChecklists() {
    document.querySelectorAll("[data-verify]").forEach((panel) => {
      const panelId = panel.id || "verify";
      panel.querySelectorAll(".verify-check").forEach((cb, idx) => {
        const key = `byo6502:${panelId}:step:${idx}`;
        try {
          if (localStorage.getItem(key) === "1") {
            cb.checked = true;
          }
          cb.addEventListener("change", () => {
            localStorage.setItem(key, cb.checked ? "1" : "0");
          });
        } catch (_err) {
          // Ignore storage errors in restricted contexts
        }
      });
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    initCodeAccessibility();
    initSidenotes();
    initExercises();
    initQuizzes();
    initVerifyChecklists();
    initMermaidAndMath();
  });
})();
