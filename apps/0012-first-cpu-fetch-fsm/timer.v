`timescale 1ns / 1ps

module timer #(
    parameter integer PERIOD = 2700000
) (
    input  wire clk,
    input  wire reset,
    output reg  tick = 1'b0
);
    localparam [24:0] MAX_COUNT = PERIOD - 1;
    reg [24:0] count = 25'd0;

    always @(posedge clk) begin
        if (reset) begin
            count <= 25'd0;
            tick  <= 1'b0;
        end else if (count == MAX_COUNT) begin
            count <= 25'd0;
            tick  <= 1'b1;
        end else begin
            count <= count + 25'd1;
            tick  <= 1'b0;
        end
    end
endmodule
