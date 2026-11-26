`timescale 1ns / 1ps

module top_tb;
    reg        s1 = 1'b0;
    reg        s2 = 1'b0;
    wire [5:0] led;

    top dut (
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    task check_gates(
        input reg       in_s1,
        input reg       in_s2,
        input reg [5:0] exp_gates
    );
        begin
            s1 = in_s1;
            s2 = in_s2;
            #10;
            if (led !== ~exp_gates) begin
                $fatal(
                    1,
                    "top mismatch for s1=%b s2=%b: got led=%b expected led=%b",
                    s1, s2, led, ~exp_gates
                );
            end
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        check_gates(1'b0, 1'b0, 6'b111000);
        check_gates(1'b0, 1'b1, 6'b001101);
        check_gates(1'b1, 1'b0, 6'b001101);
        check_gates(1'b1, 1'b1, 6'b100110);

        $display("PASS: all 4 top-level 6-gate and active-low LED cases passed");
        $finish;
    end
endmodule
