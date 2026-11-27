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
