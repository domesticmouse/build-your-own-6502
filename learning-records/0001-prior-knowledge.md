# Prior Knowledge and Hardware Baseline

The learner has general software engineering fluency and understands Boolean algebra (including De Morgan's laws), has ~40-year-rusty familiarity with 6502 assembly, has no prior Verilog or FPGA experience, and has a physical Sipeed Tang Nano 20K mounted on a breadboard on an Apple Silicon Mac.

- **Implications**: Skip remedial Boolean truth-table drills; teach Verilog concurrency (`assign` vs `always @(posedge clk)`), active-low board LEDs, physical pin constraints (`.cst`), and the synthesis → place-and-route → bitstream → USB flash pipeline from first principles while pairing every lesson with real simulation and Tang Nano 20K hardware verification.
