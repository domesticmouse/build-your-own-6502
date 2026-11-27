`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 540000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] disp_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        disp_sync <= {disp_sync[0], s2};
    end
    wire reset     = rst_sync[1];
    wire show_addr = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;
    wire [2:0]  state;
    wire [7:0]  a;
    wire        flag_c;
    wire        flag_z;
    wire        flag_n;
    wire        flag_v;
    wire [7:0]  leds;

    computer u_computer (
        .clk(clk),
        .reset(reset),
        .step(step),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v),
        .leds(leds)
    );

    assign led = ~(show_addr ? address[5:0] : leds[5:0]);
endmodule
