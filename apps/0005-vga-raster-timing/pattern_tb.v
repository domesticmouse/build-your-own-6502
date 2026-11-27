`timescale 1ns / 1ps

module pattern_tb;
    reg  [9:0] x       = 10'd0;
    reg  [9:0] y       = 10'd0;
    reg        visible = 1'b0;
    reg        mode    = 1'b0;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    pattern dut (
        .x(x),
        .y(y),
        .visible(visible),
        .mode(mode),
        .r(r),
        .g(g),
        .b(b)
    );

    reg [7:0] frame_r [0:479][0:639];
    reg [7:0] frame_g [0:479][0:639];
    reg [7:0] frame_b [0:479][0:639];

    task automatic write_bmp(input [8*64-1:0] filename);
        integer fd;
        integer row;
        integer col;
        integer file_size;
        integer img_size;
        begin
            img_size  = 640 * 480 * 3;
            file_size = 54 + img_size;
            fd = $fopen(filename, "wb");
            if (fd == 0) begin
                $display("FAIL: could not open BMP file");
                $fatal(1);
            end

            // 14-byte BITMAPFILEHEADER
            $fwrite(fd, "%c%c", 8'h42, 8'h4D);
            $fwrite(fd, "%c%c%c%c", file_size[7:0], file_size[15:8], file_size[23:16], file_size[31:24]);
            $fwrite(fd, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(fd, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);

            // 40-byte BITMAPINFOHEADER (640x480, 24bpp, bottom-up)
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

    task automatic check_pixel(
        input [9:0] px,
        input [9:0] py,
        input       pvis,
        input       pmode,
        input [7:0] exp_r,
        input [7:0] exp_g,
        input [7:0] exp_b
    );
        begin
            x = px; y = py; visible = pvis; mode = pmode;
            #1;
            if (r !== exp_r || g !== exp_g || b !== exp_b) begin
                $display("FAIL: (%0d,%0d) vis=%0d mode=%0d got #%02x%02x%02x expected #%02x%02x%02x",
                         px, py, pvis, pmode, r, g, b, exp_r, exp_g, exp_b);
                $fatal(1);
            end
        end
    endtask

    integer ry, rx;

    initial begin
        // Blanking must always output black
        check_pixel(10'd10, 10'd10, 1'b0, 1'b0, 8'h00, 8'h00, 8'h00);
        check_pixel(10'd10, 10'd10, 1'b0, 1'b1, 8'h00, 8'h00, 8'h00);

        // Mode 0: 8 vertical colour bars
        check_pixel(10'd0,   10'd100, 1'b1, 1'b0, 8'hFF, 8'hFF, 8'hFF);
        check_pixel(10'd80,  10'd100, 1'b1, 1'b0, 8'hFF, 8'hFF, 8'h00);
        check_pixel(10'd160, 10'd100, 1'b1, 1'b0, 8'h00, 8'hFF, 8'hFF);
        check_pixel(10'd240, 10'd100, 1'b1, 1'b0, 8'h00, 8'hFF, 8'h00);
        check_pixel(10'd320, 10'd100, 1'b1, 1'b0, 8'hFF, 8'h00, 8'hFF);
        check_pixel(10'd400, 10'd100, 1'b1, 1'b0, 8'hFF, 8'h00, 8'h00);
        check_pixel(10'd480, 10'd100, 1'b1, 1'b0, 8'h00, 8'h00, 8'hFF);
        check_pixel(10'd560, 10'd100, 1'b1, 1'b0, 8'h00, 8'h00, 8'h00);

        // Mode 1: border + 32x32 checkerboard
        check_pixel(10'd0,  10'd0,  1'b1, 1'b1, 8'hFF, 8'h20, 8'h20);
        check_pixel(10'd10, 10'd10, 1'b1, 1'b1, 8'h10, 8'h20, 8'h40);
        check_pixel(10'd32, 10'd10, 1'b1, 1'b1, 8'hFF, 8'hFF, 8'hFF);

        // Render and dump both full 640x480 BMP frames
        mode = 1'b0; visible = 1'b1;
        for (ry = 0; ry < 480; ry = ry + 1) begin
            for (rx = 0; rx < 640; rx = rx + 1) begin
                x = rx[9:0]; y = ry[9:0];
                #1;
                frame_r[ry][rx] = r;
                frame_g[ry][rx] = g;
                frame_b[ry][rx] = b;
            end
        end
        write_bmp("build/bars.bmp");

        mode = 1'b1; visible = 1'b1;
        for (ry = 0; ry < 480; ry = ry + 1) begin
            for (rx = 0; rx < 640; rx = rx + 1) begin
                x = rx[9:0]; y = ry[9:0];
                #1;
                frame_r[ry][rx] = r;
                frame_g[ry][rx] = g;
                frame_b[ry][rx] = b;
            end
        end
        write_bmp("build/checker.bmp");

        $display("PASS: pattern bars and checkerboard verified and dumped to build/bars.bmp & build/checker.bmp");
        $finish;
    end
endmodule
