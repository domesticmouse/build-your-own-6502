`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;

    top #(.BLINK_BIT(2)) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led)
    );

    always #5 clk = ~clk;

    task check_buttons(
        input reg in_s1,
        input reg in_s2,
        input reg exp_led0,
        input reg exp_led2,
        input reg exp_led3
    );
        begin
            s1 = in_s1;
            s2 = in_s2;
            #1;
            if (led[0] !== exp_led0) $fatal(1, "led[0] mismatch for s1=%b s2=%b: got %b expected %b", s1, s2, led[0], exp_led0);
            if (led[2] !== exp_led2) $fatal(1, "led[2] mismatch for s1=%b: got %b expected %b", s1, led[2], exp_led2);
            if (led[3] !== exp_led3) $fatal(1, "led[3] mismatch for s2=%b: got %b expected %b", s2, led[3], exp_led3);
            if (led[5:4] !== 2'b11)  $fatal(1, "led[5:4] should remain off (11): got %b", led[5:4]);
        end
    endtask

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        #1;
        if (led[1] !== 1'b1) $fatal(1, "led[1] should start off (1): got %b", led[1]);

        check_buttons(1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        check_buttons(1'b1, 1'b0, 1'b1, 1'b0, 1'b1);
        check_buttons(1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
        check_buttons(1'b1, 1'b1, 1'b0, 1'b0, 1'b0);

        repeat (4) @(posedge clk);
        #1;
        if (led[1] !== 1'b0) $fatal(1, "led[1] should turn on (0) after 4 rising edges: got %b", led[1]);

        repeat (4) @(posedge clk);
        #1;
        if (led[1] !== 1'b1) $fatal(1, "led[1] should turn off (1) after 8 rising edges: got %b", led[1]);

        $display("PASS: all combinational gate and clock-divider checks passed");
        $finish;
    end
endmodule
