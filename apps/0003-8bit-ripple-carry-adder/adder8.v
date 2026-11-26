`timescale 1ns / 1ps

module adder8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] sum,
    output wire       carry_out
);
    wire [6:0] c;

    full_adder u_fa0 (.a(a[0]), .b(b[0]), .carry_in(carry_in), .sum(sum[0]), .carry_out(c[0]));
    full_adder u_fa1 (.a(a[1]), .b(b[1]), .carry_in(c[0]),     .sum(sum[1]), .carry_out(c[1]));
    full_adder u_fa2 (.a(a[2]), .b(b[2]), .carry_in(c[1]),     .sum(sum[2]), .carry_out(c[2]));
    full_adder u_fa3 (.a(a[3]), .b(b[3]), .carry_in(c[2]),     .sum(sum[3]), .carry_out(c[3]));
    full_adder u_fa4 (.a(a[4]), .b(b[4]), .carry_in(c[3]),     .sum(sum[4]), .carry_out(c[4]));
    full_adder u_fa5 (.a(a[5]), .b(b[5]), .carry_in(c[4]),     .sum(sum[5]), .carry_out(c[5]));
    full_adder u_fa6 (.a(a[6]), .b(b[6]), .carry_in(c[5]),     .sum(sum[6]), .carry_out(c[6]));
    full_adder u_fa7 (.a(a[7]), .b(b[7]), .carry_in(c[6]),     .sum(sum[7]), .carry_out(carry_out));
endmodule
