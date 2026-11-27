`timescale 1ns / 1ps

module decoder_tb;
    `include "cpu_defs.vh"

    reg  [7:0] opcode = 8'h00;
    wire [2:0] inst;
    wire [1:0] mode;

    decoder uut (
        .opcode(opcode),
        .inst(inst),
        .mode(mode)
    );

    task check_dec;
        input [7:0] op;
        input [2:0] exp_inst;
        input [1:0] exp_mode;
        begin
            opcode = op;
            #1;
            if (inst !== exp_inst || mode !== exp_mode) begin
                $display(
                    "FAIL opcode=%02X: got inst=%0d mode=%0d (expected %0d, %0d)",
                    op, inst, mode, exp_inst, exp_mode
                );
                $fatal(1);
            end
        end
    endtask

    initial begin
        $dumpfile("build/decoder.vcd");
        $dumpvars(0, decoder_tb);

        check_dec(8'hA9, INST_LDA, MODE_IMM);
        check_dec(8'h8D, INST_STA, MODE_ABS);
        check_dec(8'h18, INST_CLC, MODE_IMP);
        check_dec(8'h69, INST_ADC, MODE_IMM);
        check_dec(8'h4C, INST_JMP, MODE_ABS);
        check_dec(8'hEA, INST_NOP, MODE_IMP);
        check_dec(8'h00, INST_NOP, MODE_IMP);

        $display("PASS: decoder (all 5 opcodes plus default NOP/IMP fallback)");
        $finish;
    end
endmodule
