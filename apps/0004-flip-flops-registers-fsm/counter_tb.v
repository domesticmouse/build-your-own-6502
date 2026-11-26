`timescale 1ns / 1ps

module counter_tb;
    reg        clk = 1'b0;
    reg        reset = 1'b0;
    reg        enable = 1'b0;
    wire [7:0] count;

    always #5 clk = ~clk;

    counter dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .count(count)
    );

    integer i;

    initial begin
        $dumpfile("build/counter.vcd");
        $dumpvars(0, counter_tb);

        enable = 1'b0;
        @(posedge clk);
        #1;
        if (count !== 8'd0) begin
            $fatal(1, "counter should hold 0 when enable=0, got %02h", count);
        end

        enable = 1'b1;
        for (i = 1; i <= 5; i = i + 1) begin
            @(posedge clk);
            #1;
            if (count !== i[7:0]) begin
                $fatal(1, "counter mismatch: got %02h expected %02h", count, i[7:0]);
            end
        end

        enable = 1'b0;
        @(posedge clk);
        #1;
        if (count !== 8'd5) begin
            $fatal(1, "counter failed to hold at 5, got %02h", count);
        end

        reset = 1'b1;
        enable = 1'b1;
        @(posedge clk);
        #1;
        if (count !== 8'd0) begin
            $fatal(1, "counter reset priority failed, got %02h", count);
        end

        reset = 1'b0;
        enable = 1'b1;
        for (i = 1; i <= 256; i = i + 1) begin
            @(posedge clk);
            #1;
        end
        if (count !== 8'd0) begin
            $fatal(1, "counter wraparound to 00 failed, got %02h", count);
        end

        $display("PASS: counter enable, hold, reset priority, and 8-bit wraparound passed");
        $finish;
    end
endmodule
