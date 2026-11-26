`timescale 1ns / 1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire carry_in,
    output wire sum,
    output wire carry_out
);
    wire s1;
    wire c1;
    wire c2;

    half_adder u_ha1 (
        .a(a),
        .b(b),
        .sum(s1),
        .carry(c1)
    );

    half_adder u_ha2 (
        .a(s1),
        .b(carry_in),
        .sum(sum),
        .carry(c2)
    );

    assign carry_out = c1 | c2;
endmodule
