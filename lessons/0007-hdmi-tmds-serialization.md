---
title: "HDMI/DVI TMDS Encoding, OSER10 & Monitor Output"
page_title: "Lesson 0007: HDMI/DVI TMDS Encoding, OSER10 & Monitor Output — Build Your Own 6502"
nav_id: "lesson-0007"
badge: "Lesson 0007 • Video Output"
subtitle: "Encode 8-bit RGB and sync pulses into DC-balanced 10-bit TMDS symbols, serialise them at 252 Mbps per lane using OSER10 and TLVDS_OBUF, and put a live picture on a physical HDMI monitor."
card:
  title: "**HDMI/DVI TMDS Encoding, OSER10 & Monitor Output**"
  summary: "Implement DVI/HDMI TMDS 8b/10b encoding, verify lossless round-trips and DC balance, and drive a real HDMI monitor at 640×480@60 Hz."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0007-hdmi-tmds-serialization/` (`make -C apps/0007-hdmi-tmds-serialization clean all`)
- **Video reference**: [Episode 7: How HDMI Really Works: I Sent a Picture from an FPGA to a Real Monitor](https://www.youtube.com/watch?v=bCDtCYCuRQ8)
- **Hardware docs**: [Sipeed Tang Nano 20K Docs](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html) and [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula)
- **Course references**: [Lesson 5](0005-vga-raster-timing.md), [Lesson 6](0006-pll-pixel-clock.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. The DVI-Over-HDMI Physical Layer

Inside an HDMI cable, there are **no** separate `hsync`, `vsync`, `r[7:0]`, `g[7:0]`, or `b[7:0]` wires. Instead, every HDMI monitor happily accepts backwards-compatible **DVI-D video** carried over just **four differential pairs**:

Table: Tang Nano 20K Onboard HDMI Differential Pinout (`GW2AR-LV18QN88C8/I7`)

| TMDS Lane | Carries (Active) | Carries (Blanking) | Positive Pin (`_p`) | Negative Pin (`_n`) |
| :--- | :--- | :--- | :--- | :--- |
| **Clock** | `25.2` MHz `10'b0000011111` | `25.2` MHz `10'b0000011111` | `33` | `34` |
| **Data 0 (Blue)** | `b[7:0]` (encoded 10-bit) | `{vsync, hsync}` control token | `35` | `36` |
| **Data 1 (Green)** | `g[7:0]` (encoded 10-bit) | `2'b00` control token | `37` | `38` |
| **Data 2 (Red)** | `r[7:0]` (encoded 10-bit) | `2'b00` control token | `39` | `40` |

Why **differential pairs** (`_p` and `_n`)? At `252 Mbps` per lane (`10` bits × `25.2` MHz), a single wire referenced to ground would radiate interference and pick up noise along a 2-metre cable. Driving equal and opposite currents down a twisted pair (`TLVDS_OBUF`) means the receiver measures $V_p - V_n$, cancelling common-mode noise cleanly.

```mermaid caption="Figure 7.1: Complete 640×480@60 Hz HDMI transmit pipeline"
flowchart LR
  CLK["video_clock<br/>25.2 MHz + 126 MHz"] --> RAST["raster + pattern<br/>(x, y, visible, RGB)"]
  RAST --> ENC["3× tmds_encoder<br/>(8b/10b + sync tokens)"]
  ENC -->|"10-bit words @ 25.2 MHz"| OSER["4× OSER10<br/>(126 MHz DDR = 252 Mbps)"]
  OSER --> LVDS["4× TLVDS_OBUF<br/>(Pins 33..40)"]
  LVDS --> HDMI["Physical HDMI Monitor"]
```

## 2. How TMDS 8b/10b Encoding Works (`tmds_encoder.v`)

If you sent raw `8'b01010101` down a high-speed cable, the wire would flip 7 times per byte; if you sent solid white (`8'hFF`) across an entire scanline, the wire would stay stuck high for thousands of bits, charging up the AC-coupled receiver capacitors until bit slicing collapsed.

**Transition-Minimized Differential Signaling (TMDS)** solves both problems in two deterministic stages by expanding 8-bit pixels into **10-bit symbols**:

1. **Stage 1 — Transition Minimisation (`q_m[8:0]`):**
   Count the `1`s in `data[7:0]` (`n1_d`). Pick whichever chained operation—`XOR` (`q_m[8] = 1`) or `XNOR` (`q_m[8] = 0`)—produces fewer transitions between adjacent bits. Because chained XOR/XNOR is completely reversible, the monitor recovers the original 8 bits with zero loss.
2. **Stage 2 — DC Balance (`bias` + bit `9`):**
   Keep a signed running disparity counter `bias` tracking cumulative `(ones - zeros)` sent on the wire. If `bias` is drifting positive (`> 0`) and the next word has more ones than zeros (`n1_qm > 4`), invert `q_m[7:0]` and set bit `9 = 1` to pull `bias` back toward zero!
3. **Blanking Control Tokens (`!visible`):**
   During blanking, reset `bias <= 0` and emit one of four reserved 10-bit **control tokens** (`10'b1101010100`, `10'b0010101011`, `10'b0101010100`, `10'b1010101011`). Each control token has `7` or `8` transitions—intentionally *high* transition density so the monitor's receiver immediately distinguishes blanking control periods from transition-minimised pixel data (`<= 5` transitions){{sidenote:Wait—does 10'b1101010100 have zero DC bias? Not quite individually, yet the four tokens average out while sync edges carry exact timing across every blanking pause.}}.

### Block 1: Stage 1 Transition Minimisation (`tmds_encoder.v`)

```verilog caption="Stage 1 XOR/XNOR encoding in tmds_encoder.v"
    // Stage 1: transition minimisation (XOR vs XNOR)
    wire [3:0] n1_d = data[0] + data[1] + data[2] + data[3] +
                      data[4] + data[5] + data[6] + data[7];
    wire use_xnor = (n1_d > 4'd4) || ((n1_d == 4'd4) && (data[0] == 1'b0));

    wire [8:0] q_m;
    assign q_m[0] = data[0];
    assign q_m[1] = use_xnor ? ~(q_m[0] ^ data[1]) : (q_m[0] ^ data[1]);
    assign q_m[2] = use_xnor ? ~(q_m[1] ^ data[2]) : (q_m[1] ^ data[2]);
    assign q_m[3] = use_xnor ? ~(q_m[2] ^ data[3]) : (q_m[2] ^ data[3]);
    assign q_m[4] = use_xnor ? ~(q_m[3] ^ data[4]) : (q_m[3] ^ data[4]);
    assign q_m[5] = use_xnor ? ~(q_m[4] ^ data[5]) : (q_m[4] ^ data[5]);
    assign q_m[6] = use_xnor ? ~(q_m[5] ^ data[6]) : (q_m[5] ^ data[6]);
    assign q_m[7] = use_xnor ? ~(q_m[6] ^ data[7]) : (q_m[6] ^ data[7]);
    assign q_m[8] = ~use_xnor;
```

- Notice `data[0] + ... + data[7]` sums eight 1-bit signals into a 4-bit popcount (`0..8`) purely combinationally.

### Block 2: Stage 2 Running Disparity & Control Tokens

```verilog caption="Stage 2 DC balancing and blanking control symbols in tmds_encoder.v"
    // Stage 2: DC balance using running disparity (N_1 - N_0)
    wire [3:0] n1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                       q_m[4] + q_m[5] + q_m[6] + q_m[7];
    wire [3:0] n0_qm = 4'd8 - n1_qm;
    wire signed [4:0] diff = $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});

    reg signed [4:0] bias = 5'sd0;

    always @(posedge clk) begin
        if (reset || !visible) begin
            bias <= 5'sd0;
            case (ctrl)
                2'b00: tmds <= 10'b1101010100;
                2'b01: tmds <= 10'b0010101011;
                2'b10: tmds <= 10'b0101010100;
                2'b11: tmds <= 10'b1010101011;
            endcase
        end else if ((bias == 5'sd0) || (n1_qm == 4'd4)) begin
            tmds <= {~q_m[8], q_m[8], (q_m[8] ? q_m[7:0] : ~q_m[7:0])};
            if (q_m[8] == 1'b0) begin
                bias <= bias - diff;
            end else begin
                bias <= bias + diff;
            end
        end else if (((bias > 5'sd0) && (n1_qm > 4'd4)) ||
                     ((bias < 5'sd0) && (n1_qm < 4'd4))) begin
            tmds <= {1'b1, q_m[8], ~q_m[7:0]};
            bias <= bias + (q_m[8] ? 5'sd2 : 5'sd0) - diff;
        end else begin
            tmds <= {1'b0, q_m[8], q_m[7:0]};
            bias <= bias - (q_m[8] ? 5'sd0 : 5'sd2) + diff;
        end
    end
```

- Using `signed [4:0]` (`-16 .. +15`) gives plenty of headroom for `bias` (which stays inside `[-8, +8]` on real streams), and writing `$signed({1'b0, n1_qm})` explicitly prevents Verilog from silently treating unsigned 4-bit arithmetic as unsigned!

## 3. High-Speed Serialisation with `OSER10` & `TLVDS_OBUF` (`hdmi_tx.v`)

Regular FPGA LUT logic cannot easily toggle pins at `252` Mbps. Instead, Gowin puts a dedicated **10:1 Double-Data-Rate (DDR) serialiser (`OSER10`)** inside every I/O tile, paired with a **True LVDS differential output buffer (`TLVDS_OBUF`)**:

- `PCLK` (`25.2` MHz `clk_pixel`) latches a fresh 10-bit word `D0..D9` once per pixel.
- `FCLK` (`126.0` MHz `clk_serial`) shifts out one bit on **every rising and falling edge**, sending `D0` first through `D9` last (`10` bits in `5` fast clock cycles = `252` Mbps).
- On the **Clock** lane, feeding fixed bits `D0..D4 = 1'b1` and `D5..D9 = 1'b0` emits a clean `25.2` MHz square wave (`10'b0000011111`) that stays phase-locked to all three data lanes!

### Complete `hdmi_tx.v` Module

```verilog caption="apps/0007-hdmi-tmds-serialization/hdmi_tx.v"
`timescale 1ns / 1ps

module hdmi_tx (
    input  wire       clk_pixel,
    input  wire       clk_serial,
    input  wire       reset,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    input  wire       visible,
    input  wire       hsync,
    input  wire       vsync,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    wire [9:0] tmds_ch [0:2];

    // Channel 0 (Blue) carries HSYNC and VSYNC control symbols during blanking
    tmds_encoder u_enc_blue (
        .clk(clk_pixel),
        .reset(reset),
        .data(b),
        .ctrl({vsync, hsync}),
        .visible(visible),
        .tmds(tmds_ch[0])
    );

    // Channel 1 (Green)
    tmds_encoder u_enc_green (
        .clk(clk_pixel),
        .reset(reset),
        .data(g),
        .ctrl(2'b00),
        .visible(visible),
        .tmds(tmds_ch[1])
    );

    // Channel 2 (Red)
    tmds_encoder u_enc_red (
        .clk(clk_pixel),
        .reset(reset),
        .data(r),
        .ctrl(2'b00),
        .visible(visible),
        .tmds(tmds_ch[2])
    );

    // Clock lane serialises fixed pattern 10'b0000011111 (LSB-first: 5 ones, 5 zeroes)
    wire ser_clk;
    OSER10 u_ser_clk (
        .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(reset),
        .Q(ser_clk)
    );

    TLVDS_OBUF u_obuf_clk (
        .I(ser_clk),
        .O(tmds_clk_p),
        .OB(tmds_clk_n)
    );

    wire [2:0] ser_d;
    genvar ch;
    generate
        for (ch = 0; ch < 3; ch = ch + 1) begin : g_lane
            OSER10 u_ser_d (
                .D0(tmds_ch[ch][0]), .D1(tmds_ch[ch][1]),
                .D2(tmds_ch[ch][2]), .D3(tmds_ch[ch][3]),
                .D4(tmds_ch[ch][4]), .D5(tmds_ch[ch][5]),
                .D6(tmds_ch[ch][6]), .D7(tmds_ch[ch][7]),
                .D8(tmds_ch[ch][8]), .D9(tmds_ch[ch][9]),
                .FCLK(clk_serial),
                .PCLK(clk_pixel),
                .RESET(reset),
                .Q(ser_d[ch])
            );

            TLVDS_OBUF u_obuf_d (
                .I(ser_d[ch]),
                .O(tmds_d_p[ch]),
                .OB(tmds_d_n[ch])
            );
        end
    endgenerate
endmodule
```

- A `generate for` loop instantiates the three identical `OSER10` + `TLVDS_OBUF` output lanes cleanly without copy-pasting boilerplate three times.
- Notice in `apps/0007-hdmi-tmds-serialization/tangnano20k.cst`, `nextpnr-himbaechel` requires separate `IO_LOC` statements for each `_p` and `_n` pin (`33` and `34`, `35` and `36`, `37` and `38`, `39` and `40`), with `IO_PORT` targeting the positive `_p` net (`PULL_MODE=NONE`).

## 4. Putting a Live Picture on HDMI (`top.v`)

Now everything from Lessons 5 and 6 snaps together inside `top.v`:
- `video_clock` supplies `clk_serial` (`126` MHz) and `clk_pixel` (`25.2` MHz).
- Both buttons (`s1` reset and `s2` pattern mode) pass through 2-FF synchronisers into the `25.2` MHz pixel domain so no asynchronous push-button edge ever hits `raster` or `pattern`.
- `raster` + `pattern` feed `hdmi_tx` directly, while a frame-counter heartbeat blinks `led[4:0]` alongside `led[5]` (`pll_lock`).

### Complete `top.v` Listing

```verilog caption="apps/0007-hdmi-tmds-serialization/top.v"
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

    // Synchronise reset and mode switch into the 25.2 MHz pixel domain
    reg [1:0] rst_sync  = 2'b11;
    reg [1:0] mode_sync = 2'b00;
    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_sync  <= 2'b11;
            mode_sync <= 2'b00;
        end else begin
            rst_sync  <= {rst_sync[0], s1};
            mode_sync <= {mode_sync[0], s2};
        end
    end
    wire reset_pix = rst_sync[1];
    wire mode_pix  = mode_sync[1];

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

    pattern u_pattern (
        .x(x),
        .y(y),
        .visible(visible),
        .mode(mode_pix),
        .r(r),
        .g(g),
        .b(b)
    );

    hdmi_tx u_hdmi (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .reset(reset_pix),
        .r(r),
        .g(g),
        .b(b),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
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

Running `make -C apps/0007-hdmi-tmds-serialization stats` shows `tmds_encoder` standalone uses **15 flip-flops** (`10 DFF`, `5 DFFR`), `17 ALU` cells, `100` LUTs (`LUT1`–`LUT4`), and `42` `MUX2_LUT*` cells; the entire HDMI pipeline in `top` consumes **1 `rPLL`**, **1 `CLKDIV`**, **4 `OSER10`**, **4 `TLVDS_OBUF`**, **82 flip-flops** (`20 DFF`, `2 DFFC`, `2 DFFP`, `35 DFFR`, `23 DFFRE`), `167 ALU` cells, `116` LUTs, and `16` `MUX2_LUT*` cells—routing cleanly well above `25.2` MHz.

---

:::exercise id="ex-0007" title="Interactive Lab: TMDS Disparity, Sync Token Channel & OSER10 Wiring" badge="Skill Practice • HDMI TMDS"
Fill in the missing TMDS Stage 1 XNOR condition, the blanking bias reset, and the Blue channel's sync control wiring:

```verilog
wire use_xnor = (n1_d > 4'd4) || ((n1_d == 4'd4) && ({{blank:data[0] == 1'b0||~data[0]|Tie-breaker when n1_d equals 4|??????????????|14}}));

if (reset || !visible) begin
    bias <= {{blank:5'sd0||0|Reset 5-bit signed disparity|?????|5}};
    case (ctrl)
        2'b00: tmds <= 10'b1101010100;
        ...
    endcase
end

tmds_encoder u_enc_blue (
    .clk(clk_pixel),
    .reset(reset),
    .data(b),
    .ctrl({{blank:{vsync, hsync}|Pack VSYNC and HSYNC into ctrl[1:0]|??????????????|14}}),
    .visible(visible),
    .tmds(tmds_ch[0])
);
```

:::prompts
hint: "Use `data[0] == 1'b0` for the Stage 1 tie-breaker, `5'sd0` to clear signed `bias` during blanking, and `{vsync, hsync}` on Blue (`tmds_ch[0]`) so `ctrl[1]=vsync` and `ctrl[0]=hsync`."
success: "Spot on! That exact DVI-D mapping puts crisp, DC-balanced 640×480@60 Hz video straight onto a real monitor."
:::
:::

:::quiz id="quiz-0007" title="Retrieval Practice: TMDS 8b/10b Encoding & OSER10 Serialisation" badge="3 Questions • Equal-Length Options"
- question: "Why does TMDS convert each 8-bit colour channel into a 10-bit symbol instead of sending 8 raw bits?"
  wrong_hint: "Think about electrical transitions along a high-speed cable and long runs of all-white or all-black pixels."
  options:
    - letter: "A"
      text: "To double the colour depth from eight bits per pixel to ten bits."
      correct: false
      explain: "Original 8-bit values are recovered losslessly at the receiver; the extra 2 bits encode inversion metadata."
    - letter: "B"
      text: "To compress horizontal blanking porches so HDMI monitors skip past sync pulses faster."
      correct: false
      explain: "8b/10b expands 8 bits to 10 bits and preserves exact 800×525 blanking durations."
    - letter: "C"
      text: "To reduce high-frequency wire transitions and preserve DC balance across the differential pairs."
      correct: true
      explain: "Correct: bit 8 selects XOR/XNOR to cut transitions (`<= 5`), and bit 9 optionally inverts the word to keep running DC disparity near zero."
    - letter: "D"
      text: "To encrypt raw pixel RGB channels against unauthorised display capture over copper cables."
      correct: false
      explain: "TMDS is a physical line coding scheme for signal integrity, not encryption (that would be HDCP)."
- question: "How do `hsync` and `vsync` reach the HDMI monitor if there are no dedicated sync wires on the HDMI cable?"
  wrong_hint: "Check which TMDS lane receives `{vsync, hsync}` when `visible` is low."
  options:
    - letter: "A"
      text: "Channel zero carries reserved ten-bit control tokens encoding vsync and hsync during blanking."
      correct: true
      explain: "Correct: Channel 0 (Blue) encodes `{vsync, hsync}` into the four high-transition 10-bit DVI control symbols whenever `visible == 0`."
    - letter: "B"
      text: "The clock lane pauses its square wave whenever either sync pulse goes active."
      correct: false
      explain: "The TMDS clock lane runs continuously (`10'b0000011111`) throughout both visible pixels and blanking."
    - letter: "C"
      text: "Channels one and two transmit analogue voltage steps outside the standard pixel range."
      correct: false
      explain: "HDMI TMDS lanes are purely digital binary differential pairs; Green and Red simply send `2'b00` control tokens during blanking."
    - letter: "D"
      text: "The PLL stops oscillating for ninety-six pixel clocks at every horizontal sync pulse."
      correct: false
      explain: "The PLL must stay locked continuously so `OSER10` keeps shifting bits smoothly."
- question: "Why does `hdmi_tx.v` feed the `126 MHz` fast clock to `OSER10` while `clk_pixel` runs at `25.2 MHz`?"
  wrong_hint: "Remember `126 / 25.2 = 5`, and `OSER10` is a Double-Data-Rate serialiser."
  options:
    - letter: "A"
      text: "Because OSER10 latches ten bits per pixel and shifts DDR on both edges."
      correct: true
      explain: "Correct: 5 cycles of `126 MHz` provide 10 rising/falling DDR edges, shifting out all 10 bits (`252 Mbps`) per `25.2 MHz` pixel."
    - letter: "B"
      text: "Because TLVDS_OBUF requires every output pin to double its frequency after serialisation completes."
      correct: false
      explain: "`TLVDS_OBUF` is simply a differential output buffer driving `O` and `OB = ~O`; `OSER10` handles the 10:1 DDR serialisation."
    - letter: "C"
      text: "Because DVI monitors sample each data wire only on every fifth clock edge."
      correct: false
      explain: "Receivers oversample and recover every single 252 Mbps bit using the 25.2 MHz TMDS clock lane."
    - letter: "D"
      text: "Because Yosys cannot route 10-bit buses unless every lane uses two different clocks."
      correct: false
      explain: "The two clocks exist specifically for 10:1 DDR serialisation, not as a Yosys routing rule."
:::

:::verify id="verify-0007" title="Verification Lab: TMDS Bit-Exact Verification & Live HDMI Monitor Output" badge="Simulation & Hardware Gate"
Verify all 256 TMDS byte values and DC balance, test `OSER10` + `TLVDS_OBUF` serialisation, inspect `tmds_encoder.vcd` in Surfer, flash the Tang Nano 20K, and plug it into an HDMI monitor:

```bash caption="Simulate, inspect waveforms/stats, and flash Lesson 7"
make -C apps/0007-hdmi-tmds-serialization clean all
make -C apps/0007-hdmi-tmds-serialization stats
make -C apps/0007-hdmi-tmds-serialization wave
make -C apps/0007-hdmi-tmds-serialization flash
```

- [ ] `make -C apps/0007-hdmi-tmds-serialization clean all` passes with zero `iverilog -Wall` warnings and prints `PASS:` for `tmds_encoder` (4 control tokens, all 256 byte values lossless, max `5` transitions, DC balanced), `hdmi_tx`, and `top`.
- [ ] `make stats` confirms `top` uses `1 rPLL`, `1 CLKDIV`, `4 OSER10`, `4 TLVDS_OBUF`, and `82` flip-flops (`20 DFF`, `2 DFFC`, `2 DFFP`, `35 DFFR`, `23 DFFRE`).
- [ ] In Surfer (`make wave` or `make wave-tx`), confirm `tmds_d_p` and `tmds_d_n` are exact complements and `tmds_clk_p` emits `0000011111` (5 ticks high, 5 ticks low) per pixel.
- [ ] Plug the Tang Nano 20K into a physical HDMI monitor:
  - Eight crisp vertical colour bars fill the 640×480 display (`led[5]` steadily lit, `led[4:0]` ticking frames).
  - Hold `S2`: the monitor switches cleanly to the 32×32 checkerboard framed by a bright red border.
  - Hold `S1`: reset holds blanking cleanly and resumes immediately on release.
:::

:::teacher-prompt title="Next Up: Lesson 8 (Our 6502 Computer Gets a 320×200 Video Card)"
Seeing your own Verilog code put a rock-solid 640×480 picture onto a physical HDMI monitor is a huge milestone! Ask any questions about TMDS disparity, `OSER10`, or `.cst` differential pins—or say **"ready for Lesson 8"** to wrap up Part 2 by replacing `pattern.v` with a real 320×200 16-colour frame buffer in Gowin Block RAM!
:::
