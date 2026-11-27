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
    wire reset     = rst_sync[1];
    wire show_meta = disp_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg [3:0] vec_idx = 4'd0;
    always @(posedge clk) begin
        if (reset) begin
            vec_idx <= 4'd0;
        end else if (step) begin
            if (vec_idx == 4'd12) begin
                vec_idx <= 4'd0;
            end else begin
                vec_idx <= vec_idx + 4'd1;
            end
        end
    end

    function [20:0] get_vector;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  get_vector = {ALU_ADD,  8'h12, 8'h15, 1'b0};
                4'd1:  get_vector = {ALU_SUB,  8'h30, 8'h0A, 1'b1};
                4'd2:  get_vector = {ALU_CMP,  8'h25, 8'h25, 1'b0};
                4'd3:  get_vector = {ALU_INC,  8'h0E, 8'h00, 1'b0};
                4'd4:  get_vector = {ALU_DEC,  8'h10, 8'h00, 1'b0};
                4'd5:  get_vector = {ALU_AND,  8'h3F, 8'h2A, 1'b0};
                4'd6:  get_vector = {ALU_ORA,  8'h14, 8'h03, 1'b0};
                4'd7:  get_vector = {ALU_EOR,  8'h3F, 8'h15, 1'b0};
                4'd8:  get_vector = {ALU_ASL,  8'h85, 8'h00, 1'b0};
                4'd9:  get_vector = {ALU_LSR,  8'h2B, 8'h00, 1'b0};
                4'd10: get_vector = {ALU_ROL,  8'h05, 8'h00, 1'b1};
                4'd11: get_vector = {ALU_ROR,  8'h10, 8'h00, 1'b1};
                default: get_vector = {ALU_PASS, 8'h00, 8'h2D, 1'b0};
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

    alu u_alu (
        .op(op),
        .a(a),
        .b(b),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out)
    );

    assign led = ~(show_meta ? {carry_out, 1'b0, op} : result[5:0]);
endmodule
