`timescale 1ns / 1ps

module scanner_tb;
    reg        clk = 1'b0;
    reg        reset = 1'b0;
    reg        step = 1'b0;
    wire [5:0] leds;

    always #5 clk = ~clk;

    scanner dut (
        .clk(clk),
        .reset(reset),
        .step(step),
        .leds(leds)
    );

    task step_and_check(input reg [5:0] exp_leds);
        begin
            @(posedge clk);
            #1;
            if (leds !== exp_leds) begin
                $fatal(1, "scanner mismatch: got %b expected %b", leds, exp_leds);
            end
        end
    endtask

    initial begin
        $dumpfile("build/scanner.vcd");
        $dumpvars(0, scanner_tb);

        reset = 1'b1;
        step_and_check(6'b000001);

        reset = 1'b0;
        step = 1'b0;
        step_and_check(6'b000001);

        step = 1'b1;
        step_and_check(6'b000010);
        step_and_check(6'b000100);
        step_and_check(6'b001000);
        step_and_check(6'b010000);
        step_and_check(6'b100000);
        step_and_check(6'b010000);
        step_and_check(6'b001000);
        step_and_check(6'b000100);
        step_and_check(6'b000010);
        step_and_check(6'b000001);
        step_and_check(6'b000010);

        reset = 1'b1;
        step_and_check(6'b000001);

        $display("PASS: scanner FSM bounce, hold, and synchronous reset passed");
        $finish;
    end
endmodule
