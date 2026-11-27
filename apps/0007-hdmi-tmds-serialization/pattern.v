`timescale 1ns / 1ps

module pattern (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       visible,
    input  wire       mode,
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b
);
    wire on_border  = (x < 10'd4) || (x >= 10'd636) || (y < 10'd4) || (y >= 10'd476);
    wire is_checker = x[5] ^ y[5];

    always @(*) begin
        if (!visible) begin
            r = 8'h00;
            g = 8'h00;
            b = 8'h00;
        end else if (mode == 1'b0) begin
            if (x < 10'd80) begin
                r = 8'hFF; g = 8'hFF; b = 8'hFF;
            end else if (x < 10'd160) begin
                r = 8'hFF; g = 8'hFF; b = 8'h00;
            end else if (x < 10'd240) begin
                r = 8'h00; g = 8'hFF; b = 8'hFF;
            end else if (x < 10'd320) begin
                r = 8'h00; g = 8'hFF; b = 8'h00;
            end else if (x < 10'd400) begin
                r = 8'hFF; g = 8'h00; b = 8'hFF;
            end else if (x < 10'd480) begin
                r = 8'hFF; g = 8'h00; b = 8'h00;
            end else if (x < 10'd560) begin
                r = 8'h00; g = 8'h00; b = 8'hFF;
            end else begin
                r = 8'h00; g = 8'h00; b = 8'h00;
            end
        end else begin
            if (on_border) begin
                r = 8'hFF; g = 8'h20; b = 8'h20;
            end else if (is_checker) begin
                r = 8'hFF; g = 8'hFF; b = 8'hFF;
            end else begin
                r = 8'h10; g = 8'h20; b = 8'h40;
            end
        end
    end
endmodule
