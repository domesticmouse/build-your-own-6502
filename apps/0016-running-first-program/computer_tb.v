`timescale 1ns / 1ps

module computer_tb;
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
    wire [7:0]  a;
    wire        flag_c;
    wire        flag_z;
    wire        flag_n;
    wire        flag_v;
    wire [7:0]  leds;

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
        .state(state),
        .a(a),
        .flag_c(flag_c),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_v(flag_v),
        .leds(leds)
    );

    always #5 clk = ~clk;

    integer cycle_count;
    integer write_count;
    integer last_write_cycle;
    reg [7:0] expected_leds;
    reg       saw_carry_wrap;

    task tick_step;
        begin
            step = 1'b1;
            @(posedge clk);
            #1;
            step = 1'b0;
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;

            if (cycle_count == 120) begin
                $dumpoff;
            end
        end
    endtask

    initial begin
        $dumpfile("build/computer.vcd");
        $dumpvars(0, computer_tb);

        @(posedge clk);
        #1;
        reset = 1'b0;

        cycle_count      = 0;
        write_count      = 0;
        last_write_cycle = 0;
        expected_leds    = 8'h00;
        saw_carry_wrap   = 1'b0;

        // Simulate 3,010 cycles (> 273 full 11-cycle loops, wrapping $FF -> $00)
        while (cycle_count < 3010) begin
            tick_step();

            if (write) begin
                if (address !== 16'h8000) begin
                    $display("FAIL unexpected write address %04X at cycle %0d", address, cycle_count);
                    $fatal(1);
                end
                if (leds !== expected_leds) begin
                    $display("FAIL cycle %0d: expected leds=%02X, got %02X", cycle_count, expected_leds, leds);
                    $fatal(1);
                end
                if (write_count > 0 && (cycle_count - last_write_cycle) !== 11) begin
                    $display("FAIL write period %0d (expected 11)", cycle_count - last_write_cycle);
                    $fatal(1);
                end
                last_write_cycle = cycle_count;
                write_count      = write_count + 1;
                expected_leds    = expected_leds + 8'd1;
            end

            // After ADC #$01 wraps $FF -> $00, flag_c must assert until CLC clears it
            if (opcode == 8'h69 && a == 8'h00 && flag_c == 1'b1 && flag_z == 1'b1) begin
                saw_carry_wrap = 1'b1;
            end
        end

        if (write_count < 270 || !saw_carry_wrap) begin
            $display("FAIL incomplete loop coverage: writes=%0d carry_wrap=%b", write_count, saw_carry_wrap);
            $fatal(1);
        end

        // Verify mid-run reset clears leds and restarts at 0
        reset = 1'b1;
        @(posedge clk);
        #1;
        if (leds !== 8'h00 || a !== 8'h00) begin
            $fatal(1, "Reset failed to clear leds and accumulator");
        end

        $display("PASS: computer (%0d cycles, %0d STA $8000 writes, full 8-bit wrap verified)", cycle_count, write_count);
        $finish;
    end
endmodule
