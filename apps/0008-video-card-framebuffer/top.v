`timescale 1ns / 1ps

module top #(
    parameter integer FRAME_DIV = 12
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    wire clk_serial;
    wire clk_pixel;
    wire pll_lock;

    video_clock u_vclk (
        .clk_27m(clk),
        .clk_serial(clk_serial),
        .clk_pixel(clk_pixel),
        .locked(pll_lock)
    );

    reg [1:0] rst_sync    = 2'b11;
    reg [1:0] border_sync = 2'b00;
    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_sync    <= 2'b11;
            border_sync <= 2'b00;
        end else begin
            rst_sync    <= {rst_sync[0], s1};
            border_sync <= {border_sync[0], s2};
        end
    end
    wire reset_pix    = rst_sync[1];
    wire [3:0] border = border_sync[1] ? 4'd0 : 4'd14;

    wire [9:0] x;
    wire [9:0] y;
    wire       visible;
    wire       hsync;
    wire       vsync;
    wire       frame_end;

    raster u_raster (
        .clk(clk_pixel),
        .reset(reset_pix),
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
    wire       vid_visible;
    wire       vid_hsync;
    wire       vid_vsync;

    video u_video (
        .clk(clk_pixel),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .border_color(border),
        .r(r),
        .g(g),
        .b(b),
        .visible_out(vid_visible),
        .hsync_out(vid_hsync),
        .vsync_out(vid_vsync)
    );

    hdmi_tx u_hdmi (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .reset(reset_pix),
        .r(r),
        .g(g),
        .b(b),
        .visible(vid_visible),
        .hsync(vid_hsync),
        .vsync(vid_vsync),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p),
        .tmds_d_n(tmds_d_n)
    );

    reg [7:0] div_count   = 8'd0;
    reg [4:0] frame_count = 5'd0;
    always @(posedge clk_pixel) begin
        if (reset_pix) begin
            div_count   <= 8'd0;
            frame_count <= 5'd0;
        end else if (frame_end) begin
            if (div_count == FRAME_DIV - 1) begin
                div_count   <= 8'd0;
                frame_count <= frame_count + 5'd1;
            end else begin
                div_count <= div_count + 8'd1;
            end
        end
    end

    assign led = ~{pll_lock, frame_count};
endmodule
