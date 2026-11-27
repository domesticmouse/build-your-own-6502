`timescale 1ns / 1ps

module palette (
    input  wire [3:0] index,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);
    // Classic Commodore 64 16-colour palette
    function [23:0] lookup(input [3:0] idx);
        case (idx)
            4'd0:  lookup = 24'h000000; // Black
            4'd1:  lookup = 24'hFFFFFF; // White
            4'd2:  lookup = 24'h880000; // Red
            4'd3:  lookup = 24'hAAFFEE; // Cyan
            4'd4:  lookup = 24'hCC44CC; // Purple
            4'd5:  lookup = 24'h00CC55; // Green
            4'd6:  lookup = 24'h0000AA; // Blue
            4'd7:  lookup = 24'hEEEE77; // Yellow
            4'd8:  lookup = 24'hDD8855; // Orange
            4'd9:  lookup = 24'h664400; // Brown
            4'd10: lookup = 24'hFF7777; // Light Red
            4'd11: lookup = 24'h333333; // Dark Grey
            4'd12: lookup = 24'h777777; // Medium Grey
            4'd13: lookup = 24'hAAFF66; // Light Green
            4'd14: lookup = 24'h0088FF; // Light Blue
            4'd15: lookup = 24'hBBBBBB; // Light Grey
        endcase
    endfunction

    assign {r, g, b} = lookup(index);
endmodule
