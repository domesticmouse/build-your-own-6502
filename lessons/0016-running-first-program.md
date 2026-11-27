---
title: "Data Path Integration, Memory-Mapped LEDs & Fault Injection"
page_title: "Lesson 0016: Data Path Integration, Memory-Mapped LEDs & Fault Injection — Build Your Own 6502"
nav_id: "lesson-0016"
badge: "Lesson 0016 • First Program"
subtitle: "Wire alu.v, Accumulator A, and status flags into cpu.v, add the 0x8000 memory-mapped LED register in computer.v, simulate 3,010 cycles of count.s, and catch testing blind spots with fault injection."
card:
  title: "**Data Path, $8000 LEDs & First 6502 Program**"
  summary: "Connect the ALU and Accumulator to our 5-state sequencer, execute count.s across 3,010 simulated cycles, and expose reset-masking test traps."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0016-running-first-program/` (`make -C apps/0016-running-first-program clean all`)
- **Video reference**: [Episode 16: Our Own 6502 Runs Its First Program, in Verilog](https://www.youtube.com/watch?v=je0NqV8yfb4)
- **Upstream reference**: [`yvesrob/6502-gate-by-gate`](https://github.com/yvesrob/6502-gate-by-gate)
- **Course references**: [Lesson 14](0014-alu-status-flags.md), [Lesson 15](0015-first-five-instructions.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Completing the Three-Part CPU

In [Lesson 14](0014-alu-status-flags.md) we verified `alu.v` across `1,703,936` combinations, and in [Lesson 15](0015-first-five-instructions.md) we built the decoder and 5-state sequencer in `cpu.v`. Today we snap those halves together by wiring the **Data Path**:

- **Registers inside `cpu.v`**: 8-bit Accumulator `a`, plus four 1-bit flip-flops for the arithmetic status flags (`flag_c`, `flag_z`, `flag_n`, `flag_v`).
- **Combinational ALU (`u_alu`)**: Continuously evaluates `a` against `data_in` using `flag_c` as `carry_in`.
- **Memory-mapped I/O port (`leds` at `$8000`)**: Added inside `computer.v` so `STA $8000` actually latches `data_out` onto the Tang Nano 20K's six onboard LEDs.

```mermaid caption="Figure 16.1: Control unit (decoder + sequencer) wired to the ALU data path and 0x8000 LED port"
flowchart LR
  DIN["data_in (from bus)"] --> DEC["decoder.v"]
  DIN --> ALU["alu.v (ALU_ADD / ALU_PASS)"]
  A["Accumulator a"] --> ALU
  FC["flag_c"] --> ALU
  DEC -->|"inst, mode"| SEQ["5-State Sequencer"]
  SEQ -->|"working = (OPERAND & IMM/IMP)"| LATCH["Latch a & N,Z,C,V on step"]
  ALU --> LATCH
  A -->|"STA in HIGH: data_out <= a"| BUS["bus.v & $8000 LED Port"]
```

## 2. The `working` Signal & Exact Execution Timing

Look closely at **when** `cpu.v` must latch `alu_result` and the status flags. During `OPCODE`, `data_in` holds the opcode byte (`$A9` or `$69`)—not the operand! The immediate operand (`$00` or `$01`) only arrives on `data_in` during `OPERAND`.

So we define a single combinational execution signal:

```verilog
wire working = (state == OPERAND) && (mode == MODE_IMM || mode == MODE_IMP);
wire [3:0] alu_op = (inst == INST_ADC) ? ALU_ADD : ALU_PASS;
```

Watch how clean the timing becomes on a single `posedge clk` when `step == 1` and `working == 1`:

1. **`INST_LDA` (`alu_op = ALU_PASS`)**: `alu.v` forwards `data_in` (`b`) straight to `alu_result`, setting `alu_zero` and `alu_negative`. On the clock edge, `cpu.v` latches `a <= alu_result`, `flag_z <= alu_zero`, and `flag_n <= alu_negative`—leaving `flag_c` and `flag_v` untouched.
2. **`INST_ADC` (`alu_op = ALU_ADD`)**: `alu.v` computes `a + data_in + flag_c`, and `cpu.v` latches `a`, `flag_c`, `flag_z`, `flag_n`, and `flag_v`.
3. **`INST_CLC`**: `cpu.v` simply clears `flag_c <= 1'b0;` while `OPERAND` finishes its Two-Read dummy fetch.
4. **`INST_STA` (in `HIGH`)**: Instead of the placeholder `8'h00` from Lesson 15, `HIGH` now drives `data_out <= a;` alongside `write <= 1'b1;` and `address <= {data_in, addr_lo};`.

### Block 1: Data Path Ports & ALU Wiring (`cpu.v`)

```verilog caption="Accumulator, status flags, and ALU instantiation inside cpu.v"
    wire       working = (state == OPERAND) && (mode == MODE_IMM || mode == MODE_IMP);
    wire [3:0] alu_op  = (inst == INST_ADC) ? ALU_ADD : ALU_PASS;

    wire [7:0] alu_result;
    wire       alu_carry;
    wire       alu_zero;
    wire       alu_negative;
    wire       alu_overflow;

    alu u_alu (
        .op(alu_op),
        .a(a),
        .b(data_in),
        .carry_in(flag_c),
        .result(alu_result),
        .carry_out(alu_carry),
        .zero(alu_zero),
        .negative(alu_negative),
        .overflow(alu_overflow)
    );
```

### Block 2: Latching Registers on `working` (`cpu.v`)

```verilog caption="Updating Accumulator and flags on the final cycle of LDA, ADC, and CLC"
            if (working) begin
                case (inst)
                    INST_LDA: begin
                        a      <= alu_result;
                        flag_z <= alu_zero;
                        flag_n <= alu_negative;
                    end
                    INST_ADC: begin
                        a      <= alu_result;
                        flag_c <= alu_carry;
                        flag_z <= alu_zero;
                        flag_n <= alu_negative;
                        flag_v <= alu_overflow;
                    end
                    INST_CLC: begin
                        flag_c <= 1'b0;
                    end
                    default: ;
                endcase
            end
```

### Block 3: Memory-Mapped `$8000` LED Register (`computer.v`)

```verilog caption="Decoding 0x8000 writes into the 8-bit LED output register"
    always @(posedge clk) begin
        if (reset) begin
            leds <= 8'h00;
        end else if (write && (address == 16'h8000)) begin
            leds <= data_out;
        end
    end
```

- Because `bus.v` sets `ram_select = ~address[15]`, writing to `$8000` (`address[15] == 1`) automatically sets `ram_write = 0` so RAM stays untouched while `computer.v` captures `data_out` into `leds`.{{sidenote:On `top.v`, we change `STEP_PERIOD` to `540000` (`50` Hz CPU clock). Since each `count.s` loop takes `11` cycles, the onboard LEDs increment at roughly `4.5` counts per second—fast enough to feel alive yet slow enough to read every bit flip!}}

### Complete `cpu.v` Module

```verilog caption="apps/0016-running-first-program/cpu.v"
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
    output reg  [2:0]  state = 3'd0,
    output reg  [7:0]  a = 8'h00,
    output reg         flag_c = 1'b0,
    output reg         flag_z = 1'b0,
    output reg         flag_n = 1'b0,
    output reg         flag_v = 1'b0
);
    `include "cpu_defs.vh"
    `include "alu_ops.vh"

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

    wire       working = (state == OPERAND) && (mode == MODE_IMM || mode == MODE_IMP);
    wire [3:0] alu_op  = (inst == INST_ADC) ? ALU_ADD : ALU_PASS;

    wire [7:0] alu_result;
    wire       alu_carry;
    wire       alu_zero;
    wire       alu_negative;
    wire       alu_overflow;

    alu u_alu (
        .op(alu_op),
        .a(a),
        .b(data_in),
        .carry_in(flag_c),
        .result(alu_result),
        .carry_out(alu_carry),
        .zero(alu_zero),
        .negative(alu_negative),
        .overflow(alu_overflow)
    );

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
            a        <= 8'h00;
            flag_c   <= 1'b0;
            flag_z   <= 1'b0;
            flag_n   <= 1'b0;
            flag_v   <= 1'b0;
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
                        data_out <= a;
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

            if (working) begin
                case (inst)
                    INST_LDA: begin
                        a      <= alu_result;
                        flag_z <= alu_zero;
                        flag_n <= alu_negative;
                    end
                    INST_ADC: begin
                        a      <= alu_result;
                        flag_c <= alu_carry;
                        flag_z <= alu_zero;
                        flag_n <= alu_negative;
                        flag_v <= alu_overflow;
                    end
                    INST_CLC: begin
                        flag_c <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
```

### Complete `computer.v` Module

```verilog caption="apps/0016-running-first-program/computer.v"
`timescale 1ns / 1ps

module computer #(
    parameter ROM_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        step,
    output wire [15:0] address,
    output wire [7:0]  data_in,
    output wire [7:0]  data_out,
    output wire        write,
    output wire [7:0]  opcode,
    output wire [15:0] pc,
    output wire [2:0]  state,
    output wire [7:0]  a,
    output wire        flag_c,
    output wire        flag_z,
    output wire        flag_n,
    output wire        flag_v,
    output reg  [7:0]  leds = 8'h00
);
    cpu u_cpu (
        .clk(clk),
        .reset(reset),
        .step(step),
        .data_in(data_in),
        .address(address),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v)
    );

    bus #(
        .ROM_FILE(ROM_FILE)
    ) u_bus (
        .clk(clk),
        .address(address),
        .data_out(data_out),
        .write(write),
        .data_in(data_in)
    );

    always @(posedge clk) begin
        if (reset) begin
            leds <= 8'h00;
        end else if (write && (address == 16'h8000)) begin
            leds <= data_out;
        end
    end
endmodule
```

## 3. Fault Injection & The `LDA #$00` Testing Trap

Here is a subtle testing trap we must never fall into—and it is a classic reason why fault injection matters so much in hardware verification:

Look at the first instruction of `count.s`: `LDA #$00`. Suppose you accidentally forgot to write the `INST_LDA` branch inside `if (working)` in `cpu.v`. Would `computer_tb.v` catch it? **No!** Because `reset` already initialised `a <= 8'h00`, `count.s` would silently start at `0`, `ADC #$01` would count `1, 2, 3, ...`, and all `3,010` cycles of `count.s` would pass even though `LDA` is completely broken!

That is why `cpu_tb.v` deliberately breaks out of reset defaults before trusting `LDA`:
1. **`LDA #$2A` from `a == $00`**: Proves `LDA` actually writes a non-zero byte into `a` and clears `Z` and `N`.
2. **`LDA #$80`**: Proves `LDA` sets `flag_n = 1` on negative bytes.
3. **`LDA #$00` from `a == $80`**: Proves `LDA` actually overwrites a non-zero Accumulator back to `$00` and sets `flag_z = 1`.

Try commenting out `INST_LDA:` in `cpu.v` once on purpose ("fail once on purpose"): `computer_tb.v` will still pass, while `cpu_tb.v` catches the fault on the very first check!

## 4. 3,010-Cycle Simulation & Silicon Footprint

`computer_tb.v` simulates `count.s` for `3,010` CPU steps—executing `274` `STA $8000` writes spaced exactly `11` cycles apart, crossing the full 8-bit `$FF -> $00` wraparound (`flag_c` asserts on `ADC #$01`, then `CLC` clears it before the next addition), and testing mid-run `reset`.

### Complete `top.v` Listing

```verilog caption="apps/0016-running-first-program/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 540000
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
    wire [7:0]  a;
    wire        flag_c;
    wire        flag_z;
    wire        flag_n;
    wire        flag_v;
    wire [7:0]  leds;

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
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v),
        .leds(leds)
    );

    assign led = ~(show_addr ? address[5:0] : leds[5:0]);
endmodule
```

Table: Yosys `synth_gowin` Cell Utilisation (`cpu`, `computer`, and `top` Running `count.s`)

| Synthesised Top | `SP` Block RAMs | `ALU` Carry Cells | `LUT1`–`LUT4` | `MUX2_LUT5`–`8` | Flip-Flops (`DFF*`) | Total Cells |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `cpu` | `0` | `41` | `100` (`12+8+18+62`) | `15` (`11+3+1`) | `76` (`DFFRE`) | `311` |
| `computer` | **`24`** (`8` ROM + `16` RAM) | `41` | `168` (`29+18+29+92`) | `56` (`37+14+5`) | `87` (`3+84`) | `467` |
| `top` | **`24`** (`8` ROM + `16` RAM) | `66` | `212` (`48+14+34+116`) | `96` (`58+26+9+3`) | `105` (`7+26+72`) | `522` |

Notice how lean our working 6502 core is: `cpu` alone fits inside **`76` flip-flops**, `41` `ALU` carry cells (including both `pc` incrementers and the shared 9-bit ALU adder), and `100` LUTs—less than `1%` of the Tang Nano 20K's `20,736` logic cells!

---

:::exercise id="ex-0016" title="Interactive Lab: Wire the Data Path Execution Signal and 0x8000 Port" badge="Skill Practice • Data Path"
Complete the `working` execution condition, `alu_op` selector, and `$8000` write port inside `cpu.v` and `computer.v`:

```verilog
wire       working = (state == {{blank:OPERAND|Cycle when immediate or implied instruction executes|???????|7}}) && (mode == MODE_IMM || mode == MODE_IMP);
wire [3:0] alu_op  = (inst == INST_ADC) ? {{blank:ALU_ADD|ALU operation for ADC|???????|7}} : {{blank:ALU_PASS|Forward data_in unchanged for LDA|????????|8}};
```

```verilog
always @(posedge clk) begin
    if (reset) begin
        leds <= 8'h00;
    end else if ({{blank:write|Bus write enable signal|?????|5}} && (address == 16'h8000)) begin
        leds <= data_out;
    end
end
```

:::prompts
hint: "Execution happens in `OPERAND`; `INST_ADC` selects `ALU_ADD` while `INST_LDA` uses `ALU_PASS`; `computer.v` latches `data_out` when `write && (address == 16'h8000)`."
success: "Verified! Your Verilog 6502 now executes real instructions end-to-end and drives hardware LEDs."
:::
:::

:::quiz id="quiz-0016" title="Retrieval Practice: Execution Timing, Memory-Mapped I/O & Testing Traps" badge="3 Questions • Equal-Length Options"
- question: "Why must `cpu.v` gate ALU and flag updates with `working = (state == OPERAND) && (mode == MODE_IMM || mode == MODE_IMP)`?"
  wrong_hint: "Check which cycle puts the immediate operand onto `data_in`."
  options:
    - letter: "A"
      text: "Because opcode fetches must overwrite the accumulator every single time the sequencer enters OPCODE."
      correct: false
      explain: "Overwriting `A` during `OPCODE` would corrupt `A` with instruction opcodes like `0x8D` or `0x4C`."
    - letter: "B"
      text: "Because immediate and implied instructions receive their operand on data_in during the OPERAND cycle."
      correct: true
      explain: "Correct: `data_in` holds the immediate byte (for `LDA`/`ADC`) precisely when `state == OPERAND` fires."
    - letter: "C"
      text: "Because absolute write instructions must latch the accumulator before fetching their low address byte."
      correct: false
      explain: "`STA` reads `A` during `HIGH` to drive `data_out`—it never modifies `A` or status flags."
    - letter: "D"
      text: "Because Gowin Block RAM blocks accumulator writes whenever the bus write signal turns low."
      correct: false
      explain: "Accumulator `a` lives inside `cpu.v` flip-flops, not in Block RAM."
- question: "How does `computer.v` keep the memory-mapped LED register from being overwritten when `STA` writes to RAM?"
  wrong_hint: "Check `address[15]` for `0x0000`–`0x7FFF` vs `0x8000`."
  options:
    - letter: "A"
      text: "By disabling the system bus write line whenever the program counter enters ROM."
      correct: false
      explain: "All code in `count.s` runs from ROM (`0xC000`+), yet `STA` still writes to `0x8000`."
    - letter: "B"
      text: "By routing LED data through the high address lines instead of data_out wires."
      correct: false
      explain: "The data value stored in `leds` comes from `data_out`, while `address` selects `0x8000`."
    - letter: "C"
      text: "By clearing the accumulator back to zero immediately before every bus store cycle."
      correct: false
      explain: "`STA` writes the live contents of `A` (`0, 1, 2, ...`) onto the LED port."
    - letter: "D"
      text: "By decoding address equality with 0x8000 while bus blocks RAM writes above 0x7FFF."
      correct: true
      explain: "Correct: `computer.v` matches `address == 0x8000` and `bus.v` keeps `ram_write = ~address[15] & write = 0`."
- question: "Why can running `count.s` alone mask a bug where `LDA` fails to update `A`?"
  wrong_hint: "Look at the initial value of `a` after `reset` vs the first instruction `LDA #0x00`."
  options:
    - letter: "A"
      text: "Because reset already zeroed A, so LDA zero appears to work until tested non-zero."
      correct: true
      explain: "Correct: `count.s` starts with `LDA #0x00` right after `reset` cleared `A = 0x00`, hiding a dead `LDA` unless `cpu_tb.v` loads non-zero bytes."
    - letter: "B"
      text: "Because Yosys automatically repairs broken load instructions whenever Block RAM outputs read zero bytes."
      correct: false
      explain: "Yosys synthesises exactly what you wrote and cannot repair missing `INST_LDA` logic."
    - letter: "C"
      text: "Because ca65 optimises away LDA immediate zero instructions before linking the binary ROM file."
      correct: false
      explain: "`ca65` emits `A9 00` literally at `0xC000` without optimising instructions away."
    - letter: "D"
      text: "Because STA writes the incoming ROM opcode straight onto LEDs instead of the accumulator."
      correct: false
      explain: "`STA` writes `a` via `data_out <= a`, never `opcode`."
:::

:::verify id="verify-0016" title="Verification Lab: Simulate 3,010 Cycles & Flash Our Working 6502 to Tang Nano 20K" badge="End-to-End Hardware Gate"
Run all four testbenches (`decoder`, `cpu` fault-injection tests, `3,010`-cycle `computer_tb.v`, and `top_tb.v`), build the bitstream, inspect Yosys resource utilisation, and flash the Tang Nano 20K to watch your own 6502 count in binary on the onboard LEDs:

```bash caption="Run all simulations, inspect stats, view waveforms, and flash hardware"
make -C apps/0016-running-first-program clean all
make -C apps/0016-running-first-program stats
make -C apps/0016-running-first-program wave
make -C apps/0016-running-first-program flash
```

- [ ] `make -C apps/0016-running-first-program clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS:` for `decoder`, `cpu` (including `LDA #$2A` and `LDA #$00` from non-zero `A`), `computer` (`3010` cycles, `274` `STA $8000` writes, full 8-bit wrap), and `top`.
- [ ] `make stats` confirms `cpu` takes `76` flip-flops and `41` `ALU` cells while `computer` preserves all `24 SP` Block RAMs (`467` total cells).
- [ ] In Surfer (`make wave`), verify `a` increments `0 -> 1 -> 2 -> ...`, `leds` updates synchronously whenever `write == 1` at `address == $8000`, and `pc` loops cleanly back to `$C002`.
- [ ] On the Tang Nano 20K, the onboard LEDs count upward in binary at ~`4.5` Hz powered by real 6502 machine code in `rom.mem` (`S2` switches to `address[5:0]`, and `S1` resets back to `0`).
:::

:::teacher-prompt title="Next Up: Lesson 17 (6502 on Real Hardware, UART Profiling & SingleStep Tests)"
Your own Verilog 6502 is officially executing its first assembled program end-to-end! Ask any questions about `working`, `$8000` I/O decoding, or the `LDA #$00` fault-injection trap—or say **"ready for Lesson 17"** to deploy at slow human-visible speed with UART cycle profiling and run the third-party SingleStep Tests vector suite.
:::
