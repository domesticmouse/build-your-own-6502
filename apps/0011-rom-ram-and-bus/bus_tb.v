`timescale 1ns / 1ps

module bus_tb;
    reg         clk = 1'b0;
    reg  [15:0] address = 16'h0000;
    reg  [7:0]  data_out = 8'h00;
    reg         write = 1'b0;
    wire [7:0]  data_in;

    bus uut (
        .clk(clk),
        .address(address),
        .data_out(data_out),
        .write(write),
        .data_in(data_in)
    );

    always #5 clk = ~clk;

    task tick_step;
        begin
            @(posedge clk);
            #1;
            @(posedge clk);
            #1;
        end
    endtask

    reg [7:0] expected_prog [0:10];
    integer i;

    initial begin
        $dumpfile("build/bus.vcd");
        $dumpvars(0, bus_tb);

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

        // 1. Read all 11 program bytes from ROM ($C000..$C00A) with 2-tick pacing
        write = 1'b0;
        for (i = 0; i < 11; i = i + 1) begin
            address = 16'hC000 + i[15:0];
            tick_step();
            if (data_in !== expected_prog[i]) begin
                $display("FAIL: ROM[$%04X] expected %02X got %02X", address, expected_prog[i], data_in);
                $fatal(1);
            end
        end

        // 2. Verify ROM ignores write attempts
        address  = 16'hC000;
        data_out = 8'hFF;
        write    = 1'b1;
        tick_step();
        write    = 1'b0;
        tick_step();
        if (data_in !== 8'hA9) begin
            $display("FAIL: ROM was overwritten! expected A9 got %02X", data_in);
            $fatal(1);
        end

        // 3. Write and read back RAM boundaries ($0000, $00FF, $0100, $4000, $7FFF)
        address = 16'h0000; data_out = 8'h11; write = 1'b1; tick_step();
        address = 16'h00FF; data_out = 8'h22; write = 1'b1; tick_step();
        address = 16'h0100; data_out = 8'h33; write = 1'b1; tick_step();
        address = 16'h4000; data_out = 8'h44; write = 1'b1; tick_step();
        address = 16'h7FFF; data_out = 8'h55; write = 1'b1; tick_step();

        write = 1'b0;
        address = 16'h0000; tick_step(); if (data_in !== 8'h11) $fatal(1, "RAM $0000 mismatch");
        address = 16'h00FF; tick_step(); if (data_in !== 8'h22) $fatal(1, "RAM $00FF mismatch");
        address = 16'h0100; tick_step(); if (data_in !== 8'h33) $fatal(1, "RAM $0100 mismatch");
        address = 16'h4000; tick_step(); if (data_in !== 8'h44) $fatal(1, "RAM $4000 mismatch");
        address = 16'h7FFF; tick_step(); if (data_in !== 8'h55) $fatal(1, "RAM $7FFF mismatch");

        // 4. Unmapped I/O space ($8000, $BFFF) returns 00 and does not corrupt RAM $0000
        address = 16'h8000; data_out = 8'hAA; write = 1'b1; tick_step();
        write = 1'b0; tick_step();
        if (data_in !== 8'h00) $fatal(1, "I/O $8000 read mismatch");
        address = 16'hBFFF; tick_step();
        if (data_in !== 8'h00) $fatal(1, "I/O $BFFF read mismatch");
        address = 16'h0000; tick_step();
        if (data_in !== 8'h11) $fatal(1, "RAM $0000 corrupted by $8000 write");

        $display("PASS: bus (ROM 11 bytes, ROM write-protect, RAM 32KB boundaries, I/O isolation)");
        $finish;
    end
endmodule
