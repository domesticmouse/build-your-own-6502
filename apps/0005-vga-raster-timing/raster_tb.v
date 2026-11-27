`timescale 1ns / 1ps

module raster_tb;
    reg        clk   = 1'b0;
    reg        reset = 1'b0;
    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;

    raster dut (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .frame_end(frame_end)
    );

    always #5 clk = ~clk;

    integer cycle;
    integer visible_count   = 0;
    integer hsync_low_count = 0;
    integer vsync_low_count = 0;
    integer frame_end_count = 0;

    initial begin
        $dumpfile("build/raster.vcd");
        $dumpvars(0, raster_tb);

        for (cycle = 0; cycle < 420000; cycle = cycle + 1) begin
            if (cycle == 1600) begin
                $dumpoff;
            end
            #1;
            if (visible)   visible_count   = visible_count + 1;
            if (!hsync)    hsync_low_count = hsync_low_count + 1;
            if (!vsync)    vsync_low_count = vsync_low_count + 1;
            if (frame_end) frame_end_count = frame_end_count + 1;

            if (x == 10'd656 && hsync !== 1'b0) begin
                $display("FAIL: hsync should be low at x=656");
                $fatal(1);
            end
            if (x == 10'd752 && hsync !== 1'b1) begin
                $display("FAIL: hsync should return high at x=752");
                $fatal(1);
            end
            if (y == 10'd490 && vsync !== 1'b0) begin
                $display("FAIL: vsync should be low at y=490");
                $fatal(1);
            end
            if (y == 10'd492 && vsync !== 1'b1) begin
                $display("FAIL: vsync should return high at y=492");
                $fatal(1);
            end

            @(posedge clk);
        end

        #1;
        if (x !== 10'd0 || y !== 10'd0) begin
            $display("FAIL: expected wrap to (0,0), got (%0d,%0d)", x, y);
            $fatal(1);
        end
        if (visible_count !== 307200) begin
            $display("FAIL: visible_count=%0d expected 307200", visible_count);
            $fatal(1);
        end
        if (hsync_low_count !== 50400) begin
            $display("FAIL: hsync_low_count=%0d expected 50400", hsync_low_count);
            $fatal(1);
        end
        if (vsync_low_count !== 1600) begin
            $display("FAIL: vsync_low_count=%0d expected 1600", vsync_low_count);
            $fatal(1);
        end
        if (frame_end_count !== 1) begin
            $display("FAIL: frame_end_count=%0d expected 1", frame_end_count);
            $fatal(1);
        end

        // Advance mid-frame and verify synchronous reset
        repeat (1000) @(posedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        if (x !== 10'd0 || y !== 10'd0) begin
            $display("FAIL: reset did not return raster to (0,0)");
            $fatal(1);
        end

        $display("PASS: raster 640x480@60Hz timing verified (%0d visible pixels, %0d hsync ticks, %0d vsync ticks)",
                 visible_count, hsync_low_count, vsync_low_count);
        $finish;
    end
endmodule
