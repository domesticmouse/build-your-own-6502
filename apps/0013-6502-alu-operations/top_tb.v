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
        // Two clocks for rst_sync to drop reset=0
        run_clocks(2);

        // Vector 0: ADD 0x12 + 0x15 = 0x27
        if (led !== ~6'h27) begin
            $display("FAIL vec 0: expected ~6'h27, got %b", led);
            $fatal(1);
        end

        // 3 clocks: count=1, tick=1, vec_idx<=1 (SUB 0x30 - 0x0A = 0x26)
        run_clocks(3);
        if (led !== ~6'h26) begin
            $display("FAIL vec 1: expected ~6'h26, got %b", led);
            $fatal(1);
        end

        // 2 clocks: tick=1, vec_idx<=2 (CMP 0x25 vs 0x25 -> result=0x00, carry=1); S2 -> {1, 0, op=2}
        s2 = 1'b1;
        run_clocks(2);
        if (led !== ~6'b10_0010) begin
            $display("FAIL meta view: expected ~6'b100010 (vec 2 CMP carry=1), got %b", led);
            $fatal(1);
        end

        $display("PASS: top (ALU vector stepper and S2 meta view verified)");
        $finish;
    end
endmodule
