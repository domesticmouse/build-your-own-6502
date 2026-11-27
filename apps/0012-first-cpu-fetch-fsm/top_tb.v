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

    task run_clocks(input integer count);
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

        // Hold reset across 2-FF synchroniser
        s1 = 1'b1;
        run_clocks(4);
        s1 = 1'b0;

        // Wait for STARTING + first OPCODE latch of rom[$C000] = $A9 -> led = ~6'h29
        run_clocks(8);
        if (led !== ~6'h29) begin
            $display("FAIL: expected ~6'h29 ($A9[5:0]), got %b", led);
            $fatal(1);
        end

        // Next step latches rom[$C001] = $00 -> led = ~6'h00
        run_clocks(2);
        if (led !== ~6'h00) begin
            $display("FAIL: expected ~6'h00 ($00[5:0]), got %b", led);
            $fatal(1);
        end

        // Next step latches rom[$C002] = $8D -> led = ~6'h0D
        run_clocks(2);
        if (led !== ~6'h0D) begin
            $display("FAIL: expected ~6'h0D ($8D[5:0]), got %b", led);
            $fatal(1);
        end

        // Switch S2 = 1 to display address[5:0] on LEDs; wait 2 clocks for disp_sync
        s2 = 1'b1;
        run_clocks(2);
        if (led !== ~6'h04) begin
            $display("FAIL: expected ~6'h04 (address $C004[5:0]), got %b", led);
            $fatal(1);
        end

        $display("PASS: top (opcode and address LED display verified with STEP_PERIOD=2)");
        $finish;
    end
endmodule
