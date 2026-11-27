`timescale 1ns / 1ps

module raster (
    input  wire       clk,
    input  wire       reset,
    output reg  [9:0] x = 10'd0,
    output reg  [9:0] y = 10'd0,
    output wire       visible,
    output wire       hsync,
    output wire       vsync,
    output wire       frame_end
);
    localparam [9:0] H_VISIBLE = 10'd640;
    localparam [9:0] H_FRONT   = 10'd16;
    localparam [9:0] H_SYNC    = 10'd96;
    localparam [9:0] H_BACK    = 10'd48;
    localparam [9:0] H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam [9:0] V_VISIBLE = 10'd480;
    localparam [9:0] V_FRONT   = 10'd10;
    localparam [9:0] V_SYNC    = 10'd2;
    localparam [9:0] V_BACK    = 10'd33;
    localparam [9:0] V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk) begin
        if (reset) begin
            x <= 10'd0;
            y <= 10'd0;
        end else if (x == H_TOTAL - 10'd1) begin
            x <= 10'd0;
            if (y == V_TOTAL - 10'd1) begin
                y <= 10'd0;
            end else begin
                y <= y + 10'd1;
            end
        end else begin
            x <= x + 10'd1;
        end
    end

    assign visible = (x < H_VISIBLE) && (y < V_VISIBLE);
    assign hsync = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));
    assign frame_end = (x == H_TOTAL - 10'd1) && (y == V_TOTAL - 10'd1);
endmodule
