`timescale 1ns / 1ps

module decoder (
    input  wire [7:0] opcode,
    output wire [2:0] inst,
    output wire [1:0] mode
);
    `include "cpu_defs.vh"

    function [4:0] decode_opcode;
        input [7:0] op;
        begin
            case (op)
                8'hA9:   decode_opcode = {INST_LDA, MODE_IMM};
                8'h8D:   decode_opcode = {INST_STA, MODE_ABS};
                8'h18:   decode_opcode = {INST_CLC, MODE_IMP};
                8'h69:   decode_opcode = {INST_ADC, MODE_IMM};
                8'h4C:   decode_opcode = {INST_JMP, MODE_ABS};
                default: decode_opcode = {INST_NOP, MODE_IMP};
            endcase
        end
    endfunction

    assign {inst, mode} = decode_opcode(opcode);
endmodule
