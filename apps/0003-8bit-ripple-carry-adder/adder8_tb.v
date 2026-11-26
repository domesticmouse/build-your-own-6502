`timescale 1ns / 1ps

module adder8_tb;
    reg  [7:0] a = 8'h00;
    reg  [7:0] b = 8'h00;
    reg        carry_in = 1'b0;
    wire [7:0] sum;
    wire       carry_out;

    adder8 dut (
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .sum(sum),
        .carry_out(carry_out)
    );

    task show_case(
        input reg [7:0] in_a,
        input reg [7:0] in_b,
        input reg       in_cin
    );
        reg [8:0] expected;
        begin
            a = in_a;
            b = in_b;
            carry_in = in_cin;
            #10;
            expected = {1'b0, a} + {1'b0, b} + {8'd0, carry_in};
            if ({carry_out, sum} !== expected) begin
                $fatal(
                    1,
                    "adder8 mismatch for a=%02h b=%02h cin=%b: got %b_%02h expected %b_%02h",
                    a, b, carry_in, carry_out, sum, expected[8], expected[7:0]
                );
            end
        end
    endtask

    integer ia, ib, ic;
    integer checked;
    reg [8:0] expected;

    initial begin
        $dumpfile("build/adder8.vcd");
        $dumpvars(0, adder8_tb);

        show_case(8'h00, 8'h00, 1'b0);
        show_case(8'h15, 8'h23, 1'b0);
        show_case(8'hFA, 8'h23, 1'b0);
        show_case(8'hFF, 8'h00, 1'b1);
        show_case(8'hFF, 8'hFF, 1'b1);

        $dumpoff;

        checked = 0;
        for (ia = 0; ia < 256; ia = ia + 1) begin
            for (ib = 0; ib < 256; ib = ib + 1) begin
                for (ic = 0; ic < 2; ic = ic + 1) begin
                    a = ia[7:0];
                    b = ib[7:0];
                    carry_in = ic[0];
                    #1;
                    expected = {1'b0, a} + {1'b0, b} + {8'd0, carry_in};
                    if ({carry_out, sum} !== expected) begin
                        $fatal(
                            1,
                            "adder8 mismatch for a=%02h b=%02h cin=%b: got %b_%02h expected %b_%02h",
                            a, b, carry_in, carry_out, sum, expected[8], expected[7:0]
                        );
                    end
                    checked = checked + 1;
                end
            end
        end

        $display("PASS: all %0d exhaustive adder8 cases passed", checked);
        $finish;
    end
endmodule
