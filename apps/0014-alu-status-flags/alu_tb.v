`timescale 1ns / 1ps

module alu_tb;
    `include "alu_ops.vh"

    reg  [3:0] op       = 4'd0;
    reg  [7:0] a        = 8'h00;
    reg  [7:0] b        = 8'h00;
    reg        carry_in = 1'b0;

    wire [7:0] result;
    wire       carry_out;
    wire       zero;
    wire       negative;
    wire       overflow;

    wire [7:0] naive_result;
    wire       naive_carry;
    wire       naive_zero;
    wire       naive_negative;
    wire       naive_overflow;

    alu uut (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out),
        .zero(zero),
        .negative(negative),
        .overflow(overflow)
    );

    alu_naive ref_naive (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(naive_result),
        .carry_out(naive_carry),
        .zero(naive_zero),
        .negative(naive_negative),
        .overflow(naive_overflow)
    );

    task check_vector;
        input [3:0] t_op;
        input [7:0] t_a;
        input [7:0] t_b;
        input       t_cin;
        input [7:0] exp_res;
        input       exp_c;
        input       exp_z;
        input       exp_n;
        input       exp_v;
        begin
            op       = t_op;
            a        = t_a;
            b        = t_b;
            carry_in = t_cin;
            #1;
            if (result !== exp_res || carry_out !== exp_c ||
                zero !== exp_z || negative !== exp_n || overflow !== exp_v) begin
                $display(
                    "FAIL directed op=%0d a=%02X b=%02X cin=%b -> got res=%02X C=%b Z=%b N=%b V=%b",
                    t_op, t_a, t_b, t_cin, result, carry_out, zero, negative, overflow
                );
                $fatal(1);
            end
        end
    endtask

    integer i_op;
    integer i_a;
    integer i_b;
    integer i_cin;
    integer total_checked;
    reg [8:0] ref_sum;
    reg [7:0] exp_r;
    reg       exp_c;
    reg       exp_z;
    reg       exp_n;
    reg       exp_v;

    initial begin
        $dumpfile("build/alu.vcd");
        $dumpvars(0, alu_tb);

        // Directed flag edge cases captured in VCD for Surfer
        check_vector(ALU_ADD,  8'h7F, 8'h01, 1'b0, 8'h80, 1'b0, 1'b0, 1'b1, 1'b1);
        check_vector(ALU_ADD,  8'h80, 8'h80, 1'b0, 8'h00, 1'b1, 1'b1, 1'b0, 1'b1);
        check_vector(ALU_ADD,  8'hFF, 8'h01, 1'b0, 8'h00, 1'b1, 1'b1, 1'b0, 1'b0);
        check_vector(ALU_SUB,  8'h80, 8'h01, 1'b1, 8'h7F, 1'b1, 1'b0, 1'b0, 1'b1);
        check_vector(ALU_SUB,  8'h00, 8'h01, 1'b1, 8'hFF, 1'b0, 1'b0, 1'b1, 1'b0);
        check_vector(ALU_CMP,  8'h40, 8'h40, 1'b0, 8'h00, 1'b1, 1'b1, 1'b0, 1'b0);
        check_vector(ALU_PASS, 8'h55, 8'h00, 1'b1, 8'h00, 1'b0, 1'b1, 1'b0, 1'b0);
        check_vector(ALU_PASS, 8'h55, 8'h80, 1'b1, 8'h80, 1'b0, 1'b0, 1'b1, 1'b0);

        $dumpoff;

        // Exhaustive 13 * 256 * 256 * 2 = 1,703,936 vector verification
        total_checked = 0;
        for (i_op = 0; i_op < 13; i_op = i_op + 1) begin
            for (i_a = 0; i_a < 256; i_a = i_a + 1) begin
                for (i_b = 0; i_b < 256; i_b = i_b + 1) begin
                    for (i_cin = 0; i_cin < 2; i_cin = i_cin + 1) begin
                        op       = i_op[3:0];
                        a        = i_a[7:0];
                        b        = i_b[7:0];
                        carry_in = i_cin[0];
                        #1;

                        exp_c = 1'b0;
                        exp_v = 1'b0;
                        case (i_op)
                            0: begin
                                ref_sum = i_a + i_b + i_cin;
                                exp_r   = ref_sum[7:0];
                                exp_c   = ref_sum[8];
                                exp_v   = (a[7] == b[7]) && (exp_r[7] != a[7]);
                            end
                            1: begin
                                ref_sum = i_a + (8'hFF ^ i_b[7:0]) + i_cin;
                                exp_r   = ref_sum[7:0];
                                exp_c   = ref_sum[8];
                                exp_v   = (a[7] != b[7]) && (exp_r[7] != a[7]);
                            end
                            2: begin
                                ref_sum = i_a + (8'hFF ^ i_b[7:0]) + 1;
                                exp_r   = ref_sum[7:0];
                                exp_c   = ref_sum[8];
                            end
                            3: exp_r = a + 8'd1;
                            4: exp_r = a - 8'd1;
                            5: exp_r = a & b;
                            6: exp_r = a | b;
                            7: exp_r = a ^ b;
                            8: begin
                                exp_r = {a[6:0], 1'b0};
                                exp_c = a[7];
                            end
                            9: begin
                                exp_r = {1'b0, a[7:1]};
                                exp_c = a[0];
                            end
                            10: begin
                                exp_r = {a[6:0], carry_in};
                                exp_c = a[7];
                            end
                            11: begin
                                exp_r = {carry_in, a[7:1]};
                                exp_c = a[0];
                            end
                            default: exp_r = b;
                        endcase
                        exp_z = (exp_r == 8'h00);
                        exp_n = exp_r[7];

                        if (result !== exp_r || carry_out !== exp_c ||
                            zero !== exp_z || negative !== exp_n || overflow !== exp_v) begin
                            $display(
                                "FAIL exhaustive op=%0d a=%02X b=%02X cin=%b",
                                i_op, i_a, i_b, i_cin
                            );
                            $fatal(1);
                        end

                        if (naive_result !== result || naive_carry !== carry_out ||
                            naive_zero !== zero || naive_negative !== negative ||
                            naive_overflow !== overflow) begin
                            $display(
                                "FAIL alu vs alu_naive mismatch op=%0d a=%02X b=%02X cin=%b",
                                i_op, i_a, i_b, i_cin
                            );
                            $fatal(1);
                        end

                        total_checked = total_checked + 1;
                    end
                end
            end
        end

        $display("PASS: alu & alu_naive (%0d vectors across all 13 ops and 4 flags)", total_checked);
        $finish;
    end
endmodule
