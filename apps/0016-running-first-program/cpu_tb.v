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
    wire [7:0]  a;
    wire        flag_c;
    wire        flag_z;
    wire        flag_n;
    wire        flag_v;

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
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v)
    );

    always #5 clk = ~clk;

    task pulse_step;
        input [7:0] bus_byte;
        begin
            data_in = bus_byte;
            step    = 1'b1;
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
        reset = 1'b0;

        // STARTING -> OPCODE
        pulse_step(8'h00);

        // Non-zero LDA #$2A catches a broken LDA that LDA #$00 after reset would mask
        pulse_step(8'hA9);
        pulse_step(8'h2A);
        if (a !== 8'h2A || flag_z !== 1'b0 || flag_n !== 1'b0) begin
            $fatal(1, "LDA #$2A failed");
        end

        // LDA #$80 sets Negative flag
        pulse_step(8'hA9);
        pulse_step(8'h80);
        if (a !== 8'h80 || flag_z !== 1'b0 || flag_n !== 1'b1) begin
            $fatal(1, "LDA #$80 failed");
        end

        // LDA #$00 from non-zero A proves LDA actually clears A and sets Z=1
        pulse_step(8'hA9);
        pulse_step(8'h00);
        if (a !== 8'h00 || flag_z !== 1'b1 || flag_n !== 1'b0) begin
            $fatal(1, "LDA #$00 from non-zero A failed");
        end

        // ADC #$7F then ADC #$01 triggers signed overflow (V=1, N=1, C=0)
        pulse_step(8'h69);
        pulse_step(8'h7F);
        pulse_step(8'h69);
        pulse_step(8'h01);
        if (a !== 8'h80 || flag_v !== 1'b1 || flag_n !== 1'b1 || flag_c !== 1'b0) begin
            $fatal(1, "ADC signed overflow failed");
        end

        // ADC #$80 produces $00 with C=1, Z=1, V=1
        pulse_step(8'h69);
        pulse_step(8'h80);
        if (a !== 8'h00 || flag_c !== 1'b1 || flag_z !== 1'b1 || flag_v !== 1'b1) begin
            $fatal(1, "ADC carry wrap failed");
        end

        // ADC #$01 while C=1 adds 1+1 = $02 (proves carry_in wiring)
        pulse_step(8'h69);
        pulse_step(8'h01);
        if (a !== 8'h02 || flag_c !== 1'b0) begin
            $fatal(1, "ADC carry-in failed");
        end

        // Set C=1 via ADC #$FE ($02+$FE=$00, C=1), then CLC clears C before ADC #$01 -> $01
        pulse_step(8'h69);
        pulse_step(8'hFE);
        if (flag_c !== 1'b1) begin
            $fatal(1, "Expected C=1 before CLC");
        end
        pulse_step(8'h18);
        pulse_step(8'h69);
        if (flag_c !== 1'b0) begin
            $fatal(1, "CLC failed to clear carry");
        end
        pulse_step(8'h69);
        pulse_step(8'h01);
        if (a !== 8'h01) begin
            $fatal(1, "ADC after CLC failed");
        end

        // STA $8000 outputs A onto data_out with write=1
        pulse_step(8'h8D);
        pulse_step(8'h00);
        pulse_step(8'h80);
        if (address !== 16'h8000 || data_out !== 8'h01 || write !== 1'b1) begin
            $fatal(1, "STA $8000 data_out/write failed");
        end
        pulse_step(8'h00);

        $display("PASS: cpu (data path, non-zero LDA trap, flags, CLC, and STA verified)");
        $finish;
    end
endmodule
