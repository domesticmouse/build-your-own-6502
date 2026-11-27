`timescale 1ns / 1ps

module alu_naive (
    input  wire [3:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out,
    output wire       zero,
    output wire       negative,
    output wire       overflow
);
    `include "alu_ops.vh"

    wire [8:0] add_sum = {1'b0, a} + {1'b0, b} + {8'd0, carry_in};
    wire [8:0] sub_sum = {1'b0, a} - {1'b0, b} - {8'd0, ~carry_in};
    wire [8:0] cmp_sum = {1'b0, a} - {1'b0, b};
    wire [7:0] inc_res = a + 8'd1;
    wire [7:0] dec_res = a - 8'd1;

    assign result =
        (op == ALU_ADD)  ? add_sum[7:0] :
        (op == ALU_SUB)  ? sub_sum[7:0] :
        (op == ALU_CMP)  ? cmp_sum[7:0] :
        (op == ALU_INC)  ? inc_res :
        (op == ALU_DEC)  ? dec_res :
        (op == ALU_AND)  ? (a & b) :
        (op == ALU_ORA)  ? (a | b) :
        (op == ALU_EOR)  ? (a ^ b) :
        (op == ALU_ASL)  ? {a[6:0], 1'b0} :
        (op == ALU_LSR)  ? {1'b0, a[7:1]} :
        (op == ALU_ROL)  ? {a[6:0], carry_in} :
        (op == ALU_ROR)  ? {carry_in, a[7:1]} :
        (op == ALU_PASS) ? b :
                           8'h00;

    assign carry_out =
        (op == ALU_ADD)                  ? add_sum[8] :
        (op == ALU_SUB)                  ? ~sub_sum[8] :
        (op == ALU_CMP)                  ? ~cmp_sum[8] :
        (op == ALU_ASL || op == ALU_ROL) ? a[7] :
        (op == ALU_LSR || op == ALU_ROR) ? a[0] :
                                           1'b0;

    assign zero     = (result == 8'h00);
    assign negative = result[7];
    assign overflow =
        (op == ALU_ADD) ? ((a[7] == b[7]) && (add_sum[7] != a[7])) :
        (op == ALU_SUB) ? ((a[7] != b[7]) && (sub_sum[7] != a[7])) :
                          1'b0;
endmodule
