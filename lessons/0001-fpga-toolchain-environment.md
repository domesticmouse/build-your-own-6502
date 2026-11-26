---
title: "FPGA Toolchain Setup, First Logic Gate & Blinking LED"
page_title: "Lesson 0001: FPGA Toolchain Setup, First Logic Gate & Blinking LED — Build Your Own 6502"
nav_id: "lesson-0001"
badge: "Lesson 0001 • Verilog & Tang Nano 20K"
subtitle: "Install the Apple Silicon FPGA + 6502 toolchain, verify a combinational gate and clock divider in simulation, and flash your first bitstream to the Tang Nano 20K."
card:
  title: "**FPGA Toolchain Setup, First Logic Gate & Blinking LED**"
  summary: "Set up OSS CAD Suite, surfer, and cc65 on macOS; write your first Verilog module, testbench, and .cst constraints; and blink LEDs on the Tang Nano 20K."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0001-fpga-toolchain-environment/` (`make -C apps/0001-fpga-toolchain-environment clean all`)
- **Video reference**: [Episode 1: Rebuilding the 6502 from Scratch, One Gate at a Time](https://www.youtube.com/watch?v=czPMjs0Y0zc)
- **Board & tools**: [Sipeed Tang Nano 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html) and [OSS CAD Suite Releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)
- **Course references**: [Glossary](../reference/GLOSSARY.md) and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Software Instructions vs. Hardware Circuits

A CPU (like the 6502 we are going to build) executes software instructions **one step after another**. An FPGA does something fundamentally different: it wires raw silicon **Look-Up Tables (LUTs)** and **flip-flops** into a physical circuit where every gate and register runs **at the same time**{{sidenote:On the Gowin GW2AR-18 inside your Tang Nano 20K, each logic cell pairs a 4-input LUT (capable of computing any 4-input Boolean truth table) with a D flip-flop.}}.

Instead of writing functions that execute sequentially, in Verilog you describe:
1. **Combinational wires** (`assign`) — continuous electrical connections whose outputs update immediately whenever their inputs change (like an `AND` or `NAND` gate).
2. **Sequential registers** (`always @(posedge clk)`) — banks of flip-flops that snapshot values only on the rising edge of a clock pulse.

```mermaid caption="Figure 1.1: From Verilog source to live silicon on the Tang Nano 20K"
flowchart LR
  V["top.v + tangnano20k.cst"] --> Y["yosys<br/>(Synthesis)"]
  Y --> N["nextpnr-himbaechel<br/>(Place & Route)"]
  N --> G["gowin_pack<br/>(Bitstream .fs)"]
  G --> O["openFPGALoader<br/>(USB Flash)"]
  O --> B["Tang Nano 20K<br/>(GW2AR-18 Silicon)"]
```

## 2. Your macOS Apple Silicon (`arm64`) Environment

Most of the individual tools exist on Homebrew, **except** the two tightly coupled Gowin FPGA backend tools (`nextpnr-himbaechel` and `apicula`/`gowin_pack`). To avoid version mismatches while keeping installation simple, we use a clean two-part setup:

- **OSS CAD Suite (`darwin-arm64`)** unpacked at `~/oss-cad-suite`: provides matched builds of `yosys`, `nextpnr-himbaechel`, `gowin_pack`, `openFPGALoader`, and Icarus Verilog (`iverilog`, `vvp`).
- **Homebrew**: provides `surfer` (VCD waveform viewer for Lesson 2+) and `cc65` (`ca65`, `ld65`, `da65` for 6502 assembly in Lesson 10+).

```bash caption="One-time setup summary (already installed in this workspace)"
# 1. Strip macOS Gatekeeper quarantine after unpacking OSS CAD Suite to ~/oss-cad-suite
xattr -dr com.apple.quarantine ~/oss-cad-suite

# 2. Install waveform viewer and 6502 assembler suite via Homebrew
brew install surfer cc65

# 3. Verify tools
source ~/oss-cad-suite/environment
yosys -V && nextpnr-himbaechel --version && openFPGALoader --version
surfer --version && ca65 --version
```

## 3. Building `top.v` Block by Block

Our first hardware design tests three essential board peripherals on your Tang Nano 20K: the **27 MHz clock** (pin 4), the **two push-buttons** `s1` and `s2` (pins 88 and 87), and the **six onboard LEDs** `led[5:0]` (pins 15–20).

### Block 1: Module Ports and Blink Parameter

```verilog caption="Module interface and compile-time parameter"
`timescale 1ns / 1ps

module top #(
    parameter integer BLINK_BIT = 24
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
```

- `` `timescale 1ns / 1ps `` tells simulators (`iverilog`) what time unit `#5` delays represent, avoiding `-Wall` warnings.
- `parameter integer BLINK_BIT = 24` makes the clock divider configurable: we use bit `24` on the real 27 MHz board, and override it to bit `2` in our testbench so simulation finishes in microseconds instead of billions of cycles{{sidenote:Using a parameter for divider widths is a classic FPGA pattern—never wait 25 million simulated clock edges in a testbench when you can test the exact same counter logic at width 3.}}.
- `output wire [5:0] led` declares a 6-bit bus ordered from most-significant bit `5` down to least-significant bit `0`.

### Block 2: Sequential Clock Divider

```verilog caption="25-bit binary counter clocked at 27 MHz"
    reg [BLINK_BIT:0] counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end
```

- `reg [BLINK_BIT:0] counter = 0;` declares a 25-bit register (`24` down to `0`). In Verilog, `reg` inside a clocked `always` block synthesizes to real hardware flip-flops—not a CPU variable.
- `always @(posedge clk)` triggers **only** on the rising edge (`0 -> 1`) of `clk`.
- `<=` is a **non-blocking assignment**: every flip-flop samples its pre-edge value simultaneously before updating, preventing race conditions across registers.
- With a 27 MHz clock, bit `24` (the 25th bit) completes one full off/on blink cycle at:

$$f_{\text{blink}} = \frac{27 \times 10^6\text{ Hz}}{2^{25}} \approx 0.805\text{ Hz}$$

### Block 3: Combinational Gates & Active-Low LEDs

```verilog caption="Combinational AND gate and active-low LED assignments"
    wire both_pressed = s1 & s2;

    assign led[0]   = ~both_pressed;
    assign led[1]   = ~counter[BLINK_BIT];
    assign led[2]   = ~s1;
    assign led[3]   = ~s2;
    assign led[5:4] = 2'b11;
endmodule
```

- `wire both_pressed = s1 & s2;` wires an `AND` gate directly between buttons `s1` and `s2`.
- On the Tang Nano 20K, the six onboard LEDs are **active-low**: driving a pin to `0` (ground) turns the LED **on**, while `1` (3.3 V) turns it **off**{{sidenote:By De Morgan's Law, inverting an AND output—<code>~(s1 &amp; s2)</code>—is identical to <code>~s1 | ~s2</code>, a physical NAND gate pulling <code>led[0]</code> low only when both active-high buttons read 1.}}.
- `led[0]` lights only when **both** `s1` and `s2` are pressed; `led[2]` and `led[3]` mirror `s1` and `s2` individually; `led[1]` blinks from `counter[24]`; and `led[5:4] = 2'b11` keeps the remaining two LEDs off.

### Complete `top.v` Listing

```verilog caption="apps/0001-fpga-toolchain-environment/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer BLINK_BIT = 24
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    reg [BLINK_BIT:0] counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    wire both_pressed = s1 & s2;

    assign led[0]   = ~both_pressed;
    assign led[1]   = ~counter[BLINK_BIT];
    assign led[2]   = ~s1;
    assign led[3]   = ~s2;
    assign led[5:4] = 2'b11;
endmodule
```

## 4. Physical Pin Constraints (`tangnano20k.cst`)

Synthesis only knows signal names like `clk` and `led[0]`. The `.cst` constraint file binds each port name to a physical package pin on the `GW2AR-LV18QN88C8/I7` chip and specifies `LVCMOS33` (3.3 V I/O).

Table: Tang Nano 20K Pin Mapping for Lesson 1

| Port | Package Pin | Pull / Drive | Hardware Behavior |
| :--- | :--- | :--- | :--- |
| `clk` | `4` | `PULL_MODE=UP` | 27 MHz onboard oscillator |
| `led[0]` .. `led[5]` | `15` .. `20` | `PULL_MODE=UP DRIVE=8` | Active-low onboard LEDs |
| `s1` | `88` | `PULL_MODE=DOWN` | Active-high push-button S1 |
| `s2` | `87` | `PULL_MODE=DOWN` | Active-high push-button S2 |

:::callout title="Why LVCMOS33 instead of LVCMOS18 for the LEDs?"
You may notice some videos or Gowin tutorials using `IO_TYPE=LVCMOS18` for the onboard LEDs. On an FPGA, `IO_TYPE` does **not** change the physical voltage supplied to an I/O bank—it tells the toolchain what voltage the PCB's `VCCIO` rail is hardwired to so it can calibrate drive strengths and catch mismatches.

- **Hardware reality:** On the Tang Nano 20K, LED pins `15`–`20` sit in Bank 6, which—along with the active-low LED pull-ups (through 510 Ω resistors)—is hardwired to **3.3 V**.
- **Why `LVCMOS18` still appears to work:** Gowin EDA defaults unspecified pins to `LVCMOS18` (and the older Tang Nano 9K actually wired its LED bank to 1.8 V). Because the LEDs are simple active-low outputs driven to ground (`0`) or the physical 3.3 V rail (`1`), declaring `LVCMOS18` still blinks them when nothing else in Bank 6 specifies `LVCMOS33`.
- **Why we use `LVCMOS33`:** As soon as any other pin in Bank 6 uses `LVCMOS33`, leaving the LEDs at `LVCMOS18` causes a bank-voltage conflict error during place-and-route (`ERROR (CT1136)` in Gowin EDA). Setting `LVCMOS33` from the start matches the real hardware and avoids conflicts later.
:::

## 5. Self-Checking Simulation (`top_tb.v`) & `Makefile`

Before touching physical silicon, we run an automated testbench with Icarus Verilog (`iverilog` + `vvp`). Notice how `top_tb.v` sets `.BLINK_BIT(2)` so the divider flips every 4 rising clock edges, tests all four `(s1, s2)` combinations via a reusable `task`, and fails loudly with `$fatal` if any bit mismatches.

```verilog caption="apps/0001-fpga-toolchain-environment/top_tb.v"
`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;

    top #(.BLINK_BIT(2)) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    always #5 clk = ~clk;

    task check_buttons(
        input reg in_s1,
        input reg in_s2,
        input reg exp_led0,
        input reg exp_led2,
        input reg exp_led3
    );
        begin
            s1 = in_s1;
            s2 = in_s2;
            #1;
            if (led[0] !== exp_led0) $fatal(1, "led[0] mismatch for s1=%b s2=%b: got %b expected %b", s1, s2, led[0], exp_led0);
            if (led[2] !== exp_led2) $fatal(1, "led[2] mismatch for s1=%b: got %b expected %b", s1, led[2], exp_led2);
            if (led[3] !== exp_led3) $fatal(1, "led[3] mismatch for s2=%b: got %b expected %b", s2, led[3], exp_led3);
            if (led[5:4] !== 2'b11)  $fatal(1, "led[5:4] should remain off (11): got %b", led[5:4]);
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        #1;
        if (led[1] !== 1'b1) $fatal(1, "led[1] should start off (1): got %b", led[1]);

        check_buttons(1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        check_buttons(1'b1, 1'b0, 1'b1, 1'b0, 1'b1);
        check_buttons(1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
        check_buttons(1'b1, 1'b1, 1'b0, 1'b0, 1'b0);

        repeat (4) @(posedge clk);
        #1;
        if (led[1] !== 1'b0) $fatal(1, "led[1] should turn on (0) after 4 rising edges: got %b", led[1]);

        repeat (4) @(posedge clk);
        #1;
        if (led[1] !== 1'b1) $fatal(1, "led[1] should turn off (1) after 8 rising edges: got %b", led[1]);

        $display("PASS: all combinational gate and clock-divider checks passed");
        $finish;
    end
endmodule
```

The `Makefile` automatically locates `~/oss-cad-suite/bin` so you can run `make test`, `make bitstream`, or `make flash` from any terminal without remembering long flags.

---

:::exercise id="ex-0001" title="Interactive Lab: Active-Low Gate & Clocked Counter" badge="Skill Practice • Verilog Foundations"
Complete the two missing expressions in `top.v`: increment `counter` safely on the rising clock edge, and wire `led[0]` so it turns on (active-low `0`) only when both `s1` and `s2` are pressed (`1`).

```verilog
always @({{blank:posedge clk|Trigger on the rising edge of clk|???|11}}) begin
    counter {{blank:<=|Use non-blocking assignment for clocked registers|??|2}} counter + 1'b1;
end

assign led[0] = {{blank:~(s1 & s2)||~s1 | ~s2|Invert the AND of s1 and s2 (active-low)|???|10}};
```

:::prompts
hint: "Use `posedge clk` with `<=` for the flip-flop counter, and invert `s1 & s2` with `~(...)` (or apply De Morgan's Law: `~s1 | ~s2`)."
success: "Nice! Notice how `~(s1 & s2)` and `~s1 | ~s2` produce identical hardware truth tables."
:::
:::

:::quiz id="quiz-0001" title="Retrieval Practice: FPGA Flow & Polarity" badge="3 Questions • Equal-Length Options"
- question: "Why must `counter` update with `<=` inside `always @(posedge clk)`?"
  wrong_hint: "Think about how multiple flip-flops share the same rising clock edge."
  options:
    - letter: "A"
      text: "Because blocking assignments run slower on Gowin FPGAs."
      correct: false
      explain: "Assignment operators are a simulation/synthesis semantic rule, not a clock speed setting."
    - letter: "B"
      text: "Because non-blocking assignments sample inputs before updating registers."
      correct: true
      explain: "Right: every flip-flop reads pre-edge values simultaneously before updating together on the edge."
    - letter: "C"
      text: "Because assign statements cannot read any 25-bit counters."
      correct: false
      explain: "Continuous assign statements can read register outputs freely."
    - letter: "D"
      text: "Because Verilog forbids regular addition inside combinational wires."
      correct: false
      explain: "Combinational wires can use addition freely; <= is specifically for clocked sequential blocks."
- question: "Why does `assign led[0] = ~(s1 & s2);` light `led[0]` only when both buttons are pressed?"
  wrong_hint: "Check the polarity of the six onboard LEDs in Section 3."
  options:
    - letter: "A"
      text: "Because Tang Nano buttons connect directly to ground rails."
      correct: false
      explain: "Buttons S1 and S2 have external pull-downs and read 1 (active-high) when pressed."
    - letter: "B"
      text: "Because the 27 MHz oscillator inverts every combinational output."
      correct: false
      explain: "The oscillator only supplies clock edges; it does not invert combinational pins."
    - letter: "C"
      text: "Because Yosys automatically flips all top-level board LED outputs."
      correct: false
      explain: "Yosys implements exactly the polarity you write in Verilog."
    - letter: "D"
      text: "Because the onboard LEDs are active-low and need zero."
      correct: true
      explain: "Correct: driving pin 15 to 0 V sinks current through the LED and lights it."
- question: "Which tool converts the placed-and-routed `top_pnr.json` layout into the `.fs` bitstream file?"
  wrong_hint: "Follow the four boxes in Figure 1.1 from Verilog to USB flash."
  options:
    - letter: "A"
      text: "gowin_pack converts the routed design into a bitstream."
      correct: true
      explain: "Correct: Project Apicula's gowin_pack packs the routed GW2AR-18 layout into build/top.fs."
    - letter: "B"
      text: "iverilog packs the routed netlist into a bitstream."
      correct: false
      explain: "iverilog compiles testbenches for simulation; it does not generate FPGA bitstreams."
    - letter: "C"
      text: "nextpnr-himbaechel compiles Verilog directly into flashable binary bitstreams."
      correct: false
      explain: "nextpnr-himbaechel performs place-and-route and outputs top_pnr.json for gowin_pack."
    - letter: "D"
      text: "openFPGALoader synthesizes logic gates into a bitstream file."
      correct: false
      explain: "openFPGALoader streams an already-packed .fs file over USB to the FPGA."
:::

:::verify id="verify-0001" title="Verification Lab: Simulate, Build & Flash Your Tang Nano 20K" badge="Hardware & Terminal Gate"
Run the full simulation, synthesis, place-and-route, and bitstream pack from the workspace root, then plug in your Tang Nano 20K via USB-C and flash it:

```bash caption="Run simulation, build bitstream, and flash the Tang Nano 20K"
make -C apps/0001-fpga-toolchain-environment clean all
make -C apps/0001-fpga-toolchain-environment detect
make -C apps/0001-fpga-toolchain-environment flash
```

- [ ] `make -C apps/0001-fpga-toolchain-environment clean all` completes with zero warnings and prints `PASS: all combinational gate and clock-divider checks passed`.
- [ ] `openFPGALoader --detect` recognizes your plugged-in Tang Nano 20K over USB-C.
- [ ] `make flash` succeeds and `led[1]` blinks roughly once every 1.25 seconds (~0.805 Hz).
- [ ] Pressing `S1` lights `led[2]`, pressing `S2` lights `led[3]`, and holding **both** `S1` + `S2` lights `led[0]`.
:::

:::teacher-prompt title="Ask Your AI Teacher & Preview Lesson 2"
Once you've flashed your Tang Nano 20K and seen `led[0]`–`led[3]` respond, ask any questions about `wire` vs `reg`, `.cst` pin constraints, or `surfer` waveforms—or say **"ready for Lesson 2"** to build a 1-bit Half Adder from two gates and inspect your first `.vcd` waveform in Surfer.
:::
