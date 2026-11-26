`timescale 1ns / 1ps

module top #(
    parameter integer TIMER_PERIOD = 2700000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire reset = s1;
    wire tick;
    wire [7:0] count;
    wire [5:0] scan_leds;

    timer #(
        .PERIOD(TIMER_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(tick)
    );

    counter u_counter (
        .clk(clk),
        .reset(reset),
        .enable(tick),
        .count(count)
    );

    scanner u_scanner (
        .clk(clk),
        .reset(reset),
        .step(tick),
        .leds(scan_leds)
    );

    wire [5:0] display = s2 ? count[5:0] : scan_leds;
    assign led = ~display;
endmodule
