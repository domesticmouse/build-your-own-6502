`timescale 1ns / 1ps

module top #(
    parameter integer FRAME_DIV = 8
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    wire       reset = s1;
    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

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

    pattern u_pattern (
        .x(x),
        .y(y),
        .visible(visible),
        .mode(s2),
        .r(r),
        .g(g),
        .b(b)
    );

    reg [15:0] div_count   = 16'd0;
    reg [5:0]  frame_count = 6'd0;

    always @(posedge clk) begin
        if (reset) begin
            div_count   <= 16'd0;
            frame_count <= 6'd0;
        end else if (frame_end) begin
            if (div_count == FRAME_DIV - 1) begin
                div_count   <= 16'd0;
                frame_count <= frame_count + 6'd1;
            end else begin
                div_count <= div_count + 16'd1;
            end
        end
    end

    wire [5:0] display = s2 ? {r[7], g[7], b[7], visible, ~hsync, ~vsync} : frame_count;
    assign led = ~display;
endmodule
