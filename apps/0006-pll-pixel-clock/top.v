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
