`timescale 1ns / 1ps

module half_adder_tb;
    reg  a = 1'b0;
    reg  b = 1'b0;
    wire sum;
    wire carry;

    half_adder dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry(carry)
    );

    task check_case(
        input reg in_a,
        input reg in_b,
        input reg exp_sum,
        input reg exp_carry
    );
        begin
            a = in_a;
            b = in_b;
            #10;
            if (sum !== exp_sum || carry !== exp_carry) begin
                $fatal(
                    1,
                    "half_adder mismatch for a=%b b=%b: got sum=%b carry=%b expected sum=%b carry=%b",
                    a, b, sum, carry, exp_sum, exp_carry
                );
            end
        end
    endtask

    initial begin
        $dumpfile("build/half_adder.vcd");
        $dumpvars(0, half_adder_tb);

        check_case(1'b0, 1'b0, 1'b0, 1'b0);
        check_case(1'b0, 1'b1, 1'b1, 1'b0);
        check_case(1'b1, 1'b0, 1'b1, 1'b0);
        check_case(1'b1, 1'b1, 1'b0, 1'b1);

        $display("PASS: all 4 half_adder truth-table cases passed");
        $finish;
    end
endmodule
