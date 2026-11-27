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

        // Step 1: presents $C000, Step 2: latches rom[$C000]=8'hA9 -> led = ~6'h29
        run_clocks(8);
        if (led !== ~6'h29) begin
            $display("FAIL: expected ~6'h29 (ROM $C000 = $A9), got %b", led);
            $fatal(1);
        end

        // Step 3: latches rom[$C001]=8'h00 -> led = ~6'h00
        run_clocks(2);
        if (led !== ~6'h00) begin
            $display("FAIL: expected ~6'h00 (ROM $C001 = $00), got %b", led);
            $fatal(1);
        end

        // Step 4: latches rom[$C002]=8'h8D -> led = ~6'h0D
        run_clocks(2);
        if (led !== ~6'h0D) begin
            $display("FAIL: expected ~6'h0D (ROM $C002 = $8D), got %b", led);
            $fatal(1);
        end

        // Switch to RAM write/read-back mode (S2 = 1).
        // mode_sync takes 2 clocks, plus 1 ROM step (addr_cnt 4 -> 5), then WR/RD/SHOW:
        // addr_cnt=5 writes 5 ^ 5A = 5F -> led = ~6'h1F
        s2 = 1'b1;
        run_clocks(12);
        if (led !== ~6'h1F) begin
            $display("FAIL: expected RAM read-back ~6'h1F (0x5F[5:0]), got %b", led);
            $fatal(1);
        end

        // Next 3 steps write/read addr_cnt=6: 6 ^ 5A = 5C -> led = ~6'h1C
        run_clocks(6);
        if (led !== ~6'h1C) begin
            $display("FAIL: expected RAM read-back ~6'h1C (0x5C[5:0]), got %b", led);
            $fatal(1);
        end

        $display("PASS: top (ROM walk and RAM write/read-back verified with STEP_PERIOD=2)");
        $finish;
    end
endmodule
