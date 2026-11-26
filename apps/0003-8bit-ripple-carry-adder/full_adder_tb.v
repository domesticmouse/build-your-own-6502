`timescale 1ns / 1ps

module full_adder_tb;
    reg  a = 1'b0;
    reg  b = 1'b0;
    reg  carry_in = 1'b0;
    wire sum;
    wire carry_out;

    full_adder dut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    integer ia, ib, ic;
    reg [1:0] expected;

    initial begin
        $dumpfile("build/full_adder.vcd");
        $dumpvars(0, full_adder_tb);

        for (ia = 0; ia < 2; ia = ia + 1) begin
            for (ib = 0; ib < 2; ib = ib + 1) begin
                for (ic = 0; ic < 2; ic = ic + 1) begin
                    a = ia[0];
                    b = ib[0];
                    carry_in = ic[0];
                    #10;
                    expected = {1'b0, a} + {1'b0, b} + {1'b0, carry_in};
                    if ({carry_out, sum} !== expected) begin
                        $fatal(
                            1,
                            "full_adder mismatch for a=%b b=%b cin=%b: got %b%b expected %b",
                            a, b, carry_in, carry_out, sum, expected
                        );
                    end
                end
            end
        end

        $display("PASS: all 8 full_adder truth-table cases passed");
        $finish;
    end
endmodule
