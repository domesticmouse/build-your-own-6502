---
title: "Raster Scanning, 640×480@60 Hz Counters & Test Patterns"
page_title: "Lesson 0005: Raster Scanning, 640×480@60 Hz Counters & Test Patterns — Build Your Own 6502"
nav_id: "lesson-0005"
badge: "Lesson 0005 • Video Architecture"
subtitle: "Turn two nested 10-bit counters into standard 640×480@60 Hz VGA timing signals, derive the 25.2 MHz pixel clock, and dump simulated frames directly to BMP images."
card:
  title: "**Raster Scanning, 640×480@60 Hz Counters & Test Patterns**"
  summary: "Build a 640×480@60 Hz raster timing engine, generate combinational colour bars and checkerboards, and render simulated frames to BMP."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0005-vga-raster-timing/` (`make -C apps/0005-vga-raster-timing clean all`)
- **Video reference**: [Episode 5: How a Screen Is Really Drawn: One Pixel at a Time, with Two Counters](https://www.youtube.com/watch?v=6d8R3dYR4KQ)
- **Simulation & waveforms**: [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/) and [Surfer Waveform Viewer](https://surfer-project.org/)
- **Course references**: [Lesson 4](0004-flip-flops-registers-fsm.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. How a Screen Is Drawn: One Pixel at a Time

In Part 1 we blinked six LEDs. Now we start Part 2: building the video card for our 6502 computer.

You might assume a display receives a whole grid of pixels at once, like an array in memory. In reality, even a modern 4K HDMI panel inherits the scan order of a 1950s cathode-ray tube (CRT) television. An electron gun swept left-to-right across a phosphor line, snapped back to the left edge during a brief pause, stepped down one row, and repeated until it reached the bottom—then paused again while flying back to the top-left corner.

That invisible retrace pause is why a **640×480** picture is actually an **800×525** timing grid:

```mermaid caption="Figure 5.1: 640×480@60 Hz frame geometry inside an 800×525 timing grid"
flowchart LR
  subgraph Line["Horizontal Scanline (800 Pixel Ticks)"]
    HV["Visible Pixels<br/>x: 0..639 (640)"] --> HF["Front Porch<br/>640..655 (16)"] --> HS["HSYNC Low<br/>656..751 (96)"] --> HB["Back Porch<br/>752..799 (48)"]
  end
  subgraph Frame["Vertical Frame (525 Lines)"]
    VV["Visible Lines<br/>y: 0..479 (480)"] --> VF["Front Porch<br/>480..489 (10)"] --> VS["VSYNC Low<br/>490..491 (2)"] --> VB["Back Porch<br/>492..524 (33)"]
  end
```

Every pixel tick (`x`, `y`) falls into one of four regions along each axis:

Table: Standard 640×480@60 Hz VGA Timing Intervals

| Region | Horizontal (`x` ticks) | Vertical (`y` lines) | Purpose |
| :--- | :--- | :--- | :--- |
| **Visible** | `0` .. `639` (`640`) | `0` .. `479` (`480`) | Active picture; RGB data carries colour |
| **Front Porch** | `640` .. `655` (`16`) | `480` .. `489` (`10`) | Black guard interval before sync pulse |
| **Sync Pulse** | `656` .. `751` (`96`) | `490` .. `491` (`2`) | **Active-low** `hsync` / `vsync` pulse (`0`) |
| **Back Porch** | `752` .. `799` (`48`) | `492` .. `524` (`33`) | Black settle interval before next active region |
| **Total** | `800` pixels/line | `525` lines/frame | `420,000` pixel ticks per frame |

Notice two things right away:
- Both `hsync` and `vsync` in standard 640×480 VGA are **active-low**: they sit at `1` almost all the time, dropping to `0` only inside the sync window (`x` in `656..751` for `hsync`, `y` in `490..491` for `vsync`).
- During the front porch, sync pulse, and back porch (collectively the **blanking interval**), RGB must stay strictly black (`0, 0, 0`) so monitors calibrating their black level never smear border colours across the screen.

## 2. Deriving the 25.2 MHz Pixel Clock

Multiply the total frame dimensions by 60 frames per second and an exact number falls straight out:

$$f_{\text{pixel}} = 800 \times 525 \times 60\text{ Hz} = 420{,}000 \times 60\text{ Hz} = 25{,}200{,}000\text{ Hz} = 25.2\text{ MHz}$$

Wait a moment—our Tang Nano 20K's onboard crystal ticks at **27.0 MHz**, not 25.2 MHz! If we drove a real HDMI monitor directly from 27 MHz, the frame rate would run at roughly $27{,}000{,}000 / 420{,}000 \approx 64.29\text{ Hz}$, which rejects or confuses picky displays. We will solve that clock mismatch cleanly in Lesson 6 using the FPGA's hardware PLL; today we build and exhaustively verify the raster engine and pattern generator first.

## 3. Nested 10-Bit Raster Counters (`raster.v`)

Since `800` and `525` are both larger than `511` ($2^9 - 1$) and smaller than `1024` ($2^{10}$), a pair of **10-bit** registers `x[9:0]` and `y[9:0]` covers the entire frame with room to spare.

### Block 1: Timing Constants & Nested Counters

```verilog caption="Nested X/Y pixel counters in raster.v"
`timescale 1ns / 1ps

module raster (
    input  wire       clk,
    input  wire       reset,
    output reg  [9:0] x = 10'd0,
    output reg  [9:0] y = 10'd0,
    output wire       visible,
    output wire       hsync,
    output wire       vsync,
    output wire       frame_end
);
    localparam [9:0] H_VISIBLE = 10'd640;
    localparam [9:0] H_FRONT   = 10'd16;
    localparam [9:0] H_SYNC    = 10'd96;
    localparam [9:0] H_BACK    = 10'd48;
    localparam [9:0] H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam [9:0] V_VISIBLE = 10'd480;
    localparam [9:0] V_FRONT   = 10'd10;
    localparam [9:0] V_SYNC    = 10'd2;
    localparam [9:0] V_BACK    = 10'd33;
    localparam [9:0] V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk) begin
        if (reset) begin
            x <= 10'd0;
            y <= 10'd0;
        end else if (x == H_TOTAL - 10'd1) begin
            x <= 10'd0;
            if (y == V_TOTAL - 10'd1) begin
                y <= 10'd0;
            end else begin
                y <= y + 10'd1;
            end
        end else begin
            x <= x + 10'd1;
        end
    end
```

- Just like nested `for` loops in software, `x` increments on every clock tick from `0` to `799` (`H_TOTAL - 1`).
- On the single tick where `x == 799`, `x` wraps back to `0` and `y` increments by `1`—unless `y` is also at `524` (`V_TOTAL - 1`), in which case both wrap to `(0, 0)` simultaneously.

### Block 2: Combinational Sync & Blanking Signals

```verilog caption="Purely combinational visible, sync, and frame_end wires"
    assign visible = (x < H_VISIBLE) && (y < V_VISIBLE);
    assign hsync = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));
    assign frame_end = (x == H_TOTAL - 10'd1) && (y == V_TOTAL - 10'd1);
endmodule
```

- Making `visible`, `hsync`, `vsync`, and `frame_end` combinational wires (`assign`) derived directly from `x` and `y` keeps every control signal locked in zero-skew phase with the current pixel coordinates{{sidenote:In Lesson 8, when we introduce synchronous Block RAM with a 1-clock read latency, we will deliberately delay <code>visible</code>, <code>hsync</code>, and <code>vsync</code> by one register tick so pixels and sync pulses stay aligned.}}.
- `frame_end` pulses `1` for a single clock tick at `(799, 524)`, acting just like the single-cycle `tick` enable pulse we built in [Lesson 4](0004-flip-flops-registers-fsm.md).

## 4. Memoryless Test Patterns (`pattern.v`) & Dumping `.bmp` Frames

Before we wire a frame buffer in RAM, we can paint crisp 640×480 graphics **purely from coordinates** with zero memory. `pattern.v` takes `(x, y, visible, mode)` and produces 24-bit RGB (`r`, `g`, `b`):

- **`mode == 0` (Colour Bars):** Eight vertical bands, `80` pixels wide each (`White`, `Yellow`, `Cyan`, `Green`, `Magenta`, `Red`, `Blue`, `Black`).
- **`mode == 1` (Checkerboard):** A `32×32`-pixel checkerboard computed with a single XOR gate (`x[5] ^ y[5]`—because bit 5 flips every $2^5 = 32$ pixels!) framed inside a 4-pixel bright red border.

### Block 1: Blanking Guard & Colour Bar Comparator Chain (`pattern.v`)

```verilog caption="apps/0005-vga-raster-timing/pattern.v"
`timescale 1ns / 1ps

module pattern (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       visible,
    input  wire       mode,
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b
);
    wire on_border  = (x < 10'd4) || (x >= 10'd636) || (y < 10'd4) || (y >= 10'd476);
    wire is_checker = x[5] ^ y[5];

    always @(*) begin
        if (!visible) begin
            r = 8'h00;
            g = 8'h00;
            b = 8'h00;
        end else if (mode == 1'b0) begin
            if (x < 10'd80) begin
                r = 8'hFF; g = 8'hFF; b = 8'hFF;
            end else if (x < 10'd160) begin
                r = 8'hFF; g = 8'hFF; b = 8'h00;
            end else if (x < 10'd240) begin
                r = 8'h00; g = 8'hFF; b = 8'hFF;
            end else if (x < 10'd320) begin
                r = 8'h00; g = 8'hFF; b = 8'h00;
            end else if (x < 10'd400) begin
                r = 8'hFF; g = 8'h00; b = 8'hFF;
            end else if (x < 10'd480) begin
                r = 8'hFF; g = 8'h00; b = 8'h00;
            end else if (x < 10'd560) begin
                r = 8'h00; g = 8'h00; b = 8'hFF;
            end else begin
                r = 8'h00; g = 8'h00; b = 8'h00;
            end
        end else begin
            if (on_border) begin
                r = 8'hFF; g = 8'h20; b = 8'h20;
            end else if (is_checker) begin
                r = 8'hFF; g = 8'hFF; b = 8'hFF;
            end else begin
                r = 8'h10; g = 8'h20; b = 8'h40;
            end
        end
    end
endmodule
```

- Notice we named the wire `is_checker` rather than `checker`! Under `iverilog -g2012`, `checker` is a reserved SystemVerilog keyword, so avoiding it keeps strict `-g2012 -Wall` builds warning- and error-free.
- Notice also how every `if / else` branch inside `always @(*)` assigns all three outputs (`r`, `g`, `b`). Leaving any branch unassigned would infer an unwanted combinational latch.

### Visualising Simulation Output as `.bmp` Files

Waveforms in Surfer are brilliant for verifying sync edges, yet staring at 307,200 RGB samples as hex waves won't tell you at a glance whether a checkerboard looks square. In `pattern_tb.v`, we use Verilog's `$fopen(..., "wb")` and `$fwrite(fd, "%c%c%c", b, g, r)` to write a real 54-byte uncompressed 24-bit Windows BMP header followed by bottom-up BGR pixel rows (`row = 479` down to `0`) into `build/bars.bmp` and `build/checker.bmp`—each `921,654` bytes (`54 + 640 × 480 × 3`). You can open both images directly in macOS Preview!

## 5. Wiring `top.v` for the Tang Nano 20K

Until we attach an HDMI serialiser in Lesson 7, `top.v` connects `raster` and `pattern` to the six onboard LEDs so we can verify real silicon synthesis, routing, and frame timing on the board:

- With `S2` released (`0`), `frame_end` steps a divider (`FRAME_DIV = 8`, overridden to `1` in `top_tb.v`) feeding a 6-bit binary `frame_count` on `led[5:0]`—ticking at roughly `64.29 / 8 ≈ 8` counts per second on the 27 MHz clock.
- Hold `S2` (`1`) and `led[5:0]` switches live to `{r[7], g[7], b[7], visible, ~hsync, ~vsync}` while `pattern` switches to checkerboard mode.
- Hold `S1` (`1`) to synchronously reset the raster coordinates and frame counter to `0`.

### Complete `top.v` Listing

```verilog caption="apps/0005-vga-raster-timing/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer FRAME_DIV = 8
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire       reset = s1;
    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    raster u_raster (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .frame_end(frame_end)
    );

    pattern u_pattern (
        .x(x),
        .y(y),
        .visible(visible),
        .mode(s2),
        .r(r),
        .g(g),
        .b(b)
    );

    reg [15:0] div_count   = 16'd0;
    reg [5:0]  frame_count = 6'd0;

    always @(posedge clk) begin
        if (reset) begin
            div_count   <= 16'd0;
            frame_count <= 6'd0;
        end else if (frame_end) begin
            if (div_count == FRAME_DIV - 1) begin
                div_count   <= 16'd0;
                frame_count <= frame_count + 6'd1;
            end else begin
                div_count <= div_count + 16'd1;
            end
        end
    end

    wire [5:0] display = s2 ? {r[7], g[7], b[7], visible, ~hsync, ~vsync} : frame_count;
    assign led = ~display;
endmodule
```

Running `make -C apps/0005-vga-raster-timing stats` shows `raster` standalone synthesises to **20 flip-flops** (`10 DFFR` for `x`, `10 DFFRE` for `y`), `56 ALU` cells, `20` LUTs (`LUT1`–`LUT4`), and `4` `MUX2_LUT*` cells; the full `top` design uses **42 flip-flops** (`10 DFFR`, `32 DFFRE`), `111 ALU` cells, `54` LUTs (`LUT1`–`LUT4`), and `23` `MUX2_LUT*` cells.

---

:::exercise id="ex-0005" title="Interactive Lab: Nested Raster Wraparound, Active-Low Sync & Blanking Guard" badge="Skill Practice • VGA Timing"
Complete the horizontal wrap condition, active-low `hsync` equation, and blanking guard below:

```verilog
if (x == {{blank:H_TOTAL - 10'd1||H_TOTAL - 1||799|Last pixel tick on the line|???|14}}) begin
    x <= 10'd0;
    y <= (y == V_TOTAL - 10'd1) ? 10'd0 : y + 10'd1;
end else begin
    x <= x + 10'd1;
end

assign hsync = {{blank:~|Invert for active-low sync|?|1}}((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));

if ({{blank:!visible||visible == 1'b0||~visible|Blanking interval check|???|8}}) begin
    r = 8'h00; g = 8'h00; b = 8'h00;
end
```

:::prompts
hint: "Compare `x` against `H_TOTAL - 10'd1`, invert the horizontal sync window with `~` for active-low polarity, and force RGB to black whenever `!visible`."
success: "Spot on! You have the exact 800×525 raster counter wrap and active-low blanking guard."
:::
:::

:::quiz id="quiz-0005" title="Retrieval Practice: VGA Raster Timing & Blanking" badge="3 Questions • Equal-Length Options"
- question: "Why does a 640×480@60 Hz VGA frame require 800×525 total pixel ticks instead of 640×480?"
  wrong_hint: "Consider what the display electronics and historic CRT beam need between visible lines and frames."
  options:
    - letter: "A"
      text: "Monitors require extra horizontal and vertical blanking ticks for porches and sync pulses."
      correct: true
      explain: "Correct: front porch, sync pulse, and back porch intervals surround the 640×480 visible window on every line and frame."
    - letter: "B"
      text: "Gowin block memory requires every scanline width to be padded to 800 bytes."
      correct: false
      explain: "Horizontal and vertical blanking intervals come from the VESA/VGA timing standard, not FPGA memory alignment."
    - letter: "C"
      text: "HDMI cables reserve the outer 160 columns exclusively for 24-bit audio sample packets."
      correct: false
      explain: "Even pure analogue VGA monitors without audio require the 800×525 blanking porches and sync pulses."
    - letter: "D"
      text: "Verilog 10-bit registers overflow unless they count up to exactly 800 clock ticks."
      correct: false
      explain: "A 10-bit unsigned register overflows at 1024; 800 and 525 are VGA standard totals."
- question: "During which horizontal `x` range must `hsync` drop low (`0`) in standard 640×480@60 Hz timing?"
  wrong_hint: "Add the 640 visible pixels and the 16-pixel front porch before starting the 96-pixel pulse."
  options:
    - letter: "A"
      text: "Between tick 0 and tick 95 before any visible pixels appear on screen."
      correct: false
      explain: "Ticks `0..639` are the visible picture; `hsync` occurs after the visible region and front porch."
    - letter: "B"
      text: "Between tick 640 and tick 655 immediately after the last visible pixel ends."
      correct: false
      explain: "Ticks `640..655` are the 16-pixel front porch, where `hsync` stays high (`1`)."
    - letter: "C"
      text: "Between tick 656 and tick 751 right after the 16-pixel front porch finishes."
      correct: true
      explain: "Correct: `640 + 16 = 656` starts the 96-pixel active-low `hsync` pulse, ending at `751` (`656 + 96 - 1`)."
    - letter: "D"
      text: "Between tick 752 and tick 799 right before the next horizontal scanline begins."
      correct: false
      explain: "Ticks `752..799` are the 48-pixel back porch, after `hsync` has already returned high."
- question: "Why must `pattern.v` force `r`, `g`, and `b` to `8'h00` whenever `visible` is low?"
  wrong_hint: "Think about how a display interprets pixel voltages or RGB values during blanking."
  options:
    - letter: "A"
      text: "Because Yosys refuses to route colour wires unless every blanking cycle emits zeroes."
      correct: false
      explain: "Yosys does not enforce VGA blanking rules; real monitors rely on zeroed RGB during blanking."
    - letter: "B"
      text: "Because displays calibrate black levels during blanking and reject any non-black retrace signals."
      correct: true
      explain: "Correct: monitors expect black (`0, 0, 0`) throughout porches and sync pulses to establish a clean black reference."
    - letter: "C"
      text: "Because 10-bit raster counters reset automatically whenever any red colour bit goes high."
      correct: false
      explain: "The raster counters depend only on `clk`, `reset`, and `H_TOTAL`/`V_TOTAL`."
    - letter: "D"
      text: "Because Icarus Verilog cannot write uncompressed BMP pixels if blanking outputs stay nonzero."
      correct: false
      explain: "The BMP testbench only records visible pixels; real displays require black blanking."
:::

:::verify id="verify-0005" title="Verification Lab: Full-Frame Simulation, BMP Render & Tang Nano 20K Test" badge="Simulation & Hardware Gate"
Simulate a full 420,000-cycle frame, inspect the generated BMP images and `raster.vcd` waveform, verify synthesis stats, and flash the Tang Nano 20K:

```bash caption="Simulate, render BMPs, check waveforms, and flash Lesson 5"
make -C apps/0005-vga-raster-timing clean all
make -C apps/0005-vga-raster-timing stats
make -C apps/0005-vga-raster-timing bmp
make -C apps/0005-vga-raster-timing wave
make -C apps/0005-vga-raster-timing flash
```

- [ ] `make -C apps/0005-vga-raster-timing clean all` passes with zero `iverilog -Wall` warnings and prints `PASS:` for `raster` (`307200` visible pixels, `50400` `hsync` ticks, `1600` `vsync` ticks), `pattern`, and `top`.
- [ ] `make bmp` opens `build/bars.bmp` (8 vertical colour bars) and `build/checker.bmp` (32×32 checkerboard inside a 4-pixel red border), each `921,654` bytes.
- [ ] `make stats` reports `20` flip-flops (`10 DFFR`, `10 DFFRE`) and `56 ALU` cells for `raster`, and `42` flip-flops (`10 DFFR`, `32 DFFRE`) for `top`.
- [ ] In Surfer (`make wave`), confirm `x` resets to `0` at `799 -> 0` while `y` increments `0 -> 1`, and `hsync` pulses low from `x = 656` through `x = 751`.
- [ ] On the flashed Tang Nano 20K, `led[5:0]` counts frames in binary (`~8` ticks/s); holding `S1` resets the counter, and holding `S2` switches the LEDs to live pattern/sync signals.
:::

:::teacher-prompt title="Next Up: Lesson 6 (Turning 27 MHz into 25.2 MHz with a PLL)"
Once you have opened `bars.bmp` and `checker.bmp` in Preview and inspected `hsync` in Surfer, ask any questions about porches, active-low sync, or BMP frame dumps—or say **"ready for Lesson 6"** to build the Gowin `rPLL` + `CLKDIV` clock generator that turns our 27 MHz crystal into an exact 25.2 MHz pixel clock and 126 MHz HDMI serial clock.
:::
