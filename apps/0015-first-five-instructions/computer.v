`timescale 1ns / 1ps

module computer #(
    parameter ROM_FILE = "rom.mem"
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        step,
    output wire [15:0] address,
    output wire [7:0]  data_in,
    output wire [7:0]  data_out,
    output wire        write,
    output wire [7:0]  opcode,
    output wire [15:0] pc,
    output wire [2:0]  state
);
    cpu u_cpu (
        .clk(clk),
        .reset(reset),
        .step(step),
        .data_in(data_in),
        .address(address),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state)
    );

    bus #(
        .ROM_FILE(ROM_FILE)
    ) u_bus (
        .clk(clk),
        .address(address),
        .data_out(data_out),
        .write(write),
        .data_in(data_in)
    );
endmodule
