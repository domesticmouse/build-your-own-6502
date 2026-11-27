`timescale 1ns / 1ps

module top_tb;
    reg        clk = 1'b0;
    reg        s1  = 1'b0;
    reg        s2  = 1'b0;
    wire [5:0] led;
    wire       tmds_clk_p;
    wire       tmds_clk_n;
    wire [2:0] tmds_d_p;
    wire [2:0] tmds_d_n;

    top #(.FRAME_DIV(1)) dut (
        .clk(clk),
        .s1(s1),
        .s2(s2),
        .led(led),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p),
        .tmds_d_n(tmds_d_n)
    );

    always #18.519 clk = ~clk;

    integer k;
    integer clk_transitions = 0;
    reg     prev_clk_p      = 1'b0;

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, top_tb);

        #300;
        if (led[5] !== 1'b0) begin
            $display("FAIL: led[5] (pll_lock) should be active-low 0, got %b", led[5]);
            $fatal(1);
        end

        prev_clk_p = tmds_clk_p;
        for (k = 0; k < 200; k = k + 1) begin
            #2;
            if (tmds_clk_p !== ~tmds_clk_n || tmds_d_p !== ~tmds_d_n) begin
                $display("FAIL: TMDS differential pairs lost complementarity");
                $fatal(1);
            end
            if (tmds_clk_p !== prev_clk_p) begin
                clk_transitions = clk_transitions + 1;
                prev_clk_p      = tmds_clk_p;
            end
        end

        if (clk_transitions < 10) begin
            $display("FAIL: expected active TMDS clock transitions, got %0d", clk_transitions);
            $fatal(1);
        end

        s2 = 1'b1;
        #200;
        if (led[5] !== 1'b0) begin
            $display("FAIL: pll_lock LED dropped when toggling S2");
            $fatal(1);
        end

        $display("PASS: top HDMI video pipeline verified (%0d TMDS clock edges observed)", clk_transitions);
        $finish;
    end
endmodule
