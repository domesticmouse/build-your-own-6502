`timescale 1ns / 1ps

module computer_tb;
    reg         clk = 1'b0;
    reg         reset = 1'b1;
    reg         step = 1'b0;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;

    computer uut (
        .clk(clk),
        .reset(reset),
        .step(step),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .write(write),
        .opcode(opcode),
        .pc(pc)
    );

    always #5 clk = ~clk;

    task pulse_step;
        begin
            step = 1'b1;
            @(posedge clk);
            #1;
            step = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    reg [7:0] expected_prog [0:10];
    integer i;

    initial begin
        $dumpfile("build/computer.vcd");
        $dumpvars(0, computer_tb);

        expected_prog[0]  = 8'hA9;
        expected_prog[1]  = 8'h00;
        expected_prog[2]  = 8'h8D;
        expected_prog[3]  = 8'h00;
        expected_prog[4]  = 8'h80;
        expected_prog[5]  = 8'h18;
        expected_prog[6]  = 8'h69;
        expected_prog[7]  = 8'h01;
        expected_prog[8]  = 8'h4C;
        expected_prog[9]  = 8'h02;
        expected_prog[10] = 8'hC0;

        @(posedge clk);
        #1;
        reset = 1'b0;

        // Step 1: STARTING puts $C000 on address and $C001 in pc
        pulse_step();
        if (address !== 16'hC000 || pc !== 16'hC001 || write !== 1'b0) begin
            $display("FAIL STARTING: addr=%04X pc=%04X", address, pc);
            $fatal(1);
        end

        // Steps 2..12: OPCODE latches every byte of rom.mem ($C000..$C00A)
        for (i = 0; i < 11; i = i + 1) begin
            pulse_step();
            if (opcode !== expected_prog[i]) begin
                $display("FAIL byte %0d: expected opcode %02X got %02X", i, expected_prog[i], opcode);
                $fatal(1);
            end
            if (address !== (16'hC001 + i[15:0]) || pc !== (16'hC002 + i[15:0])) begin
                $display("FAIL bus @ byte %0d: addr=%04X pc=%04X", i, address, pc);
                $fatal(1);
            end
            if (write !== 1'b0) begin
                $fatal(1, "Unexpected write=1 during fetch");
            end
        end

        // Mid-run reset cleanly restarts fetch at $C000 -> $A9
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        pulse_step();
        if (address !== 16'hC000 || pc !== 16'hC001) begin
            $fatal(1, "Restart STARTING mismatch");
        end
        pulse_step();
        if (opcode !== 8'hA9 || address !== 16'hC001) begin
            $fatal(1, "Restart first byte mismatch");
        end

        $display("PASS: computer (sequentially fetched all 11 ROM bytes $A9..$C0)");
        $finish;
    end
endmodule
