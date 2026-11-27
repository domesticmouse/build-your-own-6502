---
title: "FPGA & 6502 Toolchain Cheat Sheet"
page_title: "Toolchain Cheat Sheet — Build Your Own 6502"
nav_id: "toolchain"
nav_label: "Toolchain"
badge: "Mission: 6502 on Tang Nano 20K"
subtitle: "Apple Silicon macOS setup, Gowin GW2AR-18 build pipeline, Tang Nano 20K pinout, and Makefile commands."
card:
  title: "**FPGA & 6502 Toolchain Cheat Sheet**"
  summary: "Quick reference for OSS CAD Suite, Homebrew surfer/cc65, Tang Nano 20K pins, and the 4-stage bitstream pipeline."
---

## 1. Installed Toolchain Layout (macOS `arm64`)

Table: Host Tools and Where They Live

| Tool | Source | Role |
| :--- | :--- | :--- |
| `yosys` | `~/oss-cad-suite/bin` | Synthesize Verilog RTL to Gowin LUTs and flip-flops |
| `nextpnr-himbaechel` | `~/oss-cad-suite/bin` | Place and route netlist onto `GW2AR-LV18QN88C8/I7` |
| `gowin_pack` | `~/oss-cad-suite/bin` | Pack routed JSON into flashable `.fs` bitstream |
| `openFPGALoader` | `~/oss-cad-suite/bin` | Program Tang Nano 20K SRAM or SPI flash over USB |
| `iverilog`, `vvp` | `~/oss-cad-suite/bin` | Compile and run Verilog testbenches (`_tb.v`) |
| `surfer` | Homebrew (`surfer`) | Inspect `.vcd` signal waveforms |
| `ca65`, `ld65`, `da65` | Homebrew (`cc65`) | Assemble, link, and disassemble 6502 machine code |

To activate OSS CAD Suite manually in a shell session:

```bash caption="Activate OSS CAD Suite in your current shell"
source ~/oss-cad-suite/environment
```

## 2. Four-Stage Tang Nano 20K Build Pipeline

```bash caption="Exact Gowin GW2AR-18 command sequence"
# 1. Simulate testbench
iverilog -g2012 -Wall -o build/top.vvp top.v top_tb.v
vvp build/top.vvp

# 2. Synthesize Verilog -> Gowin netlist JSON
yosys -q -p "read_verilog top.v; synth_gowin -top top -json build/top.json"

# 3. Place & Route onto GW2AR-LV18QN88C8/I7
nextpnr-himbaechel --quiet \
  --device GW2AR-LV18QN88C8/I7 \
  --json build/top.json \
  --write build/top_pnr.json \
  --vopt family=GW2A-18C \
  --vopt cst=tangnano20k.cst

# 4. Pack Bitstream & Flash to SRAM (or add -f for persistent flash)
gowin_pack -d GW2A-18C -o build/top.fs build/top_pnr.json
openFPGALoader -b tangnano20k build/top.fs
```

## 3. Tang Nano 20K Core Pinout (`.cst`)

Table: Tang Nano 20K Clock, LEDs, and User Buttons

| Signal | Pin | Polarity | Constraint Attributes |
| :--- | :--- | :--- | :--- |
| `clk` (27 MHz) | `4` | Rising edge | `IO_TYPE=LVCMOS33 PULL_MODE=UP` |
| `led[0]` .. `led[5]` | `15` .. `20` | **Active-low** (`0` = ON) | `IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8` |
| `s1` (Button S1) | `88` | Active-high (`1` = pressed) | `IO_TYPE=LVCMOS33 PULL_MODE=DOWN` |
| `s2` (Button S2) | `87` | Active-high (`1` = pressed) | `IO_TYPE=LVCMOS33 PULL_MODE=DOWN` |

## 4. Multi-File Simulation & Surfer Waveforms

Pass every RTL module alongside its testbench to `iverilog` (and all synthesizable `.v` files to `yosys` via `read_verilog`):

```bash caption="Multi-file simulation, synthesis, and VCD waveform inspection"
# Unit-test a submodule and inspect its VCD waveform
iverilog -g2012 -Wall -o build/half_adder.vvp half_adder.v half_adder_tb.v
vvp build/half_adder.vvp
surfer build/half_adder.vcd

# Synthesize multiple Verilog source files into one top module
yosys -q -p "read_verilog half_adder.v top.v; synth_gowin -top top -json build/top.json"
```

## 5. Synthesis Stats & Parameterized Simulation Overrides

Inspect Gowin primitive counts (`LUT1`–`LUT4`, `ALU` carry cells, `DFFR`/`DFFRE` flip-flops) without emitting a JSON netlist, and override divider parameters in testbenches so simulations complete in nanoseconds:

```bash caption="Yosys resource stats and testbench parameter override"
# Print Gowin cell utilisation for a standalone module
yosys -p "read_verilog half_adder.v full_adder.v adder8.v; synth_gowin -top adder8; stat"

# Override a slow 27 MHz divider parameter inside a testbench
top #(.TIMER_PERIOD(4)) dut (
    .clk(clk), .s1(s1), .s2(s2), .led(led)
);
```

## 6. Gowin PLL Generation & Simulating Hard Primitives

Generate `rPLL` parameters for `GW2AR-18` with `gowin_pll`, keep behavioral simulation stubs (`rPLL`, `CLKDIV`, `OSER10`, `TLVDS_OBUF`) inside `sim_gowin_primitives.v`, and pass that file **only** to `iverilog`—never to `yosys`:

```bash caption="Generate rPLL config and simulate hard primitives without polluting synthesis"
# Solve IDIV_SEL / FBDIV_SEL / ODIV_SEL for 27 MHz -> 126 MHz
~/oss-cad-suite/bin/gowin_pll -d "GW2AR-18 C8/I7" -i 27 -o 126 -f pll_126m.v

# Pass simulation stubs ONLY to iverilog, never to yosys
iverilog -g2012 -Wall -o build/top.vvp sim_gowin_primitives.v video_clock.v top.v top_tb.v
yosys -q -p "read_verilog video_clock.v top.v; synth_gowin -top top -json build/top.json"
```

## 7. Tang Nano 20K HDMI / TMDS Pinout & Block RAM Verification

Table: Onboard HDMI Differential Pinout (`GW2AR-LV18QN88C8/I7`)

| Signal | `+` Pin | `-` Pin | Role |
| :--- | :--- | :--- | :--- |
| `tmds_clk_p` / `_n` | `33` | `34` | 25.2 MHz TMDS reference clock (`10'b0000011111`) |
| `tmds_d_p[0]` / `_n[0]` | `35` | `36` | Channel 0 (Blue + `{vsync, hsync}` control tokens) |
| `tmds_d_p[1]` / `_n[1]` | `37` | `38` | Channel 1 (Green) |
| `tmds_d_p[2]` / `_n[2]` | `39` | `40` | Channel 2 (Red) |

```text caption="Separate differential IO_LOC lines required by nextpnr-himbaechel"
IO_LOC "tmds_clk_p" 33;
IO_LOC "tmds_clk_n" 34;
IO_PORT "tmds_clk_p" IO_TYPE=LVCMOS33D PULL_MODE=NONE DRIVE=8;
```

- Preload Block RAM cleanly across both `iverilog` and `yosys` using `.mem` hex text files (`$readmemh("bitmap.mem", bitmap_mem);`, avoiding `.hex` if `.gitignore` ignores compiled hex outputs) and verify `SP` / `SPX9` primitive inference via `make stats`.
