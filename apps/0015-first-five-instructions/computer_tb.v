`timescale 1ns / 1ps

module computer_tb;
    `include "cpu_defs.vh"

    reg         clk   = 1'b0;
    reg         reset = 1'b1;
    reg         step  = 1'b0;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;
    wire [2:0]  state;

    computer uut (
        .clk(clk),
        .reset(reset),
        .step(step),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc),
        .state(state)
    );

    always #5 clk = ~clk;

    task check_step;
        input integer cycle;
        input [15:0]  exp_addr;
        input         exp_write;
        input [2:0]   exp_state;
        input [7:0]   exp_opcode;
        begin
            step = 1'b1;
            @(posedge clk);
            #1;
            step = 1'b0;
            if (address !== exp_addr || write !== exp_write ||
                state !== exp_state || opcode !== exp_opcode) begin
                $display(
                    "FAIL cycle %0d: addr=%04X wr=%b state=%0d op=%02X (exp %04X wr=%b st=%0d op=%02X)",
                    cycle, address, write, state, opcode, exp_addr, exp_write, exp_state, exp_opcode
                );
                $fatal(1);
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("build/computer.vcd");
        $dumpvars(0, computer_tb);

        @(posedge clk);
        #1;
        reset = 1'b0;

        // Cycle 1: STARTING -> $C000
        check_step(1, 16'hC000, 1'b0, OPCODE, 8'h00);

        // LDA #$00 (2 cycles)
        check_step(2, 16'hC001, 1'b0, OPERAND, 8'hA9);
        check_step(3, 16'hC002, 1'b0, OPCODE,  8'hA9);

        // Loop Iteration 1: STA $8000 (4) + CLC (2) + ADC #$01 (2) + JMP $C002 (3) = 11 cycles
        check_step(4,  16'hC003, 1'b0, OPERAND, 8'h8D);
        check_step(5,  16'hC004, 1'b0, HIGH,    8'h8D);
        check_step(6,  16'h8000, 1'b1, STORE,   8'h8D);
        check_step(7,  16'hC005, 1'b0, OPCODE,  8'h8D);

        // CLC Two-Read Rule: reads $C006 twice
        check_step(8,  16'hC006, 1'b0, OPERAND, 8'h18);
        check_step(9,  16'hC006, 1'b0, OPCODE,  8'h18);

        check_step(10, 16'hC007, 1'b0, OPERAND, 8'h69);
        check_step(11, 16'hC008, 1'b0, OPCODE,  8'h69);

        check_step(12, 16'hC009, 1'b0, OPERAND, 8'h4C);
        check_step(13, 16'hC00A, 1'b0, HIGH,    8'h4C);
        check_step(14, 16'hC002, 1'b0, OPCODE,  8'h4C);

        // Loop Iteration 2: verify exact 11-cycle loop timing back to STA $8000 on cycle 17
        check_step(15, 16'hC003, 1'b0, OPERAND, 8'h8D);
        check_step(16, 16'hC004, 1'b0, HIGH,    8'h8D);
        check_step(17, 16'h8000, 1'b1, STORE,   8'h8D);
        check_step(18, 16'hC005, 1'b0, OPCODE,  8'h8D);

        check_step(19, 16'hC006, 1'b0, OPERAND, 8'h18);
        check_step(20, 16'hC006, 1'b0, OPCODE,  8'h18);

        check_step(21, 16'hC007, 1'b0, OPERAND, 8'h69);
        check_step(22, 16'hC008, 1'b0, OPCODE,  8'h69);

        check_step(23, 16'hC009, 1'b0, OPERAND, 8'h4C);
        check_step(24, 16'hC00A, 1'b0, HIGH,    8'h4C);
        check_step(25, 16'hC002, 1'b0, OPCODE,  8'h4C);

        $display("PASS: computer (cycle-accurate 11-cycle count.s loop and Two-Read Rule verified)");
        $finish;
    end
endmodule
