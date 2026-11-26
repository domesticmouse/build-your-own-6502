`timescale 1ns / 1ps

module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire [7:0] a = s1 ? 8'hFA : 8'h15;
    wire [7:0] b = 8'h23;
    wire       carry_in = 1'b0;

    wire [7:0] sum;
    wire       carry_out;

    adder8 u_adder8 (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    wire [3:0] nibble = s2 ? sum[7:4] : sum[3:0];
    wire [5:0] display = {s2, carry_out, nibble};

    assign led = ~display;
endmodule
