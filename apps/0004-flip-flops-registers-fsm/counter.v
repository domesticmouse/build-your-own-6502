`timescale 1ns / 1ps

module counter (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,
    output reg  [7:0] count = 8'd0
);
    always @(posedge clk) begin
        if (reset) begin
            count <= 8'd0;
        end else if (enable) begin
            count <= count + 8'd1;
        end
    end
endmodule
