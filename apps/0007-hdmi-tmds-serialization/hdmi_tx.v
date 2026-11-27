`timescale 1ns / 1ps

module hdmi_tx (
    input  wire       clk_pixel,
    input  wire       clk_serial,
    input  wire       reset,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    input  wire       visible,
    input  wire       hsync,
    input  wire       vsync,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    wire [9:0] tmds_ch [0:2];

    // Channel 0 (Blue) carries HSYNC and VSYNC control symbols during blanking
    tmds_encoder u_enc_blue (
        .clk(clk_pixel),
        .reset(reset),
        .data(b),
        .ctrl({vsync, hsync}),
        .visible(visible),
        .tmds(tmds_ch[0])
    );

    // Channel 1 (Green)
    tmds_encoder u_enc_green (
        .clk(clk_pixel),
        .reset(reset),
        .data(g),
        .ctrl(2'b00),
        .visible(visible),
        .tmds(tmds_ch[1])
    );

    // Channel 2 (Red)
    tmds_encoder u_enc_red (
        .clk(clk_pixel),
        .reset(reset),
        .data(r),
        .ctrl(2'b00),
        .visible(visible),
        .tmds(tmds_ch[2])
    );

    // Clock lane serialises fixed pattern 10'b0000011111 (LSB-first: 5 ones, 5 zeroes)
    wire ser_clk;
    OSER10 u_ser_clk (
        .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(reset),
        .Q(ser_clk)
    );

    TLVDS_OBUF u_obuf_clk (
        .I(ser_clk),
        .O(tmds_clk_p),
        .OB(tmds_clk_n)
    );

    wire [2:0] ser_d;
    genvar ch;
    generate
        for (ch = 0; ch < 3; ch = ch + 1) begin : g_lane
            OSER10 u_ser_d (
                .D0(tmds_ch[ch][0]), .D1(tmds_ch[ch][1]),
                .D2(tmds_ch[ch][2]), .D3(tmds_ch[ch][3]),
                .D4(tmds_ch[ch][4]), .D5(tmds_ch[ch][5]),
                .D6(tmds_ch[ch][6]), .D7(tmds_ch[ch][7]),
                .D8(tmds_ch[ch][8]), .D9(tmds_ch[ch][9]),
                .FCLK(clk_serial),
                .PCLK(clk_pixel),
                .RESET(reset),
                .Q(ser_d[ch])
            );

            TLVDS_OBUF u_obuf_d (
                .I(ser_d[ch]),
                .O(tmds_d_p[ch]),
                .OB(tmds_d_n[ch])
            );
        end
    endgenerate
endmodule
