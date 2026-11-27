`timescale 1ns / 1ps

module alu_tb;
    `include "alu_ops.vh"

    reg  [3:0] op       = 4'd0;
    reg  [7:0] a        = 8'h00;
    reg  [7:0] b        = 8'h00;
    reg        carry_in = 1'b0;
    wire [7:0] result;
    wire       carry_out;

    alu uut (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out)
    );

    task check_op;
        input [3:0] t_op;
        input [7:0] t_a;
        input [7:0] t_b;
        input       t_cin;
        input [7:0] exp_res;
        input       exp_cout;
        begin
            op       = t_op;
            a        = t_a;
            b        = t_b;
            carry_in = t_cin;
            #5;
            if (result !== exp_res || carry_out !== exp_cout) begin
                $display(
                    "FAIL op=%0d a=%02X b=%02X cin=%b -> got res=%02X cout=%b (expected %02X, %b)",
                    t_op, t_a, t_b, t_cin, result, carry_out, exp_res, exp_cout
                );
                $fatal(1);
            end
        end
    endtask

    initial begin
        $dumpfile("build/alu.vcd");
        $dumpvars(0, alu_tb);

        // ADD: basic, carry-in, and 8-bit wrap
        check_op(ALU_ADD, 8'h12, 8'h34, 1'b0, 8'h46, 1'b0);
        check_op(ALU_ADD, 8'h12, 8'h34, 1'b1, 8'h47, 1'b0);
        check_op(ALU_ADD, 8'hFF, 8'h01, 1'b0, 8'h00, 1'b1);
        check_op(ALU_ADD, 8'hFF, 8'hFF, 1'b1, 8'hFF, 1'b1);

        // SUB: two's complement with inverted borrow (carry_in=1 means no borrow)
        check_op(ALU_SUB, 8'h50, 8'h20, 1'b1, 8'h30, 1'b1);
        check_op(ALU_SUB, 8'h50, 8'h20, 1'b0, 8'h2F, 1'b1);
        check_op(ALU_SUB, 8'h00, 8'h01, 1'b1, 8'hFF, 1'b0);

        // CMP: always forces adder_cin = 1 (ignores carry_in)
        check_op(ALU_CMP, 8'h40, 8'h40, 1'b0, 8'h00, 1'b1);
        check_op(ALU_CMP, 8'h50, 8'h40, 1'b0, 8'h10, 1'b1);
        check_op(ALU_CMP, 8'h30, 8'h40, 1'b1, 8'hF0, 1'b0);

        // INC and DEC: wraparound without altering carry_out
        check_op(ALU_INC, 8'h41, 8'h99, 1'b1, 8'h42, 1'b0);
        check_op(ALU_INC, 8'hFF, 8'h00, 1'b1, 8'h00, 1'b0);
        check_op(ALU_DEC, 8'h42, 8'h99, 1'b1, 8'h41, 1'b0);
        check_op(ALU_DEC, 8'h00, 8'h00, 1'b1, 8'hFF, 1'b0);

        // Bitwise logic
        check_op(ALU_AND, 8'hF0, 8'hAA, 1'b1, 8'hA0, 1'b0);
        check_op(ALU_ORA, 8'hF0, 8'h0A, 1'b1, 8'hFA, 1'b0);
        check_op(ALU_EOR, 8'hFF, 8'hAA, 1'b1, 8'h55, 1'b0);

        // Shifts and rotates
        check_op(ALU_ASL, 8'h85, 8'h00, 1'b1, 8'h0A, 1'b1);
        check_op(ALU_LSR, 8'h85, 8'h00, 1'b1, 8'h42, 1'b1);
        check_op(ALU_ROL, 8'h85, 8'h00, 1'b1, 8'h0B, 1'b1);
        check_op(ALU_ROL, 8'h05, 8'h00, 1'b0, 8'h0A, 1'b0);
        check_op(ALU_ROR, 8'h84, 8'h00, 1'b1, 8'hC2, 1'b0);
        check_op(ALU_ROR, 8'h05, 8'h00, 1'b0, 8'h02, 1'b1);

        // PASS forwards b unchanged
        check_op(ALU_PASS, 8'h12, 8'hA5, 1'b1, 8'hA5, 1'b0);

        $display("PASS: alu (all 13 operations and shared 9-bit adder verified)");
        $finish;
    end
endmodule
