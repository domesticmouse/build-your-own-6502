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
    output wire [2:0]  state,
    output wire [7:0]  a,
    output wire        flag_c,
    output wire        flag_z,
    output wire        flag_n,
    output wire        flag_v,
    output reg  [7:0]  leds = 8'h00
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
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v)
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

    always @(posedge clk) begin
        if (reset) begin
            leds <= 8'h00;
        end else if (write && (address == 16'h8000)) begin
            leds <= data_out;
        end
    end
endmodule
