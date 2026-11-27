---
title: "320×200 16-Colour Frame Buffer & Block RAM Latency"
page_title: "Lesson 0008: 320×200 16-Colour Frame Buffer & Block RAM Latency — Build Your Own 6502"
nav_id: "lesson-0008"
badge: "Lesson 0008 • Video Memory & Graphics"
subtitle: "Replace combinational test patterns with a Commodore 64-style 320×200 16-colour frame buffer in Gowin Block RAM, align 1-cycle memory read latency, and render retro pixel art over HDMI."
card:
  title: "**320×200 16-Colour Frame Buffer & Block RAM Latency**"
  summary: "Build a 320×200 16-colour C64-style frame buffer in 5 Gowin Block RAMs, align 1-tick BRAM latency, and display a retro boot screen over HDMI."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0008-video-card-framebuffer/` (`make -C apps/0008-video-card-framebuffer clean all`)
- **Video reference**: [Episode 8: Our 6502 Computer Gets a Video Card: 320x200, 16 Colors](https://www.youtube.com/watch?v=DH__9-V3owI)
- **Hardware & toolchain**: [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula) and [Sipeed Tang Nano 20K Docs](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- **Course references**: [Lesson 5](0005-vga-raster-timing.md), [Lesson 7](0007-hdmi-tmds-serialization.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. The Video RAM Budget: Why 320×200 with 8×8 Colour Cells

In [Lesson 7](0007-hdmi-tmds-serialization.md), our HDMI transmitter sent 640×480×24-bit pixels computed on the fly from `x` and `y`. If we tried to store an uncompressed 640×480×24-bit frame buffer in FPGA SRAM, we would need:

$$640 \times 480 \times 3\text{ bytes} = 921{,}600\text{ bytes} \approx 900\text{ KB}$$

Our Tang Nano 20K's `GW2AR-18` FPGA only contains **46 Block RAM (`BSRAM`) blocks** of 18 Kbits each (about `92` KB usable as byte-wide RAM)—and in Part 3 our 6502 CPU will need 24 of those blocks just for 16 KB ROM and 32 KB RAM!

Instead, we borrow the brilliant memory compression trick used by classic 8-bit home computers like the **Commodore 64** and **ZX Spectrum**:

1. **Halve both dimensions (`320×200`) and double 2×2 onto `640×480`:**
   - $320 \times 2 = 640$ pixels wide (exact fit!).
   - $200 \times 2 = 400$ lines tall, centred vertically inside `480` lines—leaving crisp **40-line top (`y: 0..39`) and bottom (`y: 440..479`) borders**!
2. **Split pixel bits from colour attributes:**
   - **Bitmap RAM (`bitmap_mem`, `8,000` bytes):** `1` bit per pixel (`320 × 200 / 8 = 8,000` bytes, `40` bytes per row × `200` rows, MSB = leftmost pixel).
   - **Colour Attribute RAM (`color_mem`, `1,000` bytes):** Divide the `320×200` screen into a **40 × 25 grid of `8×8`-pixel cells**. Each cell gets `1` byte storing two 4-bit C64 palette indices: upper nibble `[7:4]` = **ink** (when bitmap bit is `1`) and lower nibble `[3:0]` = **paper** (when bitmap bit is `0`).

Total video memory drops by **more than 100×**, from `921,600` bytes down to just **`9,000` bytes**—fitting inside **5 Gowin Block RAM blocks** with zero external SDRAM!

:::callout-warn title="Why 'Colour Clash' Exists in Retro 8-Bit Art"
Because every `8×8` pixel cell shares just two palette indices (**ink** and **paper**), trying to draw a third colour inside the same `8×8` tile overwrites one of the two cell colours. On our generated `frame.bmp` test image, the right half of the bottom attribute grid intentionally shows that exact **colour clash** trade-off in action.
:::

## 2. Shift-and-Add Addressing & The C64 Palette (`palette.v`)

Looking up a pixel at `(vx, vy)` inside `320×200` requires multiplying a row index by `40` (`40` bytes per bitmap row, `40` cells per attribute row). Multiplying by a constant `40` doesn't need a hardware multiplier at all because $40 = 32 + 8$:

$$\text{row} \times 40 = (\text{row} \ll 5) + (\text{row} \ll 3)$$

Two wire shifts and one small adder give us exact `×40` addresses in a single cycle:
- `bitmap_addr = (vy << 5) + (vy << 3) + vx[8:3]` (`0..7999`, 13 bits)
- `color_addr = (vy[7:3] << 5) + (vy[7:3] << 3) + vx[8:3]` (`0..999`, 10 bits, since `vy[7:3] = vy / 8` gives cell row `0..24`)

Every pixel bit picks either `color_byte[7:4]` (ink) or `color_byte[3:0]` (paper), and `palette.v` translates that 4-bit index (`0..15`) into 24-bit RGB using the classic Commodore 64 palette:

### Complete `palette.v` Module

```verilog caption="apps/0008-video-card-framebuffer/palette.v"
`timescale 1ns / 1ps

module palette (
    input  wire [3:0] index,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);
    // Classic Commodore 64 16-colour palette
    function [23:0] lookup(input [3:0] idx);
        case (idx)
            4'd0:  lookup = 24'h000000; // Black
            4'd1:  lookup = 24'hFFFFFF; // White
            4'd2:  lookup = 24'h880000; // Red
            4'd3:  lookup = 24'hAAFFEE; // Cyan
            4'd4:  lookup = 24'hCC44CC; // Purple
            4'd5:  lookup = 24'h00CC55; // Green
            4'd6:  lookup = 24'h0000AA; // Blue
            4'd7:  lookup = 24'hEEEE77; // Yellow
            4'd8:  lookup = 24'hDD8855; // Orange
            4'd9:  lookup = 24'h664400; // Brown
            4'd10: lookup = 24'hFF7777; // Light Red
            4'd11: lookup = 24'h333333; // Dark Grey
            4'd12: lookup = 24'h777777; // Medium Grey
            4'd13: lookup = 24'hAAFF66; // Light Green
            4'd14: lookup = 24'h0088FF; // Light Blue
            4'd15: lookup = 24'hBBBBBB; // Light Grey
        endcase
    endfunction

    assign {r, g, b} = lookup(index);
endmodule
```

- Using a Verilog `function` wired through `assign {r, g, b} = lookup(index);` ensures the lookup table evaluates immediately at simulation time `0`—even when `index` starts equal to `border_color` before the first transition.

## 3. Inferring Block RAM & Compensating for 1-Tick Pipeline Latency (`video.v`)

In `video.v`, we declare `bitmap_mem [0:7999]` and `color_mem [0:999]`, preload them at synthesis time using `$readmemh("bitmap.mem", bitmap_mem)` and `$readmemh("color.mem", color_mem)` (generated by `gen_image.py`{{sidenote:Notice we use <code>.mem</code> rather than <code>.hex</code> because <code>.gitignore</code> ignores compiled <code>apps/*/*.hex</code> binaries; <code>$readmemh</code> reads <code>.mem</code> text files identically and Git tracks our splash screen image cleanly.}}), and read them inside `always @(posedge clk)`:

```verilog
bitmap_byte <= bitmap_mem[bitmap_addr];
color_byte  <= color_mem[color_addr];
```

That synchronous read is crucial: **Gowin Block RAM (`SP` / `SPX9` primitives) is synchronous**, so `bitmap_byte` and `color_byte` do **not** appear until **1 clock tick after** `x` and `y` present `bitmap_addr` and `color_addr`.

If we drove `hdmi_tx` with the *undelayed* `visible`, `hsync`, `vsync`, and `vx[2:0]`, every pixel would be shifted right by 1 column (`x = 639`'s pixel leaking into blanking, and `x = 0` showing stale data)! Instead, we delay all five companion signals by **exactly 1 clock cycle** inside the same `always @(posedge clk)` block:

```mermaid caption="Figure 8.1: 1-tick pipeline alignment matching synchronous Block RAM latency"
flowchart LR
  R["raster<br/>(x, y, visible, hsync, vsync)"] -->|"Address @ Cycle N"| BRAM["Block RAM (SP / SPX9)<br/>bitmap_mem + color_mem"]
  R -->|"Delayed 1 Tick @ Cycle N"| DLY["1-Tick Registers<br/>visible_out, hsync_out, vsync_out,<br/>in_image_d1, bit_sel_d1"]
  BRAM -->|"Data Ready @ Cycle N+1"| MUX["Pixel Bit + Ink/Paper Mux<br/>+ palette LUT"]
  DLY -->|"Aligned Controls @ Cycle N+1"| MUX
  MUX -->|"Aligned RGB + Syncs"| HDMI["hdmi_tx"]
```

### Block 1: Coordinate Scaling & Clamped Block RAM Addresses (`video.v`)

```verilog caption="2x2 coordinate scaling and shift-and-add addressing in video.v"
    // 320x200 scaled 2x2 inside 640x480 leaves 40-line top and bottom borders
    wire       in_image = visible && (y >= 10'd40) && (y < 10'd440);
    wire [8:0] vx       = x[9:1];
    wire [9:0] vy_full  = y - 10'd40;
    wire [7:0] vy       = vy_full[8:1];

    // Shift-and-add *40 addressing: n*40 = (n << 5) + (n << 3)
    wire [12:0] bitmap_addr = in_image
        ? (({5'd0, vy} << 5) + ({5'd0, vy} << 3) + {7'd0, vx[8:3]})
        : 13'd0;
    wire [9:0] color_addr = in_image
        ? (({5'd0, vy[7:3]} << 5) + ({5'd0, vy[7:3]} << 3) + {4'd0, vx[8:3]})
        : 10'd0;
```

- Clamping `bitmap_addr` and `color_addr` to `0` when `!in_image` prevents out-of-range array reads (`8'hXX`) during the 40-line borders and vertical blanking porches.

### Block 2: Synchronous Block RAM & 1-Tick Alignment (`video.v`)

```verilog caption="Synchronous Block RAM reads and 1-cycle control delay in video.v"
    // Synchronous Block RAM (infers 5 Gowin SP primitives)
    reg [7:0] bitmap_mem [0:7999];
    reg [7:0] color_mem  [0:999];

    initial begin
        $readmemh("bitmap.mem", bitmap_mem);
        $readmemh("color.mem", color_mem);
    end

    reg [7:0] bitmap_byte = 8'd0;
    reg [7:0] color_byte  = 8'd0;
    reg       in_image_d1 = 1'b0;
    reg [2:0] bit_sel_d1  = 3'd0;

    // 1-tick pipeline alignment matching synchronous Block RAM read latency
    always @(posedge clk) begin
        bitmap_byte <= bitmap_mem[bitmap_addr];
        color_byte  <= color_mem[color_addr];
        visible_out <= visible;
        hsync_out   <= hsync;
        vsync_out   <= vsync;
        in_image_d1 <= in_image;
        bit_sel_d1  <= 3'd7 - vx[2:0];
    end

    wire       pixel_bit = bitmap_byte[bit_sel_d1];
    wire [3:0] color_idx = in_image_d1
        ? (pixel_bit ? color_byte[7:4] : color_byte[3:0])
        : border_color;

    wire [7:0] pal_r;
    wire [7:0] pal_g;
    wire [7:0] pal_b;

    palette u_palette (
        .index(color_idx),
        .r(pal_r),
        .g(pal_g),
        .b(pal_b)
    );

    assign r = visible_out ? pal_r : 8'd0;
    assign g = visible_out ? pal_g : 8'd0;
    assign b = visible_out ? pal_b : 8'd0;
```

- Notice `bit_sel_d1 <= 3'd7 - vx[2:0];` reverses the bit index because pixel `0` in each byte sits in the MSB (`bit 7`), matching standard screen-order bitmaps.

## 4. Wiring the Complete Video Card (`top.v`)

`top.v` wires `raster` into `video`, passes `video`'s 1-tick-delayed `vid_visible`, `vid_hsync`, and `vid_vsync` alongside `(r, g, b)` into `hdmi_tx`, and uses synchronised `S2` to toggle the 40-line border between C64 Light Blue (`4'd14`) and Black (`4'd0`).

### Complete `top.v` Listing

```verilog caption="apps/0008-video-card-framebuffer/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer FRAME_DIV = 12
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    wire clk_serial;
    wire clk_pixel;
    wire pll_lock;

    video_clock u_vclk (
        .clk_27m(clk),
        .clk_serial(clk_serial),
        .clk_pixel(clk_pixel),
        .locked(pll_lock)
    );

    reg [1:0] rst_sync    = 2'b11;
    reg [1:0] border_sync = 2'b00;
    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_sync    <= 2'b11;
            border_sync <= 2'b00;
        end else begin
            rst_sync    <= {rst_sync[0], s1};
            border_sync <= {border_sync[0], s2};
        end
    end
    wire reset_pix    = rst_sync[1];
    wire [3:0] border = border_sync[1] ? 4'd0 : 4'd14;

    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;

    raster u_raster (
        .clk(clk_pixel),
        .reset(reset_pix),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .frame_end(frame_end)
    );

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire       vid_visible;
    wire       vid_hsync;
    wire       vid_vsync;

    video u_video (
        .clk(clk_pixel),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .border_color(border),
        .r(r),
        .g(g),
        .b(b),
        .visible_out(vid_visible),
        .hsync_out(vid_hsync),
        .vsync_out(vid_vsync)
    );

    hdmi_tx u_hdmi (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .reset(reset_pix),
        .r(r),
        .g(g),
        .b(b),
        .visible(vid_visible),
        .hsync(vid_hsync),
        .vsync(vid_vsync),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p),
        .tmds_d_n(tmds_d_n)
    );

    reg [7:0] div_count   = 8'd0;
    reg [4:0] frame_count = 5'd0;
    always @(posedge clk_pixel) begin
        if (reset_pix) begin
            div_count   <= 8'd0;
            frame_count <= 5'd0;
        end else if (frame_end) begin
            if (div_count == FRAME_DIV - 1) begin
                div_count   <= 8'd0;
                frame_count <= frame_count + 5'd1;
            end else begin
                div_count <= div_count + 8'd1;
            end
        end
    end

    assign led = ~{pll_lock, frame_count};
endmodule
```

Running `make -C apps/0008-video-card-framebuffer stats` confirms Yosys infers **5 dedicated Gowin Block RAM blocks** (`4 SP` blocks for `bitmap_mem` and `1 SPX9` block for `color_mem`), while the full `top` video card consumes **1 `rPLL`**, **1 `CLKDIV`**, **4 `OSER10`**, **4 `TLVDS_OBUF`**, **4 `SP`**, **1 `SPX9`**, **89 flip-flops** (`25 DFF`, `2 DFFC`, `2 DFFP`, `35 DFFR`, `23 DFFRE`, `2 DFFS`), `160 ALU` cells, `313` LUTs, and `65` `MUX2_LUT*` cells—leaving 41 of the FPGA's 46 Block RAMs free for our 6502 CPU!

---

:::exercise id="ex-0008" title="Interactive Lab: Shift-and-Add Addressing & 1-Tick BRAM Pipeline Alignment" badge="Skill Practice • Video Memory"
Complete the vertical `×40` bitmap address shift-and-add expression, the 1-tick pipeline alignment registers, and the ink/paper colour nibble selection:

```verilog
wire [12:0] bitmap_addr = in_image
    ? (({5'd0, vy} << {{blank:5|Multiply vy by 32|?|1}}) + ({5'd0, vy} << {{blank:3|Multiply vy by 8|?|1}}) + {7'd0, vx[8:3]})
    : 13'd0;

always @(posedge clk) begin
    bitmap_byte <= bitmap_mem[bitmap_addr];
    color_byte  <= color_mem[color_addr];
    visible_out <= {{blank:visible|Delay visible by 1 clock|???????|7}};
    hsync_out   <= hsync;
    vsync_out   <= vsync;
    in_image_d1 <= in_image;
    bit_sel_d1  <= 3'd7 - vx[2:0];
end

wire [3:0] color_idx = in_image_d1
    ? (pixel_bit ? {{blank:color_byte[7:4]|Upper nibble ink colour|???????????????|15}} : color_byte[3:0])
    : border_color;
```

:::prompts
hint: "Since $40 = 32 + 8 = 2^5 + 2^3$, shift `vy` left by `5` and `3`; delay `visible` into `visible_out`; and select `color_byte[7:4]` for foreground ink."
success: "Clean Block RAM pipeline! You have the exact memory addressing and 1-cycle alignment behind our 320×200 16-colour video card."
:::
:::

:::quiz id="quiz-0008" title="Retrieval Practice: Frame Buffer Compression & Block RAM Timing" badge="3 Questions • Equal-Length Options"
- question: "Why does our video card store 320×200 bitmap and attribute memory instead of a full 640×480 24-bit RGB frame buffer?"
  wrong_hint: "Compare 921,600 bytes against the Tang Nano 20K's total internal Block RAM capacity."
  options:
    - letter: "A"
      text: "Because raw 640x480 24-bit RGB needs 921.6 KB, far exceeding our 92 KB BRAM."
      correct: true
      explain: "Correct: splitting 320×200 1-bpp bitmap (8,000 B) and 40×25 attributes (1,000 B) shrinks VRAM to 9,000 B across just 5 Block RAMs."
    - letter: "B"
      text: "Because 25.2 MHz TMDS serialisers only support up to sixteen colours per horizontal scanline."
      correct: false
      explain: "TMDS carries full 24-bit RGB on the wire; the 16-colour palette is a VRAM compression choice."
    - letter: "C"
      text: "Because the 6502 address bus cannot fetch any pixels above vertical row two hundred."
      correct: false
      explain: "The raster generator happily scans all 480 visible lines; `video.v` scales `200` stored rows 2×2 inside `480` lines."
    - letter: "D"
      text: "Because Yosys refuses to synthesise Verilog arrays larger than exactly one thousand total entries."
      correct: false
      explain: "`bitmap_mem` itself has 8,000 entries and synthesises cleanly into 4 `SP` Block RAMs."
- question: "Why must `video.v` delay `visible`, `hsync`, `vsync`, `in_image`, and `bit_sel` by 1 clock cycle?"
  wrong_hint: "Consider when `bitmap_byte` and `color_byte` become valid after `bitmap_addr` changes."
  options:
    - letter: "A"
      text: "Because synchronous Block RAM outputs data one clock tick after the address is presented."
      correct: true
      explain: "Correct: synchronous Gowin `SP` Block RAM registers the read on `posedge clk`, so companion controls must wait 1 tick to stay aligned."
    - letter: "B"
      text: "Because OSER10 serialisers ignore every odd pixel coordinate unless hsync arrives one cycle early."
      correct: false
      explain: "`OSER10` serialises whatever 10-bit symbol `tmds_encoder` feeds it every pixel clock."
    - letter: "C"
      text: "Because the Commodore 64 palette ROM needs two clock cycles to mix RGB channels."
      correct: false
      explain: "`palette.v` is purely combinational; only the Block RAM reads take 1 clock cycle."
    - letter: "D"
      text: "Because 640x480 horizontal porches shrink by one pixel whenever Block RAM blocks are enabled."
      correct: false
      explain: "The VGA porch widths remain fixed at 16 and 48 ticks; delaying all outputs together preserves alignment."
- question: "What causes 'colour clash' in this Commodore 64-style 320×200 16-colour video mode?"
  wrong_hint: "Look at how many palette indices each 8×8 character cell stores in `color_mem`."
  options:
    - letter: "A"
      text: "The TMDS encoder runs out of DC balance whenever adjacent pixels use bright colours."
      correct: false
      explain: "TMDS maintains DC balance on any pixel sequence independently of the attribute grid."
    - letter: "B"
      text: "Every 8x8 pixel cell shares just two palette colours, one ink and one paper."
      correct: true
      explain: "Correct: each 8×8 cell maps to 1 byte in `color_mem`, restricting all 64 pixels in that cell to 1 foreground ink and 1 background paper."
    - letter: "C"
      text: "Gowin SP memory blocks corrupt nibbles whenever blue and red share the same row."
      correct: false
      explain: "Block RAM stores arbitrary bytes reliably; the 2-colour limit is purely architectural."
    - letter: "D"
      text: "The 2x2 pixel doubler averages two neighbouring vertical scanlines together into blended third colours."
      correct: false
      explain: "The 2×2 scaler duplicates pixels identically without blending."
:::

:::verify id="verify-0008" title="Verification Lab: Block RAM Inference, BMP Frame Check & HDMI Video Card" badge="Simulation & Hardware Gate"
Verify all 16 C64 palette entries, simulate a full 800×525 frame into `build/frame.bmp`, inspect `video.vcd` and Yosys `SP`/`SPX9` Block RAM stats, and flash the Tang Nano 20K:

```bash caption="Simulate, inspect BMP/stats, and flash Lesson 8"
make -C apps/0008-video-card-framebuffer clean all
make -C apps/0008-video-card-framebuffer stats
make -C apps/0008-video-card-framebuffer bmp
make -C apps/0008-video-card-framebuffer wave
make -C apps/0008-video-card-framebuffer flash
```

- [ ] `make -C apps/0008-video-card-framebuffer clean all` passes with zero `iverilog -Wall` warnings and prints `PASS:` for `palette`, `video` (1-tick alignment + `build/frame.bmp`), and `top`.
- [ ] `make bmp` opens `build/frame.bmp` (`921,654` bytes) showing the `6502 GATE BY GATE` splash screen, 16 numbered C64 colour swatches (`0`–`F`), the 8×8 attribute grid (including the colour-clash region), and crisp 40-line Light Blue borders.
- [ ] `make stats` confirms Yosys inferred **5 Block RAMs** (`4 SP` + `1 SPX9`) in both `video` and `top`, plus `1 rPLL`, `1 CLKDIV`, `4 OSER10`, `4 TLVDS_OBUF`, and `89` flip-flops in `top`.
- [ ] In Surfer (`make wave`), confirm `visible_out`, `hsync_out`, and `vsync_out` lag `raster`'s signals by exactly 1 `clk` cycle alongside `bitmap_byte` and `color_byte`.
- [ ] On a physical HDMI monitor connected to the Tang Nano 20K, the 320×200 16-colour splash screen renders sharply; holding `S2` toggles the border between Light Blue (`14`) and Black (`0`).
:::

:::teacher-prompt title="Part 2 Complete — Preview Lesson 9 (Our First 6502 Program, Assembled by Hand)"
Congratulations—you have wrapped up **Part 2: Video Architecture & Graphics Pipeline** with a working 320×200 16-colour HDMI video card! Ask any questions about Block RAM inference, 1-tick pipeline alignment, or `gen_image.py`—or say **"ready for Lesson 9"** to kick off Part 3 by mapping out the 6502's registers, memory map, and hand-assembling your first 11-byte machine-code program.
:::
