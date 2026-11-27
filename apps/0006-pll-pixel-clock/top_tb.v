`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;

    // Scale 13.5M / 12.6M down by 900,000 -> 15 and 14 so both 1 Hz LEDs match in simulation
    top #(
        .DIV_27M(15),
        .DIV_25M2(14)
    ) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    always #18.519 clk = ~clk;

    integer toggles_27m   = 0;
    integer toggles_25m2  = 0;
    reg prev_27m  = 1'b1;
    reg prev_25m2 = 1'b1;

    always #5 begin
        if (led[0] !== prev_27m) begin
            toggles_27m = toggles_27m + 1;
            prev_27m    = led[0];
        end
        if (led[1] !== prev_25m2) begin
            toggles_25m2 = toggles_25m2 + 1;
            prev_25m2    = led[1];
        end
    end

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        #200;
        if (led[5] !== 1'b0) begin
            $display("FAIL: led[5] (active-low pll_lock) should be 0 once locked, got %b", led[5]);
            $fatal(1);
        end

        toggles_27m  = 0;
        toggles_25m2 = 0;
        #4000;

        if (toggles_27m < 4 || toggles_25m2 < 4) begin
            $display("FAIL: expected both clock domains to toggle >=4 times, got 27m=%0d 25m2=%0d",
                     toggles_27m, toggles_25m2);
            $fatal(1);
        end

        // Check reset clears outputs via both synchronisers
        s1 = 1'b1;
        #200;
        if (led[1:0] !== 2'b11) begin
            $display("FAIL: reset should turn off both blink LEDs (11), got %b", led[1:0]);
            $fatal(1);
        end

        s1 = 1'b0;
        s2 = 1'b1;
        #200;
        if (led[5] !== 1'b0) begin
            $display("FAIL: led[5] should remain locked during S2 mode");
            $fatal(1);
        end

        $display("PASS: top dual-domain PLL clock outputs verified (27M=%0d toggles, 25.2M=%0d toggles)",
                 toggles_27m, toggles_25m2);
        $finish;
    end
endmodule
