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
