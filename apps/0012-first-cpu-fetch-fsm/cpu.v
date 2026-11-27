`timescale 1ns / 1ps

module cpu #(
    parameter [15:0] RESET_ADDR = 16'hC000
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        step,
    input  wire [7:0]  data_in,
    output reg  [15:0] address = 16'h0000,
    output reg  [7:0]  data_out = 8'h00,
    output reg         write = 1'b0,
    output reg  [7:0]  opcode = 8'h00,
    output reg  [15:0] pc = 16'h0000
);
    localparam STARTING = 1'b0;
    localparam OPCODE   = 1'b1;

    reg state = STARTING;

    always @(posedge clk) begin
        if (reset) begin
            state    <= STARTING;
            pc       <= 16'h0000;
            address  <= 16'h0000;
            data_out <= 8'h00;
            write    <= 1'b0;
            opcode   <= 8'h00;
        end else if (step) begin
            case (state)
                STARTING: begin
                    address <= RESET_ADDR;
                    pc      <= RESET_ADDR + 16'd1;
                    state   <= OPCODE;
                end
                OPCODE: begin
                    opcode  <= data_in;
                    address <= pc;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end
            endcase
        end
    end
endmodule
