`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1 = 1'b0;
    reg        s2 = 1'b0;
    wire [5:0] led;

    always #5 clk = ~clk;

    top #(.TIMER_PERIOD(4)) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    integer i;

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        s1 = 1'b1;
        s2 = 1'b0;
        @(posedge clk);
        #1;
        if (led !== ~6'b000001) begin
            $fatal(1, "top reset scanner mismatch: got %b", led);
        end

        s1 = 1'b0;
        for (i = 0; i < 4; i = i + 1) @(posedge clk);
        #1;
        if (led !== ~6'b000001) begin
            $fatal(1, "scanner stepped too early before tick edge: got %b", led);
        end

        @(posedge clk);
        #1;
        if (led !== ~6'b000010) begin
            $fatal(1, "scanner step 1 mismatch: got %b expected %b", led, ~6'b000010);
        end

        for (i = 0; i < 4; i = i + 1) @(posedge clk);
        #1;
        if (led !== ~6'b000100) begin
            $fatal(1, "scanner step 2 mismatch: got %b expected %b", led, ~6'b000100);
        end

        s2 = 1'b1;
        #1;
        if (led !== ~6'b000010) begin
            $fatal(1, "counter view mismatch at step 2: got %b expected %b", led, ~6'b000010);
        end

        s1 = 1'b1;
        @(posedge clk);
        #1;
        if (led !== ~6'b000000) begin
            $fatal(1, "counter reset mismatch: got %b expected %b", led, ~6'b000000);
        end

        $display("PASS: top-level single-clock timer, scanner, counter, and reset passed");
        $finish;
    end
endmodule
