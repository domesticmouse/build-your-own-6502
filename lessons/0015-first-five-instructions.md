---
title: "Instruction Decoder, Multi-State Sequencer & Two-Read Rule"
page_title: "Lesson 0015: Instruction Decoder, Multi-State Sequencer & Two-Read Rule — Build Your Own 6502"
nav_id: "lesson-0015"
badge: "Lesson 0015 • Control Unit"
subtitle: "Decompose cpu.v into a combinational opcode decoder and a cycle-accurate 5-state FSM for LDA, STA, CLC, ADC, and JMP—reproducing the NMOS 6502 Two-Read Rule and restoring all 16 RAM blocks."
card:
  title: "**Decoder, 5-State Sequencer & Two-Read Rule**"
  summary: "Decode our first five 6502 opcodes, execute exact multi-cycle bus sequences from 64doc, and bring all 16 RAM SP blocks back into silicon."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0015-first-five-instructions/` (`make -C apps/0015-first-five-instructions clean all`)
- **Video reference**: [Episode 15: Teaching Our 6502 Its First Five Instructions, in Verilog](https://www.youtube.com/watch?v=NZRr0N38ymg)
- **Cycle specification**: [`64doc` — NMOS 6502/6510 Reference](https://www.nesdev.org/6502_cpu.txt)
- **Course references**: [Lesson 10](0010-ca65-ld65-toolchain.md), [Lesson 12](0012-first-cpu-fetch-fsm.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Splitting the CPU: Decoder, Sequencer, and Data Path

In [Lesson 12](0012-first-cpu-fetch-fsm.md), our CPU only had two states (`STARTING` and `OPCODE`), so it blindly marched forward through `rom.mem` one byte per step—it had no idea that `$8D` takes `4` cycles and writes to `$8000`, or that `$4C` jumps back to `$C002`.

Today we teach `cpu.v` the **control half** of our processor by separating it into two clean responsibilities (leaving the **Data Path**—wiring in `alu.v`, `A`, and flags—for Lesson 16):

1. **Decoder (`decoder.v`)**: A purely combinational lookup translating an 8-bit opcode into two compact control signals: which **instruction** (`inst`) and which **addressing mode** (`mode`).
2. **Sequencer (`cpu.v`)**: A 5-state Finite State Machine (`STARTING`, `OPCODE`, `OPERAND`, `HIGH`, `STORE`) steering `address`, `pc`, and `write` with **exact cycle-by-cycle fidelity** to the NMOS 6502 documented in [`64doc`](https://www.nesdev.org/6502_cpu.txt).

Notice the five opcodes we need for `count.s`:

Table: The Five Instructions of `count.s` and Their Cycle Timing

| Instruction | Opcode | `inst` | `mode` | Length | Cycles | Bus Activity (`64doc`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `LDA #$00` | `$A9` | `INST_LDA` | `MODE_IMM` | `2` bytes | `2` | Fetch opcode, fetch immediate byte |
| `STA $8000` | `$8D` | `INST_STA` | `MODE_ABS` | `3` bytes | `4` | Fetch opcode, fetch `addr_lo`, fetch `addr_hi` + assert `write = 1`, bus write tick |
| `CLC` | `$18` | `INST_CLC` | `MODE_IMP` | `1` byte | `2` | Fetch opcode, **re-read next byte without advancing `pc`** |
| `ADC #$01` | `$69` | `INST_ADC` | `MODE_IMM` | `2` bytes | `2` | Fetch opcode, fetch immediate byte |
| `JMP $C002` | `$4C` | `INST_JMP` | `MODE_ABS` | `3` bytes | `3` | Fetch opcode, fetch `addr_lo`, jump directly to `{addr_hi, addr_lo}` |

## 2. The 5-State Sequencer & the Two-Read Rule

Look closely at the **Two-Read Rule** on `CLC` (`$18`), because it surprises almost everyone meeting real 6502 hardware for the first time:

Even though `CLC` is a **1-byte** implied instruction, the real NMOS 6502 never executes *any* instruction in `1` clock cycle—every instruction takes at least `2` cycles. On Cycle 1 (`OPCODE`), the CPU reads `$18` from `$C005` and puts `pc` (`$C006`) onto `address`. On Cycle 2 (`OPERAND`), the CPU performs a dummy read of `$C006` and discards the byte, keeping `address = $C006` again for the *real* opcode fetch of `ADC #$01`!{{sidenote:Why does real 6502 silicon work this way? Because the instruction register takes the first cycle to decode `$18`, and the bus interface never sits idle—so Cycle 2 naturally reads the byte after `$18` while `CLC` clears Carry internally, simply holding `pc` still so Cycle 1 of the next instruction fetches that same byte for real.}}

```mermaid caption="Figure 15.1: Five-state cycle-accurate sequencer in cpu.v"
stateDiagram-v2
  [*] --> STARTING: reset = 1
  STARTING --> OPCODE: step / address <= $C000, pc <= $C001
  OPCODE --> OPERAND: step / decode data_in; if MODE_IMP hold pc!
  OPERAND --> OPCODE: step [MODE_IMM or MODE_IMP] / address <= pc, pc <= pc + 1
  OPERAND --> HIGH: step [MODE_ABS] / addr_lo <= data_in, address <= pc, pc <= pc + 1
  HIGH --> OPCODE: step [INST_JMP] / address <= {data_in, addr_lo}, pc <= target + 1
  HIGH --> STORE: step [INST_STA] / address <= {data_in, addr_lo}, write <= 1
  STORE --> OPCODE: step / write <= 0, address <= pc, pc <= pc + 1
```

Why must `decoder.v` read **`data_in`** directly rather than waiting for the registered `opcode` flip-flop? Because on the exact clock tick when `state == OPCODE`, `opcode` has *not* latched `data_in` yet! Wiring `u_decoder (.opcode(data_in))` lets `OPCODE` inspect `dec_mode` on the very same clock edge—so if `dec_mode == MODE_IMP`, `cpu.v` suppresses `pc <= pc + 16'd1` immediately to honour the Two-Read Rule.

## 3. Cycle-by-Cycle Trace of `count.s`

Running `computer_tb.v` confirms that our 5-state FSM matches the exact `11`-cycle loop we hand-traced in [Lesson 10](0010-ca65-ld65-toolchain.md):

Table: First 15 Cycles of `count.s` Executed by `cpu.v` + `bus.v`

| Step | State Before Step | `data_in` Seen | `address` After Step | `pc` After Step | `write` | Instruction Phase |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `1` | `STARTING` | `$00` | `$C000` | `$C001` | `0` | Boot fetch |
| `2` | `OPCODE` | `$A9` | `$C001` | `$C002` | `0` | `LDA #$00` (cycle 1/2) |
| `3` | `OPERAND` | `$00` | `$C002` | `$C003` | `0` | `LDA #$00` (cycle 2/2) |
| `4` | `OPCODE` | `$8D` | `$C003` | `$C004` | `0` | `STA $8000` (cycle 1/4) |
| `5` | `OPERAND` | `$00` (`addr_lo`) | `$C004` | `$C005` | `0` | `STA $8000` (cycle 2/4) |
| `6` | `HIGH` | `$80` (`addr_hi`) | **`$8000`** | `$C005` | **`1`** | `STA $8000` (cycle 3/4: bus write) |
| `7` | `STORE` | `$00` | `$C005` | `$C006` | `0` | `STA $8000` (cycle 4/4: resume fetch) |
| `8` | `OPCODE` | `$18` | **`$C006`** | **`$C006`** | `0` | `CLC` (cycle 1/2: `pc` held!) |
| `9` | `OPERAND` | `$69` (discarded) | **`$C006`** | `$C007` | `0` | `CLC` (cycle 2/2: Two-Read Rule) |
| `10` | `OPCODE` | `$69` | `$C007` | `$C008` | `0` | `ADC #$01` (cycle 1/2) |
| `11` | `OPERAND` | `$01` | `$C008` | `$C009` | `0` | `ADC #$01` (cycle 2/2) |
| `12` | `OPCODE` | `$4C` | `$C009` | `$C00A` | `0` | `JMP $C002` (cycle 1/3) |
| `13` | `OPERAND` | `$02` (`addr_lo`) | `$C00A` | `$C00B` | `0` | `JMP $C002` (cycle 2/3) |
| `14` | `HIGH` | `$C0` (`addr_hi`) | **`$C002`** | `$C003` | `0` | `JMP $C002` (cycle 3/3: jump!) |
| `15` | `OPCODE` | `$8D` | `$C003` | `$C004` | `0` | `STA $8000` (loop iteration 2) |

Count the steps between Step 4 and Step 15 (`15 - 4 = 11`), and between the first `write = 1` (Step 6) and the second `write = 1` (Step 17): **`11` cycles** (`4 + 2 + 2 + 3`), identical to real 6502 hardware.

### Block 1: Instruction, Mode & State Constants (`cpu_defs.vh`)

```verilog caption="Shared control constants in cpu_defs.vh"
localparam [2:0] INST_NOP = 3'd0;
localparam [2:0] INST_LDA = 3'd1;
localparam [2:0] INST_STA = 3'd2;
localparam [2:0] INST_CLC = 3'd3;
localparam [2:0] INST_ADC = 3'd4;
localparam [2:0] INST_JMP = 3'd5;

localparam [1:0] MODE_IMP = 2'd0;
localparam [1:0] MODE_IMM = 2'd1;
localparam [1:0] MODE_ABS = 2'd2;

localparam [2:0] STARTING = 3'd0;
localparam [2:0] OPCODE   = 3'd1;
localparam [2:0] OPERAND  = 3'd2;
localparam [2:0] HIGH     = 3'd3;
localparam [2:0] STORE    = 3'd4;
```

### Block 2: Combinational Opcode Decoder (`decoder.v`)

```verilog caption="apps/0015-first-five-instructions/decoder.v"
`timescale 1ns / 1ps

module decoder (
    input  wire [7:0] opcode,
    output wire [2:0] inst,
    output wire [1:0] mode
);
    `include "cpu_defs.vh"

    function [4:0] decode_opcode;
        input [7:0] op;
        begin
            case (op)
                8'hA9:   decode_opcode = {INST_LDA, MODE_IMM};
                8'h8D:   decode_opcode = {INST_STA, MODE_ABS};
                8'h18:   decode_opcode = {INST_CLC, MODE_IMP};
                8'h69:   decode_opcode = {INST_ADC, MODE_IMM};
                8'h4C:   decode_opcode = {INST_JMP, MODE_ABS};
                default: decode_opcode = {INST_NOP, MODE_IMP};
            endcase
        end
    endfunction

    assign {inst, mode} = decode_opcode(opcode);
endmodule
```

### Block 3: Five-State Sequencer (`cpu.v`)

```verilog caption="apps/0015-first-five-instructions/cpu.v"
`timescale 1ns / 1ps

module cpu #(
    parameter [15:0] RESET_ADDR = 16'hC000
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        step,
    input  wire [7:0]  data_in,
    output reg  [15:0] address = 16'h0000,
    output reg  [7:0]  data_out = 8'h00,
    output reg         write = 1'b0,
    output reg  [7:0]  opcode = 8'h00,
    output reg  [15:0] pc = 16'h0000,
    output reg  [2:0]  state = 3'd0
);
    `include "cpu_defs.vh"

    wire [2:0] dec_inst;
    wire [1:0] dec_mode;

    decoder u_decoder (
        .opcode(data_in),
        .inst(dec_inst),
        .mode(dec_mode)
    );

    reg [2:0] inst    = INST_NOP;
    reg [1:0] mode    = MODE_IMP;
    reg [7:0] addr_lo = 8'h00;

    always @(posedge clk) begin
        if (reset) begin
            state    <= STARTING;
            pc       <= 16'h0000;
            address  <= 16'h0000;
            data_out <= 8'h00;
            write    <= 1'b0;
            opcode   <= 8'h00;
            inst     <= INST_NOP;
            mode     <= MODE_IMP;
            addr_lo  <= 8'h00;
        end else if (step) begin
            case (state)
                STARTING: begin
                    address <= RESET_ADDR;
                    pc      <= RESET_ADDR + 16'd1;
                    write   <= 1'b0;
                    state   <= OPCODE;
                end
                OPCODE: begin
                    opcode  <= data_in;
                    inst    <= dec_inst;
                    mode    <= dec_mode;
                    address <= pc;
                    if (dec_mode != MODE_IMP) begin
                        pc <= pc + 16'd1;
                    end
                    write   <= 1'b0;
                    state   <= OPERAND;
                end
                OPERAND: begin
                    write <= 1'b0;
                    if (mode == MODE_ABS) begin
                        addr_lo <= data_in;
                        address <= pc;
                        pc      <= pc + 16'd1;
                        state   <= HIGH;
                    end else begin
                        address <= pc;
                        pc      <= pc + 16'd1;
                        state   <= OPCODE;
                    end
                end
                HIGH: begin
                    if (inst == INST_JMP) begin
                        address <= {data_in, addr_lo};
                        pc      <= {data_in, addr_lo} + 16'd1;
                        write   <= 1'b0;
                        state   <= OPCODE;
                    end else begin
                        address  <= {data_in, addr_lo};
                        data_out <= 8'h00;
                        write    <= 1'b1;
                        state    <= STORE;
                    end
                end
                STORE: begin
                    address <= pc;
                    pc      <= pc + 16'd1;
                    write   <= 1'b0;
                    state   <= OPCODE;
                end
                default: begin
                    state <= STARTING;
                    write <= 1'b0;
                end
            endcase
        end
    end
endmodule
```

- Notice `HIGH` for `INST_STA`: right now it writes `8'h00` because `cpu.v` does not have an Accumulator register yet—and `STORE` immediately drops `write <= 1'b0` while returning `address` to `pc` for the next opcode!

## 4. Watching All 16 RAM `SP` Blocks Snap Back

### Complete `top.v` Listing

```verilog caption="apps/0015-first-five-instructions/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 13500000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] disp_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        disp_sync <= {disp_sync[0], s2};
    end
    wire reset     = rst_sync[1];
    wire show_addr = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;
    wire [2:0]  state;

    computer u_computer (
        .clk(clk),
        .reset(reset),
        .step(step),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state)
    );

    assign led = ~(show_addr ? address[5:0] : opcode[5:0]);
endmodule
```

Remember how Yosys deleted all `16` RAM blocks in Lesson 12 because `cpu.v` held `write = 0`? Look at `make -C apps/0015-first-five-instructions stats` now that `STA` drives `write <= 1'b1`:

Table: Yosys `synth_gowin` Synthesis Stats Across `decoder`, `cpu`, `computer`, and `top`

| Synthesised Top | `SP` Block RAMs | `ALU` Carry Cells | `LUT1`–`LUT4` | Flip-Flops (`DFF*`) | Total Cells |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `decoder` | `0` | `0` | `80` (`69+0+0+11`) | `0` | `169` |
| `cpu` | `0` | `32` | `63` (`3+4+6+50`) | `57` (`DFFRE`) | `222` |
| `computer` | **`24`** (`8` ROM + **`16` RAM**) | `32` | `101` (`1+4+15+81`) | `60` (`3+57`) | `318` |
| `top` | **`24`** (`8` ROM + **`16` RAM**) | `57` | `113` (`6+6+18+83`) | `88` (`7+26+55`) | `324` |

Every single one of the `16` `SP` RAM blocks snapped straight back into the netlist because `write` is no longer a compile-time constant `0`!

---

:::exercise id="ex-0015" title="Interactive Lab: Implement the Two-Read Rule and JMP/STA HIGH State" badge="Skill Practice • Sequencer FSM"
Complete the `OPCODE` `pc` increment guard and the `HIGH` state inside `cpu.v` so `MODE_IMP` honours the Two-Read Rule and `INST_JMP`/`INST_STA` diverge cleanly:

```verilog
OPCODE: begin
    opcode  <= data_in;
    inst    <= dec_inst;
    mode    <= dec_mode;
    address <= pc;
    if (dec_mode != {{blank:MODE_IMP|Implied mode holds pc for the Two-Read Rule|????????|8}}) begin
        pc <= pc + 16'd1;
    end
    write   <= 1'b0;
    state   <= OPERAND;
end
```

```verilog
HIGH: begin
    if (inst == {{blank:INST_JMP|Jump jumps straight to OPCODE|????????|8}}) begin
        address <= {data_in, addr_lo};
        pc      <= {data_in, addr_lo} + 16'd1;
        write   <= 1'b0;
        state   <= {{blank:OPCODE|Next instruction fetch state|??????|6}};
    end else begin
        address  <= {data_in, addr_lo};
        data_out <= 8'h00;
        write    <= {{blank:1'b1|Assert bus write during STA|????|4}};
        state    <= STORE;
    end
end
```

:::prompts
hint: "Skip `pc + 1` when `dec_mode == MODE_IMP`; in `HIGH`, `INST_JMP` transitions directly to `OPCODE`, while `INST_STA` asserts `write <= 1'b1` and enters `STORE`."
success: "Verified! You have implemented cycle-accurate 6502 control flow and the Two-Read Rule."
:::
:::

:::quiz id="quiz-0015" title="Retrieval Practice: Combinational Decode, Two-Read Rule & RAM Re-Materialisation" badge="3 Questions • Equal-Length Options"
- question: "Why must `cpu.v` decode `data_in` combinationally on the `OPCODE` edge instead of waiting for `opcode` to latch first?"
  wrong_hint: "Check when `opcode` receives `data_in` vs when `dec_mode` controls `pc`."
  options:
    - letter: "A"
      text: "Because Gowin Block RAM resets the decoder register to zero whenever address bit fifteen turns high."
      correct: false
      explain: "Block RAM never modifies `cpu.v` registers; `decoder.v` is purely combinational."
    - letter: "B"
      text: "Because Verilog flip-flops cannot update an instruction register and a program counter inside one always block."
      correct: false
      explain: "Non-blocking `<=` updates multiple flip-flops simultaneously, just not before combinational inputs are decoded."
    - letter: "C"
      text: "Because operand fetches and the Two-Read Rule must steer pc immediately on that same clock tick."
      correct: true
      explain: "Correct: `OPCODE` uses `dec_mode` on the very edge that latches `opcode`, deciding immediately whether to advance `pc`."
    - letter: "D"
      text: "Because immediate instructions always fetch their high operand byte before reading any opcode from system memory."
      correct: false
      explain: "Every 6502 instruction fetches its opcode first in `OPCODE`, and immediate instructions have no high byte."
- question: "How does `cpu.v` reproduce the NMOS 6502 Two-Read Rule during a 1-byte implied instruction like `CLC` (`0x18`)?"
  wrong_hint: "Look at `address` and `pc` across Cycles 8 and 9 of Table 2."
  options:
    - letter: "A"
      text: "It halts the timer tick for one full cycle while clearing the processor carry flip-flop."
      correct: false
      explain: "`timer.v` keeps pulsing `step` continuously; the CPU executes a real dummy bus read in `OPERAND`."
    - letter: "B"
      text: "It places pc on address during OPCODE without incrementing pc, fetching the next byte twice."
      correct: true
      explain: "Correct: `address` reads `0xC006` during `OPERAND` (and discards it), then reads `0xC006` again for `ADC #0x01`."
    - letter: "C"
      text: "It jumps straight from OPCODE back to OPCODE in one step, skipping OPERAND completely today."
      correct: false
      explain: "Skipping `OPERAND` would make `CLC` a 1-cycle instruction, breaking cycle-accurate 6502 bus timing."
    - letter: "D"
      text: "It decrements pc by two inside OPERAND so the following instruction executes twice in hardware."
      correct: false
      explain: "`pc` is never decremented here—it simply holds still during `OPCODE` when `dec_mode == MODE_IMP`."
- question: "Why did all 16 RAM `SP` blocks reappear in `make stats` for `computer` in Lesson 15?"
  wrong_hint: "Compare `write` in Lesson 12 (`write <= 1'b0`) against `HIGH` for `INST_STA` in Lesson 15."
  options:
    - letter: "A"
      text: "Because adding decoder.v doubled Block RAM depth from sixteen kilobytes to sixty-four kilobytes in hardware."
      correct: false
      explain: "`ram.v` is still `32` KB (`16 SP` blocks) and `rom.v` is still `16` KB (`8 SP` blocks)."
    - letter: "B"
      text: "Because the Two-Read Rule forces Yosys to duplicate every ROM table across sixteen RAM tiles."
      correct: false
      explain: "ROM remains `8 SP` blocks; the `16` restored `SP` blocks belong to `u_ram`."
    - letter: "C"
      text: "Because nextpnr forbids zero-RAM netlists whenever a processor exposes its three-bit FSM state on pins."
      correct: false
      explain: "Lesson 12 already synthesised `0` RAM blocks cleanly when `write` was constant `0`."
    - letter: "D"
      text: "Because STA drives write high during HIGH state, preventing Yosys from proving RAM stays unwritten."
      correct: true
      explain: "Correct: once `write` can go high, `ram_write` is no longer constant `0`, so Yosys keeps all `16` `SP` RAM blocks."
:::

:::verify id="verify-0015" title="Verification Lab: Simulate the 11-Cycle Loop & Verify 24 Block RAMs" badge="Cycle-Accurate Simulation Gate"
Run all four testbenches (`decoder_tb.v`, `cpu_tb.v`, `computer_tb.v`, `top_tb.v`), build the bitstream, verify `24 SP` Block RAMs in `make stats`, and inspect the `11`-cycle loop in Surfer:

```bash caption="Test decoder/cpu/computer/top, verify 24 SP blocks, and view waveforms"
make -C apps/0015-first-five-instructions clean all
make -C apps/0015-first-five-instructions stats
make -C apps/0015-first-five-instructions wave
make -C apps/0015-first-five-instructions flash
```

- [ ] `make -C apps/0015-first-five-instructions clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS:` for `decoder`, `cpu`, `computer`, and `top`.
- [ ] `make stats` confirms `computer` and `top` both instantiate **`24 SP`** Block RAMs (`8` ROM + `16` RAM), confirming RAM is no longer pruned.
- [ ] In Surfer (`make wave`), confirm `CLC` fetches `$C006` twice (`Cycles 8` and `9`), `write` pulses high at `address = $8000` on `Cycle 6` and again `11` cycles later on `Cycle 17`, and `JMP` reloads `$C002`.
- [ ] On the Tang Nano 20K, onboard LEDs step through the fetched instruction opcodes at `2` Hz (`S2` switches to `address[5:0]`, and `S1` resets to `$C000`).
:::

:::teacher-prompt title="Next Up: Lesson 16 (Data Path Integration & Running Our First Program)"
Our 6502 now decodes all five instructions of `count.s` and drives the system bus with exact NMOS cycle timing! Ask any questions about `decoder.v`, the 5-state FSM, or the Two-Read Rule—or say **"ready for Lesson 16"** to wire in `alu.v`, the Accumulator (`A`), and the `$8000` LED register so our 6502 actually executes `count.s` and lights up the Tang Nano 20K.
:::
