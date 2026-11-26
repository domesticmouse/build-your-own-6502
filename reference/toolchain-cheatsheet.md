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
