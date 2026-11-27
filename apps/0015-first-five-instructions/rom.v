`timescale 1ns / 1ps

module rom #(
    parameter INIT_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire [13:0] address,
    output reg  [7:0]  data_out = 8'h00
);
    reg [7:0] mem [0:16383];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        data_out <= mem[address];
    end
endmodule
