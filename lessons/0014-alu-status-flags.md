---
title: "N, Z, C, V Flags & Exhaustive ALU Verification"
page_title: "Lesson 0014: N, Z, C, V Flags & Exhaustive ALU Verification — Build Your Own 6502"
nav_id: "lesson-0014"
badge: "Lesson 0014 • ALU Verification"
subtitle: "Add Zero, Negative, and Signed Overflow flags to alu.v, verify all 1,703,936 input combinations in Icarus Verilog, and measure the silicon savings of our shared adder against a five-adder alternative."
card:
  title: "**ALU Flags & 1.7M-Vector Verification**"
  summary: "Compute N, Z, C, and V flags, run an exhaustive 1,703,936-vector simulation, and compare 9 vs 43 Gowin ALU carry cells."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0014-alu-status-flags/` (`make -C apps/0014-alu-status-flags clean all`)
- **Video reference**: [Episode 14: The Four Flags of Our 6502's ALU, in Verilog](https://www.youtube.com/watch?v=MwEeMDGKOW0)
- **Upstream reference**: [`yvesrob/6502-gate-by-gate`](https://github.com/yvesrob/6502-gate-by-gate)
- **Course references**: [Lesson 13](0013-6502-alu-operations.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. The Four Arithmetic Flags (`N`, `Z`, `C`, `V`)

In [Lesson 13](0013-6502-alu-operations.md), our ALU produced an 8-bit `result` and `carry_out`. A real 6502 pairs that result with three more status wires so conditional branches and signed arithmetic work without extra instructions:

- **`zero` (`Z`)**: High (`1'b1`) whenever `result == 8'h00`. That takes a single 8-input NOR across all bits of `result`.
- **`negative` (`N`)**: Simply `result[7]`, the sign bit in two's-complement arithmetic (negative numbers run from `$80` = `-128` to `$FF` = `-1`).
- **`carry_out` (`C`)**: Already wired in Lesson 13 for unsigned overflow (`ADD`), inverted borrow (`SUB`/`CMP`), and bit shifts (`ASL`/`LSR`/`ROL`/`ROR`).
- **`overflow` (`V`)**: Signed two's-complement overflow—the most misunderstood flag in 8-bit computing.

### Unpacking Signed Overflow (`V`)

Unsigned overflow (`C`) happens when a sum exceeds `255` (`$FF + $01 = $00`, `C = 1`). Signed overflow (`V`) happens when two signed 8-bit numbers (`-128..+127`) add up to a result that does not fit in `-128..+127`. Look at the four possibilities when adding `a + second`:

- Adding a positive (`bit 7 = 0`) and a negative (`bit 7 = 1`) **can never overflow**—the result always stays closer to zero than at least one input.
- Adding two positives (`a[7] == 0` and `second[7] == 0`) overflows only if the sum lands in negative territory (`sum[7] == 1`), such as `127 + 1 = -128` (`$7F + $01 = $80`).
- Adding two negatives (`a[7] == 1` and `second[7] == 1`) overflows only if the sum wraps into positive territory (`sum[7] == 0`), such as `-128 + (-1) = +127` (`$80 + $FF = $7F`).

Both overflow cases collapse into one crisp expression:

```verilog
wire adder_overflow = (a[7] == second[7]) && (sum[7] != a[7]);
```

And here is the neat payoff of sharing `second` in Lesson 13: because `ALU_SUB` already feeds `second = ~b` into the adder, **that exact same formula handles subtraction too!**{{sidenote:When subtracting `` `$80 - $01` `` (`-128 - 1`), `second` is `~$01 = $FE`, so `a[7]` (`1`) matches `second[7]` (`1`), while `sum = $7F` has `sum[7] = 0`. One formula catches both addition and subtraction signed overflow!}}

Table: Concrete Signed & Unsigned Flag Examples Verified by `alu_tb.v`

| Operation | `a` | `b` | `carry_in` | `result` | `N` | `V` | `Z` | `C` | Interpretation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ALU_ADD` | `$7F` (`+127`) | `$01` (`+1`) | `0` | `$80` (`-128`) | `1` | **`1`** | `0` | `0` | Signed overflow (`+127 + 1` wrapped) |
| `ALU_ADD` | `$80` (`-128`) | `$80` (`-128`) | `0` | `$00` (`0`) | `0` | **`1`** | `1` | `1` | Signed overflow AND unsigned carry AND zero |
| `ALU_ADD` | `$FF` (`-1`) | `$01` (`+1`) | `0` | `$00` (`0`) | `0` | `0` | **`1`** | **`1`** | Unsigned carry (`256`), valid signed `-1 + 1 = 0` |
| `ALU_SUB` | `$80` (`-128`) | `$01` (`+1`) | `1` | `$7F` (`+127`) | `0` | **`1`** | `0` | `1` | Signed overflow (`-128 - 1` wrapped) |
| `ALU_SUB` | `$00` (`0`) | `$01` (`+1`) | `1` | `$FF` (`-1`) | `1` | `0` | `0` | **`0`** | Valid signed `-1`, unsigned borrow (`C = 0`) |
| `ALU_PASS` | `any` | `$00` | `any` | `$00` | `0` | `0` | **`1`** | `0` | `LDA #$00` computes `Z = 1, N = 0` via `ALU_PASS` |

Notice why `ALU_PASS` is worth its weight in gold: whenever `LDA` loads a byte onto `b`, routing it through `alu.v` with `ALU_PASS` automatically updates `zero` and `negative` without duplicating `(data_in == 8'h00)` and `data_in[7]` inside `cpu.v`.

### Block 1: Extended ALU Ports (`alu.v`)

```verilog caption="Adding zero, negative, and overflow outputs to alu.v"
module alu (
    input  wire [3:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out,
    output wire       zero,
    output wire       negative,
    output wire       overflow
);
```

### Block 2: Signed Overflow & Flag Wiring (`alu.v`)

```verilog caption="Computing adder_overflow from a[7], second[7], and sum[7]"
    wire [8:0] adder_sum      = {1'b0, a} + {1'b0, second} + {8'd0, adder_cin};
    wire [7:0] sum            = adder_sum[7:0];
    wire       adder_carry    = adder_sum[8];
    wire       adder_overflow = (a[7] == second[7]) && (sum[7] != a[7]);
```

```verilog caption="Deriving zero, negative, and gated overflow flags"
    assign zero     = (result == 8'h00);
    assign negative = result[7];
    assign overflow = (op == ALU_ADD || op == ALU_SUB) ? adder_overflow : 1'b0;
```

- Notice that `overflow` is gated to `ALU_ADD` and `ALU_SUB` only: on a 6502, `CMP`, `INC`, `DEC`, logic, and shifts never alter the `V` flag.

### Complete `alu.v` Module

```verilog caption="apps/0014-alu-status-flags/alu.v"
`timescale 1ns / 1ps

module alu (
    input  wire [3:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out,
    output wire       zero,
    output wire       negative,
    output wire       overflow
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

    wire [8:0] adder_sum      = {1'b0, a} + {1'b0, second} + {8'd0, adder_cin};
    wire [7:0] sum            = adder_sum[7:0];
    wire       adder_carry    = adder_sum[8];
    wire       adder_overflow = (a[7] == second[7]) && (sum[7] != a[7]);

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

    assign zero     = (result == 8'h00);
    assign negative = result[7];
    assign overflow = (op == ALU_ADD || op == ALU_SUB) ? adder_overflow : 1'b0;
endmodule
```

## 2. Exhaustive Verification: All 1,703,936 Combinations

Directed unit tests are great for smoke checks, yet ALU corner cases (especially `V` and inverted borrow) hide in weird input pairs. Because our ALU has `13` operations, `256` values of `a`, `256` values of `b`, and `2` `carry_in` states, the entire truth table is only:

$$13 \times 256 \times 256 \times 2 = 1{,}703{,}936 \text{ vectors}$$

Just like in [Lesson 3](0003-8bit-ripple-carry-adder.md), `alu_tb.v` tests **every single combination** against an independent reference implementation—and simultaneously cross-checks our shared-adder `alu.v` against a naive five-adder version (`alu_naive.v`) to prove 100% behavioural equivalence.

Two practical tips keep `1.7` million vectors snappy:
1. **Dump only directed edge cases to VCD**: `alu_tb.v` records the 8 directed flag edge cases (`$dumpfile("build/alu.vcd")`), then calls `$dumpoff;` before starting the nested loops so disk I/O never slows the sweep down or fills gigabytes of VCD text.
2. **Use `#1;` per vector**: Even `1,703,936` iterations complete in a couple of seconds in `vvp`.

## 3. Measuring the Silicon Savings (`9` vs `43` `ALU` Cells)

To prove our shared-adder optimisation is real and not guesswork, `apps/0014-alu-status-flags/alu_naive.v` implements the exact same module interface using five separate arithmetic expressions (`add_sum`, `sub_sum`, `cmp_sum`, `inc_res`, and `dec_res`). Running `make -C apps/0014-alu-status-flags stats` prints the exact Gowin primitive counts side by side:

Table: Yosys `synth_gowin` Resource Comparison (`alu` Shared Adder vs `alu_naive` Five Adders)

| Design | `ALU` Carry Cells | `LUT1`–`LUT4` | `MUX2_LUT5`–`8` | Total Cells (incl. I/O) |
| :--- | :--- | :--- | :--- | :--- |
| `alu` (shared 9-bit adder) | **`9`** | `172` (`103+26+15+28`) | `127` (`71+34+15+7`) | **`343`** |
| `alu_naive` (5 separate adders) | **`43`** (`9+9+9+8+8`) | `210` (`104+12+23+71`) | `141` (`86+36+14+5`) | **`429`** |
| `top` (8-vector flag demo) | `27` | `20` (`4+2+2+12`) | `2` (`MUX2_LUT5`) | `95` (`33` `DFF*`) |

Sharing one 9-bit adder cuts dedicated carry-chain `ALU` primitives by nearly **5×** (`9` vs `43`), eliminates `38` LUTs and `14` muxes, and keeps routing tight—while `alu_tb.v` proves across all `1,703,936` inputs that both designs behave identically down to the last flag bit!

### Complete `top.v` Listing

On hardware, `top.v` cycles through eight curated flag-triggering vectors at `1` Hz (`STEP_PERIOD = 27000000`, overridden to `2` in `top_tb.v`). LEDs `led[3:0]` display `{negative, overflow, zero, carry_out}` (`N, V, Z, C`), and holding `S2` switches the LEDs to `result[5:0]`:

```verilog caption="apps/0014-alu-status-flags/top.v"
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
    wire reset    = rst_sync[1];
    wire show_res = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg [2:0] vec_idx = 3'd0;
    always @(posedge clk) begin
        if (reset) begin
            vec_idx <= 3'd0;
        end else if (step) begin
            vec_idx <= vec_idx + 3'd1;
        end
    end

    function [20:0] get_vector;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: get_vector = {ALU_ADD,  8'h7F, 8'h01, 1'b0};
                3'd1: get_vector = {ALU_ADD,  8'hFF, 8'h01, 1'b0};
                3'd2: get_vector = {ALU_SUB,  8'h80, 8'h01, 1'b1};
                3'd3: get_vector = {ALU_SUB,  8'h00, 8'h01, 1'b1};
                3'd4: get_vector = {ALU_CMP,  8'h40, 8'h40, 1'b0};
                3'd5: get_vector = {ALU_PASS, 8'h00, 8'h00, 1'b0};
                3'd6: get_vector = {ALU_PASS, 8'h00, 8'h80, 1'b0};
                default: get_vector = {ALU_ASL, 8'h81, 8'h00, 1'b0};
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
    wire       zero;
    wire       negative;
    wire       overflow;

    alu u_alu (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out),
        .zero(zero),
        .negative(negative),
        .overflow(overflow)
    );

    wire [5:0] flags_view = {2'b00, negative, overflow, zero, carry_out};
    assign led = ~(show_res ? result[5:0] : flags_view);
endmodule
```

---

:::exercise id="ex-0014" title="Interactive Lab: Wire Signed Overflow and Zero Flags" badge="Skill Practice • ALU Flags"
Fill in `adder_overflow`, `zero`, and `overflow` inside `alu.v` so signed overflow works for both `ALU_ADD` and `ALU_SUB` without triggering during `ALU_CMP` or logic operations:

```verilog
wire adder_overflow = (a[7] == {{blank:second[7]|Sign bit of the steered second operand|?????????|9}}) && (sum[7] != a[7]);

assign zero     = (result == {{blank:8'h00|Zero byte constant|?????|5}});
assign negative = result[7];
assign overflow = (op == ALU_ADD || op == {{blank:ALU_SUB|Only addition and subtraction update V|???????|7}}) ? adder_overflow : 1'b0;
```

:::prompts
hint: "Compare `a[7]` against `second[7]` (not `b[7]`), compare `result` to `8'h00`, and gate `overflow` to `ALU_ADD` and `ALU_SUB`."
success: "Verified! Reusing `second[7]` makes signed overflow work automatically for both `ADD` and `SUB`."
:::
:::

:::quiz id="quiz-0014" title="Retrieval Practice: Overflow Mechanics, ALU_PASS & Exhaustive Testing" badge="3 Questions • Equal-Length Options"
- question: "When does two's-complement signed overflow (`V = 1`) occur during addition or subtraction?"
  wrong_hint: "Think about the sign bits of `a`, `second`, and `sum`."
  options:
    - letter: "A"
      text: "Because overflow occurs whenever an eight-bit addition produces a carry out from bit seven."
      correct: false
      explain: "Bit-7 carry out is unsigned carry (`C`), which happens in valid signed additions like `-1 + 1 = 0`."
    - letter: "B"
      text: "Because overflow occurs whenever two inputs with matching signs yield a different result sign."
      correct: true
      explain: "Correct: `(a[7] == second[7]) && (sum[7] != a[7])` catches positive+positive wrapping negative and negative+negative wrapping positive."
    - letter: "C"
      text: "Because overflow occurs whenever subtracting zero from any signed negative byte clears bit seven."
      correct: false
      explain: "Subtracting zero leaves a negative byte unchanged with bit `7` still set (`V = 0`)."
    - letter: "D"
      text: "Because overflow occurs whenever the accumulator holds zero after shifting left by one bit."
      correct: false
      explain: "Shift instructions (`ASL`, `ROL`) never touch the `V` flag on a 6502."
- question: "Why does `alu.v` include the `ALU_PASS` operation even though it performs no arithmetic?"
  wrong_hint: "Remember which flags `LDA` updates when loading a byte into `A`."
  options:
    - letter: "A"
      text: "Because LOAD instructions clear Carry and Overflow flags by adding zero to the accumulator."
      correct: false
      explain: "`LDA` must leave Carry (`C`) and Overflow (`V`) untouched, and `ALU_PASS` forces both to `0`."
    - letter: "B"
      text: "Because LOAD instructions bypass the system bus and read operands directly from internal ROM."
      correct: false
      explain: "All instruction operands travel over `bus.v` into `data_in` regardless of ALU design."
    - letter: "C"
      text: "Because LOAD instructions read memory bytes into b, automatically computing Zero and Negative flags."
      correct: true
      explain: "Correct: routing loaded bytes through `ALU_PASS` computes `zero` and `negative` without duplicating flag logic in `cpu.v`."
    - letter: "D"
      text: "Because LOAD instructions must shift incoming memory bytes left once before latching them cleanly."
      correct: false
      explain: "`ALU_PASS` outputs `b` completely unmodified."
- question: "Why does `alu_tb.v` call `$dumpoff` immediately after the eight directed edge cases?"
  wrong_hint: "Think about running `1,703,936` loop iterations while writing a text VCD file."
  options:
    - letter: "A"
      text: "Stopping VCD recording skips dumping 1.7 million vectors, keeping the waveform file compact and fast."
      correct: true
      explain: "Correct: Surfer needs only the directed edge cases, whereas writing 1.7 million VCD transitions would bloat disk output."
    - letter: "B"
      text: "Stopping VCD recording disables all self-checking Verilog assertions immediately after the first eight directed vectors."
      correct: false
      explain: "`$fatal` assertions remain active throughout all `1,703,936` exhaustive checks."
    - letter: "C"
      text: "Stopping VCD recording pauses the simulation timer so combinational logic gates evaluate without timing delays."
      correct: false
      explain: "The `#1;` delay and simulation loop still advance normally after `$dumpoff`."
    - letter: "D"
      text: "Stopping VCD recording merges five separate arithmetic adders into one shared carry chain inside Yosys."
      correct: false
      explain: "`$dumpoff` is a simulation-only task and has zero effect on Yosys synthesis."
:::

:::verify id="verify-0014" title="Verification Lab: Run All 1,703,936 ALU Vectors & Compare Yosys Stats" badge="Exhaustive Simulation Gate"
Run the 1,703,936-vector exhaustive equivalence check between `alu` and `alu_naive`, build the bitstream, compare Gowin cell counts (`9` vs `43` `ALU` cells), and inspect the directed edge-case waveforms in Surfer:

```bash caption="Run 1,703,936 exhaustive checks, compare Yosys stats, and open Surfer"
make -C apps/0014-alu-status-flags clean all
make -C apps/0014-alu-status-flags stats
make -C apps/0014-alu-status-flags wave
make -C apps/0014-alu-status-flags flash
```

- [ ] `make -C apps/0014-alu-status-flags clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS: alu & alu_naive (1703936 vectors across all 13 ops and 4 flags)` plus `PASS: top`.
- [ ] `make stats` confirms `alu` uses **`9` `ALU` cells** (`343` total cells) compared to **`43` `ALU` cells** (`429` total cells) for `alu_naive`.
- [ ] In Surfer (`make wave`), verify `$7F + $01` sets `N=1, V=1, C=0`, `$FF + $01` sets `Z=1, C=1, V=0`, and `$80 - $01` sets `V=1, C=1`.
- [ ] On the Tang Nano 20K, `led[3:0]` displays `{N, V, Z, C}` across the eight flag edge cases (`S2` switches to `result[5:0]`).
:::

:::teacher-prompt title="Next Up: Lesson 15 (Instruction Decoder & Five-Instruction Sequencer)"
With all 13 ALU operations and all 4 flags (`N, Z, C, V`) exhaustively verified across `1,703,936` test vectors, our arithmetic unit is rock-solid! Ask any questions about signed overflow, `ALU_PASS`, or the `9` vs `43` cell synthesis comparison—or say **"ready for Lesson 15"** to split `cpu.v` into a Decoder and Multi-State Sequencer for our first five 6502 instructions (`LDA`, `STA`, `CLC`, `ADC`, `JMP`).
:::
