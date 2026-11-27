`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;

    top #(.FRAME_DIV(1)) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        #1;
        if (led !== 6'b111111) begin
            $display("FAIL: initial LEDs should be all off (6'b111111), got %b", led);
            $fatal(1);
        end

        // Advance one full 800x525 frame (420,000 clocks)
        repeat (420000) @(posedge clk);
        #1;
        if (led !== 6'b111110) begin
            $display("FAIL: after 1 frame, led should be 6'b111110 (count=1), got %b", led);
            $fatal(1);
        end

        // Hold S2 to inspect live pattern/sync signals (x=0, y=0, mode=1 -> red border r[7]=1, g[7]=0, b[7]=0, visible=1, ~hsync=0, ~vsync=0)
        s2 = 1'b1;
        #1;
        if (led !== ~6'b100100) begin
            $display("FAIL: s2 live peek at (0,0) expected %b, got %b", ~6'b100100, led);
            $fatal(1);
        end

        // Assert reset via S1
        s2 = 1'b0;
        s1 = 1'b1;
        @(posedge clk);
        #1;
        if (led !== 6'b111111) begin
            $display("FAIL: reset should clear frame_count to 0 (led=6'b111111), got %b", led);
            $fatal(1);
        end

        $display("PASS: top VGA raster integration and frame counter verified");
        $finish;
    end
endmodule
