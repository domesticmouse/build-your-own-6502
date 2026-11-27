`timescale 1ns / 1ps

module alu (
    input  wire [3:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out
);
    `include "alu_ops.vh"

    wire [7:0] second =
        (op == ALU_ADD) ? b :
        (op == ALU_SUB) ? ~b :
        (op == ALU_CMP) ? ~b :
        (op == ALU_DEC) ? 8'hFF :
                          8'h00;

    wire adder_cin =
        (op == ALU_ADD || op == ALU_SUB) ? carry_in :
        (op == ALU_CMP || op == ALU_INC) ? 1'b1 :
                                           1'b0;

    wire [8:0] adder_sum   = {1'b0, a} + {1'b0, second} + {8'd0, adder_cin};
    wire [7:0] sum         = adder_sum[7:0];
    wire       adder_carry = adder_sum[8];

    assign result =
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP || op == ALU_INC || op == ALU_DEC) ? sum :
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
        (op == ALU_ADD || op == ALU_SUB || op == ALU_CMP) ? adder_carry :
        (op == ALU_ASL || op == ALU_ROL)                  ? a[7] :
        (op == ALU_LSR || op == ALU_ROR)                  ? a[0] :
                                                            1'b0;
endmodule
