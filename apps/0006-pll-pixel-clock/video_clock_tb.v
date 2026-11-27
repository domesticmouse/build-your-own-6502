`timescale 1ns / 1ps

module video_clock_tb;
    reg  clk_27m = 1'b0;
    wire clk_serial;
    wire clk_pixel;
    wire locked;

    video_clock dut (
        .clk_27m(clk_27m),
        .clk_serial(clk_serial),
        .clk_pixel(clk_pixel),
        .locked(locked)
    );

    // 27.0 MHz half-period = 18.519 ns
    always #18.519 clk_27m = ~clk_27m;

    integer serial_edges = 0;
    integer pixel_edges  = 0;

    always @(posedge clk_serial) begin
        if (locked) serial_edges = serial_edges + 1;
    end

    always @(posedge clk_pixel) begin
        if (locked) pixel_edges = pixel_edges + 1;
    end

    initial begin
        $dumpfile("build/video_clock.vcd");
        $dumpvars(0, video_clock_tb);

        #1;
        if (locked !== 1'b0) begin
            $display("FAIL: PLL should start unlocked");
            $fatal(1);
        end
        if (clk_pixel !== 1'b0) begin
            $display("FAIL: clk_pixel should stay low while PLL is unlocked");
            $fatal(1);
        end

        @(posedge locked);
        @(posedge clk_pixel);
        #1;
        serial_edges = 0;
        pixel_edges  = 0;

        repeat (20) @(posedge clk_pixel);
        #1;
        if (pixel_edges !== 20 || serial_edges !== 100) begin
            $display("FAIL: expected 100 serial edges for 20 pixel edges (5:1), got %0d:%0d",
                     serial_edges, pixel_edges);
            $fatal(1);
        end

        $display("PASS: video_clock locked cleanly with exact 5:1 serial-to-pixel ratio (%0d:%0d)",
                 serial_edges, pixel_edges);
        $finish;
    end
endmodule
