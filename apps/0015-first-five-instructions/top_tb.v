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

        // Wait for STARTING (3 clocks) + OPCODE of LDA #$00 (2 clocks) -> opcode=$A9
        run_clocks(5);
        if (led !== ~6'h29) begin
            $display("FAIL LDA opcode: expected ~6'h29, got %b", led);
            $fatal(1);
        end

        // 4 clocks later: OPCODE of STA $8000 -> opcode=$8D
        run_clocks(4);
        if (led !== ~6'h0D) begin
            $display("FAIL STA opcode: expected ~6'h0D, got %b", led);
            $fatal(1);
        end

        // Switch S2=1 to inspect address[5:0] at OPERAND of STA ($C004 -> 6'h04)
        s2 = 1'b1;
        run_clocks(2);
        if (led !== ~6'h04) begin
            $display("FAIL address view: expected ~6'h04, got %b", led);
            $fatal(1);
        end

        $display("PASS: top (five-instruction sequencer opcode and address LED view verified)");
        $finish;
    end
endmodule
