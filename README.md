# Build your own 6502

A study repository and interactive course for the **[Our Own 6502, Gate by Gate](https://www.youtube.com/playlist?list=PLUe5uP3A3_Vw)** video series by **Yves Robert** ([Gate by Gate](https://www.youtube.com/@gatebygate)), building a 6502 processor and 320×200 HDMI computer system from scratch in Verilog on a Sipeed Tang Nano 20K FPGA.

- **Hosted Course Site:** [https://domesticmouse.github.io/build-your-own-6502/](https://domesticmouse.github.io/build-your-own-6502/)
- **Detailed Curriculum & Episode Notes:** [curriculum.md](curriculum.md)
- **Course Mission:** [MISSION.md](MISSION.md)
- **Curated Resources:** [RESOURCES.md](RESOURCES.md)
- **Upstream Reference Repository:** [yvesrob/6502-gate-by-gate](https://github.com/yvesrob/6502-gate-by-gate)

## Interactive Course Site

- **Live Course Index:** [https://domesticmouse.github.io/build-your-own-6502/](https://domesticmouse.github.io/build-your-own-6502/)

Build and validate the static HTML lessons and reference sheets locally:

```bash
.venv/bin/python build.py --check
```

### Published Lessons
- [Lesson 0001: FPGA Toolchain Setup, First Logic Gate & Blinking LED](https://domesticmouse.github.io/build-your-own-6502/lessons/0001-fpga-toolchain-environment.html) ([source](lessons/0001-fpga-toolchain-environment.md) • [companion app](apps/0001-fpga-toolchain-environment/))
- [Lesson 0002: Logic Gates, Half Adder, Testbenches & Surfer](https://domesticmouse.github.io/build-your-own-6502/lessons/0002-half-adder-and-waveforms.html) ([source](lessons/0002-half-adder-and-waveforms.md) • [companion app](apps/0002-half-adder-and-waveforms/))
- [Lesson 0003: Full Adder, 8-Bit Ripple Carry & Exhaustive Testing](https://domesticmouse.github.io/build-your-own-6502/lessons/0003-8bit-ripple-carry-adder.html) ([source](lessons/0003-8bit-ripple-carry-adder.md) • [companion app](apps/0003-8bit-ripple-carry-adder/))
- [Lesson 0004: D Flip-Flops, Non-Blocking <=, Counters & FSMs](https://domesticmouse.github.io/build-your-own-6502/lessons/0004-flip-flops-registers-fsm.html) ([source](lessons/0004-flip-flops-registers-fsm.md) • [companion app](apps/0004-flip-flops-registers-fsm/))
- [Lesson 0005: Raster Scanning, 640×480@60 Hz Counters & Test Patterns](https://domesticmouse.github.io/build-your-own-6502/lessons/0005-vga-raster-timing.html) ([source](lessons/0005-vga-raster-timing.md) • [companion app](apps/0005-vga-raster-timing/))
- [Lesson 0006: Gowin rPLL & Clock Domain Segregation](https://domesticmouse.github.io/build-your-own-6502/lessons/0006-pll-pixel-clock.html) ([source](lessons/0006-pll-pixel-clock.md) • [companion app](apps/0006-pll-pixel-clock/))
- [Lesson 0007: HDMI/DVI TMDS Encoding, OSER10 & Monitor Output](https://domesticmouse.github.io/build-your-own-6502/lessons/0007-hdmi-tmds-serialization.html) ([source](lessons/0007-hdmi-tmds-serialization.md) • [companion app](apps/0007-hdmi-tmds-serialization/))
- [Lesson 0008: 320×200 16-Colour Frame Buffer & Block RAM Latency](https://domesticmouse.github.io/build-your-own-6502/lessons/0008-video-card-framebuffer.html) ([source](lessons/0008-video-card-framebuffer.md) • [companion app](apps/0008-video-card-framebuffer/))
- [Lesson 0009: 6502 Registers, Memory Map & Hand-Assembled Machine Code](https://domesticmouse.github.io/build-your-own-6502/lessons/0009-hand-assembled-6502.html) ([source](lessons/0009-hand-assembled-6502.md) • [companion app](apps/0009-hand-assembled-6502/))
- [Lesson 0010: Assembling & Linking 6502 Programs with ca65 and ld65](https://domesticmouse.github.io/build-your-own-6502/lessons/0010-ca65-ld65-toolchain.html) ([source](lessons/0010-ca65-ld65-toolchain.md) • [companion app](apps/0010-ca65-ld65-toolchain/))
- [Lesson 0011: System Bus, Address Decoding & Synchronous Memory Timing](https://domesticmouse.github.io/build-your-own-6502/lessons/0011-rom-ram-and-bus.html) ([source](lessons/0011-rom-ram-and-bus.md) • [companion app](apps/0011-rom-ram-and-bus/))
- [Lesson 0012: CPU Skeleton, Reset Vector & Fetch FSM](https://domesticmouse.github.io/build-your-own-6502/lessons/0012-first-cpu-fetch-fsm.html) ([source](lessons/0012-first-cpu-fetch-fsm.md) • [companion app](apps/0012-first-cpu-fetch-fsm/))

### Reference Sheets
- [Glossary of FPGA & 6502 Hardware Terms](https://domesticmouse.github.io/build-your-own-6502/reference/glossary.html) ([source](reference/GLOSSARY.md))
- [FPGA & 6502 Toolchain Cheat Sheet](https://domesticmouse.github.io/build-your-own-6502/reference/toolchain-cheatsheet.html) ([source](reference/toolchain-cheatsheet.md))

## License

This repository is licensed under the Apache License 2.0 — see [LICENSE](LICENSE) for details.

## Disclaimer

This is not an officially supported Google product.
