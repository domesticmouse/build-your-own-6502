`timescale 1ns / 1ps

module cpu_tb;
    reg         clk = 1'b0;
    reg         reset = 1'b1;
    reg         step = 1'b0;
    reg  [7:0]  data_in = 8'h00;
    wire [15:0] address;
    wire [7:0]  data_out;
    wire        write;
    wire [7:0]  opcode;
    wire [15:0] pc;

    cpu uut (
        .clk(clk),
        .reset(reset),
        .step(step),
        .data_in(data_in),
        .address(address),
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

    initial begin
        $dumpfile("build/cpu.vcd");
        $dumpvars(0, cpu_tb);

        @(posedge clk);
        #1;
        if (address !== 16'h0000 || pc !== 16'h0000 || opcode !== 8'h00 || write !== 1'b0) begin
            $fatal(1, "Reset state mismatch");
        end

        reset = 1'b0;

        // Step 1 (STARTING -> OPCODE): puts $C000 on address and $C001 in pc
        pulse_step();
        if (address !== 16'hC000 || pc !== 16'hC001 || opcode !== 8'h00) begin
            $display("FAIL Step 1: addr=%04X pc=%04X op=%02X", address, pc, opcode);
            $fatal(1);
        end

        // Step 2 (OPCODE): latches data_in=$A9, advances address=$C001, pc=$C002
        data_in = 8'hA9;
        pulse_step();
        if (opcode !== 8'hA9 || address !== 16'hC001 || pc !== 16'hC002) begin
            $display("FAIL Step 2: addr=%04X pc=%04X op=%02X", address, pc, opcode);
            $fatal(1);
        end

        // Step 3 (OPCODE): latches data_in=$00, advances address=$C002, pc=$C003
        data_in = 8'h00;
        pulse_step();
        if (opcode !== 8'h00 || address !== 16'hC002 || pc !== 16'hC003 || write !== 1'b0) begin
            $display("FAIL Step 3: addr=%04X pc=%04X op=%02X", address, pc, opcode);
            $fatal(1);
        end

        // Verify mid-run reset returns to STARTING and restarts at $C000
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        pulse_step();
        if (address !== 16'hC000 || pc !== 16'hC001) begin
            $fatal(1, "Post-reset STARTING failed");
        end

        $display("PASS: cpu (STARTING -> OPCODE, pc=address+1, reset recovery)");
        $finish;
    end
endmodule
