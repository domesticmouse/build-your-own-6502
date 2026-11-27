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

        // Cycle 6 (11 clocks from step 1 + 3 startup) -> STA $8000 writes 0 -> led = ~6'h00
        // Wait 16 clocks to enter loop iteration 1 comfortably, then verify counting 1, 2, 3
        run_clocks(17);
        if (led !== ~6'h00) begin
            $display("FAIL count 0: expected ~6'h00, got %b", led);
            $fatal(1);
        end

        // 11 steps = 22 clocks per loop iteration
        run_clocks(22);
        if (led !== ~6'h01) begin
            $display("FAIL count 1: expected ~6'h01, got %b", led);
            $fatal(1);
        end

        run_clocks(22);
        if (led !== ~6'h02) begin
            $display("FAIL count 2: expected ~6'h02, got %b", led);
            $fatal(1);
        end

        run_clocks(22);
        if (led !== ~6'h03) begin
            $display("FAIL count 3: expected ~6'h03, got %b", led);
            $fatal(1);
        end

        // Switch S2=1 to confirm address[5:0] differs from leds[5:0]
        s2 = 1'b1;
        run_clocks(2);
        if (led === ~6'h03) begin
            $display("FAIL S2 switch: expected address view, still got ~6'h03");
            $fatal(1);
        end

        $display("PASS: top (full 6502 computer counting 0->1->2->3 on LEDs verified)");
        $finish;
    end
endmodule
