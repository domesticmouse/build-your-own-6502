---
title: "CPU Skeleton, Reset Vector & Fetch FSM"
page_title: "Lesson 0012: CPU Skeleton, Reset Vector & Fetch FSM — Build Your Own 6502"
nav_id: "lesson-0012"
badge: "Lesson 0012 • 6502 CPU Core"
subtitle: "Write the first lines of cpu.v with a two-state STARTING/OPCODE fetch FSM, distinguish the Program Counter from the active bus address, simulate all 11 ROM bytes across the bus, and watch Yosys prune unwritten RAM."
card:
  title: "**CPU Skeleton, Reset Vector & Fetch FSM**"
  summary: "Build our first cpu.v skeleton with STARTING and OPCODE states, fetch all 11 ROM bytes in simulation, and observe Yosys dead-code elimination."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0012-first-cpu-fetch-fsm/` (`make -C apps/0012-first-cpu-fetch-fsm clean all`)
- **Video reference**: [Episode 12: Our Own 6502 in Verilog: Writing the First Lines of the Processor](https://www.youtube.com/watch?v=laCEMFvLe48)
- **Upstream reference**: [`yvesrob/6502-gate-by-gate`](https://github.com/yvesrob/6502-gate-by-gate)
- **Course references**: [Lesson 4](0004-flip-flops-registers-fsm.md), [Lesson 11](0011-rom-ram-and-bus.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Anatomy of the First CPU Skeleton (`cpu.v`)

In [Lesson 11](0011-rom-ram-and-bus.md), we wired `rom.v`, `ram.v`, and `bus.v` behind a synthetic counter in `top.v`. Today we replace that test harness with the very first lines of our real 6502 processor: **`cpu.v`**.

Just like a seasoned engineer starting any new system, we do not try to implement all 151 opcodes on day one. Instead, we build the smallest possible **fetch skeleton** that plugs cleanly into `bus.v` and proves our processor can wake up after reset and walk through `rom.mem` byte by byte:

- **Inputs**: `clk` (27 MHz FPGA clock), `reset` (active-high synchronous reset), `step` (1-tick enable pulse with `PERIOD >= 2`), and `data_in[7:0]` (incoming byte from `bus.v`).
- **Outputs**: `address[15:0]`, `data_out[7:0]`, `write` (always `0` for now), plus `opcode[7:0]` and `pc[15:0]` exposed so our testbenches and Tang Nano 20K LEDs can observe internal state directly.

## 2. The Two-State Fetch FSM (`STARTING` vs `OPCODE`)

Remember from Lesson 11 that our Block RAM takes **1 clock tick** to answer an address. When `reset` drops, `data_in` does *not* hold the first instruction yet—because `cpu.v` hasn't even asked `bus.v` for `$C000`!

That forces a clean **two-state Finite State Machine** (`STARTING` and `OPCODE`) using the exact `localparam` + `case` pattern from [Lesson 4](0004-flip-flops-registers-fsm.md):

```mermaid caption="Figure 12.1: Two-state fetch FSM in cpu.v handling 1-tick Block RAM latency"
stateDiagram-v2
  [*] --> STARTING: reset = 1 (address = $0000, pc = $0000)
  STARTING --> OPCODE: step = 1 / address <= $C000, pc <= $C001
  OPCODE --> OPCODE: step = 1 / opcode <= data_in, address <= pc, pc <= pc + 1
  OPCODE --> STARTING: reset = 1
```

Look closely at why **`STARTING` cannot latch `data_in`**:
1. During `reset = 1`, `address` is `$0000`.
2. On the **first `step`** (`state == STARTING`), the CPU places `RESET_ADDR` (`$C000`) on `address`, queues `pc <= $C001`, and transitions to `OPCODE`. `opcode` stays `$00` because `$C000` has only just been requested!
3. Between Step 1 and Step 2 (because `STEP_PERIOD >= 2`), synchronous ROM inside `bus.v` reads `rom[$C000]` (`$A9`) onto `data_in`.
4. On the **second `step`** (`state == OPCODE`), `data_in` holds `$A9`, so the CPU latches `opcode <= data_in`, puts `pc` (`$C001`) onto `address`, and increments `pc <= $C002`.

From Step 2 onward, `cpu.v` runs a continuous 1-byte-per-step fetch pipeline!{{sidenote:Here we hard-wire `RESET_ADDR = 16'hC000` as a parameter so we can focus on fetch mechanics first; later we will fetch the dynamic 2-byte reset vector from `` `$FFFC` ``–`` `$FFFD` ``.}}

## 3. Program Counter (`pc`) vs Active Bus Address (`address`)

Beginners often expect `pc` and `address` to always hold the exact same number. Look at the step-by-step trace of our `computer_tb.v` simulation and notice they are **always off by 1** during sequential fetches:

Table: Step-by-Step Fetch Trace (`cpu` + `bus` + `rom.mem`)

| Step | State Before Step | `address` (After Step) | `pc` (After Step) | `data_in` (Before Next Step) | `opcode` (After Step) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Reset | `—` | `$0000` | `$0000` | `$00` | `$00` |
| `1` | `STARTING` | `$C000` | `$C001` | `$A9` (`LDA`) | `$00` |
| `2` | `OPCODE` | `$C001` | `$C002` | `$00` (`#$00`) | **`$A9`** |
| `3` | `OPCODE` | `$C002` | `$C003` | `$8D` (`STA`) | **`$00`** |
| `4` | `OPCODE` | `$C003` | `$C004` | `$00` (lo) | **`$8D`** |
| `5` | `OPCODE` | `$C004` | `$C005` | `$80` (hi) | **`$00`** |
| `6` | `OPCODE` | `$C005` | `$C006` | `$18` (`CLC`) | **`$80`** |

Why keep `address` and `pc` separate? Because in upcoming lessons, instructions like `STA $8000` must put a **data address** (`$8000`) on `address` for one cycle *without losing track of where the next instruction lives in `pc`* (`$C005`)! Separating `address` (what the bus is reading/writing right now) from `pc` (where instruction fetch will resume next) is essential for every multi-cycle CPU.

### Block 1: CPU Ports & FSM States (`cpu.v`)

```verilog caption="CPU skeleton interfaces and STARTING/OPCODE states in cpu.v"
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
    output reg  [15:0] pc = 16'h0000
);
    localparam STARTING = 1'b0;
    localparam OPCODE   = 1'b1;

    reg state = STARTING;
```

### Block 2: Synchronous Reset & Non-Blocking Fetch Updates (`cpu.v`)

```verilog caption="Non-blocking <= updates ensuring address receives pre-increment pc"
    always @(posedge clk) begin
        if (reset) begin
            state    <= STARTING;
            pc       <= 16'h0000;
            address  <= 16'h0000;
            data_out <= 8'h00;
            write    <= 1'b0;
            opcode   <= 8'h00;
        end else if (step) begin
            case (state)
                STARTING: begin
                    address <= RESET_ADDR;
                    pc      <= RESET_ADDR + 16'd1;
                    state   <= OPCODE;
                end
                OPCODE: begin
                    opcode  <= data_in;
                    address <= pc;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end
            endcase
        end
    end
```

- Notice how non-blocking assignment (`<=`) inside `OPCODE` makes `address <= pc;` and `pc <= pc + 16'd1;` clean and race-free: `address` receives the *old* `pc` while `pc` simultaneously advances by `1` for the following step.

### Complete `cpu.v` Module

```verilog caption="apps/0012-first-cpu-fetch-fsm/cpu.v"
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
    output reg  [15:0] pc = 16'h0000
);
    localparam STARTING = 1'b0;
    localparam OPCODE   = 1'b1;

    reg state = STARTING;

    always @(posedge clk) begin
        if (reset) begin
            state    <= STARTING;
            pc       <= 16'h0000;
            address  <= 16'h0000;
            data_out <= 8'h00;
            write    <= 1'b0;
            opcode   <= 8'h00;
        end else if (step) begin
            case (state)
                STARTING: begin
                    address <= RESET_ADDR;
                    pc      <= RESET_ADDR + 16'd1;
                    state   <= OPCODE;
                end
                OPCODE: begin
                    opcode  <= data_in;
                    address <= pc;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end
            endcase
        end
    end
endmodule
```

### Complete `computer.v` Module

`computer.v` encapsulates `cpu` and `bus` into a reusable system module so `computer_tb.v` can simulate the exact CPU-to-memory handshake cleanly without board-specific button or LED logic:

```verilog caption="apps/0012-first-cpu-fetch-fsm/computer.v"
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
    output wire [15:0] pc
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
        .pc(pc)
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
endmodule
```

## 4. Wiring `top.v` & Watching Yosys Prune Unwritten RAM

In `top.v`, we connect `timer` (`2` Hz on hardware, `STEP_PERIOD = 2` in simulation) to `computer` and use `S2` to toggle the 6 active-low onboard LEDs between `opcode[5:0]` (what byte the CPU just fetched) and `address[5:0]` (the low 6 bits of where it is fetching next).

### Complete `top.v` Listing

```verilog caption="apps/0012-first-cpu-fetch-fsm/top.v"
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

    computer u_computer (
        .clk(clk),
        .reset(reset),
        .step(step),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc)
    );

    assign led = ~(show_addr ? address[5:0] : opcode[5:0]);
endmodule
```

Now run `make -C apps/0012-first-cpu-fetch-fsm stats` and look closely at the Block RAM numbers Yosys prints across the three modules:

Table: Yosys `synth_gowin` Block RAM Pruning Across `bus`, `computer`, and `top`

| Synthesised Top | `SP` Block RAMs | What Changed in the Netlist |
| :--- | :--- | :--- |
| `bus` | **`24` `SP`** (`8` ROM + `16` RAM) | All RAM/ROM ports are top-level I/O pins, so nothing can be pruned |
| `computer` | **`8` `SP`** (`8` ROM + **`0` RAM**) | `cpu` holds `write = 0`, so Yosys proves `ram` is never written and deletes all `16` RAM blocks! |
| `top` | **`6` `SP`** (`6` ROM + `0` RAM) | `top` only shows `opcode[5:0]` on 6 LEDs, so Yosys also slices off `rom[7:6]` (`2` blocks) |

:::callout-warn title="Dead-Code Elimination Is Normal (and Catchy!)"
Seeing `16` RAM blocks vanish to `0` inside `computer` is **synthesis dead-code elimination** in action: because `cpu.v` never drives `write = 1`, `ram_write` is stuck at constant `0`, and Yosys deletes the unreachable memory hardware automatically. Once our CPU starts executing `STA` instructions in later lessons, those `16` `SP` blocks will snap straight back into the netlist!
:::

---

:::exercise id="ex-0012" title="Interactive Lab: Complete the Two-State Fetch FSM" badge="Skill Practice • CPU Core"
Fill in the `STARTING` and `OPCODE` transitions inside `cpu.v` so reset begins fetching at `RESET_ADDR` (`$C000`) and each `OPCODE` step latches the incoming byte while advancing `pc`:

```verilog
case (state)
    STARTING: begin
        address <= {{blank:RESET_ADDR|First fetch address on boot|??????????|10}};
        pc      <= RESET_ADDR + 16'd1;
        state   <= {{blank:OPCODE|Next FSM state|??????|6}};
    end
    OPCODE: begin
        opcode  <= {{blank:data_in|Incoming byte from bus|???????|7}};
        address <= {{blank:pc|Next instruction address|??|2}};
        pc      <= pc + 16'd1;
        state   <= OPCODE;
    end
endcase
```

:::prompts
hint: "`STARTING` puts `RESET_ADDR` on `address` and enters `OPCODE`; `OPCODE` latches `data_in` into `opcode` and puts `pc` onto `address`."
success: "Verified! You have the exact two-state fetch skeleton of our Verilog 6502."
:::
:::

:::quiz id="quiz-0012" title="Retrieval Practice: Fetch FSM, PC vs Address Bus & Dead-Code Elimination" badge="3 Questions • Equal-Length Options"
- question: "Why does `cpu.v` wait in `STARTING` for one `step` before latching `opcode <= data_in` in `OPCODE`?"
  wrong_hint: "Check what address `bus.v` sees during reset before the first `step` fires."
  options:
    - letter: "A"
      text: "Because the 6502 always discards the very first instruction byte stored in ROM."
      correct: false
      explain: "No byte is discarded—`0xA9` at `0xC000` is latched cleanly on Step 2."
    - letter: "B"
      text: "Because reset keeps address zero, so ROM needs one step to output data."
      correct: true
      explain: "Correct: `STARTING` places `0xC000` onto `address`, giving synchronous ROM 1+ clock ticks before `OPCODE` latches `data_in` on Step 2."
    - letter: "C"
      text: "Because the reset button S1 forces the accumulator to load zero before fetching."
      correct: false
      explain: "`cpu.v` doesn't even have an accumulator yet; the extra step is purely for synchronous bus timing."
    - letter: "D"
      text: "Because Yosys requires an extra dummy state whenever a Verilog case uses localparams."
      correct: false
      explain: "Yosys does not require dummy states; `STARTING` exists strictly because synchronous BRAM needs an address before answering."
- question: "During sequential fetches in `OPCODE`, why is `pc` always one ahead of `address` (`pc == address + 1`)?"
  wrong_hint: "Look at the two non-blocking assignments `address <= pc;` and `pc <= pc + 16'd1;`."
  options:
    - letter: "A"
      text: "Because 6502 instructions always fetch odd memory addresses before reading even memory addresses."
      correct: false
      explain: "Fetches proceed strictly sequentially (`0xC000`, `0xC001`, `0xC002`, ...)."
    - letter: "B"
      text: "Because little-endian buses add one automatically inside the dedicated Gowin Block RAM primitive."
      correct: false
      explain: "Block RAM performs no arithmetic; `cpu.v` explicitly increments `pc`."
    - letter: "C"
      text: "Because address holds the active fetch location while pc prepares the following byte."
      correct: true
      explain: "Correct: thanks to `<=`, `address` receives the old `pc` for the current bus read while `pc` increments by `1` for the next cycle."
    - letter: "D"
      text: "Because the system bus shifts every 16-bit address left by one bit internally."
      correct: false
      explain: "`bus.v` passes `address[13:0]` directly to ROM without shifting."
- question: "When running `make stats`, why does `bus` synthesise `24 SP` Block RAMs while `computer` synthesises only `8 SP`?"
  wrong_hint: "Check what `cpu.v` drives onto `write` in this first skeleton."
  options:
    - letter: "A"
      text: "Because cpu never asserts write, allowing Yosys to prune all sixteen unwritten RAMs."
      correct: true
      explain: "Correct: dead-code elimination detects that `write` stays `0`, so the 32 KB `ram` cannot be written and its `16 SP` blocks are optimised away."
    - letter: "B"
      text: "Because computer merges the 32 KB RAM directly into LUT flip-flops for speed."
      correct: false
      explain: "32 KB (`262,144` bits) could never fit in the GW2AR-18's flip-flops; Yosys simply deleted the unused RAM."
    - letter: "C"
      text: "Because Yosys disables Block RAM whenever two modules share one 27 MHz clock."
      correct: false
      explain: "ROM (`8 SP`) still synthesises cleanly on the same `27` MHz clock."
    - letter: "D"
      text: "Because the Tang Nano 20K hardware has only eight physical Block RAM tiles."
      correct: false
      explain: "The GW2AR-18 has `46` Block RAM tiles; `bus` standalone already placed `24 SP` blocks."
:::

:::verify id="verify-0012" title="Verification Lab: Simulate All 11 ROM Fetches, Inspect Dead-Code Pruning & Flash" badge="Simulation & Hardware Gate"
Unit-test `cpu.v`, simulate the full `computer` fetching all 11 bytes of `rom.mem`, inspect `make stats` comparing `bus` vs `computer` vs `top`, inspect `computer.vcd` in Surfer, and flash the Tang Nano 20K:

```bash caption="Test CPU/computer/top, compare Yosys stats, and flash"
make -C apps/0012-first-cpu-fetch-fsm clean all
make -C apps/0012-first-cpu-fetch-fsm stats
make -C apps/0012-first-cpu-fetch-fsm wave
make -C apps/0012-first-cpu-fetch-fsm flash
```

- [ ] `make -C apps/0012-first-cpu-fetch-fsm clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS:` for `cpu`, `computer` (all 11 ROM bytes `$A9`..`$C0`), and `top` (`STEP_PERIOD=2`).
- [ ] `make stats` confirms `24 SP` for `bus`, `8 SP` for `computer` (all 16 unwritten RAM blocks pruned), and `6 SP` (`41 ALU`, `70` flip-flops) for `top`.
- [ ] In Surfer (`make wave`), confirm `STARTING` places `$C000` on `address` on Step 1, and `opcode` latches `$A9`, `$00`, `$8D`, `$00`, `$80`, `$18`, `$69`, `$01`, `$4C`, `$02`, `$C0` one step at a time while `pc == address + 1`.
- [ ] On the Tang Nano 20K, onboard LEDs step through the lower 6 bits of each fetched byte at `2` Hz (`S2` switches to `address[5:0]`, and `S1` resets back to `$C000`).
:::

:::teacher-prompt title="Next Up: Lesson 13 (Writing the 6502 ALU in Verilog)"
Our Verilog 6502 now boots at `$C000` and fetches real machine code from `rom.mem` across the system bus! Ask any questions about the `STARTING`/`OPCODE` FSM, `pc` vs `address`, or Yosys dead-code elimination—or say **"ready for Lesson 13"** to build the 6502's combinational ALU and see how a single shared 9-bit adder powers five different instructions.
:::
