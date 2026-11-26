# Build Your Own 6502 Resources

## Knowledge

- [Our Own 6502, Gate by Gate — Video Series](https://www.youtube.com/playlist?list=PLUe5uP3A3_Vw)
  Yves Robert's 28-episode video curriculum walking from logic gates and HDMI video to a cycle-accurate 6502 CPU in Verilog. Use for: conceptual walkthroughs, visual hardware intuition, and episode sequence.
- [Upstream Companion Repository: `yvesrob/6502-gate-by-gate`](https://github.com/yvesrob/6502-gate-by-gate)
  Authoritative source code, constraints, and test programs accompanying the series. Use for: checking reference implementations and episode milestones.
- [YosysHQ OSS CAD Suite Releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)
  Official prebuilt Apple Silicon (`darwin-arm64`) open-source FPGA toolchain bundling Yosys, `nextpnr-himbaechel`, `gowin_pack`, `openFPGALoader`, and Icarus Verilog. Use for: installing and updating the FPGA synthesis, place-and-route, and flashing pipeline.
- [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula)
  Open-source Gowin FPGA documentation and bitstream tools (`gowin_pack`, `gowin_pll`, `gowin_unpack`). Use for: Gowin device flags, `.cst` constraint syntax, and PLL configuration.
- [nextpnr Documentation (`YosysHQ/nextpnr`)](https://github.com/YosysHQ/nextpnr)
  Official documentation for place-and-route, including the `himbaechel` Gowin architecture backend. Use for: diagnosing timing, routing, and pin constraint errors.
- [Sipeed Tang Nano 20K Wiki & Hardware Docs](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
  Board pinout, GW2AR-LV18QN88C8/I7 schematic details, onboard LEDs, buttons S1/S2, 27 MHz oscillator, and HDMI wiring. Use for: verifying physical pin numbers, active-low/active-high polarity, and I/O standards.
- [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/)
  Official compiler (`iverilog`) and simulation runtime (`vvp`) reference for IEEE 1364 / SystemVerilog subsets. Use for: writing self-checking `_tb.v` testbenches and generating `.vcd` waveform dumps.
- [Surfer Waveform Viewer](https://surfer-project.org/)
  Fast, modern VCD/FST waveform viewer. Use for: inspecting simulated clock edges, bus transactions, and register transitions.
- [cc65 User Documentation (`ca65`, `ld65`, `da65`)](https://cc65.github.io/doc/)
  Official assembler, linker, and disassembler manuals for 6502 targets. Use for: writing 6502 assembly programs and `memory.cfg` linker layouts (Episodes 10+).
- [`64doc` — NMOS 6502/6510 Reference](https://www.nesdev.org/6502_cpu.txt)
  Classic cycle-by-cycle NMOS 6502 instruction, bus, and quirk specification. Use for: verifying exact cycle timing, decimal mode flags, and edge cases (Episodes 15+).
- [SingleStepTests `65x02` Hardware Test Vectors](https://github.com/SingleStepTests/65x02)
  Cycle-accurate JSON test vectors captured from real silicon 6502 behavior. Use for: exhaustive randomized opcode and bus verification (Episodes 17+).

## Wisdom (Communities)

- [6502.org Forum](http://forum.6502.org/)
  Long-running hardware and assembly community for 6502 architecture, bus timing, and edge-case discussions. Use for: deep 6502 behavioral questions and assembly idioms.
- [YosysHQ GitHub Discussions](https://github.com/orgs/YosysHQ/discussions)
  Maintainer-monitored forum for Yosys, `nextpnr`, and OSS CAD Suite questions. Use for: synthesis warnings, Gowin primitive mapping, and toolchain debugging.
- [Sipeed Tang Nano Discussions (`sipeed/TangNano-20K-example`)](https://github.com/sipeed/TangNano-20K-example)
  Board-specific hardware examples and community issue threads. Use for: Tang Nano 20K breadboard power, USB JTAG detection, and HDMI pin troubleshooting.
