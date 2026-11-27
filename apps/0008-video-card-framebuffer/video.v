`timescale 1ns / 1ps

module video (
    input  wire       clk,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       visible,
    input  wire       hsync,
    input  wire       vsync,
    input  wire [3:0] border_color,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b,
    output reg        visible_out = 1'b0,
    output reg        hsync_out   = 1'b1,
    output reg        vsync_out   = 1'b1
);
    // 320x200 scaled 2x2 inside 640x480 leaves 40-line top and bottom borders
    wire       in_image = visible && (y >= 10'd40) && (y < 10'd440);
    wire [8:0] vx       = x[9:1];
    wire [9:0] vy_full  = y - 10'd40;
    wire [7:0] vy       = vy_full[8:1];

    // Shift-and-add *40 addressing: n*40 = (n << 5) + (n << 3)
    wire [12:0] bitmap_addr = in_image
        ? (({5'd0, vy} << 5) + ({5'd0, vy} << 3) + {7'd0, vx[8:3]})
        : 13'd0;
    wire [9:0] color_addr = in_image
        ? (({5'd0, vy[7:3]} << 5) + ({5'd0, vy[7:3]} << 3) + {4'd0, vx[8:3]})
        : 10'd0;

    // Synchronous Block RAM (infers 5 Gowin SP primitives)
    reg [7:0] bitmap_mem [0:7999];
    reg [7:0] color_mem  [0:999];

    initial begin
        $readmemh("bitmap.mem", bitmap_mem);
        $readmemh("color.mem", color_mem);
    end

    reg [7:0] bitmap_byte = 8'd0;
    reg [7:0] color_byte  = 8'd0;
    reg       in_image_d1 = 1'b0;
    reg [2:0] bit_sel_d1  = 3'd0;

    // 1-tick pipeline alignment matching synchronous Block RAM read latency
    always @(posedge clk) begin
        bitmap_byte <= bitmap_mem[bitmap_addr];
        color_byte  <= color_mem[color_addr];
        visible_out <= visible;
        hsync_out   <= hsync;
        vsync_out   <= vsync;
        in_image_d1 <= in_image;
        bit_sel_d1  <= 3'd7 - vx[2:0];
    end

    wire       pixel_bit = bitmap_byte[bit_sel_d1];
    wire [3:0] color_idx = in_image_d1
        ? (pixel_bit ? color_byte[7:4] : color_byte[3:0])
        : border_color;

    wire [7:0] pal_r;
    wire [7:0] pal_g;
    wire [7:0] pal_b;

    palette u_palette (
        .index(color_idx),
        .r(pal_r),
        .g(pal_g),
        .b(pal_b)
    );

    assign r = visible_out ? pal_r : 8'd0;
    assign g = visible_out ? pal_g : 8'd0;
    assign b = visible_out ? pal_b : 8'd0;
endmodule
