---
title: "6502 Registers, Memory Map & Hand-Assembled Machine Code"
page_title: "Lesson 0009: 6502 Registers, Memory Map & Hand-Assembled Machine Code — Build Your Own 6502"
nav_id: "lesson-0009"
badge: "Lesson 0009 • 6502 Architecture & Machine Code"
subtitle: "Map out the 6502's six internal registers and 64 KB address space, write a five-instruction LED counter, and assemble all 11 bytes by hand using little-endian encoding."
card:
  title: "**6502 Registers, Memory Map & Hand-Assembled Machine Code**"
  summary: "Learn the 6502 programmer's model, design our 64 KB memory map, and hand-assemble an 11-byte machine-code LED counter."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0009-hand-assembled-6502/` (`make -C apps/0009-hand-assembled-6502 clean all`)
- **Video reference**: [Episode 9: Our First 6502 Program: Machine Code, Assembled by Hand](https://www.youtube.com/watch?v=tfPIlLQfTQE)
- **Architecture & assembler references**: [`64doc` — NMOS 6502/6510 Reference](https://www.nesdev.org/6502_cpu.txt) and [cc65 Disassembler (`da65`) Docs](https://cc65.github.io/doc/da65.html)
- **Course references**: [Lesson 8](0008-video-card-framebuffer.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. The 6502 Programmer's Model & Fetch-Decode-Execute Cycle

In Part 2 we built an HDMI video card capable of scanning `320×200` pixels in 16 C64 colours. Now we pivot to the brain of the computer: the **MOS 6502** processor. If your 6502 assembly is forty years rusty, the wonderful surprise is how tiny the chip actually is—there are only six programmer-visible registers in the entire core:

```mermaid caption="Figure 9.1: MOS 6502 internal registers and the fetch-decode-execute loop"
flowchart LR
  subgraph REGS["Internal CPU Registers"]
    PC["PC (16-bit)<br/>Program Counter"]
    A["A (8-bit)<br/>Accumulator"]
    X["X (8-bit)<br/>Index Register"]
    Y["Y (8-bit)<br/>Index Register"]
    S["S (8-bit)<br/>Stack Pointer"]
    P["P (8-bit)<br/>Status Flags<br/>N V - B D I Z C"]
  end
  F["1. Fetch<br/>Read byte at PC"] --> D["2. Decode<br/>Identify opcode & mode"]
  D --> E["3. Execute<br/>Read/ALU/Write & advance PC"]
  E --> F
```

Unlike modern 64-bit CPUs with dozens of general-purpose registers, almost all arithmetic on a 6502 funnels through a single 8-bit workhorse called the **Accumulator (`A`)**. Every instruction moves through the same **fetch-decode-execute** rhythm:

1. **Fetch**: Put the 16-bit **Program Counter (`PC`)** on the address bus, read the next opcode byte, and increment `PC`.
2. **Decode**: Examine that 8-bit opcode to determine *what operation* to run and *how many operand bytes* follow it.
3. **Execute**: Fetch any operand bytes, perform the arithmetic, load, store, or jump, and update the **Status Register (`P`)** flags.

Table: The Eight Bits of the 6502 Status Register (`P`)

| Bit | Flag | Name | Meaning |
| :--- | :--- | :--- | :--- |
| `7` | `N` | Negative | Mirrors bit `7` of the last result (`1` = signed negative) |
| `6` | `V` | Overflow | Signed arithmetic overflow out of bit `6` into bit `7` |
| `5` | `-` | Unused | Always reads as `1` when pushed to the stack |
| `4` | `B` | Break | Distinguishes software `BRK` from hardware `IRQ` on stack |
| `3` | `D` | Decimal | Switches `ADC` and `SBC` into Binary Coded Decimal (BCD) mode |
| `2` | `I` | Interrupt Disable | Masks external `IRQ` interrupts when `1` |
| `1` | `Z` | Zero | Set to `1` when the last result equals `0x00` |
| `0` | `C` | Carry | Unsigned carry-out from `ADC`, or inverted borrow for `SBC` |

## 2. Our 6502 Computer's 64 KB Memory Map

The 6502 has a **16-bit address bus** (`A15..A0`), allowing it to address $2^{16} = 65{,}536$ bytes (`$0000` through `$FFFF`). On the 6502, *everything*—RAM, ROM, and hardware peripherals like our Tang Nano 20K LEDs—shares this single 64 KB address space. There are no separate I/O port instructions (`IN`/`OUT`).{{sidenote:Keeping all peripherals inside the normal 64 KB address space is called **memory-mapped I/O**. Writing to `` `$8000` `` uses the exact same `STA` instruction as writing to RAM at `` `$0200` ``; only the bus address decoder cares which physical hardware answers.}}

Table: System Memory Map (`$0000`–`$FFFF`)

| Address Range | Size | Region | Purpose in Our Computer |
| :--- | :--- | :--- | :--- |
| `$0000`–`$00FF` | `256` B | Zero Page (RAM) | Fast 2-byte instructions and indirect pointers |
| `$0100`–`$01FF` | `256` B | Hardware Stack (RAM) | Descending Page 1 stack indexed by `S` |
| `$0200`–`$7FFF` | `31.5` KB | General RAM | Program variables and user data (`32` KB total RAM) |
| `$8000` | `1` B | LED Output Port | Memory-mapped register driving onboard LEDs |
| `$8001`–`$BFFF` | `~16` KB | Reserved I/O Space | Future peripherals (UART, video card control) |
| `$C000`–`$FFF9` | `~16` KB | Program ROM | Machine code and read-only tables (`16` KB total ROM) |
| `$FFFA`–`$FFFF` | `6` B | Hardware Vectors | `NMI` (`$FFFA`), `RESET` (`$FFFC`), `IRQ/BRK` (`$FFFE`) |

Look closely at the top two address bits (`A15` and `A14`):
- Every address with `A15 = 0` (`$0000`–`$7FFF`) lands in the **32 KB RAM**.
- Every address with `A15 = 1, A14 = 0` (`$8000`–`$BFFF`) lands in **I/O space**, where `$8000` controls our LEDs.
- Every address with `A15 = 1, A14 = 1` (`$C000`–`$FFFF`) lands in the **16 KB ROM**.

That clean power-of-two split will make our Verilog address decoder in Lesson 11 just two logic gates!

## 3. Our First 6502 Program & Addressing Modes

Before touching an assembler, let's write a real five-instruction program that counts in binary on the Tang Nano 20K's LEDs starting from ROM address `$C000`:

```asm6502 caption="Our first 6502 counting loop (starting at $C000)"
        LDA #$00        ; Load 0 into Accumulator A (Immediate mode)
loop:
        STA $8000       ; Write A to memory-mapped LEDs (Absolute mode)
        CLC             ; Clear Carry flag before adding (Implied mode)
        ADC #$01        ; Add 1 + Carry to A (Immediate mode)
        JMP $C002       ; Jump back to loop: at $C002 (Absolute mode)
```

Notice three **addressing modes** in just five lines:

1. **Immediate (`#$00`, `#$01`)**: The `#` prefix means *"use the literal constant stored in the very next byte of ROM"*, not a memory address. Leaving off `#` (`LDA $00` instead of `LDA #$00`) is the classic 6502 beginner bug—it reads whatever sits in Zero Page address `$0000` instead of loading zero!
2. **Absolute (`$8000`, `$C002`)**: A full 16-bit target address follows the opcode in the next two bytes.
3. **Implied (`CLC`)**: The instruction needs zero operand bytes because the target (`C` flag in `P`) is implied by the opcode itself.

:::callout-warn title="Why CLC Is Mandatory Before ADC"
The 6502 has **no plain `ADD` instruction**—only `ADC` (**Ad**d with **C**arry), which always computes `A + operand + C`. When `A` wraps from `$FF` (`255`) back to `$00`, `ADC #$01` sets the Carry flag `C = 1`. Without `CLC` inside the loop, the very next pass would add `0 + 1 + 1 = 2`, skipping `1` forever!
:::

## 4. Hand-Assembling All 11 Bytes & Little-Endian Encoding

Back in 1975, plenty of hobbyists entered programs into a monitor keypad one hex byte at a time. Doing it by hand once guarantees you never forget what an assembler actually emits.

Looking up each instruction + addressing mode in the 6502 opcode table gives us our five opcodes:
- `LDA #imm` → `$A9` (2 bytes: opcode + immediate value)
- `STA abs` → `$8D` (3 bytes: opcode + 16-bit address)
- `CLC` → `$18` (1 byte: opcode only)
- `ADC #imm` → `$69` (2 bytes: opcode + immediate value)
- `JMP abs` → `$4C` (3 bytes: opcode + 16-bit target address)

Now watch **little-endian byte order** on the two 16-bit addresses: the 6502 always expects the **low byte first** and the **high byte second** because it fetches the low address byte while simultaneously preparing the next increment. So `$8000` becomes `00 80`, and `loop:` at `$C002` becomes `02 C0`:

Table: Hand-Assembled Memory Layout at `$C000`–`$C00A` (`11` Bytes)

| Address | Hex Bytes | Instruction | Addressing Mode | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `$C000` | `A9 00` | `LDA #$00` | Immediate | `A <- $00` |
| `$C002` | `8D 00 80` | `STA $8000` | Absolute | `$8000` encoded little-endian as `00 80` |
| `$C005` | `18` | `CLC` | Implied | `C <- 0` before addition |
| `$C006` | `69 01` | `ADC #$01` | Immediate | `A <- A + 1 + C` |
| `$C008` | `4C 02 C0` | `JMP $C002` | Absolute | Target `$C002` encoded as `02 C0` |

We store those 11 bytes directly in `apps/0009-hand-assembled-6502/hand_assembled.mem` (one hex byte per line, ready for Verilog `$readmemh` later) and verify them with a small Python script `verify_hand_asm.py` plus the real `da65` 6502 disassembler.

### Block 1: Loading & Decoding `hand_assembled.mem` (`verify_hand_asm.py`)

```python caption="Loading the 11 hex bytes and decoding little-endian operands"
EXPECTED = [0xA9, 0x00, 0x8D, 0x00, 0x80, 0x18, 0x69, 0x01, 0x4C, 0x02, 0xC0]
BASE_ADDR = 0xC000


def load_mem(path: Path) -> list[int]:
    lines = [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]
    return [int(tok, 16) for tok in lines]


def disassemble_summary(rom: list[int]) -> list[tuple[int, str, str]]:
    led_addr = rom[3] | (rom[4] << 8)
    jmp_addr = rom[9] | (rom[10] << 8)
    return [
        (0xC000, f"{rom[0]:02X} {rom[1]:02X}", f"LDA #${rom[1]:02X}"),
        (0xC002, f"{rom[2]:02X} {rom[3]:02X} {rom[4]:02X}", f"STA ${led_addr:04X}"),
        (0xC005, f"{rom[5]:02X}", "CLC"),
        (0xC006, f"{rom[6]:02X} {rom[7]:02X}", f"ADC #${rom[7]:02X}"),
        (0xC008, f"{rom[8]:02X} {rom[9]:02X} {rom[10]:02X}", f"JMP ${jmp_addr:04X}"),
    ]
```

- Notice `rom[3] | (rom[4] << 8)` reconstructs `$8000` from low byte `0x00` and high byte `0x80`, while `rom[9] | (rom[10] << 8)` reconstructs `$C002` from `0x02` and `0xC0`.

### Block 2: Behavioral Loop Check Across 8-Bit Wraparound (`verify_hand_asm.py`)

```python caption="Stepping through 260 loop passes starting with dirty A=0xFF and C=1"
def simulate(rom: list[int], iterations: int) -> list[int]:
    pc = BASE_ADDR
    a = 0xFF
    c = 1
    writes: list[int] = []

    def fetch() -> int:
        nonlocal pc
        idx = pc - BASE_ADDR
        if not 0 <= idx < len(rom):
            raise AssertionError(f"PC out of ROM bounds: ${pc:04X}")
        val = rom[idx]
        pc += 1
        return val

    while len(writes) < iterations:
        op = fetch()
        if op == 0xA9:  # LDA #imm
            a = fetch()
        elif op == 0x8D:  # STA abs
            lo = fetch()
            hi = fetch()
            addr = lo | (hi << 8)
            assert addr == 0x8000, f"unexpected write address ${addr:04X}"
            writes.append(a)
        elif op == 0x18:  # CLC
            c = 0
        elif op == 0x69:  # ADC #imm
            imm = fetch()
            total = a + imm + c
            c = 1 if total > 0xFF else 0
            a = total & 0xFF
        elif op == 0x4C:  # JMP abs
            lo = fetch()
            hi = fetch()
            pc = lo | (hi << 8)
        else:
            raise AssertionError(f"unexpected opcode ${op:02X}")
    return writes
```

- Starting with `a = 0xFF` and `c = 1` models real uninitialised silicon before `LDA #$00` and `CLC` establish known state, and running `260` iterations verifies `0xFF -> 0x00` wraparound plus carry clearing before `0x00 -> 0x01`.

### Complete `verify_hand_asm.py` Listing

```python caption="apps/0009-hand-assembled-6502/verify_hand_asm.py"
#!/usr/bin/env python3
"""Verify the 11 hand-assembled 6502 machine-code bytes for the LED counter."""

from __future__ import annotations

from pathlib import Path

EXPECTED = [0xA9, 0x00, 0x8D, 0x00, 0x80, 0x18, 0x69, 0x01, 0x4C, 0x02, 0xC0]
BASE_ADDR = 0xC000


def load_mem(path: Path) -> list[int]:
    lines = [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]
    return [int(tok, 16) for tok in lines]


def disassemble_summary(rom: list[int]) -> list[tuple[int, str, str]]:
    led_addr = rom[3] | (rom[4] << 8)
    jmp_addr = rom[9] | (rom[10] << 8)
    return [
        (0xC000, f"{rom[0]:02X} {rom[1]:02X}", f"LDA #${rom[1]:02X}"),
        (0xC002, f"{rom[2]:02X} {rom[3]:02X} {rom[4]:02X}", f"STA ${led_addr:04X}"),
        (0xC005, f"{rom[5]:02X}", "CLC"),
        (0xC006, f"{rom[6]:02X} {rom[7]:02X}", f"ADC #${rom[7]:02X}"),
        (0xC008, f"{rom[8]:02X} {rom[9]:02X} {rom[10]:02X}", f"JMP ${jmp_addr:04X}"),
    ]


def simulate(rom: list[int], iterations: int) -> list[int]:
    pc = BASE_ADDR
    a = 0xFF
    c = 1
    writes: list[int] = []

    def fetch() -> int:
        nonlocal pc
        idx = pc - BASE_ADDR
        if not 0 <= idx < len(rom):
            raise AssertionError(f"PC out of ROM bounds: ${pc:04X}")
        val = rom[idx]
        pc += 1
        return val

    while len(writes) < iterations:
        op = fetch()
        if op == 0xA9:  # LDA #imm
            a = fetch()
        elif op == 0x8D:  # STA abs
            lo = fetch()
            hi = fetch()
            addr = lo | (hi << 8)
            assert addr == 0x8000, f"unexpected write address ${addr:04X}"
            writes.append(a)
        elif op == 0x18:  # CLC
            c = 0
        elif op == 0x69:  # ADC #imm
            imm = fetch()
            total = a + imm + c
            c = 1 if total > 0xFF else 0
            a = total & 0xFF
        elif op == 0x4C:  # JMP abs
            lo = fetch()
            hi = fetch()
            pc = lo | (hi << 8)
        else:
            raise AssertionError(f"unexpected opcode ${op:02X}")
    return writes


def main() -> int:
    app_dir = Path(__file__).resolve().parent
    rom = load_mem(app_dir / "hand_assembled.mem")
    assert len(rom) == 11, f"expected 11 bytes, got {len(rom)}"
    assert rom == EXPECTED, f"mismatch: {rom} != {EXPECTED}"

    print("Addr   Bytes      Instruction")
    for addr, raw, mnem in disassemble_summary(rom):
        print(f"${addr:04X}  {raw:<9}  {mnem}")

    writes = simulate(rom, 260)
    expected_writes = [i & 0xFF for i in range(260)]
    assert writes == expected_writes, "LED output sequence mismatch across wraparound"

    bin_path = app_dir / "build" / "hand_assembled.bin"
    bin_path.parent.mkdir(parents=True, exist_ok=True)
    bin_path.write_bytes(bytes(rom))
    print("PASS: hand_assembled.mem (11 bytes, 260 loop iterations verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

---

:::exercise id="ex-0009" title="Interactive Lab: Hand-Assemble the 11-Byte LED Counter" badge="Skill Practice • Little-Endian Machine Code"
Fill in the missing hex bytes (uppercase two-digit hex) for `STA $8000`, `CLC`, `ADC #$01`, and the little-endian jump target `$C002`:

```text
$C000: A9 00                  ; LDA #$00
$C002: {{blank:8D|STA absolute opcode|??|2}} {{blank:00|Low byte of $8000|??|2}} {{blank:80|High byte of $8000|??|2}}            ; STA $8000
$C005: {{blank:18|CLC implied opcode|??|2}}                     ; CLC
$C006: {{blank:69|ADC immediate opcode|??|2}} 01                  ; ADC #$01
$C008: 4C {{blank:02|Low byte of $C002|??|2}} {{blank:C0|High byte of $C002|??|2}}            ; JMP $C002
```

:::prompts
hint: "Remember little-endian order puts the low byte before the high byte: `$8000` is `00 80` and `$C002` is `02 C0`. Opcodes are `8D` (`STA abs`), `18` (`CLC`), and `69` (`ADC #imm`)."
success: "Spot on! You just encoded all 11 bytes of a real 6502 program from scratch."
:::
:::

:::quiz id="quiz-0009" title="Retrieval Practice: 6502 Registers, Memory Map & Endianness" badge="3 Questions • Equal-Length Options"
- question: "Why must our counting loop execute `CLC` right before `ADC #$01`?"
  wrong_hint: "Check how `ADC` uses the Carry flag `C` when `A` wraps from `0xFF` to `0x00`."
  options:
    - letter: "A"
      text: "Because the 6502 has no add without carry instruction, so carry changes sums."
      correct: true
      explain: "Correct: `ADC` always computes `A + operand + C`. After `0xFF + 1` wraps to `0x00`, `C` stays `1`, so `CLC` prevents `0 + 1 + 1 = 2`."
    - letter: "B"
      text: "Because the 6502 accumulator clears bit seven only after running a flag instruction."
      correct: false
      explain: "Bit `7` of `A` is simply an ordinary data bit; `CLC` clears only the Carry bit `C` in `P`."
    - letter: "C"
      text: "Because memory writes to port address hex 8000 automatically set the carry flag."
      correct: false
      explain: "`STA` never modifies any status flags (`N`, `Z`, `C`, or `V`); only `ADC` sets `C` on wraparound."
    - letter: "D"
      text: "Because immediate mode constants are inverted unless the carry flag equals logic zero."
      correct: false
      explain: "Immediate operands are read verbatim from ROM; only `ADC` adds `C` to the sum."
- question: "In our 11-byte ROM image starting at `0xC000`, why does `JMP $C002` appear as `4C 02 C0` instead of `4C C0 02`?"
  wrong_hint: "Recall which byte of a 16-bit address the 6502 fetches first from memory."
  options:
    - letter: "A"
      text: "Because the 6502 stores 16-bit addresses in little-endian order, putting low byte first."
      correct: true
      explain: "Correct: the 6502 fetches the low byte (`02`) first and the high byte (`C0`) second."
    - letter: "B"
      text: "Because ROM chips swap bit seven and bit zero across every odd address."
      correct: false
      explain: "ROM stores bytes verbatim; the low-then-high ordering is a CPU instruction-set rule."
    - letter: "C"
      text: "Because absolute jump opcodes encode a signed offset instead of a target address."
      correct: false
      explain: "`JMP` (`0x4C`) takes a full 16-bit absolute address; relative branch instructions come later in Lesson 24."
    - letter: "D"
      text: "Because page zero addresses must always precede program ROM addresses inside machine code."
      correct: false
      explain: "Both bytes belong to the 16-bit target address `0xC002`—neither refers to Zero Page."
- question: "According to our 64 KB memory map, which hardware region answers when address bit `A15` is `0` (`0x0000`–`0x7FFF`)?"
  wrong_hint: "Look at the address decoding table splitting RAM, I/O, and ROM."
  options:
    - letter: "A"
      text: "The 16 KB program ROM storing instructions, tables, and reset vectors."
      correct: false
      explain: "ROM lives at `0xC000`–`0xFFFF` where both `A15` and `A14` equal `1`."
    - letter: "B"
      text: "The memory-mapped I/O space containing the Tang Nano onboard LED register."
      correct: false
      explain: "I/O space starts at `0x8000` (`A15 = 1`, `A14 = 0`)."
    - letter: "C"
      text: "The 32 KB system RAM covering zero page, stack, and variables."
      correct: true
      explain: "Correct: `0x0000`–`0x7FFF` spans the lower 32 KB (`A15 = 0`), housing Zero Page, Page 1 Stack, and user RAM."
    - letter: "D"
      text: "The 9 KB HDMI frame buffer storing bitmap and colour cells."
      correct: false
      explain: "Our video card's 9,000-byte frame buffer currently lives inside dedicated video Block RAMs."
:::

:::verify id="verify-0009" title="Verification Lab: Verify Hand-Assembled Machine Code & Run da65" badge="Terminal Gate"
Verify all 11 bytes in `hand_assembled.mem`, simulate 260 loop iterations across 8-bit wraparound, and cross-check our machine code with the `cc65` suite's `da65` disassembler:

```bash caption="Verify hand-assembled bytes and inspect da65 disassembly"
make -C apps/0009-hand-assembled-6502 clean all
make -C apps/0009-hand-assembled-6502 disasm
```

- [ ] `make -C apps/0009-hand-assembled-6502 clean all` prints the 5-instruction breakdown (`$C000`–`$C008`), `PASS: hand_assembled.mem (11 bytes, 260 loop iterations verified)`, and `PASS: da65 verified all 5 instructions at $C000`.
- [ ] `make disasm` reconstructs `lda #$00`, `LC002: sta $8000`, `clc`, `adc #$01`, and `jmp LC002` cleanly from raw binary bytes.
:::

:::teacher-prompt title="Next Up: Lesson 10 (Assembling & Linking with ca65 and ld65)"
Hand-assembling 11 bytes once teaches you little-endian encoding for life—and also makes it obvious why nobody wants to recalculate jump offsets by hand once programs hit 50 lines! Ask any questions about 6502 flags, addressing modes, or memory maps, or move straight on to Lesson 10 to automate the entire build with `ca65` and `ld65`.
:::
