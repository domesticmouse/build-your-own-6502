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

    task check_case(
        input reg       in_s1,
        input reg       in_s2,
        input reg [5:0] exp_display
    );
        begin
            s1 = in_s1;
            s2 = in_s2;
            #10;
            if (led !== ~exp_display) begin
                $fatal(
                    1,
                    "top mismatch for s1=%b s2=%b: got led=%b expected led=%b",
                    s1, s2, led, ~exp_display
                );
            end
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        check_case(1'b0, 1'b0, 6'b00_1000);
        check_case(1'b0, 1'b1, 6'b10_0011);
        check_case(1'b1, 1'b0, 6'b01_1101);
        check_case(1'b1, 1'b1, 6'b11_0001);

        $display("PASS: all 4 top-level adder8 + mux LED cases passed");
        $finish;
    end
endmodule
