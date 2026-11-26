---
title: "Full Adder, 8-Bit Ripple Carry & Exhaustive Testing"
page_title: "Lesson 0003: Full Adder, 8-Bit Ripple Carry & Exhaustive Testing — Build Your Own 6502"
nav_id: "lesson-0003"
badge: "Lesson 0003 • Multi-Bit Arithmetic & Synthesis"
subtitle: "Compose two Half Adders into a 1-bit Full Adder, chain eight Full Adders into an 8-bit ripple-carry adder, test all 131,072 additions exhaustively, and compare LUTs against Gowin's dedicated carry chain."
card:
  title: "**Full Adder, 8-Bit Ripple Carry & Exhaustive Testing**"
  summary: "Build an 8-bit ripple-carry adder from Full Adders, route nibbles with ternary multiplexers, verify all 131,072 inputs, and inspect Yosys carry-chain synthesis."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0003-8bit-ripple-carry-adder/` (`make -C apps/0003-8bit-ripple-carry-adder clean all`)
- **Video reference**: [Episode 3: I Built an 8-Bit Adder and Tested Every Possible Addition](https://www.youtube.com/watch?v=P7UMo3etuU0)
- **Simulation & synthesis**: [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/) and [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula)
- **Course references**: [Lesson 2](0002-half-adder-and-waveforms.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. From Half Adder to Full Adder

In [Lesson 2](0002-half-adder-and-waveforms.md), our two-gate `half_adder` added `a` and `b` cleanly for column `0`. The snag appears the moment we step left to column `1`: when `1 + 1` in bit `0` overflows, bit `1` has to accept **three** single-bit inputs—`a`, `b`, and `carry_in`.

$$a + b + c_{\text{in}} = 2^1 \cdot c_{\text{out}} + 2^0 \cdot \text{sum}$$

Adding three single-bit numbers can yield `0`, `1`, `2`, or `3` (`2'b11`), which maps out across eight rows:

Table: 1-Bit Full Adder Truth Table

| `a` | `b` | `carry_in` | Decimal Sum | `carry_out` | `sum` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0` | `0` | `0` | `0` (`00`₂) | `0` | `0` |
| `0` | `0` | `1` | `1` (`01`₂) | `0` | `1` |
| `0` | `1` | `0` | `1` (`01`₂) | `0` | `1` |
| `0` | `1` | `1` | `2` (`10`₂) | `1` | `0` |
| `1` | `0` | `0` | `1` (`01`₂) | `0` | `1` |
| `1` | `0` | `1` | `2` (`10`₂) | `1` | `0` |
| `1` | `1` | `0` | `2` (`10`₂) | `1` | `0` |
| `1` | `1` | `1` | `3` (`11`₂) | `1` | `1` |

Instead of starting over from raw gates, we can compose a **Full Adder** out of two instances of the `half_adder` module we already built and tested in Lesson 2, plus one `OR` gate:

```mermaid caption="Figure 3.1: Composing a 1-bit Full Adder from two Half Adders and an OR gate"
flowchart LR
  A["a"] --> HA1["u_ha1 (half_adder)"]
  B["b"] --> HA1
  HA1 -->|"s1"| HA2["u_ha2 (half_adder)"]
  CIN["carry_in"] --> HA2
  HA2 -->|"sum"| SUM["sum"]
  HA1 -->|"c1"| OR["OR (c1 | c2)"]
  HA2 -->|"c2"| OR
  OR --> COUT["carry_out"]
```

Why does `c1 | c2` work without risking a lost carry? Because `c1` and `c2` can never both be `1` on the same input{{sidenote:For <code>c2</code> (<code>s1 &amp; carry_in</code>) to equal <code>1</code>, the partial sum <code>s1 = a ^ b</code> must be <code>1</code>—which means <code>a</code> and <code>b</code> differ, forcing <code>c1 = a &amp; b</code> to <code>0</code>.}}.

### Block 1: First Half Adder and Internal Wires (`full_adder.v`)

```verilog caption="Module interface and first-stage Half Adder in full_adder.v"
`timescale 1ns / 1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire carry_in,
    output wire sum,
    output wire carry_out
);
    wire s1;
    wire c1;
    wire c2;

    half_adder u_ha1 (
        .a(a),
        .b(b),
        .sum(s1),
        .carry(c1)
    );
```

- `wire s1;`, `wire c1;`, and `wire c2;` declare internal single-bit interconnects linking our submodules.
- `u_ha1` adds `a` and `b`, producing intermediate sum `s1` and first carry `c1`.

### Block 2: Second Half Adder and Carry OR Gate

```verilog caption="Adding carry_in and combining both carries in full_adder.v"
    half_adder u_ha2 (
        .a(s1),
        .b(carry_in),
        .sum(sum),
        .carry(c2)
    );

    assign carry_out = c1 | c2;
endmodule
```

- `u_ha2` adds `s1` and `carry_in`, driving the module's final `sum` output and second carry `c2`.
- `assign carry_out = c1 | c2;` raises `carry_out` whenever either addition overflowed.

### Full `full_adder.v` Module

```verilog caption="apps/0003-8bit-ripple-carry-adder/full_adder.v"
`timescale 1ns / 1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire carry_in,
    output wire sum,
    output wire carry_out
);
    wire s1;
    wire c1;
    wire c2;

    half_adder u_ha1 (
        .a(a),
        .b(b),
        .sum(s1),
        .carry(c1)
    );

    half_adder u_ha2 (
        .a(s1),
        .b(carry_in),
        .sum(sum),
        .carry(c2)
    );

    assign carry_out = c1 | c2;
endmodule
```

## 2. Chaining Eight Full Adders (`adder8.v`)

The 6502 is an 8-bit processor: its accumulator, index registers, and ALU data paths are all 8 bits wide. To add two 8-bit numbers `a[7:0]` and `b[7:0]` plus an incoming `carry_in`, we wire eight `full_adder` instances side by side so the `carry_out` of column $i$ feeds the `carry_in` of column $i+1$.

```mermaid caption="Figure 3.2: 8-bit Ripple-Carry Adder chain from bit 0 to bit 7"
flowchart LR
  CIN["carry_in"] --> FA0["u_fa0<br/>bit 0"]
  FA0 -->|"c[0]"| FA1["u_fa1<br/>bit 1"]
  FA1 -->|"c[1]"| FA2["u_fa2<br/>bit 2"]
  FA2 -->|"c[2] .. c[5]"| FA6["u_fa6<br/>bit 6"]
  FA6 -->|"c[6]"| FA7["u_fa7<br/>bit 7"]
  FA7 --> COUT["carry_out"]
```

Why is this topology called a **ripple-carry adder**? Although all eight `full_adder` blocks sit in silicon simultaneously, bit `7`'s `sum[7]` and final `carry_out` cannot settle until the carry signal has rippled through bits `0`, `1`, `2`, `3`, `4`, `5`, and `6` in turn{{sidenote:Think of adding <code>8'hFF + 8'h00 + 1'b1</code>: bit 0 overflows into <code>c[0]</code>, which flips bit 1 and raises <code>c[1]</code>, all the way up to <code>carry_out</code>. That worst-case carry chain determines the adder's critical path delay.}}.

### Full `adder8.v` Module

```verilog caption="apps/0003-8bit-ripple-carry-adder/adder8.v"
`timescale 1ns / 1ps

module adder8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] sum,
    output wire       carry_out
);
    wire [6:0] c;

    full_adder u_fa0 (.a(a[0]), .b(b[0]), .carry_in(carry_in), .sum(sum[0]), .carry_out(c[0]));
    full_adder u_fa1 (.a(a[1]), .b(b[1]), .carry_in(c[0]),     .sum(sum[1]), .carry_out(c[1]));
    full_adder u_fa2 (.a(a[2]), .b(b[2]), .carry_in(c[1]),     .sum(sum[2]), .carry_out(c[2]));
    full_adder u_fa3 (.a(a[3]), .b(b[3]), .carry_in(c[2]),     .sum(sum[3]), .carry_out(c[3]));
    full_adder u_fa4 (.a(a[4]), .b(b[4]), .carry_in(c[3]),     .sum(sum[4]), .carry_out(c[4]));
    full_adder u_fa5 (.a(a[5]), .b(b[5]), .carry_in(c[4]),     .sum(sum[5]), .carry_out(c[5]));
    full_adder u_fa6 (.a(a[6]), .b(b[6]), .carry_in(c[5]),     .sum(sum[6]), .carry_out(c[6]));
    full_adder u_fa7 (.a(a[7]), .b(b[7]), .carry_in(c[6]),     .sum(sum[7]), .carry_out(carry_out));
endmodule
```

- `wire [6:0] c;` holds the seven internal carry wires connecting the eight stages (`u_fa0`..`u_fa7`).
- Writing all eight instances explicitly makes the bit-by-bit ripple crystal clear; for 16-bit or 32-bit buses later, Verilog also offers `generate` / `genvar` loops to instantiate repetitive hardware without copy-pasting lines.

## 3. Hardware Multiplexers (`? :`) & Wiring `top.v`

Our Tang Nano 20K only has **6 onboard LEDs**, yet `adder8` outputs **9 bits** (`8`-bit `sum` plus `carry_out`). How do we inspect a 9-bit result on 6 LEDs using our two push-buttons `s1` and `s2`? With a **hardware multiplexer** (`? :`).

In C or Python, `cond ? x : y` is a control-flow branch. In Verilog RTL, `cond ? x : y` wires a **combinational multiplexer (mux)**: a physical selector switch built from LUTs that continuously routes either bus `x` (when `cond == 1`) or bus `y` (when `cond == 0`) to the output wire. Both inputs are live at all times—only the selector bit picks which wire reaches the LEDs.

### Block 1: Selecting Operands with a Ternary Mux

```verilog caption="Operand mux and adder8 instantiation in top.v"
module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire [7:0] a = s1 ? 8'hFA : 8'h15;
    wire [7:0] b = 8'h23;
    wire       carry_in = 1'b0;

    wire [7:0] sum;
    wire       carry_out;

    adder8 u_adder8 (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );
```

- Button `s1` acts as the selector for operand `a`:
  - `s1 == 0`: adds `0x15 + 0x23 = 0x38` (`21 + 35 = 56`), with `carry_out = 0`.
  - `s1 == 1`: adds `0xFA + 0x23 = 0x11D` (`250 + 35 = 285`), wrapping the 8-bit `sum` to `0x1D` (`29`) and raising `carry_out = 1`.

### Block 2: Nibble Selector Mux and Active-Low LED Boundary

```verilog caption="Routing lower or upper nibble and inverting for active-low LEDs"
    wire [3:0] nibble = s2 ? sum[7:4] : sum[3:0];
    wire [5:0] display = {s2, carry_out, nibble};

    assign led = ~display;
endmodule
```

- Button `s2` feeds a second 4-bit mux: hold `s2` to view the upper nibble `sum[7:4]` on `led[3:0]`, or release it to view the lower nibble `sum[3:0]`.
- `{s2, carry_out, nibble}` uses Verilog **bit concatenation** to pack `s2` onto `led[5]`, `carry_out` onto `led[4]`, and the 4-bit `nibble` onto `led[3:0]` before `assign led = ~display;` flips polarity once for the active-low board LEDs.

Table: All Four Button Combinations on the Tang Nano 20K

| `s1` | `s2` | Addition (`a + b`) | `carry_out` (`led[4]`) | Displayed `nibble` (`led[3:0]`) | Active-High `display` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0` | `0` | `0x15 + 0x23 = 0x038` | `0` (off) | `sum[3:0] = 4'h8` (`1000`) | `6'b00_1000` |
| `0` | `1` | `0x15 + 0x23 = 0x038` | `0` (off) | `sum[7:4] = 4'h3` (`0011`) | `6'b10_0011` |
| `1` | `0` | `0xFA + 0x23 = 0x11D` | `1` (on) | `sum[3:0] = 4'hD` (`1101`) | `6'b01_1101` |
| `1` | `1` | `0xFA + 0x23 = 0x11D` | `1` (on) | `sum[7:4] = 4'h1` (`0001`) | `6'b11_0001` |

### Complete `top.v` Listing

```verilog caption="apps/0003-8bit-ripple-carry-adder/top.v"
`timescale 1ns / 1ps

module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire [7:0] a = s1 ? 8'hFA : 8'h15;
    wire [7:0] b = 8'h23;
    wire       carry_in = 1'b0;

    wire [7:0] sum;
    wire       carry_out;

    adder8 u_adder8 (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    wire [3:0] nibble = s2 ? sum[7:4] : sum[3:0];
    wire [5:0] display = {s2, carry_out, nibble};

    assign led = ~display;
endmodule
```

## 4. Exhaustive Verification: All 131,072 Additions

With a 1-bit `half_adder`, 4 test cases covered 100% of the truth table. With `full_adder`, 8 cases cover 100%. What about `adder8`? Two 8-bit operands and a 1-bit `carry_in` give:

$$2^8 \times 2^8 \times 2^1 = 256 \times 256 \times 2 = 131{,}072 \text{ combinations}$$

That is small enough for `vvp` to test **every single possible input** in well under a second—leaving zero hiding places for a miswired carry bit like `.carry_in(c[2])` duplicated on `u_fa4`.

There is one practical trick when dumping waveforms during exhaustive loops: if you leave `$dumpvars` recording for all 131,072 iterations, your `.vcd` file balloons to tens of megabytes and Surfer slows to a crawl. In `adder8_tb.v`, we run five readable 10 ns showcase cases first (including `8'hFF + 8'h00 + 1'b1`, where a single carry ripples across all eight columns), call `$dumpoff;`, and then sweep all 131,072 combinations at `#1` spacing:

```verilog caption="apps/0003-8bit-ripple-carry-adder/adder8_tb.v"
`timescale 1ns / 1ps

module adder8_tb;
    reg  [7:0] a = 8'h00;
    reg  [7:0] b = 8'h00;
    reg        carry_in = 1'b0;
    wire [7:0] sum;
    wire       carry_out;

    adder8 dut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    task show_case(
        input reg [7:0] in_a,
        input reg [7:0] in_b,
        input reg       in_cin
    );
        reg [8:0] expected;
        begin
            a = in_a;
            b = in_b;
            carry_in = in_cin;
            #10;
            expected = {1'b0, a} + {1'b0, b} + {8'd0, carry_in};
            if ({carry_out, sum} !== expected) begin
                $fatal(
                    1,
                    "adder8 mismatch for a=%02h b=%02h cin=%b: got %b_%02h expected %b_%02h",
                    a, b, carry_in, carry_out, sum, expected[8], expected[7:0]
                );
            end
        end
    endtask

    integer ia, ib, ic;
    integer checked;
    reg [8:0] expected;

    initial begin
        $dumpfile("build/adder8.vcd");
        $dumpvars(0, adder8_tb);

        show_case(8'h00, 8'h00, 1'b0);
        show_case(8'h15, 8'h23, 1'b0);
        show_case(8'hFA, 8'h23, 1'b0);
        show_case(8'hFF, 8'h00, 1'b1);
        show_case(8'hFF, 8'hFF, 1'b1);

        $dumpoff;

        checked = 0;
        for (ia = 0; ia < 256; ia = ia + 1) begin
            for (ib = 0; ib < 256; ib = ib + 1) begin
                for (ic = 0; ic < 2; ic = ic + 1) begin
                    a = ia[7:0];
                    b = ib[7:0];
                    carry_in = ic[0];
                    #1;
                    expected = {1'b0, a} + {1'b0, b} + {8'd0, carry_in};
                    if ({carry_out, sum} !== expected) begin
                        $fatal(
                            1,
                            "adder8 mismatch for a=%02h b=%02h cin=%b: got %b_%02h expected %b_%02h",
                            a, b, carry_in, carry_out, sum, expected[8], expected[7:0]
                        );
                    end
                    checked = checked + 1;
                end
            end
        end

        $display("PASS: all %0d exhaustive adder8 cases passed", checked);
        $finish;
    end
endmodule
```

- Notice `{1'b0, a} + {1'b0, b} + {8'd0, carry_in}` zero-extends all three terms to 9 bits before adding, matching the 9-bit `expected` target with zero `-Wall` width warnings.
- Remember the **fail-once-on-purpose** rule from Lesson 2: if you accidentally connect `u_fa5`'s `.carry_in(c[3])` instead of `c[4]` in `adder8.v`, `make test` catches the bug immediately and reports the exact failing hex operands.

## 5. Synthesis Insights: LUTs vs. Dedicated Carry Chains

Building `adder8` out of `half_adder` and `full_adder` modules teaches us exactly how addition works at the gate level. Now let's ask a practical FPGA question: what does `yosys` actually put onto the Gowin `GW2AR-18` silicon when we synthesise it?

Run `make -C apps/0003-8bit-ripple-carry-adder stats` to see what Yosys produces for the standalone `adder8` module, and compare it against two other synthesis targets on the same chip:

Table: Verified Gowin `GW2AR-18` Cell Counts (`yosys` `synth_gowin; stat`)

| Design Under Synthesis | `LUT1`–`LUT4` | `MUX2_LUT5`–`LUT8` | Hard `ALU` Cells | `IBUF` / `OBUF` | Why? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Structural `adder8` (`full_adder` chain) | `49` (`12` + `6` + `6` + `25`) | `32` (`19` + `8` + `4` + `1`) | `0` | `17` / `9` | Yosys flattens hand-wired gates into LUTs and LUT mux trees |
| Behavioural `a + b + carry_in` | `0` | `0` | `9` | `17` / `9` | Yosys recognises `+` and maps directly to Gowin's fast carry chain |
| Constant-folded `top.v` | `5` (`2` + `3`) | `0` | `0` | `2` / `6` | With constant `b` and muxed `a`, Yosys precomputes both sums at compile time |

Two real takeaways jump straight out of those numbers:

1. **Why we wrote gates here, and why we'll switch to `+` for the 6502 ALU**: Inside each Gowin logic slice sits a hardwired **carry chain** (`ALU` primitive) built specifically so carries sprint across bits in sub-nanosecond silicon without burning general-purpose LUTs. When we write our 6502's shared 9-bit ALU in Lesson 13, using Verilog's `+` operator lets Yosys tap those `9 ALU` cells automatically—saving dozens of LUTs for the instruction decoder and sequencer.
2. **Dead-logic and constant propagation**: Notice `top.v` collapsed from 49 LUTs down to just `2 LUT1 + 3 LUT2`! Because `b` (`8'h23`), `carry_in` (`1'b0`), and both `s1` inputs (`8'h15` and `8'hFA`) are known at synthesis time, Yosys evaluates the entire 8-bit adder at compile time and ships only the 5 tiny LUTs needed to drive the 6 LEDs from `s1` and `s2`. Remember that optimisation when we build the CPU in Lesson 12—if an output doesn't depend on a dynamic input or isn't wired to a pin, Yosys will happily prune whole blocks away!

---

:::exercise id="ex-0003" title="Interactive Lab: Full Adder, Ripple Chain & Ternary Mux" badge="Skill Practice • Multi-Bit Verilog"
Fill in the missing Full Adder carry expression, the ripple carry link into bit 1, the upper-nibble ternary selector, and the 9-bit golden testbench check:

```verilog
assign carry_out = {{blank:c1 | c2||c2 | c1|OR of both half-adder carries|???|7}};

full_adder u_fa1 (.a(a[1]), .b(b[1]), .carry_in({{blank:c[0]|Carry out from bit 0|???|4}}), .sum(sum[1]), .carry_out(c[1]));

wire [3:0] nibble = s2 ? {{blank:sum[7:4]|Upper 4 bits of sum|???|8}} : sum[3:0];

if ({{blank:{carry_out, sum}|9-bit concatenated output|???|16}} !== expected) $fatal(1, "mismatch");
```

:::prompts
hint: "Use `c1 | c2` for Full Adder carry_out, `c[0]` for bit 1's carry_in, `sum[7:4]` when `s2` is high, and `{carry_out, sum}` to match the 9-bit expected sum."
success: "Nice work! You just connected structural ripple carries, a combinational mux, and a 9-bit 4-state assertion."
:::
:::

:::quiz id="quiz-0003" title="Retrieval Practice: Full Adders, Muxes & Synthesis" badge="3 Questions • Equal-Length Options"
- question: "Why can the two intermediate half-adder carries (`c1` and `c2`) in a Full Adder never both be `1` at the same time?"
  wrong_hint: "Check what `s1 = a ^ b` must equal when `c1 = a & b` is `1`."
  options:
    - letter: "A"
      text: "Because half adders clear their internal carry flip-flop before every single rising clock edge."
      correct: false
      explain: "A half adder is purely combinational and contains no flip-flops or clock."
    - letter: "B"
      text: "Because at least one input must be zero when the first sum is one."
      correct: true
      explain: "Correct: `c2 = s1 & carry_in` requires `s1 = a ^ b = 1`, which guarantees `a` and `b` are not both `1`, so `c1 = a & b` is `0`."
    - letter: "C"
      text: "Because Yosys automatically drops the second carry wire during Gowin Look-Up Table cell synthesis."
      correct: false
      explain: "This property holds in pure Boolean arithmetic regardless of how synthesis maps it."
    - letter: "D"
      text: "Because the final OR gate inverts both carry wires before bit one ever runs."
      correct: false
      explain: "An OR gate (`|`) combines carries without inverting them."
- question: "What does Verilog's ternary expression `s2 ? sum[7:4] : sum[3:0]` synthesise to in FPGA hardware?"
  wrong_hint: "Remember that combinational hardware does not execute branches over time."
  options:
    - letter: "A"
      text: "A conditional branch instruction executed sequentially inside an onboard Gowin microcontroller logic core."
      correct: false
      explain: "There is no microcontroller executing software instructions here; the circuit is pure combinational logic."
    - letter: "B"
      text: "A clocked shift register that rotates the byte left by four bit positions."
      correct: false
      explain: "Shift registers require clock edges and flip-flops, whereas `? :` is purely combinational."
    - letter: "C"
      text: "A tristate bus driver that disconnects the unselected nibble into a floating state."
      correct: false
      explain: "Internal FPGA LUT fabric uses multiplexers rather than internal tristate drivers."
    - letter: "D"
      text: "A combinational multiplexer selecting between the upper nibble and the lower nibble wires."
      correct: true
      explain: "Correct: `? :` synthesises to a hardware multiplexer that continuously routes either `sum[7:4]` or `sum[3:0]` based on `s2`."
- question: "Why did Yosys map `a + b + carry_in` to 9 `ALU` cells instead of 49 LUTs?"
  wrong_hint: "Look at what dedicated hardware sits inside Gowin logic slices alongside LUT4s."
  options:
    - letter: "A"
      text: "Because the behavioural plus operator lets Yosys target dedicated hardwired carry-chain silicon cells."
      correct: true
      explain: "Correct: recognising `+` allows `synth_gowin` to map the ripple chain onto Gowin's fast hardwired `ALU` carry cells."
    - letter: "B"
      text: "Because Gowin FPGAs automatically convert any addition expression into a dual-port Block RAM."
      correct: false
      explain: "Block RAM stores arrays of memory words; arithmetic `+` maps to `ALU` carry cells, not BRAM."
    - letter: "C"
      text: "Because Icarus Verilog precomputes every sum into a static constant table before synthesis."
      correct: false
      explain: "Icarus Verilog is a simulator, not part of the Yosys synthesis pipeline, and `adder8_beh` has variable inputs."
    - letter: "D"
      text: "Because behavioural addition skips computing carry-out whenever carry-in starts tied at logic zero."
      correct: false
      explain: "All 9 bits (`sum[7:0]` and `carry_out`) are still computed identically for every input."
:::

:::verify id="verify-0003" title="Verification Lab: Exhaustive Simulation, Synthesis Stats & Board Check" badge="Simulation & Hardware Gate"
Run all three testbenches (including the 131,072-case exhaustive sweep), inspect the Gowin synthesis cell counts, check the carry cascade in Surfer, and flash your Tang Nano 20K:

```bash caption="Simulate, inspect stats and waveforms, and flash Lesson 3"
make -C apps/0003-8bit-ripple-carry-adder clean all
make -C apps/0003-8bit-ripple-carry-adder stats
make -C apps/0003-8bit-ripple-carry-adder wave
make -C apps/0003-8bit-ripple-carry-adder flash
```

- [ ] `make -C apps/0003-8bit-ripple-carry-adder clean all` passes with zero `iverilog -Wall` warnings and prints `PASS:` for all 8 `full_adder`, 131,072 `adder8`, and 4 `top` cases.
- [ ] `make stats` reports `49` LUTs (`LUT1`–`LUT4`), `32` `MUX2_LUT*` cells, and `0` `ALU` cells for the structural `adder8`.
- [ ] In Surfer (`make wave`), expand `adder8_tb` → `dut` and verify the `30–40 ns` window (`a=FF`, `b=00`, `carry_in=1`) shows `c[6:0]` all `1`, `sum=00`, and `carry_out=1`.
- [ ] On the flashed Tang Nano 20K:
  - Neither button pressed (`0x15 + 0x23 = 0x38`): `led[5:0]` shows `00_1000` (only `led[3]` lit).
  - Hold `S2` alone: `led[5:0]` shows `10_0011` (`s2` indicator on `led[5]` + upper nibble `3`).
  - Hold `S1` alone (`0xFA + 0x23 = 0x11D`): `led[5:0]` shows `01_1101` (`carry_out` lit on `led[4]` + lower nibble `0xD`).
  - Hold **both** `S1` + `S2`: `led[5:0]` shows `11_0001` (`s2`, `carry_out`, and `led[0]` lit for upper nibble `1`).
:::

:::teacher-prompt title="Ask Your AI Teacher & Preview Lesson 4"
Once you have verified all 131,072 additions and watched `carry_out` light up `led[4]` on the board, ask any questions about ripple propagation, ternary muxes, or Yosys `ALU` cells—or say **"ready for Lesson 4"** to leave purely combinational circuits behind and build D flip-flops, registers, counters, and your first finite state machine.
:::
