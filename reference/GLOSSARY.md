---
title: "Glossary of FPGA & 6502 Hardware Terms"
page_title: "Glossary — Build Your Own 6502"
nav_id: "glossary"
nav_label: "Glossary"
badge: "Mission: 6502 on Tang Nano 20K"
subtitle: "Canonical definitions used across all lessons and reference sheets. Designed for quick screen lookup and clean printing."
card:
  title: "**Glossary of FPGA & 6502 Terms**"
  summary: "Tight canonical definitions for FPGA primitives, the synthesis-to-bitstream pipeline, and hardware verification concepts."
---

## 1. FPGA & Digital Logic Foundations

**FPGA**:
A reconfigurable integrated circuit containing programmable Look-Up Tables, flip-flops, block RAM, and routing switches that implement custom digital hardware circuits directly in silicon.
_Avoid_: Microcontroller, emulator

**LUT**:
A Look-Up Table—the basic combinational logic building block inside an FPGA (4-input LUT4 on Gowin GW2A/GW2AR devices) that implements any Boolean truth table over its inputs.
_Avoid_: Software lookup array

**Active-Low**:
A signal convention where the asserted or "on" physical state corresponds to logic `0` (ground, 0 V) rather than logic `1` (3.3 V), such as the Tang Nano 20K's six onboard LEDs.
_Avoid_: Negative logic (when referring to pin polarity)

**Non-Blocking Assignment**:
The Verilog `<=` operator used inside clocked `always @(posedge clk)` blocks so all right-hand sides are sampled before any left-hand-side register updates on the clock edge.
_Avoid_: Sequential assignment

## 2. Toolchain & Verification Pipeline

**Synthesis**:
The compilation stage (`yosys`) that translates Verilog RTL into a netlist of target FPGA primitives such as LUTs, carry chains, and flip-flops.
_Avoid_: Compiling (without specifying hardware synthesis)

**Place and Route**:
The physical layout stage (`nextpnr-himbaechel`) that assigns synthesized logic cells to specific silicon locations on the FPGA die and wires interconnecting signal paths to meet pin and timing constraints.
_Avoid_: Linking

**Constraint File**:
A `.cst` configuration file mapping logical Verilog top-level port names to physical FPGA package pin numbers, I/O voltage standards (`LVCMOS33`), pull resistors, and drive strengths.
_Avoid_: Config file

**Bitstream**:
The packed binary configuration image (`.fs`) produced by `gowin_pack` and loaded onto the FPGA over USB by `openFPGALoader` to configure its internal hardware routing and LUTs.
_Avoid_: Firmware binary

**Testbench**:
A non-synthesizable Verilog harness module (`_tb.v`) run in simulation (`iverilog` + `vvp`) that drives input waveforms, checks assertions (`$fatal`), and dumps signal histories to a `.vcd` file.
_Avoid_: Unit test script
