# Mission: Build Your Own 6502 on a Tang Nano 20K

## Why
Build, simulate, synthesize, and flash a complete, cycle-accurate 6502 processor and 320×200 16-color HDMI video computer onto a physical Sipeed Tang Nano 20K FPGA board, following Yves Robert's 28-episode *Our Own 6502, Gate by Gate* curriculum.

## Success looks like
- Simulate, synthesize, place-and-route, and flash Verilog designs onto the physical Tang Nano 20K using open-source command-line tooling (OSS CAD Suite + `surfer` + `cc65`).
- Drive a physical HDMI monitor with a 640×480@60 Hz raster pipeline and 320×200 16-color frame buffer.
- Assemble 6502 machine code with `ca65`/`ld65` and execute real programs (LED counter, decimal stopwatch, Collatz sequence, recursive subroutines) on your own Verilog 6502 core verified against the SingleStep Tests suite.

## Constraints
- Host: Apple Silicon macOS (`arm64`); Hardware: Sipeed Tang Nano 20K (`GW2AR-LV18QN88C8/I7`) mounted on a breadboard.
- Toolchain: OSS CAD Suite (`darwin-arm64`) for FPGA flow + Homebrew for `surfer` and `cc65`.
- Starting point: Knows software development and Boolean algebra (De Morgan's laws); 6502 assembly is ~40 years rusty; brand new to Verilog and FPGA hardware design.

## Out of scope
- Proprietary Gowin EDA IDE.
- Software-only or non-cycle-accurate 6502 emulators.
- Peripherals or architectures outside the 28-episode syllabus unless the mission evolves.
