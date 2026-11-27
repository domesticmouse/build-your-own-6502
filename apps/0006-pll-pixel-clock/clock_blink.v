`timescale 1ns / 1ps

module clock_blink #(
    parameter integer HALF_PERIOD = 13500000
) (
    input  wire       clk,
    input  wire       reset,
    output reg        out   = 1'b0,
    output reg  [2:0] count = 3'd0
);
    reg [24:0] div = 25'd0;

    always @(posedge clk) begin
        if (reset) begin
            div   <= 25'd0;
            out   <= 1'b0;
            count <= 3'd0;
        end else if (div == HALF_PERIOD - 1) begin
            div   <= 25'd0;
            out   <= ~out;
            count <= count + 3'd1;
        end else begin
            div <= div + 25'd1;
        end
    end
endmodule
