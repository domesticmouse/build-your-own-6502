---
title: "Combinational ALU & Shared 9-Bit Adder Architecture"
page_title: "Lesson 0013: Combinational ALU & Shared 9-Bit Adder Architecture — Build Your Own 6502"
nav_id: "lesson-0013"
badge: "Lesson 0013 • 6502 ALU"
subtitle: "Build a purely combinational 13-operation 6502 ALU in Verilog that shares one 9-bit hardware adder across five arithmetic operations via two's-complement steering."
card:
  title: "**Combinational ALU & Shared 9-Bit Adder**"
  summary: "Implement all 13 6502 ALU operations without a clock, sharing one 9-bit adder across ADD, SUB, CMP, INC, and DEC."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0013-6502-alu-operations/` (`make -C apps/0013-6502-alu-operations clean all`)
- **Video reference**: [Episode 13: Writing the ALU of Our Own 6502 in Verilog](https://www.youtube.com/watch?v=Pn0TVKFSsGY)
- **Upstream reference**: [`yvesrob/6502-gate-by-gate`](https://github.com/yvesrob/6502-gate-by-gate)
- **Course references**: [Lesson 3](0003-8bit-ripple-carry-adder.md), [Lesson 12](0012-first-cpu-fetch-fsm.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. A Clockless Calculator Inside the CPU

In [Lesson 12](0012-first-cpu-fetch-fsm.md), we wrote the first lines of `cpu.v` so our 6502 can wake up at `$C000` and walk through `rom.mem`. Right now, though, our processor cannot add `1` to anything—not even for the `ADC #$01` instruction sitting at `$C006`.

Before we wire arithmetic into the CPU state machine, we build the **Arithmetic and Logic Unit (`alu.v`)** as a standalone, **purely combinational** module. Notice what is missing from `alu.v`'s port list: there is no `clk`, no `reset`, and no `step`. Put an opcode `op`, two 8-bit inputs `a` and `b`, and a `carry_in` bit onto the wires, and the `result` and `carry_out` wires settle purely through logic gates within the same clock cycle.{{sidenote:Keeping the ALU clockless mirrors real 6502 silicon: the combinational logic computes the answer continuously, and the CPU sequencer only latches `result` into `A` or `P` on the exact rising clock edge when an instruction completes.}}

We define **13 operations** in a shared header (`alu_ops.vh`) so both `alu.v` and future CPU modules speak the exact same 4-bit `op` codes:

- **Shared-adder arithmetic (`0`–`4`)**: `ALU_ADD`, `ALU_SUB`, `ALU_CMP`, `ALU_INC`, `ALU_DEC`
- **Bitwise logic (`5`–`7`)**: `ALU_AND`, `ALU_ORA`, `ALU_EOR`
- **Shifts and rotates (`8`–`11`)**: `ALU_ASL`, `ALU_LSR`, `ALU_ROL`, `ALU_ROR`
- **Pass-through (`12`)**: `ALU_PASS` (forwards `b` untouched so load instructions like `LDA` can reuse the ALU's flag wires in the next lesson)

## 2. One Shared 9-Bit Adder, Five Operations

A naive Verilog developer writes five separate `+` and `-` expressions inside a `case (op)` statement. That works in simulation, yet Yosys happily synthesises five separate carry chains in silicon. Instead, we build **one** 9-bit adder:

```text
{1'b0, a} + {1'b0, second} + {8'd0, adder_cin}
```

Why `9` bits wide? Because adding two 8-bit numbers plus a carry-in produces an 8-bit `sum` (`adder_sum[7:0]`) and a 9th carry-out bit (`adder_sum[8]`). By steering just two helper signals—an 8-bit `second` operand and a 1-bit `adder_cin`—that single adder handles all five arithmetic operations:

```mermaid caption="Figure 13.1: Steering one shared 9-bit adder across five 6502 ALU operations"
flowchart LR
  A["Input a (8-bit)"] --> ADD["9-Bit Adder: a + second + adder_cin"]
  B["Input b (8-bit)"] --> MUX2["second Mux"]
  MUX2 -->|"ADD: b / SUB,CMP: ~b / INC: $00 / DEC: $FF"| ADD
  CIN["carry_in"] --> MUXC["adder_cin Mux"]
  MUXC -->|"ADD,SUB: carry_in / CMP,INC: 1 / DEC: 0"| ADD
  ADD -->|"adder_sum[7:0]"| RES["Final result Mux"]
  ADD -->|"adder_sum[8]"| COUT["carry_out Mux"]
  LOGIC["AND / ORA / EOR / Shifts / PASS"] --> RES
```

Look closely at every row of the steering table below—especially `ALU_SUB`, `ALU_CMP`, and `ALU_DEC`:

Table: Input Steering and Carry Behaviour for the Five Shared-Adder Operations

| `op` | `second` | `adder_cin` | Effective Equation | `carry_out` |
| :--- | :--- | :--- | :--- | :--- |
| `ALU_ADD` | `b` | `carry_in` | $a + b + c_{\text{in}}$ | `adder_carry` |
| `ALU_SUB` | `~b` | `carry_in` | $a + \overline{b} + c_{\text{in}}$ | `adder_carry` (inverted borrow) |
| `ALU_CMP` | `~b` | `1'b1` | $a + \overline{b} + 1$ | `adder_carry` (`1` if $a \ge b$) |
| `ALU_INC` | `8'h00` | `1'b1` | $a + 0 + 1$ | `1'b0` (6502 `INC`/`INX` leaves `C` unchanged) |
| `ALU_DEC` | `8'hFF` | `1'b0` | $a + 255 + 0 \equiv a - 1 \pmod{256}$ | `1'b0` (6502 `DEC`/`DEX` leaves `C` unchanged) |

### Why Subtraction Uses `~b + carry_in` (Inverted Borrow)

In two's-complement arithmetic, negating an 8-bit number `b` is `-b = ~b + 1`. So computing `a - b` with no incoming borrow is literally `a + (~b) + 1`.

On the 6502, the Carry flag during subtraction represents **no borrow** (that is why 6502 programmers always write `SEC` before `SBC`, and `CLC` before `ADC`):

- When `carry_in == 1` (carry set = **no borrow**): `a + ~b + 1` computes $a - b$.
- When `carry_in == 0` (carry clear = **borrow pending**): `a + ~b + 0` computes $a - b - 1$.
- Look at the 9th bit `adder_carry`: if $a \ge b$ (no unsigned borrow needed), `a + ~b + 1` wraps past `255` and produces `adder_carry = 1` (keep Carry set!). If $a < b$ (unsigned borrow occurred), the sum stays below `256` and `adder_carry = 0` (Carry cleared!).

`ALU_CMP` (used by `CMP`, `CPX`, and `CPY`) uses the exact same `~b` subtraction, except it forces `adder_cin = 1'b1` regardless of the processor's current Carry flag. Comparing two numbers never depends on a stale carry left over from an earlier addition!

And look at `ALU_DEC`: adding `8'hFF` (`255`) with `adder_cin = 1'b0` produces `(a + 255) & 8'hFF = (a - 1) & 8'hFF`. Meanwhile, `ALU_INC` adds `8'h00 + 1'b1`. Both force `carry_out = 1'b0` in the output multiplexer because 6502 increment and decrement instructions never touch the Carry flag.

## 3. Bitwise Logic and Zero-Gate Shifts

Once the shared adder is wired, the remaining eight operations take almost no silicon at all:

- **Bitwise logic (`AND`, `ORA`, `EOR`)**: Straight Verilog operators `a & b`, `a | b`, and `a ^ b`, with `carry_out = 1'b0`.
- **Shifts and rotates (`ASL`, `LSR`, `ROL`, `ROR`)**: Pure **bit-slice wiring**! Shifting `a` left (`{a[6:0], 1'b0}`) or rotating left through carry (`{a[6:0], carry_in}`) uses zero adders and zero LUTs for arithmetic—only routing wires into the output mux:
  - `ALU_ASL`: `result = {a[6:0], 1'b0}`, `carry_out = a[7]`
  - `ALU_LSR`: `result = {1'b0, a[7:1]}`, `carry_out = a[0]`
  - `ALU_ROL`: `result = {a[6:0], carry_in}`, `carry_out = a[7]`
  - `ALU_ROR`: `result = {carry_in, a[7:1]}`, `carry_out = a[0]`
- **Pass-through (`ALU_PASS`)**: Routes `b` directly to `result`. In Lesson 14, we will see how `ALU_PASS` lets `LDA` compute its `N` and `Z` flags for free using the same ALU wires.

### Block 1: Operation Constants (`alu_ops.vh`)

```verilog caption="Shared 4-bit operation codes in alu_ops.vh"
localparam [3:0] ALU_ADD  = 4'd0;
localparam [3:0] ALU_SUB  = 4'd1;
localparam [3:0] ALU_CMP  = 4'd2;
localparam [3:0] ALU_INC  = 4'd3;
localparam [3:0] ALU_DEC  = 4'd4;
localparam [3:0] ALU_AND  = 4'd5;
localparam [3:0] ALU_ORA  = 4'd6;
localparam [3:0] ALU_EOR  = 4'd7;
localparam [3:0] ALU_ASL  = 4'd8;
localparam [3:0] ALU_LSR  = 4'd9;
localparam [3:0] ALU_ROL  = 4'd10;
localparam [3:0] ALU_ROR  = 4'd11;
localparam [3:0] ALU_PASS = 4'd12;
```

### Block 2: Shared 9-Bit Adder Steering (`alu.v`)

```verilog caption="Steering second operand and adder_cin into one 9-bit adder"
    wire [7:0] second =
        (op == ALU_ADD) ? b :
        (op == ALU_SUB) ? ~b :
        (op == ALU_CMP) ? ~b :
        (op == ALU_DEC) ? 8'hFF :
                          8'h00;

    wire adder_cin =
        (op == ALU_ADD || op == ALU_SUB) ? carry_in :
        (op == ALU_CMP || op == ALU_INC) ? 1'b1 :
                                           1'b0;

    wire [8:0] adder_sum   = {1'b0, a} + {1'b0, second} + {8'd0, adder_cin};
    wire [7:0] sum         = adder_sum[7:0];
    wire       adder_carry = adder_sum[8];
```

- Notice why we wrote continuous `assign` / ternary multiplexers instead of an `always @(*)` block: in Verilog simulation, continuous `assign` expressions evaluate immediately at time `0` even if inputs start constant, avoiding subtle simulation-only `X` values when a module powers up before its first input edge.{{sidenote:Icarus Verilog only triggers an `always @(*)` block when a signal on its sensitivity list *changes* after time `0`; continuous `assign` wires evaluate from the very first picosecond.}}

### Block 3: Result and Carry-Out Multiplexers (`alu.v`)

```verilog caption="Selecting result and carry_out across all 13 operations"
    assign result =
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP || op == ALU_INC || op == ALU_DEC) ? sum :
        (op == ALU_AND)  ? (a & b) :
        (op == ALU_ORA)  ? (a | b) :
        (op == ALU_EOR)  ? (a ^ b) :
        (op == ALU_ASL)  ? {a[6:0], 1'b0} :
        (op == ALU_LSR)  ? {1'b0, a[7:1]} :
        (op == ALU_ROL)  ? {a[6:0], carry_in} :
        (op == ALU_ROR)  ? {carry_in, a[7:1]} :
        (op == ALU_PASS) ? b :
                           8'h00;

    assign carry_out =
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP) ? adder_carry :
        (op == ALU_ASL || op == ALU_ROL)                  ? a[7] :
        (op == ALU_LSR || op == ALU_ROR)                  ? a[0] :
                                                            1'b0;
```

### Complete `alu.v` Module

```verilog caption="apps/0013-6502-alu-operations/alu.v"
`timescale 1ns / 1ps

module alu (
    input  wire [3:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out
);
    `include "alu_ops.vh"

    wire [7:0] second =
        (op == ALU_ADD) ? b :
        (op == ALU_SUB) ? ~b :
        (op == ALU_CMP) ? ~b :
        (op == ALU_DEC) ? 8'hFF :
                          8'h00;

    wire adder_cin =
        (op == ALU_ADD || op == ALU_SUB) ? carry_in :
        (op == ALU_CMP || op == ALU_INC) ? 1'b1 :
                                           1'b0;

    wire [8:0] adder_sum   = {1'b0, a} + {1'b0, second} + {8'd0, adder_cin};
    wire [7:0] sum         = adder_sum[7:0];
    wire       adder_carry = adder_sum[8];

    assign result =
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP || op == ALU_INC || op == ALU_DEC) ? sum :
        (op == ALU_AND)  ? (a & b) :
        (op == ALU_ORA)  ? (a | b) :
        (op == ALU_EOR)  ? (a ^ b) :
        (op == ALU_ASL)  ? {a[6:0], 1'b0} :
        (op == ALU_LSR)  ? {1'b0, a[7:1]} :
        (op == ALU_ROL)  ? {a[6:0], carry_in} :
        (op == ALU_ROR)  ? {carry_in, a[7:1]} :
        (op == ALU_PASS) ? b :
                           8'h00;

    assign carry_out =
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP) ? adder_carry :
        (op == ALU_ASL || op == ALU_ROL)                  ? a[7] :
        (op == ALU_LSR || op == ALU_ROR)                  ? a[0] :
                                                            1'b0;
endmodule
```

## 4. Hardware Demo (`top.v`) & Yosys Resource Footprint

To put `alu.v` on our physical Tang Nano 20K before integrating it into `cpu.v`, `top.v` steps through 13 representative test vectors at `1` Hz (`STEP_PERIOD = 27000000`, overridden to `2` in `top_tb.v`). By default the six active-low LEDs show `result[5:0]`; holding `S2` switches the LEDs to `{carry_out, 1'b0, op}` so you can read the active operation index and carry flag on hardware.

### Complete `top.v` Listing

```verilog caption="apps/0013-6502-alu-operations/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 27000000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    `include "alu_ops.vh"

    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] disp_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        disp_sync <= {disp_sync[0], s2};
    end
    wire reset     = rst_sync[1];
    wire show_meta = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg [3:0] vec_idx = 4'd0;
    always @(posedge clk) begin
        if (reset) begin
            vec_idx <= 4'd0;
        end else if (step) begin
            if (vec_idx == 4'd12) begin
                vec_idx <= 4'd0;
            end else begin
                vec_idx <= vec_idx + 4'd1;
            end
        end
    end

    function [20:0] get_vector;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  get_vector = {ALU_ADD,  8'h12, 8'h15, 1'b0};
                4'd1:  get_vector = {ALU_SUB,  8'h30, 8'h0A, 1'b1};
                4'd2:  get_vector = {ALU_CMP,  8'h25, 8'h25, 1'b0};
                4'd3:  get_vector = {ALU_INC,  8'h0E, 8'h00, 1'b0};
                4'd4:  get_vector = {ALU_DEC,  8'h10, 8'h00, 1'b0};
                4'd5:  get_vector = {ALU_AND,  8'h3F, 8'h2A, 1'b0};
                4'd6:  get_vector = {ALU_ORA,  8'h14, 8'h03, 1'b0};
                4'd7:  get_vector = {ALU_EOR,  8'h3F, 8'h15, 1'b0};
                4'd8:  get_vector = {ALU_ASL,  8'h85, 8'h00, 1'b0};
                4'd9:  get_vector = {ALU_LSR,  8'h2B, 8'h00, 1'b0};
                4'd10: get_vector = {ALU_ROL,  8'h05, 8'h00, 1'b1};
                4'd11: get_vector = {ALU_ROR,  8'h10, 8'h00, 1'b1};
                default: get_vector = {ALU_PASS, 8'h00, 8'h2D, 1'b0};
            endcase
        end
    endfunction

    wire [20:0] vec      = get_vector(vec_idx);
    wire [3:0]  op       = vec[20:17];
    wire [7:0]  a        = vec[16:9];
    wire [7:0]  b        = vec[8:1];
    wire        carry_in = vec[0];

    wire [7:0] result;
    wire       carry_out;

    alu u_alu (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out)
    );

    assign led = ~(show_meta ? {carry_out, 1'b0, op} : result[5:0]);
endmodule
```

Running `make -C apps/0013-6502-alu-operations stats` reveals how cleanly Yosys maps our shared 9-bit adder onto Gowin `ALU` carry-chain primitives:

Table: Yosys `synth_gowin` Cell Utilisation (`alu` Standalone vs `top` Demo)

| Synthesised Top | `ALU` Carry Cells | `LUT1`–`LUT4` | `MUX2_LUT5`/`6` | Flip-Flops (`DFF*`) | Total Cells (incl. I/O) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `alu` | **`9`** | `76` (`19+1+8+48`) | `23` (`22+1`) | **`0`** | `140` |
| `top` | `29` (25-bit `timer` + folded `alu`) | `32` (`9+2+5+16`) | `11` (`10+1`) | `34` (`4+26+4`) | `119` |

Look at `alu` standalone: **zero flip-flops** (confirming it is purely combinational) and **exactly `9` `ALU` carry cells**—one per bit of our single 9-bit adder!

---

:::exercise id="ex-0013" title="Interactive Lab: Steer the Shared 9-Bit Adder" badge="Skill Practice • ALU Design"
Complete the `second` operand and `adder_cin` steering expressions so `ALU_SUB`, `ALU_CMP`, `ALU_INC`, and `ALU_DEC` all share `{1'b0, a} + {1'b0, second} + {8'd0, adder_cin}`:

```verilog
wire [7:0] second =
    (op == ALU_ADD) ? b :
    (op == ALU_SUB) ? {{blank:~b|Bitwise complement of b for two's-complement subtraction|??|2}} :
    (op == ALU_CMP) ? ~b :
    (op == ALU_DEC) ? {{blank:8'hFF|Adding 255 mod 256 subtracts 1|?????|5}} :
                      8'h00;

wire adder_cin =
    (op == ALU_ADD || op == ALU_SUB) ? {{blank:carry_in|Use processor Carry flag as input|????????|8}} :
    (op == ALU_CMP || op == ALU_INC) ? {{blank:1'b1|Force +1 for two's complement or increment|????|4}} :
                                       1'b0;
```

:::prompts
hint: "`ALU_SUB` inverts `b` (`~b`) and uses `carry_in`; `ALU_DEC` adds `8'hFF` with `adder_cin = 1'b0`; `ALU_CMP` and `ALU_INC` force `adder_cin = 1'b1`."
success: "Verified! One 9-bit adder now drives ADD, SUB, CMP, INC, and DEC."
:::
:::

:::quiz id="quiz-0013" title="Retrieval Practice: Shared 9-Bit Adder & Two's-Complement Subtraction" badge="3 Questions • Equal-Length Options"
- question: "Why does `ALU_SUB` compute `a + ~b + carry_in` instead of `a + ~b + 1'b1` unconditionally?"
  wrong_hint: "Recall what the 6502 Carry flag represents before executing an `SBC` instruction."
  options:
    - letter: "A"
      text: "Because the 6502 treats Carry clear as an incoming borrow, reducing the difference by one."
      correct: true
      explain: "Correct: in 6502 subtraction, `C=1` means no borrow (`a + ~b + 1 = a - b`) while `C=0` subtracts an extra `1` (`a + ~b + 0 = a - b - 1`)."
    - letter: "B"
      text: "Because Gowin FPGAs forbid constant one literals on the carry-in wire of dedicated arithmetic cells."
      correct: false
      explain: "Gowin `ALU` cells allow constant carry-ins—indeed `ALU_CMP` and `ALU_INC` drive `adder_cin = 1'b1`."
    - letter: "C"
      text: "Because two's-complement negation flips every input bit only when the accumulator holds an odd number."
      correct: false
      explain: "Two's-complement negation always computes `~b + 1` regardless of whether `a` is odd or even."
    - letter: "D"
      text: "Because Verilog addition operators refuse to compile unless both input operands share identical bit widths."
      correct: false
      explain: "Our operands already share 9-bit widths; `carry_in` is wired specifically for multi-byte borrow chaining."
- question: "How does `ALU_CMP` differ from `ALU_SUB` inside the shared 9-bit adder steering logic?"
  wrong_hint: "Compare their `adder_cin` rows in Table 1."
  options:
    - letter: "A"
      text: "Compare inverts the A operand instead of B while leaving carry unchanged."
      correct: false
      explain: "Both `ALU_SUB` and `ALU_CMP` invert `b` (`~b`) so the adder computes `a - b`."
    - letter: "B"
      text: "Compare forces adder_cin to one so stale Carry flags never skew comparisons."
      correct: true
      explain: "Correct: `CMP` always computes `a + ~b + 1` so `C=0` from a prior instruction cannot alter the comparison."
    - letter: "C"
      text: "Compare bypasses the shared adder completely and uses bitwise XOR gates instead."
      correct: false
      explain: "Bitwise XOR only checks equality, whereas `CMP` needs magnitude (`C = 1` when `a >= b`)."
    - letter: "D"
      text: "Compare swaps inputs a and b so negative values always set carry."
      correct: false
      explain: "`a` stays on the left side and `~b` stays on the right side (`second`)."
- question: "Why does `ALU_DEC` feed `second = 8'hFF` and `adder_cin = 1'b0` into the adder?"
  wrong_hint: "Compute `(a + 255) mod 256` for any 8-bit byte `a`."
  options:
    - letter: "A"
      text: "Because adding 255 modulo 256 is mathematically identical to subtracting one without carry."
      correct: true
      explain: "Correct: `255` is `-1` in 8-bit two's complement, so `a + 8'hFF + 0` wraps around to `a - 1`."
    - letter: "B"
      text: "Because Gowin Block RAM resets every decrement counter byte to 255 at power-up."
      correct: false
      explain: "`alu.v` is purely combinational and does not use Block RAM."
    - letter: "C"
      text: "Because loading 255 forces every shift wire low during all right-rotate ALU operations."
      correct: false
      explain: "Shifts and rotates bypass the adder completely via `{...}` concatenation."
    - letter: "D"
      text: "Because adding 255 guarantees carry_out stays set to one whenever a equals zero."
      correct: false
      explain: "Our `carry_out` mux explicitly drives `1'b0` for `ALU_INC` and `ALU_DEC`."
:::

:::verify id="verify-0013" title="Verification Lab: Simulate All 13 ALU Operations, Check Yosys Stats & Inspect Waveforms" badge="Simulation & Synthesis Gate"
Run all self-checking testbenches (`alu_tb.v` and `top_tb.v`), build the Tang Nano 20K bitstream, inspect standalone `alu` primitive counts, and view `alu.vcd` in Surfer:

```bash caption="Simulate, synthesise, inspect stats, and view waveforms"
make -C apps/0013-6502-alu-operations clean all
make -C apps/0013-6502-alu-operations stats
make -C apps/0013-6502-alu-operations wave
make -C apps/0013-6502-alu-operations flash
```

- [ ] `make -C apps/0013-6502-alu-operations clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS:` for both `alu` and `top`.
- [ ] `make stats` confirms standalone `alu` synthesises to **`9` `ALU` cells** and **`0` flip-flops**, proving all five arithmetic operations share one 9-bit carry chain.
- [ ] In Surfer (`make wave`), verify `ALU_SUB` with `carry_in = 1` vs `0`, `ALU_CMP` ignoring `carry_in = 0`, `ALU_DEC` wrapping `$00 -> $FF`, and `ALU_ROL`/`ALU_ROR` shifting bits across `carry_out`.
- [ ] On the Tang Nano 20K, LEDs cycle through all 13 ALU results at `1` Hz (`S2` switches to `{carry_out, 1'b0, op}`, and `S1` resets to vector `0`).
:::

:::teacher-prompt title="Next Up: Lesson 14 (ALU Status Flags & Exhaustive Verification)"
Our combinational ALU now computes all 13 results and `carry_out` using a single 9-bit adder! Ask any questions about two's-complement steering, `ALU_CMP`, or the Yosys `9 ALU` cell count—or say **"ready for Lesson 14"** to add the `N`, `Z`, and `V` flags and prove our ALU across all **1,703,936** possible input combinations.
:::
