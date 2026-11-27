`timescale 1ns / 1ps

module video_clock (
    input  wire clk_27m,
    output wire clk_serial,
    output wire clk_pixel,
    output wire locked
);
    rPLL #(
        .FCLKIN("27.0"),
        .IDIV_SEL(2),
        .FBDIV_SEL(13),
        .ODIV_SEL(4)
    ) u_pll (
        .CLKOUT(clk_serial),
        .LOCK(locked),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(1'b0),
        .RESET_P(1'b0),
        .CLKIN(clk_27m),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN("false")
    ) u_div (
        .HCLKIN(clk_serial),
        .RESETN(locked),
        .CALIB(1'b0),
        .CLKOUT(clk_pixel)
    );
endmodule
