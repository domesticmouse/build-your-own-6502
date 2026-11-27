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
    output reg  [15:0] pc = 16'h0000,
    output reg  [2:0]  state = 3'd0
);
    `include "cpu_defs.vh"

    wire [2:0] dec_inst;
    wire [1:0] dec_mode;

    decoder u_decoder (
        .opcode(data_in),
        .inst(dec_inst),
        .mode(dec_mode)
    );

    reg [2:0] inst    = INST_NOP;
    reg [1:0] mode    = MODE_IMP;
    reg [7:0] addr_lo = 8'h00;

    always @(posedge clk) begin
        if (reset) begin
            state    <= STARTING;
            pc       <= 16'h0000;
            address  <= 16'h0000;
            data_out <= 8'h00;
            write    <= 1'b0;
            opcode   <= 8'h00;
            inst     <= INST_NOP;
            mode     <= MODE_IMP;
            addr_lo  <= 8'h00;
        end else if (step) begin
            case (state)
                STARTING: begin
                    address <= RESET_ADDR;
                    pc      <= RESET_ADDR + 16'd1;
                    write   <= 1'b0;
                    state   <= OPCODE;
                end
                OPCODE: begin
                    opcode  <= data_in;
                    inst    <= dec_inst;
                    mode    <= dec_mode;
                    address <= pc;
                    if (dec_mode != MODE_IMP) begin
                        pc <= pc + 16'd1;
                    end
                    write   <= 1'b0;
                    state   <= OPERAND;
                end
                OPERAND: begin
                    write <= 1'b0;
                    if (mode == MODE_ABS) begin
                        addr_lo <= data_in;
                        address <= pc;
                        pc      <= pc + 16'd1;
                        state   <= HIGH;
                    end else begin
                        address <= pc;
                        pc      <= pc + 16'd1;
                        state   <= OPCODE;
                    end
                end
                HIGH: begin
                    if (inst == INST_JMP) begin
                        address <= {data_in, addr_lo};
                        pc      <= {data_in, addr_lo} + 16'd1;
                        write   <= 1'b0;
                        state   <= OPCODE;
                    end else begin
                        address  <= {data_in, addr_lo};
                        data_out <= 8'h00;
                        write    <= 1'b1;
                        state    <= STORE;
                    end
                end
                STORE: begin
                    address <= pc;
                    pc      <= pc + 16'd1;
                    write   <= 1'b0;
                    state   <= OPCODE;
                end
                default: begin
                    state <= STARTING;
                    write <= 1'b0;
                end
            endcase
        end
    end
endmodule
