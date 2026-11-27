---
title: "Gowin rPLL & Clock Domain Segregation"
page_title: "Lesson 0006: Gowin rPLL & Clock Domain Segregation — Build Your Own 6502"
nav_id: "lesson-0006"
badge: "Lesson 0006 • Clocking & PLLs"
subtitle: "Synthesise 126 MHz and 25.2 MHz clocks from the 27 MHz crystal using rPLL and CLKDIV, isolate asynchronous clock domains, and prove both frequencies on real hardware."
card:
  title: "**Gowin rPLL & Clock Domain Segregation**"
  summary: "Turn the Tang Nano 20K's 27 MHz crystal into 126 MHz and 25.2 MHz clocks with rPLL + CLKDIV while keeping clock domains isolated."
---

:::callout title="Recommended Primary Sources"
- **Companion app**: `apps/0006-pll-pixel-clock/` (`make -C apps/0006-pll-pixel-clock clean all`)
- **Video reference**: [Episode 6: The Missing Clock: How a PLL Turns 27 MHz into 25.2 MHz](https://www.youtube.com/watch?v=SuOi-peTmv8)
- **Toolchain reference**: [Project Apicula (`YosysHQ/apicula`)](https://github.com/YosysHQ/apicula) (`gowin_pll`) and [Sipeed Tang Nano 20K Docs](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- **Course references**: [Lesson 5](0005-vga-raster-timing.md), [Glossary](../reference/GLOSSARY.md), and [Toolchain Cheat Sheet](../reference/toolchain-cheatsheet.md)
:::

## 1. Why 27 MHz Cannot Divide Down to 25.2 MHz

In [Lesson 5](0005-vga-raster-timing.md), we calculated that standard 640×480@60 Hz VGA requires an exact **25.2 MHz** pixel clock, while the Tang Nano 20K crystal ticks at **27.0 MHz**.

A digital counter built from flip-flops can only divide a clock by whole integers ($\div 2$, $\div 3$, $\div 4$, ...). To turn 27 MHz into 25.2 MHz, we need a rational fraction:

$$\frac{25.2\text{ MHz}}{27.0\text{ MHz}} = \frac{252}{270} = \frac{14}{15}$$

Even more importantly, in Lesson 7 our HDMI serialiser will need a **5×** bit clock (**126.0 MHz**) alongside the 25.2 MHz pixel clock so it can shift 10 bits per pixel using both clock edges (Double Data Rate). Notice how neatly the numbers line up:

$$27.0\text{ MHz} \times \frac{14}{3} = 126.0\text{ MHz} \quad\longrightarrow\quad \frac{126.0\text{ MHz}}{5} = 25.2\text{ MHz}$$

Digital counters cannot multiply a frequency up to 126 MHz. That job belongs to an analogue **Phase-Locked Loop (PLL)** hardwired inside the Gowin FPGA silicon.

## 2. Inside the Gowin `rPLL` and `CLKDIV` Primitives

A PLL locks a high-frequency Voltage-Controlled Oscillator (VCO) onto a crystal reference using a feedback loop:

```mermaid caption="Figure 6.1: Gowin rPLL + CLKDIV clock tree turning 27 MHz into 126 MHz and 25.2 MHz"
flowchart LR
  XTAL["27.0 MHz Crystal<br/>(Pin 4)"] --> IDIV["Input Divider ÷3<br/>IDIV_SEL = 2<br/>(9.0 MHz PFD)"]
  IDIV --> PFD["Phase/Freq Detector<br/>& Loop Filter"]
  PFD --> VCO["VCO<br/>504.0 MHz"]
  VCO --> ODIV["Output Divider ÷4<br/>ODIV_SEL = 4<br/>(126.0 MHz CLKOUT)"]
  ODIV --> FBDIV["Feedback ÷14<br/>FBDIV_SEL = 13"]
  FBDIV --> PFD
  ODIV -->|"clk_serial (126 MHz)"| DIV5["Hard CLKDIV ÷5<br/>DIV_MODE = 5"]
  DIV5 -->|"clk_pixel (25.2 MHz)"| PIX["Pixel Logic Domain"]
```

Notice the subtle **off-by-one encoding** in Gowin's `rPLL` parameters, where each selector stores $N - 1$:
- `IDIV_SEL = 2` divides the `27.0` MHz input by `2 + 1 = 3` down to a `9.0` MHz phase-detector reference.
- `FBDIV_SEL = 13` multiplies that `9.0` MHz reference by `13 + 1 = 14` to reach `126.0` MHz at `CLKOUT`.
- `ODIV_SEL = 4` keeps the internal VCO spinning at $126.0 \times 4 = 504.0\text{ MHz}$, safely inside the GW2AR-18's `500–1250 MHz` VCO window!

You do not have to guess these integers by hand. OSS CAD Suite ships `gowin_pll` specifically to solve them:

```bash caption="Generating Gowin rPLL parameters with gowin_pll"
~/oss-cad-suite/bin/gowin_pll -d "GW2AR-18 C8/I7" -i 27 -o 126 -f video_clock.v
```

From `126.0` MHz (`clk_serial`), Gowin's dedicated `CLKDIV` hard block (`DIV_MODE = "5"`) divides cleanly down to `25.2` MHz (`clk_pixel`), held in reset via `.RESETN(locked)` until the PLL reports stable phase lock{{sidenote:Because both <code>clk_serial</code> and <code>clk_pixel</code> are driven by dedicated Gowin clock primitives, <code>nextpnr-himbaechel</code> routes both onto global low-skew clock networks automatically.}}.

### Block-by-Block: `video_clock.v`

```verilog caption="apps/0006-pll-pixel-clock/video_clock.v"
`timescale 1ns / 1ps

module video_clock (
    input  wire clk_27m,
    output wire clk_serial,
    output wire clk_pixel,
    output wire locked
);
    rPLL #(
        .FCLKIN("27.0"),
        .IDIV_SEL(2),
        .FBDIV_SEL(13),
        .ODIV_SEL(4)
    ) u_pll (
        .CLKOUT(clk_serial),
        .LOCK(locked),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(1'b0),
        .RESET_P(1'b0),
        .CLKIN(clk_27m),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN("false")
    ) u_div (
        .HCLKIN(clk_serial),
        .RESETN(locked),
        .CALIB(1'b0),
        .CLKOUT(clk_pixel)
    );
endmodule
```

- Every unused dynamic-reconfiguration port on `rPLL` (`RESET`, `CLKFB`, `FBDSEL`, `IDSEL`, `ODSEL`, `PSDA`, `DUTYDA`, `FDLY`) is tied explicitly to `0` so Yosys and Icarus Verilog never complain about floating inputs.

## 3. Clock Domain Segregation & Reset Synchronisation

In [Lesson 4](0004-flip-flops-registers-fsm.md), we stuck to a single 27 MHz clock. Now we genuinely have **multiple asynchronous clock domains**: `clk` (`27.0` MHz) and `clk_pixel` (`25.2` MHz) drift past each other continuously (`14` pixel ticks vs `15` crystal ticks).

If a flip-flop clocked by `25.2` MHz directly samples a register or raw button changing in the `27` MHz world, the input can transition right inside the flip-flop's setup/hold aperture—pushing the silicon into **metastability**, where `q` hovers halfway between `0` and `1` and resolves randomly.

:::callout-warn title="The Clock Domain Segregation Rule"
Keep every subsystem cleanly inside **one clock domain**, and never let flip-flops in one domain directly read signals from an unrelated clock domain without a proper synchroniser. Even a push-button reset (`s1`) crossing into `clk_pixel` passes through a **two-flip-flop synchroniser** first!
:::

Look at the two-stage reset synchroniser we use for the 25.2 MHz domain:

```verilog caption="Async-assert (~pll_lock), sync-release 2-FF reset synchroniser"
    reg [1:0] rst_sync_pix = 2'b11;
    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_sync_pix <= 2'b11;
        end else begin
            rst_sync_pix <= {rst_sync_pix[0], s1};
        end
    end
    wire reset_pix = rst_sync_pix[1];
```

- While `pll_lock` is `0`, `rst_sync_pix` immediately forces `2'b11` (holding `reset_pix = 1`).
- Once `pll_lock` rises and `s1` is released (`0`), `rst_sync_pix` shifts out `1 -> 0` over **two rising edges of `clk_pixel`**, guaranteeing `reset_pix` de-asserts cleanly in sync with the 25.2 MHz clock!

## 4. Simulating Vendor Hard Primitives (`sim_gowin_primitives.v`)

Yosys knows about `rPLL` and `CLKDIV` because it loads `cells_sim.v` and `cells_xtra_gw2a.v` during `synth_gowin`. Icarus Verilog (`iverilog`), however, is a generic simulator—if you compile `video_clock.v` alone, `iverilog` errors out because `rPLL` and `CLKDIV` are not standard Verilog keywords.

Our solution is clean separation:
- Keep behavioral simulation models of `rPLL` and `CLKDIV` in `sim_gowin_primitives.v`.
- Pass `sim_gowin_primitives.v` **only** to `iverilog` in the `Makefile` (`test:` target), and **never** to `yosys` (`synth:` target) so hardware synthesis always maps to the real Gowin silicon primitives!

## 5. Proving 27 MHz ≠ 25.2 MHz on Six LEDs (`top.v`)

How can you *see* the difference between `27.0` MHz and `25.2` MHz with the naked eye before hooking up an HDMI monitor? Put both frequencies side by side on the Tang Nano 20K's LEDs using the reusable `clock_blink` counter:

- **`led[0]`** (`blink_27m`): runs on `clk` (`27.0` MHz) with `HALF_PERIOD = 13,500,000` $\rightarrow$ toggles at **1.000 Hz** (`0.5 s` on, `0.5 s` off).
- **`led[1]`** (`blink_25m2`): runs on `clk_pixel` (`25.2` MHz) with `HALF_PERIOD = 12,600,000` $\rightarrow$ also toggles at **1.000 Hz**, blinking in **exact lockstep** with `led[0]`!
- **`led[2]`** (`blink_drift`): runs on `clk_pixel` (`25.2` MHz) with the *wrong* `27` MHz divisor (`13,500,000`) $\rightarrow$ toggles at `25.2 / 27.0 = 0.933 Hz`, drifting noticeably behind `led[0]` and `led[1]` within seconds.
- **`led[5]`**: wired directly to `pll_lock` (stays steadily lit once locked).

### Complete `top.v` Listing

```verilog caption="apps/0006-pll-pixel-clock/top.v"
`timescale 1ns / 1ps

module top #(
    parameter integer DIV_27M  = 13500000,
    parameter integer DIV_25M2 = 12600000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
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

    // Synchronise button s1 into the 27 MHz domain
    reg [1:0] rst_sync_27m = 2'b11;
    always @(posedge clk) begin
        rst_sync_27m <= {rst_sync_27m[0], s1};
    end
    wire reset_27m = rst_sync_27m[1];

    // Async-assert (~pll_lock), sync-release reset into the 25.2 MHz pixel domain
    reg [1:0] rst_sync_pix = 2'b11;
    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_sync_pix <= 2'b11;
        end else begin
            rst_sync_pix <= {rst_sync_pix[0], s1};
        end
    end
    wire reset_pix = rst_sync_pix[1];

    wire       blink_27m;
    wire [2:0] cnt_27m;
    clock_blink #(.HALF_PERIOD(DIV_27M)) u_blink_27m (
        .clk(clk),
        .reset(reset_27m),
        .out(blink_27m),
        .count(cnt_27m)
    );

    wire       blink_25m2;
    wire [2:0] cnt_25m2;
    clock_blink #(.HALF_PERIOD(DIV_25M2)) u_blink_25m2 (
        .clk(clk_pixel),
        .reset(reset_pix),
        .out(blink_25m2),
        .count(cnt_25m2)
    );

    wire       blink_drift;
    wire [2:0] cnt_drift;
    clock_blink #(.HALF_PERIOD(DIV_27M)) u_blink_drift (
        .clk(clk_pixel),
        .reset(reset_pix),
        .out(blink_drift),
        .count(cnt_drift)
    );

    wire [5:0] display = s2
        ? {pll_lock, cnt_27m[1:0], cnt_25m2[2:0]}
        : {pll_lock, cnt_27m[0], cnt_25m2[0], blink_drift, blink_25m2, blink_27m};

    assign led = ~display;
endmodule
```

Running `make -C apps/0006-pll-pixel-clock stats` confirms `video_clock` synthesises to **1 `rPLL`**, **1 `CLKDIV`**, and **0 LUTs or flip-flops**, while the full `top` design maps to **1 `rPLL`**, **1 `CLKDIV`**, **87 flip-flops** (`75 DFFR`, `8 DFFRE`, `2 DFFP`, `2 DFFS`), `80 ALU` cells, `62` LUTs (`LUT1`–`LUT4`), and `21` `MUX2_LUT*` cells.

---

:::exercise id="ex-0006" title="Interactive Lab: rPLL Dividers, CLKDIV & 2-FF Reset Synchroniser" badge="Skill Practice • Clocking & CDC"
Fill in the `rPLL` off-by-one parameters, the `CLKDIV` divide mode, and the 2-FF reset synchroniser shift register:

```verilog
rPLL #(
    .FCLKIN("27.0"),
    .IDIV_SEL({{blank:2|Divide 27 MHz by 3 (N-1)|?|1}}),
    .FBDIV_SEL({{blank:13|Multiply 9 MHz by 14 (N-1)|??|2}}),
    .ODIV_SEL(4)
) u_pll ( ... );

CLKDIV #(
    .DIV_MODE("{{blank:5|Divide 126 MHz to 25.2 MHz|?|1}}"),
    .GSREN("false")
) u_div (
    .HCLKIN(clk_serial),
    .RESETN({{blank:locked|Hold divider reset until PLL locks|??????|6}}),
    .CALIB(1'b0),
    .CLKOUT(clk_pixel)
);

always @(posedge clk_pixel or negedge pll_lock) begin
    if (!pll_lock) rst_sync_pix <= 2'b11;
    else           rst_sync_pix <= {{blank:{rst_sync_pix[0], s1}|Shift s1 through two flip-flops|????????????????????|18}};
end
```

:::prompts
hint: "Remember `rPLL` subtracts 1 (`÷3` -> `2`, `×14` -> `13`), `CLKDIV` divides 126 MHz by `5` while `RESETN` watches `locked`, and the synchroniser shifts `{rst_sync_pix[0], s1}`."
success: "Clean clock engineering! That exact `rPLL` + `CLKDIV` + 2-FF synchroniser pipeline will drive our real HDMI monitor in Lesson 7."
:::
:::

:::quiz id="quiz-0006" title="Retrieval Practice: PLL Synthesis & Clock Domain Crossing" badge="3 Questions • Equal-Length Options"
- question: "Why can we not generate an exact 25.2 MHz pixel clock from the 27 MHz crystal using an ordinary Verilog flip-flop counter?"
  wrong_hint: "Compare integer clock division with the fractional ratio 14/15."
  options:
    - letter: "A"
      text: "Because integer counters only divide down and cannot multiply 27 MHz by fourteen-fifteenths."
      correct: true
      explain: "Correct: digital counters can only divide by integers, whereas a PLL multiplies up (`×14/3 = 126 MHz`) before dividing by `5`."
    - letter: "B"
      text: "Because Gowin flip-flops reject clock divisors smaller than ten inside synchronous Verilog loops."
      correct: false
      explain: "Flip-flop counters support any integer divisor (`÷2`, `÷3`, etc.), just not non-integer ratios like `27 / 25.2`."
    - letter: "C"
      text: "Because 27 MHz crystal oscillators automatically shut down whenever any counter reaches fifteen."
      correct: false
      explain: "The crystal ticks continuously at 27 MHz regardless of downstream counters."
    - letter: "D"
      text: "Because dividing clocks in logic creates 126 MHz signals that overflow 25-bit registers."
      correct: false
      explain: "Dividing a 27 MHz clock produces lower frequencies, never 126 MHz."
- question: "Why does `video_clock.v` configure `rPLL` to output 126 MHz and then divide by 5 in `CLKDIV` instead of outputting 25.2 MHz directly?"
  wrong_hint: "Look ahead to how HDMI TMDS bit serialisation shifts 10 bits per pixel clock."
  options:
    - letter: "A"
      text: "Because Lesson 7 needs 126 MHz to serialise 10-bit TMDS symbols at 5x."
      correct: true
      explain: "Correct: `OSER10` shifts 10 bits per `25.2` MHz pixel using both edges of the `126` MHz fast serial clock."
    - letter: "B"
      text: "Because Gowin CLKDIV blocks require an input frequency below fifty megahertz to lock."
      correct: false
      explain: "`CLKDIV` is a pure digital divider with no minimum 50 MHz ceiling; here it receives `126` MHz."
    - letter: "C"
      text: "Because the onboard crystal stops oscillating unless the VCO runs below 500 MHz."
      correct: false
      explain: "The GW2AR-18 VCO actually requires `500–1250 MHz` (`504 MHz` here), and does not control the external crystal."
    - letter: "D"
      text: "Because Icarus Verilog cannot simulate a clock divider unless a PLL multiplies first."
      correct: false
      explain: "Icarus Verilog simulates any divider directly; the `126` MHz + `÷5` pair exists for HDMI `OSER10` hardware."
- question: "What happens if a flip-flop in the 25.2 MHz domain directly samples a signal changing on the 27 MHz clock without a synchroniser?"
  wrong_hint: "Recall what happens when an input changes inside a flip-flop's setup and hold window."
  options:
    - letter: "A"
      text: "The downstream flip-flop skips every fifteenth clock cycle without losing any data bits."
      correct: false
      explain: "Asynchronous clocks drift continuously and can violate setup/hold windows, corrupting data."
    - letter: "B"
      text: "Yosys automatically inserts a hardware FIFO queue between every mismatched clock edge pair."
      correct: false
      explain: "Yosys does not insert automatic clock-domain-crossing FIFOs; designers must isolate domains explicitly."
    - letter: "C"
      text: "Setup or hold violations can drive the sampling flip-flop into unpredictable metastable oscillation."
      correct: true
      explain: "Correct: sampling an asynchronous edge inside the setup/hold window risks metastability, which 2-FF synchronisers mitigate."
    - letter: "D"
      text: "The PLL loses phase lock and resets the FPGA crystal back to zero."
      correct: false
      explain: "Cross-domain sampling glitches affect downstream logic, not the PLL's crystal reference."
:::

:::verify id="verify-0006" title="Verification Lab: PLL Simulation, Surfer Clocks & Live Drift Demo" badge="Simulation & Hardware Gate"
Verify the 5:1 serial-to-pixel ratio in simulation, inspect `video_clock.vcd` in Surfer, verify global clock routing, and watch the 27 MHz vs 25.2 MHz LEDs side by side on your Tang Nano 20K:

```bash caption="Simulate, inspect waveforms/stats, and flash Lesson 6"
make -C apps/0006-pll-pixel-clock clean all
make -C apps/0006-pll-pixel-clock stats
make -C apps/0006-pll-pixel-clock wave
make -C apps/0006-pll-pixel-clock flash
```

- [ ] `make -C apps/0006-pll-pixel-clock clean all` passes with zero `iverilog -Wall` warnings and prints `PASS:` for `video_clock` (`100:20` = exact 5:1 edge ratio) and `top`.
- [ ] `make stats` confirms `video_clock` uses `1 rPLL` and `1 CLKDIV` (`0` LUTs/FFs), and `top` uses `1 rPLL`, `1 CLKDIV`, and `87` flip-flops (`75 DFFR`, `8 DFFRE`, `2 DFFP`, `2 DFFS`).
- [ ] In Surfer (`make wave`), confirm `clk_pixel` stays `0` until `locked` goes high, then pulses once for every 5 rising edges of `clk_serial`.
- [ ] On the flashed Tang Nano 20K:
  - `led[5]` (`pll_lock`) stays steadily lit.
  - `led[0]` (27 MHz `1.000 Hz`) and `led[1]` (25.2 MHz `1.000 Hz`) blink in exact lockstep.
  - `led[2]` (25.2 MHz driven by the 27 MHz divisor) visibly drifts slower and falls out of phase with `led[0]`/`led[1]`.
  - Holding `S1` synchronously resets both clock domains; holding `S2` displays the live 3-bit counters from both domains.
:::

:::teacher-prompt title="Next Up: Lesson 7 (Sending Real HDMI Video to a Monitor)"
Now that we have an exact 25.2 MHz pixel clock and 126 MHz bit clock locked on real silicon, inspect `video_clock.vcd` in Surfer and watch `led[2]` drift behind `led[0]`/`led[1]` on the board. Ask any questions about PLL dividers, `CLKDIV`, or metastability—or say **"ready for Lesson 7"** to build the TMDS 8b/10b encoder and `OSER10` differential serialiser and light up a physical HDMI monitor!
:::
