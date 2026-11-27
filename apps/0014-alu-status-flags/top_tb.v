`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;

    top #(
        .STEP_PERIOD(2)
    ) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    always #5 clk = ~clk;

    task run_clocks;
        input integer count;
        integer k;
        begin
            for (k = 0; k < count; k = k + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        s1 = 1'b1;
        run_clocks(4);
        s1 = 1'b0;
        run_clocks(2);

        // Vector 0: 0x7F + 0x01 = 0x80 -> N=1, V=1, Z=0, C=0 -> 4'b1100
        if (led !== ~6'b00_1100) begin
            $display("FAIL vec 0 flags: expected ~6'b001100, got %b", led);
            $fatal(1);
        end

        // Vector 1: 0xFF + 0x01 = 0x00 -> N=0, V=0, Z=1, C=1 -> 4'b0011
        run_clocks(3);
        if (led !== ~6'b00_0011) begin
            $display("FAIL vec 1 flags: expected ~6'b000011, got %b", led);
            $fatal(1);
        end

        // Vector 2: 0x80 - 0x01 = 0x7F -> N=0, V=1, Z=0, C=1; with S2=1 -> result[5:0]=6'h3F
        s2 = 1'b1;
        run_clocks(2);
        if (led !== ~6'h3F) begin
            $display("FAIL vec 2 result: expected ~6'h3F, got %b", led);
            $fatal(1);
        end

        $display("PASS: top (N, V, Z, C flag stepper and S2 result view verified)");
        $finish;
    end
endmodule
