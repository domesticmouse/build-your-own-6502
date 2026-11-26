---
title: "Logic Gates, Half Adder, Testbenches & Surfer"
page_title: "Lesson 0002: Logic Gates, Half Adder, Testbenches & Surfer — Build Your Own 6502"
nav_id: "lesson-0002"
badge: "Lesson 0002 • Combinational Logic & Simulation"
subtitle: "Wire all six fundamental logic gates on a 6-bit bus, build a reusable 1-bit Half Adder module, verify it with self-checking testbenches, and inspect your first VCD waveform in Surfer."
card:
  title: "**Logic Gates, Half Adder, Testbenches & Surfer**"
  summary: "Build a 6-gate bus and reusable 1-bit Half Adder in Verilog, enforce the fail-once-on-purpose testbench rule, and inspect VCD waveforms in Surfer."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0002-half-adder-and-waveforms/` (`make -C apps/0002-half-adder-and-waveforms clean all`)
- **Video reference**: [Episode 2: How a Computer Adds: I Built an Adder from Just Two Logic Gates](https://www.youtube.com/watch?v=oW3Ts-unUhM)
- **Simulation & waveforms**: [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/) and [Surfer Waveform Viewer](https://surfer-project.org/)
- **Course references**: [Lesson 1](0001-fpga-toolchain-environment.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. From One Gate to a 6-Wire Gate Bus

In [Lesson 1](0001-fpga-toolchain-environment.md), we needed a 25-bit sequential counter just to slow a 27 MHz oscillator down enough to see an LED blink. In this lesson, we drop the clock completely. Every circuit we build here is **purely combinational**: no `clk` port, no `always @(posedge clk)` blocks, and **0 flip-flops** in the synthesised hardware.

Before we build an adder, let's put all six fundamental two-input logic gates on the Tang Nano 20K's six onboard LEDs (`led[5:0]`) driven by push-buttons `s1` and `s2`. Grouping those six Boolean wires into a single 6-bit bus (`wire [5:0] gates`) lets us keep our logic active-high inside the circuit and flip the active-low LED polarity in one place at the board boundary.

Table: Six Two-Input Logic Gates Mapped to `gates[5:0]`

| Bus Bit | Gate | Verilog Expression | Output High (`1`) When |
| :--- | :--- | :--- | :--- |
| `gates[0]` | `XOR` | `s1 ^ s2` | Inputs differ (`0,1` or `1,0`) |
| `gates[1]` | `AND` | `s1 & s2` | Both inputs are `1` |
| `gates[2]` | `OR` | `s1 \| s2` | Either input is `1` |
| `gates[3]` | `NAND` | `~(s1 & s2)` | Not both inputs are `1` |
| `gates[4]` | `NOR` | `~(s1 \| s2)` | Both inputs are `0` |
| `gates[5]` | `XNOR` | `s1 ~^ s2` | Inputs match (`0,0` or `1,1`) |

:::callout-warn title="Verilog Gotcha: Binary NAND/NOR vs. Unary Reduction Operators"
If you write `s1 ~& s2` or `s1 ~| s2` expecting binary NAND or NOR, `iverilog` will reject it as a syntax error. In Verilog, `~&` and `~|` are **unary reduction operators** that collapse a single multi-bit bus into one bit (for example, `~&gates` NANDs all six bits of `gates` together). Binary two-input NAND and NOR must be written `~(s1 & s2)` and `~(s1 | s2)`, whereas binary XNOR *is* a valid infix operator (`s1 ~^ s2` or `s1 ^~ s2`){{sidenote:By De Morgan's Law, <code>~(s1 &amp; s2)</code> and <code>~(s1 | s2)</code> correspond cleanly to <code>~s1 | ~s2</code> and <code>~s1 &amp; ~s2</code>, and Yosys folds either form into a single Gowin <code>LUT2</code> truth table.}}.
:::

## 2. How Hardware Adds: The 1-Bit Half Adder

Adding two single-bit binary numbers $a$ and $b$ can produce `0`, `1`, or `2` (`2'b10` in binary). In positional notation, that 2-bit result splits cleanly into two weights:

$$a + b = 2^1 \cdot \text{carry} + 2^0 \cdot \text{sum}$$

Look closely at the two output columns of that addition table:

Table: 1-Bit Half Adder Truth Table and Tang Nano 20K LED Output

| `a` (`s1`) | `b` (`s2`) | Decimal `a + b` | `carry` (`a & b`) | `sum` (`a ^ b`) | Active-Low `led[1:0]` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0` | `0` | `0` (`00`₂) | `0` | `0` | `11` (both off) |
| `0` | `1` | `1` (`01`₂) | `0` | `1` | `10` (`led[0]` on) |
| `1` | `0` | `1` (`01`₂) | `0` | `1` | `10` (`led[0]` on) |
| `1` | `1` | `2` (`10`₂) | `1` | `0` | `01` (`led[1]` on) |

That is the punchline of Episode 2: **a 1-bit adder is literally two logic gates**. An `XOR` gate (`a ^ b`) computes the units digit (`sum`), and an `AND` gate (`a & b`) computes the twos digit (`carry`). And because `gates[0]` is `sum` and `gates[1]` is `carry`, pressing `s1` and `s2` on your board counts `0` → `1` → `2` in binary right across `led[1]` and `led[0]`.

```mermaid caption="Figure 2.1: Half Adder and 6-gate bus wired to active-low Tang Nano 20K LEDs"
flowchart LR
  S1["s1 (Pin 88)"] --> HA["half_adder<br/>(sum = a ^ b, carry = a & b)"]
  S2["s2 (Pin 87)"] --> HA
  HA --> G01["gates[0] = sum<br/>gates[1] = carry"]
  S1 --> G25["OR, NAND, NOR, XNOR"]
  S2 --> G25
  G25 --> G25B["gates[5:2]"]
  G01 --> INV["assign led = ~gates"]
  G25B --> INV
  INV --> LED["led[5:0] (Pins 20..15)"]
```

Why is this circuit called a **half** adder rather than a full adder? Because it only takes two inputs (`a` and `b`)—it has no `carry_in` port to accept a carry spilled over from a lower column. That works fine for bit `0` (the least-significant bit of an addition), but for bits `1` through `7` of our 6502's ALU we will need to add three bits (`a`, `b`, and `carry_in`). In Lesson 3, we will wire two `half_adder` instances together with an `OR` gate to build a **Full Adder** and chain eight of them into an 8-bit ripple-carry adder.

## 3. Building `half_adder.v` and Wiring `top.v` Block by Block

Just like extracting a helper function in software, Verilog lets us isolate `half_adder` in its own file (`half_adder.v`), unit-test it directly, and instantiate it inside `top.v`.

### Building `half_adder.v`

```verilog caption="Module interface and two-gate assignments in half_adder.v"
`timescale 1ns / 1ps

module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule
```

- All four ports (`a`, `b`, `sum`, `carry`) are 1-bit `wire` signals—no `reg`, no clock, and no state.
- `assign sum = a ^ b;` and `assign carry = a & b;` are evaluated continuously and concurrently in hardware.

### Full `half_adder.v` Module

```verilog caption="apps/0002-half-adder-and-waveforms/half_adder.v"
`timescale 1ns / 1ps

module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule
```

### Block 1: Instantiating `half_adder` by Named Ports in `top.v`

```verilog caption="Named port instantiation inside top.v"
module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire sum;
    wire carry;

    half_adder u_half_adder (
        .a(s1),
        .b(s2),
        .sum(sum),
        .carry(carry)
    );
```

- Notice `clk` is gone from `top`'s port list—our design is purely combinational, and we remove `clk` from `tangnano20k.cst` as well so `nextpnr-himbaechel` does not complain about an unused constraint.
- `half_adder u_half_adder (.a(s1), ...);` creates a physical hardware instance named `u_half_adder` (not a runtime function call).
- **Named port mapping** (`.port_name(local_wire)`) explicitly pairs each module port with a local wire. Avoid positional mapping (`half_adder u_half_adder (s1, s2, sum, carry);`)—once CPU modules grow to 15+ ports, swapping two positional wires by mistake compiles silently and creates maddening bugs{{sidenote:In Verilog, leaving an output unconnected or mis-ordered with positional ports rarely causes a compile error; named ports make miswiring jump off the screen and let <code>-Wall</code> catch width mismatches immediately.}}.

### Block 2: The 6-Wire `gates` Bus and Active-Low Polarity Boundary

```verilog caption="Collecting all 6 gates onto gates[5:0] and inverting once for led[5:0]"
    wire [5:0] gates;
    assign gates[0] = sum;
    assign gates[1] = carry;
    assign gates[2] = s1 | s2;
    assign gates[3] = ~(s1 & s2);
    assign gates[4] = ~(s1 | s2);
    assign gates[5] = s1 ~^ s2;

    assign led = ~gates;
endmodule
```

- Separating `gates` (active-high logic) from `led = ~gates` (active-low physical pins) keeps the design readable and self-documenting: you verify `gates` in human Boolean terms, and invert the entire 6-bit vector at the very last line.
- Notice `~gates` applies bitwise inversion across all 6 wires at once (`~gates[5]`, `~gates[4]`, ..., `~gates[0]`).

### Complete `top.v` Listing

```verilog caption="apps/0002-half-adder-and-waveforms/top.v"
`timescale 1ns / 1ps

module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire sum;
    wire carry;

    half_adder u_half_adder (
        .a(s1),
        .b(s2),
        .sum(sum),
        .carry(carry)
    );

    wire [5:0] gates;
    assign gates[0] = sum;
    assign gates[1] = carry;
    assign gates[2] = s1 | s2;
    assign gates[3] = ~(s1 & s2);
    assign gates[4] = ~(s1 | s2);
    assign gates[5] = s1 ~^ s2;

    assign led = ~gates;
endmodule
```

When Yosys synthesises `half_adder.v` and `top.v` for the Gowin `GW2AR-18` (`synth_gowin -top top`), the entire circuit compiles down to **2 `IBUF`**, **6 `LUT2`**, and **6 `OBUF`** cells—with **0 flip-flops**. Even the active-low inversion (`assign led = ~gates`) costs zero extra gates because Yosys simply flips the output column inside each 2-input LUT's truth table.

## 4. Self-Checking Testbenches & The "Fail Once on Purpose" Rule

In Lesson 1 we tested `top.v` as one whole unit. Now that we have a reusable `half_adder` submodule, we follow standard hardware hygiene: write a focused **unit testbench** (`half_adder_tb.v`) for `half_adder` and an **integration testbench** (`top_tb.v`) for `top`.

```verilog caption="apps/0002-half-adder-and-waveforms/half_adder_tb.v"
`timescale 1ns / 1ps

module half_adder_tb;
    reg  a = 1'b0;
    reg  b = 1'b0;
    wire sum;
    wire carry;

    half_adder dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry(carry)
    );

    task check_case(
        input reg in_a,
        input reg in_b,
        input reg exp_sum,
        input reg exp_carry
    );
        begin
            a = in_a;
            b = in_b;
            #10;
            if (sum !== exp_sum || carry !== exp_carry) begin
                $fatal(
                    1,
                    "half_adder mismatch for a=%b b=%b: got sum=%b carry=%b expected sum=%b carry=%b",
                    a, b, sum, carry, exp_sum, exp_carry
                );
            end
        end
    endtask

    initial begin
        $dumpfile("build/half_adder.vcd");
        $dumpvars(0, half_adder_tb);

        check_case(1'b0, 1'b0, 1'b0, 1'b0);
        check_case(1'b0, 1'b1, 1'b1, 1'b0);
        check_case(1'b1, 1'b0, 1'b1, 1'b0);
        check_case(1'b1, 1'b1, 1'b0, 1'b1);

        $display("PASS: all 4 half_adder truth-table cases passed");
        $finish;
    end
endmodule
```

Two details here save hours of debugging later in the course:

1. **Why `#10` spacing instead of `#1`?** Each call to `check_case` holds `(a, b)` steady for 10 ns before checking and moving on. When you open `build/half_adder.vcd` in Surfer, the four truth-table rows span four clean 10 ns columns (`0–10 ns`, `10–20 ns`, `20–30 ns`, `30–40 ns`) rather than squashed 1 ns slivers.
2. **Why `!==` (case inequality) instead of `!=`?** Unlike software booleans, Verilog wires use **4-state logic**: `0`, `1`, `x` (unknown/uninitialised), and `z` (high-impedance/undriven). If you accidentally forget to wire `.sum(sum)` inside `half_adder`, `sum` floats at `1'bz`. With `!=`, evaluating `(1'bz != 1'b0)` yields `1'bx`—and in Verilog an `if (1'bx)` branch is **not taken**! The buggy test passes silently. With `!==` (four-state case inequality), `(1'bz !== 1'b0)` evaluates strictly to `1'b1`, firing `$fatal` immediately{{sidenote:Always use <code>===</code> and <code>!==</code> in Verilog testbenches (and never <code>==</code> or <code>!=</code>) whenever comparing against expected constants. In synthesisable RTL inside <code>top.v</code>, stick to <code>==</code> and <code>!=</code>.}}.

Our integration testbench `top_tb.v` checks all 6 gates and the active-low inversion together in one 6-bit vector comparison (`led !== ~exp_gates`):

```verilog caption="apps/0002-half-adder-and-waveforms/top_tb.v"
`timescale 1ns / 1ps

module top_tb;
    reg        s1 = 1'b0;
    reg        s2 = 1'b0;
    wire [5:0] led;

    top dut (
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    task check_gates(
        input reg       in_s1,
        input reg       in_s2,
        input reg [5:0] exp_gates
    );
        begin
            s1 = in_s1;
            s2 = in_s2;
            #10;
            if (led !== ~exp_gates) begin
                $fatal(
                    1,
                    "top mismatch for s1=%b s2=%b: got led=%b expected led=%b",
                    s1, s2, led, ~exp_gates
                );
            end
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        check_gates(1'b0, 1'b0, 6'b111000);
        check_gates(1'b0, 1'b1, 6'b001101);
        check_gates(1'b1, 1'b0, 6'b001101);
        check_gates(1'b1, 1'b1, 6'b100110);

        $display("PASS: all 4 top-level 6-gate and active-low LED cases passed");
        $finish;
    end
endmodule
```

:::callout title="The 'Fail Once on Purpose' Rule"
A green testbench you have never seen fail proves almost nothing—maybe the assertions were never reached, or `!=` swallowed an `x`. Every time you write a new testbench, **break the design on purpose once**: temporarily change `assign sum = a ^ b;` in `half_adder.v` to `assign sum = a | b;`, run `make -C apps/0002-half-adder-and-waveforms test`, confirm `half_adder_tb` aborts loudly on `a=1 b=1` (`got sum=1 carry=1 expected sum=0 carry=1`), and then restore `a ^ b`.
:::

## 5. Inspecting VCD Waveforms in Surfer

Terminal `$display` output tells you *whether* a test passed; a **VCD (Value Change Dump)** waveform tells you *when* and *why* signals changed over time. Whenever `vvp` runs `half_adder_tb.v`, `$dumpfile("build/half_adder.vcd")` and `$dumpvars(0, half_adder_tb)` record every signal transition in `half_adder_tb` and its child `dut` into `build/half_adder.vcd`.

Launch Surfer directly via the `Makefile`:

```bash caption="Open the half_adder simulation waveform in Surfer"
make -C apps/0002-half-adder-and-waveforms wave
```

Once Surfer opens:
1. In the left **Scopes** tree, expand `half_adder_tb` → `dut`.
2. Select `a`, `b`, `sum`, and `carry` to add them to the waveform pane.
3. Press **`f`** (Zoom to Fit) so the full `0` to `40 ns` run fills the screen.
4. Click across the four 10 ns intervals (`0–10 ns`, `10–20 ns`, `20–30 ns`, `30–40 ns`) and watch the cursor readout verify `(0,0) -> (0,0)`, `(0,1) -> (1,0)`, `(1,0) -> (1,0)`, and `(1,1) -> (0,1)`.
5. Run `make -C apps/0002-half-adder-and-waveforms wave-top` to inspect `build/top.vcd` and compare active-high `gates[5:0]` inside `dut` against active-low `led[5:0]` at the pins.

---

:::exercise id="ex-0002" title="Interactive Lab: Half Adder, Named Ports & Four-State Check" badge="Skill Practice • Combinational Verilog"
Complete the two gate expressions inside `half_adder`, wire `.sum(sum)` by name inside `top`, and use the 4-state inequality check in the testbench:

```verilog
module half_adder (input wire a, input wire b, output wire sum, output wire carry);
    assign sum   = {{blank:a ^ b||b ^ a|XOR of a and b|???|5}};
    assign carry = {{blank:a & b||b & a|AND of a and b|???|5}};
endmodule

half_adder u_half_adder (
    .a(s1),
    .b(s2),
    {{blank:.sum(sum)|Named port connection for sum|???|9}},
    .carry(carry)
);

if (sum {{blank:!==|Four-state case inequality|???|3}} exp_sum) $fatal(1, "mismatch");
```

:::prompts
hint: "Use `a ^ b` for sum, `a & b` for carry, `.sum(sum)` for named port mapping, and `!==` so `x`/`z` values fail loudly."
success: "Spot on! Named port wiring and 4-state `!==` checks will protect every module we add on the road to the 6502."
:::
:::

:::quiz id="quiz-0002" title="Retrieval Practice: Gates, Half Adder & Simulation" badge="3 Questions • Equal-Length Options"
- question: "Why does `half_adder_tb.v` compare signals with `!==` instead of `!=`?"
  wrong_hint: "Think about what happens in Verilog when an output wire is undriven (`x` or `z`)."
  options:
    - letter: "A"
      text: "Because standard inequality evaluates faster during Icarus Verilog testbench compilation."
      correct: false
      explain: "Operator choice does not change compile speed; it changes how 4-state unknowns behave."
    - letter: "B"
      text: "Because four-state comparison automatically adds ten nanoseconds of simulation delay."
      correct: false
      explain: "Simulation time only advances on explicit `#delay` statements or edge waits."
    - letter: "C"
      text: "Because case inequality treats unknown x values as real mismatches."
      correct: true
      explain: "Correct: `sum != 1'b0` returns `x` when `sum` is `x`/`z`, which `if (...)` skips, whereas `!==` returns `1` and triggers `$fatal`."
    - letter: "D"
      text: "Because logical inequality only works inside clocked sequential always blocks."
      correct: false
      explain: "`!=` is legal inside `initial` and `task` blocks—it just treats `x`/`z` values silently."
- question: "How do you write a two-input NAND gate in Verilog?"
  wrong_hint: "Remember which operator is unary reduction vs. binary bitwise."
  options:
    - letter: "A"
      text: "Invert the bitwise AND expression using a tilde outside parentheses."
      correct: true
      explain: "Correct: `~(a & b)` applies bitwise AND first and inverts the result; `~&` is unary reduction on a single vector."
    - letter: "B"
      text: "Combine both wire inputs using the binary tilde-ampersand infix operator."
      correct: false
      explain: "`~&` is a unary reduction operator in Verilog, so `a ~& b` is a syntax error."
    - letter: "C"
      text: "Place an exclamation mark between the two input wire names."
      correct: false
      explain: "`!` is logical negation (unary), not a binary infix gate operator."
    - letter: "D"
      text: "Negate the exclusive-OR wire output before routing to output pins."
      correct: false
      explain: "`~(a ^ b)` produces XNOR, not NAND."
- question: "Why can a single Half Adder not add bit 1 of two multi-bit bytes?"
  wrong_hint: "Think about what overflows from bit 0 into bit 1 when `1 + 1` happens."
  options:
    - letter: "A"
      text: "Because XOR gates cannot operate on wires wider than one."
      correct: false
      explain: "Bitwise `^` works on buses of any width, though without carry propagation between bits."
    - letter: "B"
      text: "Because Gowin LUTs only accept signals coming from push buttons."
      correct: false
      explain: "LUTs accept signals from any internal wire, register, or input pin."
    - letter: "C"
      text: "Because combinational adders require a clock divider before bit one."
      correct: false
      explain: "Adders are purely combinational and do not require a clock divider."
    - letter: "D"
      text: "Because it has no carry-in port from the previous column."
      correct: true
      explain: "Correct: bit 1 needs a three-input Full Adder (`a`, `b`, and `carry_in` from bit 0)."
:::

:::verify id="verify-0002" title="Verification Lab: Test, Fault-Inject, Inspect in Surfer & Flash" badge="Simulation & Hardware Gate"
Run both testbenches and the bitstream build, practice the fail-once-on-purpose check, inspect the waveform in Surfer, and flash your Tang Nano 20K:

```bash caption="Simulate, inspect waveforms, and flash Lesson 2 onto the Tang Nano 20K"
make -C apps/0002-half-adder-and-waveforms clean all
make -C apps/0002-half-adder-and-waveforms wave
make -C apps/0002-half-adder-and-waveforms flash
```

- [ ] `make -C apps/0002-half-adder-and-waveforms clean all` passes with zero `iverilog -Wall` warnings and prints both `PASS:` messages.
- [ ] Temporarily breaking `sum` to `a | b` in `half_adder.v` causes `make test` to fail loudly at `a=1 b=1` (and you restored `a ^ b` afterwards).
- [ ] In Surfer (`make wave`), `a`, `b`, `sum`, and `carry` clearly show all four 10 ns truth-table windows.
- [ ] On the flashed Tang Nano 20K, with neither button pressed, `led[5:0]` shows `XNOR`, `NOR`, `NAND` lit (`led[5]`, `led[4]`, `led[3]` on) and `OR`, `carry`, `sum` off (`led[2:0]` off); pressing `S1` or `S2` alone lights `sum` (`led[0]`, `1` in binary) plus `OR`/`NAND`; pressing **both** `S1` + `S2` lights `carry` (`led[1]`, `10`₂ = `2` in binary) plus `OR`/`XNOR`.
:::

:::teacher-prompt title="Ask Your AI Teacher & Preview Lesson 3"
Once you've inspected `half_adder.vcd` in Surfer and added `1 + 1 = 2` on your Tang Nano 20K's LEDs, ask any questions about named port wiring, 4-state `!==` checks, or Surfer navigation—or say **"ready for Lesson 3"** to build a Full Adder from two Half Adders, chain eight of them into an 8-bit ripple-carry adder, and test all 131,072 possible additions.
:::
