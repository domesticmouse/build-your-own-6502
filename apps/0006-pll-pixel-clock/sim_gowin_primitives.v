`timescale 1ns / 1ps

module rPLL #(
    parameter FCLKIN         = "27.0",
    parameter DYN_IDIV_SEL   = "false",
    parameter IDIV_SEL       = 2,
    parameter DYN_FBDIV_SEL  = "false",
    parameter FBDIV_SEL      = 13,
    parameter DYN_ODIV_SEL   = "false",
    parameter ODIV_SEL       = 4,
    parameter PSDA_SEL       = "0000",
    parameter DYN_DA_EN      = "false",
    parameter DUTYDA_SEL     = "1000",
    parameter CLKOUT_FT_DIR  = 1'b1,
    parameter CLKOUTP_FT_DIR = 1'b1,
    parameter CLKOUT_DLY_STEP  = 0,
    parameter CLKOUTP_DLY_STEP = 0,
    parameter CLKFB_SEL      = "internal",
    parameter CLKOUT_BYPASS  = "false",
    parameter CLKOUTP_BYPASS = "false",
    parameter CLKOUTD_BYPASS = "false",
    parameter DYN_SDIV_SEL   = 2,
    parameter CLKOUTD_SRC    = "CLKOUT",
    parameter CLKOUTD3_SRC   = "CLKOUT",
    parameter DEVICE         = "GW2AR-18C"
) (
    output reg  CLKOUT   = 1'b0,
    output wire CLKOUTP,
    output wire CLKOUTD,
    output wire CLKOUTD3,
    output reg  LOCK     = 1'b0,
    input  wire CLKIN,
    input  wire CLKFB,
    input  wire [5:0] FBDSEL,
    input  wire [5:0] IDSEL,
    input  wire [5:0] ODSEL,
    input  wire [3:0] PSDA,
    input  wire [3:0] FDLY,
    input  wire [3:0] DUTYDA,
    input  wire RESET,
    input  wire RESET_P
);
    assign CLKOUTP  = 1'b0;
    assign CLKOUTD  = 1'b0;
    assign CLKOUTD3 = 1'b0;

    // 126 MHz half-period = 1000 / (2 * 126) = 3.968 ns
    always #3.968 begin
        if (RESET || RESET_P) begin
            CLKOUT <= 1'b0;
        end else begin
            CLKOUT <= ~CLKOUT;
        end
    end

    initial begin
        LOCK = 1'b0;
        #100;
        LOCK = 1'b1;
    end
endmodule

module CLKDIV #(
    parameter DIV_MODE = "5",
    parameter GSREN    = "false"
) (
    input  wire HCLKIN,
    input  wire RESETN,
    input  wire CALIB,
    output reg  CLKOUT = 1'b0
);
    reg [2:0] cnt = 3'd0;

    always @(posedge HCLKIN or negedge RESETN) begin
        if (!RESETN) begin
            cnt    <= 3'd0;
            CLKOUT <= 1'b0;
        end else if (cnt == 3'd4) begin
            cnt    <= 3'd0;
            CLKOUT <= 1'b1;
        end else begin
            cnt <= cnt + 3'd1;
            if (cnt == 3'd1) begin
                CLKOUT <= 1'b0;
            end
        end
    end
endmodule
