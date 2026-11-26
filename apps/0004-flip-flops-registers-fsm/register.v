`timescale 1ns / 1ps

module register (
    input  wire       clk,
    input  wire       reset,
    input  wire       load,
    input  wire [7:0] d,
    output reg  [7:0] q = 8'd0
);
    always @(posedge clk) begin
        if (reset) begin
            q <= 8'd0;
        end else if (load) begin
            q <= d;
        end
    end
endmodule
