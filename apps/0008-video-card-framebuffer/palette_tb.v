`timescale 1ns / 1ps

module palette_tb;
    reg  [3:0] index;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    palette dut (
        .index(index),
        .r(r),
        .g(g),
        .b(b)
    );

    task automatic check_entry(input [3:0] idx, input [7:0] er, input [7:0] eg, input [7:0] eb);
        begin
            index = idx;
            #1;
            if (r !== er || g !== eg || b !== eb) begin
                $display("FAIL: palette[%0d] got #%02x%02x%02x expected #%02x%02x%02x",
                         idx, r, g, b, er, eg, eb);
                $fatal(1);
            end
        end
    endtask

    initial begin
        check_entry(4'd0,  8'h00, 8'h00, 8'h00);
        check_entry(4'd1,  8'hFF, 8'hFF, 8'hFF);
        check_entry(4'd2,  8'h88, 8'h00, 8'h00);
        check_entry(4'd3,  8'hAA, 8'hFF, 8'hEE);
        check_entry(4'd4,  8'hCC, 8'h44, 8'hCC);
        check_entry(4'd5,  8'h00, 8'hCC, 8'h55);
        check_entry(4'd6,  8'h00, 8'h00, 8'hAA);
        check_entry(4'd7,  8'hEE, 8'hEE, 8'h77);
        check_entry(4'd8,  8'hDD, 8'h88, 8'h55);
        check_entry(4'd9,  8'h66, 8'h44, 8'h00);
        check_entry(4'd10, 8'hFF, 8'h77, 8'h77);
        check_entry(4'd11, 8'h33, 8'h33, 8'h33);
        check_entry(4'd12, 8'h77, 8'h77, 8'h77);
        check_entry(4'd13, 8'hAA, 8'hFF, 8'h66);
        check_entry(4'd14, 8'h00, 8'h88, 8'hFF);
        check_entry(4'd15, 8'hBB, 8'hBB, 8'hBB);

        $display("PASS: all 16 C64 palette entries verified");
        $finish;
    end
endmodule
