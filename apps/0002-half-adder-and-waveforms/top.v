`timescale 1ns / 1ps

module top (
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire sum;
    wire carry;

    half_adder u_half_adder (
        .a(s1),
        .b(s2),
        .sum(sum),
        .carry(carry)
    );

    wire [5:0] gates;
    assign gates[0] = sum;
    assign gates[1] = carry;
    assign gates[2] = s1 | s2;
    assign gates[3] = ~(s1 & s2);
    assign gates[4] = ~(s1 | s2);
    assign gates[5] = s1 ~^ s2;

    assign led = ~gates;
endmodule
