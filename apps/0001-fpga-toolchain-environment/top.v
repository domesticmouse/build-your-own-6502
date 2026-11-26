`timescale 1ns / 1ps

module top #(
    parameter integer BLINK_BIT = 24
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    reg [BLINK_BIT:0] counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    wire both_pressed = s1 & s2;

    assign led[0]   = ~both_pressed;
    assign led[1]   = ~counter[BLINK_BIT];
    assign led[2]   = ~s1;
    assign led[3]   = ~s2;
    assign led[5:4] = 2'b11;
endmodule
