`timescale 1ns / 1ps

module timer_tb;
    reg  clk = 1'b0;
    reg  reset = 1'b0;
    wire tick;

    always #5 clk = ~clk;

    timer #(.PERIOD(4)) dut (
        .clk(clk),
        .reset(reset),
        .tick(tick)
    );

    integer cycle;
    reg exp_tick;

    initial begin
        $dumpfile("build/timer.vcd");
        $dumpvars(0, timer_tb);

        reset = 1'b1;
        @(posedge clk);
        #1;
        if (tick !== 1'b0) begin
            $fatal(1, "timer tick should be 0 during reset");
        end

        reset = 1'b0;
        for (cycle = 1; cycle <= 12; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            exp_tick = ((cycle % 4) == 0) ? 1'b1 : 1'b0;
            if (tick !== exp_tick) begin
                $fatal(1, "timer mismatch on cycle %0d: got tick=%b expected %b", cycle, tick, exp_tick);
            end
        end

        $display("PASS: timer emitted single-cycle tick every 4 clocks");
        $finish;
    end
endmodule
