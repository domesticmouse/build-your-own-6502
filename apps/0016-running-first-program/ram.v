`timescale 1ns / 1ps

module ram (
    input  wire        clk,
    input  wire [14:0] address,
    input  wire [7:0]  data_in,
    input  wire        write,
    output reg  [7:0]  data_out = 8'h00
);
    reg [7:0] mem [0:32767];

    always @(posedge clk) begin
        if (write) begin
            mem[address] <= data_in;
        end
        data_out <= mem[address];
    end
endmodule
