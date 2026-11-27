`timescale 1ns / 1ps

module video_tb;
    reg        clk          = 1'b0;
    reg        reset        = 1'b0;
    reg  [3:0] border_color = 4'd14;
    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;

    raster u_raster (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .frame_end(frame_end)
    );

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire       visible_out;
    wire       hsync_out;
    wire       vsync_out;

    video dut (
        .clk(clk),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .border_color(border_color),
        .r(r),
        .g(g),
        .b(b),
        .visible_out(visible_out),
        .hsync_out(hsync_out),
        .vsync_out(vsync_out)
    );

    always #5 clk = ~clk;

    reg [7:0] frame_r [0:479][0:639];
    reg [7:0] frame_g [0:479][0:639];
    reg [7:0] frame_b [0:479][0:639];

    task automatic write_bmp(input [8*64-1:0] filename);
        integer fd, row, col, file_size, img_size;
        begin
            img_size  = 640 * 480 * 3;
            file_size = 54 + img_size;
            fd = $fopen(filename, "wb");
            if (fd == 0) begin
                $display("FAIL: could not open BMP file");
                $fatal(1);
            end
            $fwrite(fd, "%c%c", 8'h42, 8'h4D);
            $fwrite(fd, "%c%c%c%c", file_size[7:0], file_size[15:8], file_size[23:16], file_size[31:24]);
            $fwrite(fd, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'h80, 8'h02, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'hE0, 8'h01, 8'h00, 8'h00);
            $fwrite(fd, "%c%c", 8'h01, 8'h00);
            $fwrite(fd, "%c%c", 8'h18, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", img_size[7:0], img_size[15:8], img_size[23:16], img_size[31:24]);
            $fwrite(fd, "%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c",
                    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00);
            for (row = 479; row >= 0; row = row - 1) begin
                for (col = 0; col < 640; col = col + 1) begin
                    $fwrite(fd, "%c%c%c", frame_b[row][col], frame_g[row][col], frame_r[row][col]);
                end
            end
            $fclose(fd);
        end
    endtask

    integer cycle;
    reg [9:0] prev_x   = 10'd0;
    reg [9:0] prev_y   = 10'd0;
    reg       prev_vis = 1'b0;
    reg       prev_hs  = 1'b1;
    reg       prev_vs  = 1'b1;

    initial begin
        $dumpfile("build/video.vcd");
        $dumpvars(0, video_tb);
        #1;

        // Run one full 800x525 frame (each tick latches (prev_x, prev_y) into video's 1-tick pipeline)
        for (cycle = 0; cycle < 420000; cycle = cycle + 1) begin
            if (cycle == 1600) begin
                $dumpoff;
            end
            prev_x   = x;
            prev_y   = y;
            prev_vis = visible;
            prev_hs  = hsync;
            prev_vs  = vsync;

            @(posedge clk);
            #1;
            if (visible_out !== prev_vis || hsync_out !== prev_hs || vsync_out !== prev_vs) begin
                $display("FAIL: 1-tick sync/visible alignment mismatch at cycle %0d", cycle);
                $fatal(1);
            end
            if (!visible_out && (r !== 8'd0 || g !== 8'd0 || b !== 8'd0)) begin
                $display("FAIL: non-black pixel during blanking at (%0d,%0d)", prev_x, prev_y);
                $fatal(1);
            end
            if (visible_out) begin
                frame_r[prev_y][prev_x] = r;
                frame_g[prev_y][prev_x] = g;
                frame_b[prev_y][prev_x] = b;
            end
        end

        // Verify top/bottom borders are C64 Light Blue (#0088FF)
        if (frame_r[0][0] !== 8'h00 || frame_g[0][0] !== 8'h88 || frame_b[0][0] !== 8'hFF) begin
            $display("FAIL: top border (0,0) expected #0088FF");
            $fatal(1);
        end
        if (frame_r[479][639] !== 8'h00 || frame_g[479][639] !== 8'h88 || frame_b[479][639] !== 8'hFF) begin
            $display("FAIL: bottom border (639,479) expected #0088FF");
            $fatal(1);
        end

        // Verify top-left image pixel (0,40) has ink=0xE (#0088FF) from frame border (zero off-by-one shift)
        if (frame_r[40][0] !== 8'h00 || frame_g[40][0] !== 8'h88 || frame_b[40][0] !== 8'hFF) begin
            $display("FAIL: image origin (0,40) mismatch");
            $fatal(1);
        end
        // Verify interior background pixel (8,48) is C64 Blue (#0000AA)
        if (frame_r[48][8] !== 8'h00 || frame_g[48][8] !== 8'h00 || frame_b[48][8] !== 8'hAA) begin
            $display("FAIL: interior background (8,48) expected #0000AA, got #%02x%02x%02x",
                     frame_r[48][8], frame_g[48][8], frame_b[48][8]);
            $fatal(1);
        end
        // Verify 2x horizontal doubling on adjacent pixels
        if (frame_r[56][128] !== frame_r[56][129] ||
            frame_g[56][128] !== frame_g[56][129] ||
            frame_b[56][128] !== frame_b[56][129]) begin
            $display("FAIL: 2x horizontal pixel doubling mismatch");
            $fatal(1);
        end

        write_bmp("build/frame.bmp");
        $display("PASS: video 320x200 Block RAM pipeline, 1-tick alignment & frame.bmp verified");
        $finish;
    end
endmodule
