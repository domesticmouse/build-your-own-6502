`timescale 1ns / 1ps

module cpu_tb;
    `include "cpu_defs.vh"

    reg         clk     = 1'b0;
    reg         reset   = 1'b1;
    reg         step    = 1'b0;
    reg  [7:0]  data_in = 8'h00;
    wire [15:0] address;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;
    wire [2:0]  state;

    cpu uut (
        .clk(clk),
        .reset(reset),
        .step(step),
        .data_in(data_in),
        .address(address),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state)
    );

    always #5 clk = ~clk;

    task pulse_step;
        input [7:0]  bus_byte;
        input [15:0] exp_addr;
        input        exp_write;
        input [2:0]  exp_state;
        input [15:0] exp_pc;
        begin
            data_in = bus_byte;
            step    = 1'b1;
            @(posedge clk);
            #1;
            step    = 1'b0;
            if (address !== exp_addr || write !== exp_write ||
                state !== exp_state || pc !== exp_pc) begin
                $display(
                    "FAIL bus=%02X: got addr=%04X wr=%b state=%0d pc=%04X (exp %04X wr=%b st=%0d pc=%04X)",
                    bus_byte, address, write, state, pc, exp_addr, exp_write, exp_state, exp_pc
                );
                $fatal(1);
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("build/cpu.vcd");
        $dumpvars(0, cpu_tb);

        @(posedge clk);
        #1;
        reset = 1'b0;

        // Boot: STARTING -> OPCODE at $C000
        pulse_step(8'h00, 16'hC000, 1'b0, OPCODE, 16'hC001);

        // LDA #$42 (2 cycles)
        pulse_step(8'hA9, 16'hC001, 1'b0, OPERAND, 16'hC002);
        pulse_step(8'h42, 16'hC002, 1'b0, OPCODE,  16'hC003);

        // STA $8000 (4 cycles; write=1 on cycle 3)
        pulse_step(8'h8D, 16'hC003, 1'b0, OPERAND, 16'hC004);
        pulse_step(8'h00, 16'hC004, 1'b0, HIGH,    16'hC005);
        pulse_step(8'h80, 16'h8000, 1'b1, STORE,   16'hC005);
        pulse_step(8'h00, 16'hC005, 1'b0, OPCODE,  16'hC006);

        // CLC (2 cycles; Two-Read Rule fetches $C006 twice)
        pulse_step(8'h18, 16'hC006, 1'b0, OPERAND, 16'hC006);
        pulse_step(8'h69, 16'hC006, 1'b0, OPCODE,  16'hC007);

        // ADC #$01 (2 cycles)
        pulse_step(8'h69, 16'hC007, 1'b0, OPERAND, 16'hC008);
        pulse_step(8'h01, 16'hC008, 1'b0, OPCODE,  16'hC009);

        // JMP $C002 (3 cycles)
        pulse_step(8'h4C, 16'hC009, 1'b0, OPERAND, 16'hC00A);
        pulse_step(8'h02, 16'hC00A, 1'b0, HIGH,    16'hC00B);
        pulse_step(8'hC0, 16'hC002, 1'b0, OPCODE,  16'hC003);

        $display("PASS: cpu (all 5 instructions, exact cycle counts, Two-Read Rule verified)");
        $finish;
    end
endmodule
