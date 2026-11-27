---
title: "Assembling & Linking 6502 Programs with ca65 and ld65"
page_title: "Lesson 0010: Assembling & Linking 6502 Programs with ca65 and ld65 — Build Your Own 6502"
nav_id: "lesson-0010"
badge: "Lesson 0010 • cc65 Assembler & Linker"
subtitle: "Automate 6502 assembly with ca65, configure our 16 KB ROM layout in ld65's memory.cfg, inspect unresolved relocation markers, and trace the 11-cycle counting loop on paper."
card:
  title: "**Assembling & Linking 6502 Programs with ca65 and ld65**"
  summary: "Assemble count.s with ca65, link a 16 KB ROM image with ld65 memory.cfg, inspect relocation markers, and trace exact clock cycles."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0010-ca65-ld65-toolchain/` (`make -C apps/0010-ca65-ld65-toolchain clean all`)
- **Video reference**: [Episode 10: Assembling Our First 6502 Program with ca65 and ld65](https://www.youtube.com/watch?v=GZObLHEx75E)
- **Toolchain manuals**: [`ca65` Macro Assembler](https://cc65.github.io/doc/ca65.html), [`ld65` Linker](https://cc65.github.io/doc/ld65.html), and [`da65` Disassembler](https://cc65.github.io/doc/da65.html)
- **Course references**: [Lesson 9](0009-hand-assembled-6502.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Why Split Assembly and Linking (`ca65` → `ld65` → `rom.mem`)

Hand-assembling 11 bytes in [Lesson 9](0009-hand-assembled-6502.md) was fun right up until you imagine inserting a single `NOP` before `loop:`—suddenly `$C002` shifts to `$C003`, and every jump target after it breaks.

The `cc65` suite solves this cleanly by splitting machine-code generation into two distinct tools:

```mermaid caption="Figure 10.1: From human-readable 6502 assembly to a Verilog $readmemh ROM image"
flowchart LR
  S["count.s<br/>Symbolic 6502 assembly"] -->|"ca65 -l build/count.lst"| O["build/count.o<br/>Relocatable object file<br/>(4C rr rr placeholders)"]
  CFG["memory.cfg<br/>ZP, RAM &amp; 16 KB ROM map"] -->|"ld65 -C memory.cfg"| BIN["build/count.bin<br/>16,384-byte padded ROM"]
  O -->|"ld65 resolves labels"| BIN
  BIN -->|"bin2mem.py"| MEM["build/rom.mem<br/>16,384 hex lines for Verilog"]
  BIN -->|"da65 --start-addr 0xC000"| DIS["Verified 6502 disassembly"]
```

- **`ca65` (Assembler)**: Translates instructions, expressions, and symbolic labels inside a single `.s` file into a **relocatable object file** (`.o`). Because `ca65` does not yet know where the linker will place the `CODE` segment in memory, local labels like `loop` stay unresolved.
- **`ld65` (Linker)**: Reads your `memory.cfg` layout script, assigns `CODE` to physical address `$C000`, patches every relocatable reference (`rr rr`) with its true little-endian address, and pads the output to an exact `16,384`-byte ROM image (`$4000` bytes).
- **`bin2mem.py` (Formatter)**: Converts the raw binary into `16,384` uppercase two-digit hex lines (`rom.mem`) ready for Verilog's `$readmemh` in Lesson 11.

## 2. Writing `count.s` & Symbolic Labels

In `count.s`, we replace hard-coded addresses with meaningful symbols: `LEDS` names our memory-mapped LED register at `$8000`, and `loop:` lets `jmp loop` track its target automatically no matter how much code sits above it.

### Block 1: Constants, Segments & Labels (`count.s`)

```asm6502 caption="Symbolic LED port constant and CODE segment in count.s"
LEDS = $8000

.segment "CODE"
reset:
        lda #$00
loop:
        sta LEDS
        clc
        adc #$01
        jmp loop
```

- `LEDS = $8000` defines a compile-time constant (no ROM bytes emitted).
- `.segment "CODE"` tells `ca65` which logical bucket owns the following bytes; `ld65` decides where `"CODE"` lands in physical memory.
- Notice `reset:` and `loop:` end with colons (`:`) to declare address labels. Even though `LEDS` is known immediately (`8D 00 80`), `loop` depends on where `"CODE"` starts—which `ca65` intentionally leaves flexible.

### Complete `count.s` Listing

```asm6502 caption="apps/0010-ca65-ld65-toolchain/count.s"
LEDS = $8000

.segment "CODE"
reset:
        lda #$00
loop:
        sta LEDS
        clc
        adc #$01
        jmp loop
```

## 3. Telling `ld65` Where Memory Lives (`memory.cfg` & `bin2mem.py`)

`ld65` knows nothing about our Tang Nano 20K's custom memory map until we describe it in `memory.cfg`. The configuration has two halves: **`MEMORY`** declares physical address regions, and **`SEGMENTS`** routes assembly segments into those regions.

### Block 1: Physical `MEMORY` Regions (`memory.cfg`)

```text caption="Declaring Zero Page, RAM, and 16 KB padded ROM in memory.cfg"
MEMORY {
    ZP:  start = $0000, size = $0100, type = rw, file = "";
    RAM: start = $0200, size = $7E00, type = rw, file = "";
    ROM: start = $C000, size = $4000, type = ro, fill = yes, fillval = $00, file = %O;
}
```

- `file = ""` on `ZP` and `RAM` tells `ld65` *not* to emit bytes for read/write RAM into our ROM output file.
- `ROM` starts at `$C000` with size `$4000` (`16,384` bytes), `fill = yes`, and `fillval = $00`, guaranteeing `count.bin` is always a full `16` KB image for our future Verilog `rom.v` module.

### Block 2: Routing `SEGMENTS` into Regions (`memory.cfg`)

```text caption="Mapping logical assembly segments into physical memory areas"
SEGMENTS {
    ZEROPAGE: load = ZP,  type = zp,  optional = yes;
    BSS:      load = RAM, type = bss, optional = yes;
    CODE:     load = ROM, type = ro;
    RODATA:   load = ROM, type = ro,  optional = yes;
    VECTORS:  load = ROM, type = ro,  start = $FFFA, optional = yes;
}
```

- Marking `ZEROPAGE`, `BSS`, `RODATA`, and `VECTORS` as `optional = yes` keeps `ld65` happy now while reserving clean homes for variables, lookup tables, and hardware vectors in later lessons.{{sidenote:Because `VECTORS` sits at `` `$FFFA` `` inside our `16` KB `ROM`, later episodes can drop `.word reset` into `.segment "VECTORS"` without touching `memory.cfg` again.}}

### Complete `memory.cfg` Configuration

```text caption="apps/0010-ca65-ld65-toolchain/memory.cfg"
MEMORY {
    ZP:  start = $0000, size = $0100, type = rw, file = "";
    RAM: start = $0200, size = $7E00, type = rw, file = "";
    ROM: start = $C000, size = $4000, type = ro, fill = yes, fillval = $00, file = %O;
}

SEGMENTS {
    ZEROPAGE: load = ZP,  type = zp,  optional = yes;
    BSS:      load = RAM, type = bss, optional = yes;
    CODE:     load = ROM, type = ro;
    RODATA:   load = ROM, type = ro,  optional = yes;
    VECTORS:  load = ROM, type = ro,  start = $FFFA, optional = yes;
}
```

### Complete `bin2mem.py` Script

```python caption="apps/0010-ca65-ld65-toolchain/bin2mem.py"
#!/usr/bin/env python3
"""Convert a 16 KB ld65 ROM binary into a $readmemh .mem file and 11-byte code slice."""

from __future__ import annotations

import sys
from pathlib import Path

EXPECTED_CODE = bytes([0xA9, 0x00, 0x8D, 0x00, 0x80, 0x18, 0x69, 0x01, 0x4C, 0x02, 0xC0])
ROM_SIZE = 16384


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: bin2mem.py <input.bin> <output.mem> <code.bin>", file=sys.stderr)
        return 2

    in_path, mem_path, code_path = (Path(p) for p in sys.argv[1:4])
    data = in_path.read_bytes()
    assert len(data) == ROM_SIZE, f"expected {ROM_SIZE} bytes, got {len(data)}"
    assert data[: len(EXPECTED_CODE)] == EXPECTED_CODE, (
        f"code bytes {data[:len(EXPECTED_CODE)].hex(' ')} != {EXPECTED_CODE.hex(' ')}"
    )
    assert all(b == 0x00 for b in data[len(EXPECTED_CODE) :]), "expected zero-padded ROM tail"

    mem_path.write_text("".join(f"{b:02X}\n" for b in data), encoding="utf-8")
    code_path.write_bytes(data[: len(EXPECTED_CODE)])
    print(f"PASS: {in_path.name} ({len(data)} bytes) -> {mem_path.name} ({ROM_SIZE} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

## 4. Relocation in Action (`count.lst` vs `count.map`)

Running `ca65 -l build/count.lst count.s -o build/count.o` lets us peek *inside* the gap between assembling and linking. Look at line `000008r` of `build/count.lst`:

```text caption="Actual ca65 listing output (build/count.lst) before linking"
000000r 1               LEDS = $8000
000000r 1
000000r 1               .segment "CODE"
000000r 1               reset:
000000r 1  A9 00                lda #$00
000002r 1               loop:
000002r 1  8D 00 80             sta LEDS
000005r 1  18                   clc
000006r 1  69 01                adc #$01
000008r 1  4C rr rr             jmp loop
```

Look closely at those two lines:
- `sta LEDS` already displays `8D 00 80`, because `LEDS = $8000` is an absolute numeric constant.
- `jmp loop`, however, prints **`4C rr rr`**! Those `rr rr` bytes mark an **unresolved relocatable address**—`ca65` recorded *"offset `0x0002` inside segment `CODE`"* inside `count.o` and left the final two bytes for `ld65`.

Once `ld65 -C memory.cfg -m build/count.map` runs, `build/count.map` confirms `CODE` lives at `00C000..00C00A` (`Size = 00000B`, i.e., `11` bytes), so `ld65` patches `4C rr rr` into **`4C 02 C0`**—an exact byte-for-byte match with our hand-assembled program from Lesson 9!

## 5. Pencil-and-Paper Cycle-by-Cycle Execution Trace

Before we wire a single flip-flop of our Verilog CPU, let's trace what a real NMOS 6502 puts on the address and data buses on *every single clock cycle*. On the real 6502, **every clock cycle performs one memory read or write**—there are no silent internal cycles:

Table: Cycle-by-Cycle Bus Trace of Our Counting Program

| Cycle | Phase | Address Bus | R/W | Data Bus | Internal CPU Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `1` | `LDA #$00` (1/2) | `$C000` | Read | `$A9` | Fetch `LDA #imm` opcode |
| `2` | `LDA #$00` (2/2) | `$C001` | Read | `$00` | Fetch immediate operand `#$00`, load `A <- $00` |
| `3` | `STA $8000` (1/4) | `$C002` | Read | `$8D` | Fetch `STA abs` opcode (`loop:` entry point) |
| `4` | `STA $8000` (2/4) | `$C003` | Read | `$00` | Fetch low address byte (`$00`) |
| `5` | `STA $8000` (3/4) | `$C004` | Read | `$80` | Fetch high address byte (`$80`) |
| `6` | `STA $8000` (4/4) | `$8000` | **Write** | `$00` | Write `A` (`$00`) to LED port `$8000` |
| `7` | `CLC` (1/2) | `$C005` | Read | `$18` | Fetch `CLC` opcode |
| `8` | `CLC` (2/2) | `$C006` | Read | `$69` | **Dummy read** of next byte while clearing `C <- 0` |
| `9` | `ADC #$01` (1/2) | `$C006` | Read | `$69` | Fetch `ADC #imm` opcode |
| `10` | `ADC #$01` (2/2) | `$C007` | Read | `$01` | Fetch `#$01`, compute `A <- A + 1 + C` |
| `11` | `JMP $C002` (1/3) | `$C008` | Read | `$4C` | Fetch `JMP abs` opcode |
| `12` | `JMP $C002` (2/3) | `$C009` | Read | `$02` | Fetch low target byte (`$02`) |
| `13` | `JMP $C002` (3/3) | `$C00A` | Read | `$C0` | Fetch high target byte (`$C0`), load `PC <- $C002` |

Add up the loop body (`STA`: `4` + `CLC`: `2` + `ADC`: `2` + `JMP`: `3`):

$$4 + 2 + 2 + 3 = 11\text{ clock cycles per loop iteration}$$

Notice Cycle `8` during `CLC`: even though `CLC` is a 1-byte implied instruction, the real 6502 **always takes at least 2 cycles** and reads the byte at `$C006` *twice*—once as a throwaway dummy read in Cycle `8`, then again to actually fetch `ADC` in Cycle `9`. Remember that quirk; we will faithfully build that exact "Two-Read Rule" into our CPU sequencer in Part 4!

---

:::exercise id="ex-0010" title="Interactive Lab: Configure ld65's 16 KB ROM Layout" badge="Skill Practice • Linker Configuration"
Complete the `ROM` memory area and `CODE` segment mapping in `memory.cfg` so `ld65` places our program at `$C000`, pads it to `16,384` bytes (`$4000`), and fills unused bytes with `$00`:

```text
MEMORY {
    ZP:  start = $0000, size = $0100, type = rw, file = "";
    RAM: start = $0200, size = $7E00, type = rw, file = "";
    ROM: start = {{blank:$C000|ROM start address|$????|5}}, size = {{blank:$4000|16 KB in hex|$????|5}}, type = ro, fill = {{blank:yes|Pad entire ROM image|???|3}}, fillval = $00, file = %O;
}

SEGMENTS {
    CODE: load = {{blank:ROM|Target MEMORY region|???|3}}, type = ro;
}
```

:::prompts
hint: "16 KB is `16384 = 0x4000`, starting at `$C000`. Set `fill = yes` so `ld65` pads out all 16 KB, and route `CODE` into `ROM`."
success: "Clean linker layout! Every byte of your 16 KB ROM image now lands at its exact hardware address."
:::
:::

:::quiz id="quiz-0010" title="Retrieval Practice: ca65, ld65 Relocation & Cycle Timing" badge="3 Questions • Equal-Length Options"
- question: "Why does `build/count.lst` show `4C rr rr` for `jmp loop` even though `sta LEDS` already shows `8D 00 80`?"
  wrong_hint: "Compare a fixed numeric constant (`LEDS = $8000`) against a label inside a relocatable segment (`CODE`)."
  options:
    - letter: "A"
      text: "Because loop depends on where ld65 places CODE, whereas LEDS is a fixed constant."
      correct: true
      explain: "Correct: `ca65` resolves constant symbols immediately, while segment-relative labels like `loop` remain relocatable (`rr rr`) until `ld65` assigns `CODE` to `0xC000`."
    - letter: "B"
      text: "Because jump instructions never encode target addresses until runtime inside the FPGA block RAM."
      correct: false
      explain: "`ld65` resolves all static jump targets at link time before the ROM image is ever packed."
    - letter: "C"
      text: "Because ca65 reserves the letters rr inside listing files whenever a label uses lowercase."
      correct: false
      explain: "Case has nothing to do with it; `rr` stands for relocatable byte in `ca65` listing output."
    - letter: "D"
      text: "Because zero-page symbols always require two extra linker passes before absolute opcodes compile cleanly."
      correct: false
      explain: "Neither `LEDS` nor `loop` is in Zero Page; `jmp loop` simply waits for `ld65` segment placement."
- question: "How many total clock cycles does one pass through our 4-instruction loop (`STA $8000`, `CLC`, `ADC #$01`, `JMP $C002`) take on a real 6502?"
  wrong_hint: "Add the cycle counts of `STA abs` (`4`), `CLC` (`2`), `ADC #imm` (`2`), and `JMP abs` (`3`)."
  options:
    - letter: "A"
      text: "Nine cycles per loop, one cycle for each byte fetched."
      correct: false
      explain: "Loop instructions total `9` bytes, but `STA` needs a 4th cycle to write `$8000` and `CLC` takes `2` cycles."
    - letter: "B"
      text: "Eleven cycles per loop: four, two, two, and three cycles."
      correct: true
      explain: "Correct: `4 + 2 + 2 + 3 = 11` clock cycles per iteration (after the initial 2-cycle `LDA #$00`)."
    - letter: "C"
      text: "Eight cycles per loop, skipping the dummy read on clear."
      correct: false
      explain: "A real NMOS 6502 always executes the 2nd cycle of `CLC`, never finishing any instruction in 1 cycle."
    - letter: "D"
      text: "Sixteen cycles per loop, matching four cycles for every instruction."
      correct: false
      explain: "`CLC` and `ADC #imm` take `2` cycles each and `JMP abs` takes `3`, not `4`."
- question: "In `memory.cfg`, why do we set `file = \"\"` on `ZP` and `RAM` while setting `fill = yes` on `ROM`?"
  wrong_hint: "Think about what belongs inside the 16 KB `.bin` image loaded into ROM."
  options:
    - letter: "A"
      text: "So ld65 outputs only the padded 16 KB ROM image without RAM bytes."
      correct: true
      explain: "Correct: RAM starts at `0x0000` and is empty SRAM on hardware; omitting `file` keeps `count.bin` an exact 16,384-byte ROM image."
    - letter: "B"
      text: "So ca65 encrypts zero-page variables before placing them inside the final ROM binary."
      correct: false
      explain: "`memory.cfg` controls `ld65` layout and output files, not encryption."
    - letter: "C"
      text: "So da65 automatically skips disassembling instructions stored inside the first 256 zero-page bytes."
      correct: false
      explain: "`da65` only reads the binary you pass it; `file = \"\"` controls what `ld65` writes."
    - letter: "D"
      text: "So openFPGALoader flashes RAM contents directly over USB instead of configuring FPGA LUTs."
      correct: false
      explain: "`openFPGALoader` programs the FPGA bitstream (`.fs`), which only embeds ROM initialisation from `rom.mem`."
:::

:::verify id="verify-0010" title="Verification Lab: Assemble, Link, Disassemble & Inspect Relocation" badge="Terminal Gate"
Assemble `count.s` with `ca65`, link the 16 KB padded ROM with `ld65`, convert it to `build/rom.mem`, and inspect the listing, memory map, and `da65` output:

```bash caption="Build and inspect the Lesson 10 cc65 pipeline"
make -C apps/0010-ca65-ld65-toolchain clean all
make -C apps/0010-ca65-ld65-toolchain inspect
```

- [ ] `make -C apps/0010-ca65-ld65-toolchain clean all` succeeds with zero warnings and prints `PASS: count.bin (16384 bytes) -> rom.mem (16384 lines)` and `PASS: ca65/ld65/da65 verified 16 KB ROM and 11-byte loop`.
- [ ] `make inspect` shows `4C rr rr` for `jmp loop` inside `build/count.lst`, `CODE` placed at `00C000..00C00A` inside `build/count.map`, and `4C 02 C0` resolved inside `build/rom.mem` and `da65`.
:::

:::teacher-prompt title="Next Up: Lesson 11 (ROM, RAM & the System Bus in Verilog)"
Now that `ca65` and `ld65` can build real 16 KB `rom.mem` images on demand, it is time to switch back to Verilog and give our computer its physical memory and system bus! Ask any questions about linker scripts, relocation, or the 11-cycle bus trace, or continue to Lesson 11 to build `rom.v`, `ram.v`, and `bus.v` across 24 Gowin Block RAMs.
:::
