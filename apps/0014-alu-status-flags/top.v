`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 27000000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    `include "alu_ops.vh"

    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] disp_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        disp_sync <= {disp_sync[0], s2};
    end
    wire reset    = rst_sync[1];
    wire show_res = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg [2:0] vec_idx = 3'd0;
    always @(posedge clk) begin
        if (reset) begin
            vec_idx <= 3'd0;
        end else if (step) begin
            vec_idx <= vec_idx + 3'd1;
        end
    end

    function [20:0] get_vector;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: get_vector = {ALU_ADD,  8'h7F, 8'h01, 1'b0};
                3'd1: get_vector = {ALU_ADD,  8'hFF, 8'h01, 1'b0};
                3'd2: get_vector = {ALU_SUB,  8'h80, 8'h01, 1'b1};
                3'd3: get_vector = {ALU_SUB,  8'h00, 8'h01, 1'b1};
                3'd4: get_vector = {ALU_CMP,  8'h40, 8'h40, 1'b0};
                3'd5: get_vector = {ALU_PASS, 8'h00, 8'h00, 1'b0};
                3'd6: get_vector = {ALU_PASS, 8'h00, 8'h80, 1'b0};
                default: get_vector = {ALU_ASL, 8'h81, 8'h00, 1'b0};
            endcase
        end
    endfunction

    wire [20:0] vec      = get_vector(vec_idx);
    wire [3:0]  op       = vec[20:17];
    wire [7:0]  a        = vec[16:9];
    wire [7:0]  b        = vec[8:1];
    wire        carry_in = vec[0];

    wire [7:0] result;
    wire       carry_out;
    wire       zero;
    wire       negative;
    wire       overflow;

    alu u_alu (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out),
        .zero(zero),
        .negative(negative),
        .overflow(overflow)
    );

    wire [5:0] flags_view = {2'b00, negative, overflow, zero, carry_out};
    assign led = ~(show_res ? result[5:0] : flags_view);
endmodule
