`timescale 1ns / 1ps

module bus #(
    parameter ROM_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire [15:0] address,
    input  wire [7:0]  data_out,
    input  wire        write,
    output wire [7:0]  data_in
);
    wire ram_select = ~address[15];
    wire rom_select = address[15] & address[14];
    wire ram_write  = ram_select & write;

    wire [7:0] ram_data;
    wire [7:0] rom_data;

    ram u_ram (
        .clk(clk),
        .address(address[14:0]),
        .data_in(data_out),
        .write(ram_write),
        .data_out(ram_data)
    );

    rom #(
        .INIT_FILE(ROM_FILE)
    ) u_rom (
        .clk(clk),
        .address(address[13:0]),
        .data_out(rom_data)
    );

    reg ram_select_d1 = 1'b0;
    reg rom_select_d1 = 1'b0;

    always @(posedge clk) begin
        ram_select_d1 <= ram_select;
        rom_select_d1 <= rom_select;
    end

    assign data_in = rom_select_d1 ? rom_data :
                     (ram_select_d1 ? ram_data : 8'h00);
endmodule
