---
title: "System Bus, Address Decoding & Synchronous Memory Timing"
page_title: "Lesson 0011: System Bus, Address Decoding & Synchronous Memory Timing — Build Your Own 6502"
nav_id: "lesson-0011"
badge: "Lesson 0011 • System Bus & Block RAM"
subtitle: "Build 16 KB ROM and 32 KB RAM in Gowin Block RAM, decode the 6502 address bus with two logic gates, align 1-tick synchronous read latency, and pace bus transactions with a 2-clock step signal."
card:
  title: "**System Bus, Address Decoding & Synchronous Memory Timing**"
  summary: "Wire 16 KB ROM, 32 KB RAM, and a 2-bit address decoder across 24 Gowin Block RAMs while respecting 1-tick synchronous memory timing."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0011-rom-ram-and-bus/` (`make -C apps/0011-rom-ram-and-bus clean all`)
- **Video reference**: [Episode 11: ROM, RAM and the Bus for Our 6502 Computer, in Verilog](https://www.youtube.com/watch?v=DwrVhG-ZAuk)
- **Hardware & toolchain**: [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula) and [Sipeed Tang Nano 20K Docs](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- **Course references**: [Lesson 4](0004-flip-flops-registers-fsm.md), [Lesson 8](0008-video-card-framebuffer.md), [Lesson 10](0010-ca65-ld65-toolchain.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. System Bus Topology & Split Data Buses

On a physical 1975 MOS 6502 DIP chip, 8 bidirectional pins (`D7..D0`) share reads and writes using tri-state drivers. Inside an FPGA, however, internal routing fabric has **no internal tri-state buses**—every internal wire must have one unambiguous driver.

Instead of fighting tri-state synthesis warnings, FPGA designs split the 8-bit data path cleanly into two unidirectional buses:

```mermaid caption="Figure 11.1: Unidirectional FPGA system bus connecting CPU, RAM, and ROM"
flowchart LR
  MASTER["Bus Master<br/>(Exerciser now, 6502 CPU in Lesson 12)"] -->|"address[15:0]"| DEC["Address Decoder<br/>A15 &amp; A14"]
  MASTER -->|"data_out[7:0], write"| BUS["System Bus"]
  DEC -->|"ram_select = ~A15"| RAM["ram.v (32 KB)<br/>16 x SP Block RAMs"]
  DEC -->|"rom_select = A15 &amp; A14"| ROM["rom.v (16 KB)<br/>8 x SP Block RAMs"]
  BUS -->|"data_in (ram_write = ram_select &amp; write)"| RAM
  RAM -->|"ram_data[7:0]"| MUX["1-Tick Delayed<br/>Read Multiplexer"]
  ROM -->|"rom_data[7:0]"| MUX
  MUX -->|"data_in[7:0]"| MASTER
```

Notice the naming convention from the **CPU's point of view**:
- **`data_out[7:0]`**: Bytes flowing *out* of the CPU toward RAM or memory-mapped I/O when `write = 1`.
- **`data_in[7:0]`**: Bytes flowing *into* the CPU from whichever memory device won the address decoder.

## 2. Two-Bit Address Decoding

Because we laid out our 64 KB memory map in [Lesson 9](0009-hand-assembled-6502.md) on clean power-of-two boundaries, decoding all `65,536` addresses comes down to inspecting just the **top two address bits** (`address[15]` and `address[14]`):

Table: Two-Bit Address Decoding Truth Table

| `address[15:14]` | Hex Range | Size | Selected Device | Write Behaviour |
| :--- | :--- | :--- | :--- | :--- |
| `2'b00`, `2'b01` | `$0000`–`$7FFF` | `32` KB | **RAM** (`ram_select = ~address[15]`) | Writes allowed (`ram_write = ram_select & write`) |
| `2'b10` | `$8000`–`$BFFF` | `16` KB | **I/O Space** (unmapped in Lesson 11) | Ignored by RAM and ROM; reads return `$00` |
| `2'b11` | `$C000`–`$FFFF` | `16` KB | **ROM** (`rom_select = address[15] & address[14]`) | Strictly read-only; writes never touch ROM |

Look how compact that combinational decoder is:
- `ram_select = ~address[15];` matches both `2'b00` and `2'b01`, feeding the lower 15 bits `address[14:0]` (`0..32767`) into `ram.v`.
- `rom_select = address[15] & address[14];` matches `2'b11`, feeding the lower 14 bits `address[13:0]` (`0..16383`) into `rom.v`.
- `ram_write = ram_select & write;` ensures a stray write to `$8000` (I/O) or `$C000` (ROM) can *never* alias into system RAM!

## 3. Inferring 24 Gowin Block RAMs (`rom.v`, `ram.v` & `bus.v`)

Just like our `320×200` video card in [Lesson 8](0008-video-card-framebuffer.md), both `rom.v` and `ram.v` must register their reads inside `always @(posedge clk)` so Yosys infers dedicated **Gowin `SP` Block RAM primitives** rather than burning thousands of general-purpose LUTs.

### Complete `rom.v` Module

```verilog caption="apps/0011-rom-ram-and-bus/rom.v"
`timescale 1ns / 1ps

module rom #(
    parameter INIT_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire [13:0] address,
    output reg  [7:0]  data_out = 8'h00
);
    reg [7:0] mem [0:16383];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        data_out <= mem[address];
    end
endmodule
```

### Complete `ram.v` Module

```verilog caption="apps/0011-rom-ram-and-bus/ram.v"
`timescale 1ns / 1ps

module ram (
    input  wire        clk,
    input  wire [14:0] address,
    input  wire [7:0]  data_in,
    input  wire        write,
    output reg  [7:0]  data_out = 8'h00
);
    reg [7:0] mem [0:32767];

    always @(posedge clk) begin
        if (write) begin
            mem[address] <= data_in;
        end
        data_out <= mem[address];
    end
endmodule
```

Look closely at `bus.v` below. Why do we register `ram_select_d1` and `rom_select_d1` on `posedge clk` instead of multiplexing `data_in` directly with `ram_select` and `rom_select`? Because `ram_data` and `rom_data` take **1 clock tick** to emerge from synchronous Block RAM! If the master switches `address` from `$C000` (ROM) to `$0000` (RAM) on tick $N$, `rom_data` is *still* finishing the `$C000` read on tick $N+1$—so `rom_select_d1` must wait 1 tick alongside `rom_data` to route the right device onto `data_in`.

### Complete `bus.v` Module

```verilog caption="apps/0011-rom-ram-and-bus/bus.v"
`timescale 1ns / 1ps

module bus #(
    parameter ROM_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire [15:0] address,
    input  wire [7:0]  data_out,
    input  wire        write,
    output wire [7:0]  data_in
);
    wire ram_select = ~address[15];
    wire rom_select = address[15] & address[14];
    wire ram_write  = ram_select & write;

    wire [7:0] ram_data;
    wire [7:0] rom_data;

    ram u_ram (
        .clk(clk),
        .address(address[14:0]),
        .data_in(data_out),
        .write(ram_write),
        .data_out(ram_data)
    );

    rom #(
        .INIT_FILE(ROM_FILE)
    ) u_rom (
        .clk(clk),
        .address(address[13:0]),
        .data_out(rom_data)
    );

    reg ram_select_d1 = 1'b0;
    reg rom_select_d1 = 1'b0;

    always @(posedge clk) begin
        ram_select_d1 <= ram_select;
        rom_select_d1 <= rom_select;
    end

    assign data_in = rom_select_d1 ? rom_data :
                     (ram_select_d1 ? ram_data : 8'h00);
endmodule
```

## 4. Synchronous Bus Timing & the Minimum 2-Tick `step` Rule

A real NMOS 6502 uses **asynchronous** SRAM and ROM chips that answer within the same clock cycle. Our FPGA's **synchronous Block RAM** cannot do that: presenting an address on `posedge clk` only delivers the byte on the *next* `posedge clk`.

To give synchronous memory time to respond without redesigning the 6502's single-cycle bus semantics, we pace our bus master (and later our CPU) using the single-clock-domain `timer.v` enable pulse (`step`) we built in [Lesson 4](0004-flip-flops-registers-fsm.md), enforcing a **minimum `STEP_PERIOD` of 2 clock ticks**:

```mermaid caption="Figure 11.2: Two-tick synchronous memory timing on the 27 MHz FPGA clock"
sequenceDiagram
  participant M as Bus Master (top / cpu)
  participant B as System Bus + BRAM
  Note over M,B: Tick 0 (step = 1): Master registers address = $C000
  M->>B: address = $C000 stable after Tick 0
  Note over M,B: Tick 1 (step = 0): BRAM samples $C000, bus latches rom_select_d1
  B-->>M: data_in = $A9 stable before Tick 2
  Note over M,B: Tick 2 (step = 1): Master safely latches data_in = $A9 and advances to $C001
```

On hardware (`STEP_PERIOD = 13500000`, `2` Hz), millions of ticks sit between steps. In simulation (`top_tb.v`), overriding `.STEP_PERIOD(2)` stresses the **fastest possible** 2-tick boundary (`13.5` MHz effective CPU clock on a `27` MHz board)—proving our timing has zero off-by-one slack errors!

## 5. Exercising ROM & RAM on the Tang Nano 20K (`top.v`)

In `top.v`, we connect `timer` and `bus` to our Tang Nano 20K LEDs and buttons (`S1` = reset, `S2` = mode):
- **`S2 = 0` (ROM walk)**: Steps sequentially from `$C000` upwards, displaying each byte's lower 6 bits on the active-low onboard LEDs (`$A9`, `$00`, `$8D`, `$00`, `$80`, `$18`, ...).
- **`S2 = 1` (RAM write/read-back)**: Cycles `MODE_RAM_WR` → `MODE_RAM_RD` → `MODE_RAM_SHOW`, writing `addr_cnt[7:0] ^ 8'h5A` into RAM and reading it right back onto the LEDs across the full 15-bit RAM address range.

### Complete `top.v` Listing

```verilog caption="apps/0011-rom-ram-and-bus/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 13500000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    localparam [1:0]
        MODE_ROM_READ = 2'd0,
        MODE_RAM_WR   = 2'd1,
        MODE_RAM_RD   = 2'd2,
        MODE_RAM_SHOW = 2'd3;

    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] mode_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        mode_sync <= {mode_sync[0], s2};
    end
    wire reset    = rst_sync[1];
    wire ram_mode = mode_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg  [15:0] bus_addr     = 16'hC000;
    reg  [7:0]  bus_data_out = 8'h00;
    reg         bus_write    = 1'b0;
    wire [7:0]  bus_data_in;

    bus u_bus (
        .clk(clk),
        .address(bus_addr),
        .data_out(bus_data_out),
        .write(bus_write),
        .data_in(bus_data_in)
    );

    reg [14:0] addr_cnt     = 15'd0;
    reg [1:0]  phase        = MODE_ROM_READ;
    reg        rom_armed    = 1'b0;
    reg [7:0]  display_byte = 8'h00;

    always @(posedge clk) begin
        if (reset) begin
            addr_cnt     <= 15'd0;
            phase        <= MODE_ROM_READ;
            rom_armed    <= 1'b0;
            bus_addr     <= 16'hC000;
            bus_data_out <= 8'h00;
            bus_write    <= 1'b0;
            display_byte <= 8'h00;
        end else if (step) begin
            if (!ram_mode) begin
                phase     <= MODE_ROM_READ;
                bus_write <= 1'b0;
                bus_addr  <= {2'b11, addr_cnt[13:0]};
                rom_armed <= 1'b1;
                if (rom_armed) begin
                    display_byte <= bus_data_in;
                end
                addr_cnt <= addr_cnt + 15'd1;
            end else begin
                rom_armed <= 1'b0;
                case (phase)
                    MODE_RAM_WR: begin
                        bus_addr     <= {1'b0, addr_cnt};
                        bus_data_out <= addr_cnt[7:0] ^ 8'h5A;
                        bus_write    <= 1'b1;
                        phase        <= MODE_RAM_RD;
                    end
                    MODE_RAM_RD: begin
                        bus_write <= 1'b0;
                        phase     <= MODE_RAM_SHOW;
                    end
                    MODE_RAM_SHOW: begin
                        display_byte <= bus_data_in;
                        addr_cnt     <= addr_cnt + 15'd1;
                        phase        <= MODE_RAM_WR;
                    end
                    default: begin
                        bus_write <= 1'b0;
                        phase     <= MODE_RAM_WR;
                    end
                endcase
            end
        end
    end

    assign led = ~display_byte[5:0];
endmodule
```

Running `make -C apps/0011-rom-ram-and-bus stats` reveals something fascinating about how Gowin `SP` Block RAMs work:
- Standalone `rom` uses **`8` `SP`** blocks (`16,384 × 1` bit per `SP`, one block per data bit!).
- Standalone `ram` uses **`16` `SP`** blocks (`2` `SP` blocks deep per bit for `32,768` bytes × `8` bits).
- Standalone `bus` combines them into **`24` `SP`** blocks (`8 + 16`), leaving `22` of our FPGA's `46` Block RAMs available.
- Inside `top`, because we only display `display_byte[5:0]` on 6 LEDs, Yosys automatically prunes the top 2 unobserved bit-slices (`[7:6]`) from both memories (`2` from ROM and `4` from RAM), reporting **`18` `SP`** blocks (`6 + 12`) alongside `40` `ALU` cells and `80` flip-flops! Once our real CPU reads full 8-bit opcodes and data in Lesson 12+, all `8` data bits of ROM will come right back.

---

:::exercise id="ex-0011" title="Interactive Lab: Decode Addresses & Align Synchronous Bus Reads" badge="Skill Practice • System Bus"
Complete the two-bit address decoding wires, the write-protect guard on RAM, and the 1-tick delayed read multiplexer in `bus.v`:

```verilog
wire ram_select = {{blank:~address[15]|Active when A15 is 0|???????????|11}};
wire rom_select = address[15] & {{blank:address[14]|Check A14 = 1 for $C000-$FFFF|???????????|11}};
wire ram_write  = {{blank:ram_select|Only allow writes inside RAM|??????????|10}} & write;

always @(posedge clk) begin
    ram_select_d1 <= ram_select;
    rom_select_d1 <= rom_select;
end

assign data_in = {{blank:rom_select_d1|1-tick delayed ROM select|?????????????|13}} ? rom_data :
                 (ram_select_d1 ? ram_data : 8'h00);
```

:::prompts
hint: "RAM spans `$0000`–`$7FFF` (`~address[15]`), ROM spans `$C000`–`$FFFF` (`address[15] & address[14]`), `ram_write` gates `write` with `ram_select`, and `data_in` checks `rom_select_d1`."
success: "Spot on! Your address decoder isolates RAM, I/O, and ROM while keeping every synchronous Block RAM read aligned by 1 tick."
:::
:::

:::quiz id="quiz-0011" title="Retrieval Practice: Address Decoding, Block RAM & 2-Tick Bus Pacing" badge="3 Questions • Equal-Length Options"
- question: "Why does `bus.v` register `ram_select_d1` and `rom_select_d1` on `posedge clk` instead of using combinational `ram_select` and `rom_select` to mux `data_in`?"
  wrong_hint: "Compare when `address` changes against when synchronous `SP` Block RAM outputs `rom_data` and `ram_data`."
  options:
    - letter: "A"
      text: "Because synchronous Block RAM outputs data one clock tick after the address changes."
      correct: true
      explain: "Correct: when `address` moves to a new region on tick `N`, `rom_data` and `ram_data` still hold the previous cycle's read until tick `N + 1`, so the mux select must wait 1 tick too."
    - letter: "B"
      text: "Because Gowin SP memory blocks invert their data bus unless registered inside flip-flops."
      correct: false
      explain: "Block RAM does not invert data; the register is strictly for 1-tick latency alignment."
    - letter: "C"
      text: "Because FPGA internal routing uses tri-state drivers that require two cycles to settle."
      correct: false
      explain: "FPGAs avoid internal tri-state buses altogether, using separate `data_in` and `data_out` multiplexers instead."
    - letter: "D"
      text: "Because Yosys refuses to synthesise combinational multiplexers attached to 16-bit address bus wires."
      correct: false
      explain: "Yosys happily synthesises combinational multiplexers; delaying select bits is a synchronous timing requirement."
- question: "What happens in `bus.v` if a program executes a write (`write = 1`) to ROM address `0xC000` or I/O address `0x8000`?"
  wrong_hint: "Trace `ram_select` and `ram_write = ram_select & write` when `address[15]` is `1`."
  options:
    - letter: "A"
      text: "Both memories mirror the write simultaneously unless rom_select explicitly clears the write line."
      correct: false
      explain: "`rom.v` is read-only and `ram_write` is gated by `~address[15]`, preventing any aliasing."
    - letter: "B"
      text: "Neither ROM nor RAM changes because ram_select stays zero whenever A15 is one."
      correct: true
      explain: "Correct: `ram_select = ~address[15]` is `0` for both `0x8000` and `0xC000`, so `ram_write` stays `0` and ROM has no write port."
    - letter: "C"
      text: "The lower 32 KB RAM overwrites zero page because address bits ignore A15."
      correct: false
      explain: "Even though `address[14:0]` wraps numerically, `ram_write` is `0` whenever `address[15] == 1`."
    - letter: "D"
      text: "The bus raises a hardware fault flag that halts the 27 MHz clock."
      correct: false
      explain: "The 6502 bus never halts on unmapped writes; `$8000` writes will soon drive our LED register."
- question: "Why must `STEP_PERIOD` be at least `2` clock cycles when a bus master reads synchronous Block RAM?"
  wrong_hint: "Count the clock edges from registering a new `address` to safely latching `data_in`."
  options:
    - letter: "A"
      text: "Because the Gowin rPLL requires two 27 MHz cycles before unlocking after reset."
      correct: false
      explain: "This design runs directly on the `27` MHz crystal without a PLL."
    - letter: "B"
      text: "Because every 6502 instruction always fetches two identical bytes from every ROM address."
      correct: false
      explain: "Even a single-byte read from synchronous BRAM requires 2 FPGA clock ticks per bus cycle."
    - letter: "C"
      text: "Because button debouncers block the timer tick output during every odd clock edge."
      correct: false
      explain: "The 2-tick minimum is imposed by synchronous Block RAM read latency, not buttons."
    - letter: "D"
      text: "Because one tick latches the address into BRAM and the next delivers data."
      correct: true
      explain: "Correct: Tick 0 registers `bus_addr`, Tick 1 lets synchronous BRAM output `data_in`, and Tick 2 safely samples `data_in`."
:::

:::verify id="verify-0011" title="Verification Lab: Simulate Bus Timing, Inspect Block RAM Stats & Flash FPGA" badge="Simulation & Hardware Gate"
Verify ROM reads, ROM write-protection, 32 KB RAM boundaries, unmapped I/O isolation, minimum `STEP_PERIOD=2` pacing, Yosys `SP` Block RAM counts, and hardware execution on the Tang Nano 20K:

```bash caption="Simulate bus and top, inspect Yosys Block RAM stats, and flash"
make -C apps/0011-rom-ram-and-bus clean all
make -C apps/0011-rom-ram-and-bus stats
make -C apps/0011-rom-ram-and-bus wave
make -C apps/0011-rom-ram-and-bus flash
```

- [ ] `make -C apps/0011-rom-ram-and-bus clean all` compiles with zero `iverilog -Wall` warnings and prints `PASS:` for both `bus` and `top` (`STEP_PERIOD=2`).
- [ ] `make stats` confirms `8 SP` for `rom`, `16 SP` for `ram`, `24 SP` for `bus`, and `18 SP` (`6` ROM + `12` RAM) for `top`.
- [ ] In Surfer (`make wave`), confirm `data_in` updates 1 `clk` edge after `address` changes, well before the second `clk` edge of each 2-tick step.
- [ ] On the Tang Nano 20K, LEDs walk the binary lower 6 bits of `rom.mem` (`$A9`, `$00`, `$8D`, ...) when `S2` is released, and display live RAM write/read-back patterns when holding `S2`.
:::

:::teacher-prompt title="Part 3 Complete — Preview Lesson 12 (Our First 6502 CPU in Verilog)"
With `ca65`, `ld65`, `rom.v`, `ram.v`, and `bus.v` all verified, **Part 3: 6502 Architecture & Toolchain Setup** is complete! Ask any questions about address decoding, Block RAM slicing, or 2-tick bus pacing—or continue to Lesson 12 to start **Part 4** by writing the very first lines of `cpu.v` and watching our processor fetch its first instructions across the bus.
:::
