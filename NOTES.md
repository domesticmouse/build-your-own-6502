# Course Notes & Roadmap

## Learner Profile & Environment
- **Host OS:** macOS on Apple Silicon (`arm64`).
- **FPGA Hardware:** Sipeed Tang Nano 20K (`GW2AR-LV18QN88C8/I7`) mounted on a breadboard.
- **Toolchain:** OSS CAD Suite (`darwin-arm64`) installed at `~/oss-cad-suite` + Homebrew `surfer` and `cc65`.
- **Prior Knowledge:** Comfortable with software engineering and Boolean algebra (De Morgan's laws). 6502 assembly is ~40 years rusty. Brand new to Verilog and FPGA development.
- **ZPD Pacing:** Skip basic Boolean gate truth-table remediation; focus on hardware concurrency (wires vs sequential flip-flops), active-low board wiring, `.cst` pin constraints, and the synthesis -> place-and-route -> bitstream -> flash workflow.

## 28-Lesson Curriculum Roadmap (Maps 1:1 to `curriculum.md`)

### Part 1: Digital Logic & FPGA Fundamentals
1. `0001-fpga-toolchain-environment` — Toolchain Setup, First Gate & Blinking LED (Ep. 1)
2. `0002-half-adder-and-waveforms` — Logic Gates, Half Adder, Testbenches & Surfer (Ep. 2)
3. `0003-8bit-ripple-carry-adder` — Full Adder, 8-Bit Ripple Carry & Exhaustive Testing (Ep. 3)
4. `0004-flip-flops-registers-fsm` — D Flip-Flops, Non-Blocking `<=`, Counters & FSMs (Ep. 4)

### Part 2: Video Architecture & Graphics Pipeline
5. `0005-vga-raster-timing` — Raster Scanning, 640x480@60 Hz Counters & Test Patterns (Ep. 5)
6. `0006-pll-pixel-clock` — Gowin rPLL & Clock Domain Segregation (Ep. 6)
7. `0007-hdmi-tmds-serialization` — HDMI/DVI TMDS Encoding, `OSER10` & Monitor Output (Ep. 7)
8. `0008-video-card-framebuffer` — 320x200 16-Color Frame Buffer & Block RAM Latency (Ep. 8)

### Part 3: 6502 Architecture & Toolchain Setup
9. `0009-hand-assembled-6502` — 6502 Registers, Memory Map & Hand-Assembled Machine Code (Ep. 9)
10. `0010-ca65-ld65-toolchain` — Assembling & Linking 6502 Programs with `ca65` and `ld65` (Ep. 10)
11. `0011-rom-ram-and-bus` — System Bus, Address Decoding & Synchronous Memory Timing (Ep. 11)

### Part 4: Processor Core & ALU Implementation
12. `0012-first-cpu-fetch-fsm` — CPU Skeleton, Reset Vector & Fetch FSM (Ep. 12)
13. `0013-6502-alu-operations` — Combinational ALU & Shared 9-Bit Adder Architecture (Ep. 13)
14. `0014-alu-status-flags` — N, Z, C, V Flags & Exhaustive ALU Verification (Ep. 14)
15. `0015-first-five-instructions` — Instruction Decoder, Multi-State Sequencer & Two-Read Rule (Ep. 15)
16. `0016-running-first-program` — Data Path Integration, Memory-Mapped LEDs & Fault Injection (Ep. 16)
17. `0017-6502-on-tang-nano` — Real FPGA Execution, UART Profiling & SingleStep Tests (Ep. 17)

### Part 5: Addressing Modes & Tables
18. `0018-index-registers-zero-page` — X/Y Registers, Zero Page & Indexed RAM Reads (Ep. 18)
19. `0019-absolute-indexed-rom-tables` — Absolute Indexed Modes & Page-Crossing Penalties (Ep. 19)
20. `0020-indirect-modes-jmp-bug` — Indirect Modes, Read-Modify-Write & Historic JMP Bug (Ep. 20)

### Part 6: Complete Arithmetic & Decimal Mode
21. `0021-subtraction-compare-shifts` — SBC, Comparisons, Shifts & `(* keep *)` Attributes (Ep. 21)
22. `0022-bcd-decimal-mode` — Binary Coded Decimal Fixup, NMOS Flag Quirks & Stopwatch (Ep. 22)
23. `0023-million-test-verification` — 1.23M SingleStep Vectors & Fault Coverage Auditing (Ep. 23)

### Part 7: Branching, Decision Making & Subroutines
24. `0024-relative-branching-basics` — Relative Offsets, Conditional Branches & Transfers (Ep. 24)
25. `0025-collatz-branch-sequencer` — Sign Extension, Branch States & Collatz on Hardware (Ep. 25)
26. `0026-page-crossing-branches` — Page-Crossing Loops, Flag Silicon Cost & Regression Suite (Ep. 26)
27. `0027-hardware-stack-subroutines` — Page 1 Stack, `PHA`/`PLA` & `JSR`/`RTS` Asymmetry (Ep. 27)
28. `0028-recursive-subroutines` — Stack Sequencer Logic, Recursion & Stack Corruption Demo (Ep. 28)
