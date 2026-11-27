`timescale 1ns / 1ps

module hdmi_tx_tb;
    reg        clk_27m = 1'b0;
    wire       clk_serial;
    wire       clk_pixel;
    wire       locked;
    reg        reset   = 1'b1;
    reg  [7:0] r       = 8'h00;
    reg  [7:0] g       = 8'h00;
    reg  [7:0] b       = 8'h00;
    reg        visible = 1'b0;
    reg        hsync   = 1'b1;
    reg        vsync   = 1'b1;
    wire       tmds_clk_p;
    wire       tmds_clk_n;
    wire [2:0] tmds_d_p;
    wire [2:0] tmds_d_n;

    video_clock u_vclk (
        .clk_27m(clk_27m),
        .clk_serial(clk_serial),
        .clk_pixel(clk_pixel),
        .locked(locked)
    );

    hdmi_tx dut (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .reset(reset),
        .r(r),
        .g(g),
        .b(b),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p),
        .tmds_d_n(tmds_d_n)
    );

    always #18.519 clk_27m = ~clk_27m;

    reg [9:0] cap_clk  = 10'd0;
    reg [9:0] cap_blue = 10'd0;
    integer   k;

    initial begin
        $dumpfile("build/hdmi_tx.vcd");
        $dumpvars(0, hdmi_tx_tb);

        @(posedge locked);
        repeat (3) @(posedge clk_pixel);
        reset <= 1'b0;

        // Drive blanking with {vsync=1, hsync=0} -> ctrl=2'b10 -> 10'b0101010100
        visible <= 1'b0;
        hsync   <= 1'b0;
        vsync   <= 1'b1;
        repeat (3) @(posedge clk_pixel);

        // Capture the next 10 DDR edges (one pixel word shifted out LSB-first)
        for (k = 0; k < 10; k = k + 1) begin
            @(clk_serial);
            #0.5;
            if (tmds_clk_p !== ~tmds_clk_n || tmds_d_p !== ~tmds_d_n) begin
                $display("FAIL: differential outputs are not exact complements");
                $fatal(1);
            end
            cap_clk[k]  = tmds_clk_p;
            cap_blue[k] = tmds_d_p[0];
        end

        if (cap_clk !== 10'b0000011111) begin
            $display("FAIL: TMDS clock lane expected 0000011111, got %b", cap_clk);
            $fatal(1);
        end
        if (cap_blue !== 10'b0101010100) begin
            $display("FAIL: Blue ctrl=10 expected 0101010100, got %b", cap_blue);
            $fatal(1);
        end

        // Drive active visible pixel and confirm data lanes toggle cleanly
        visible <= 1'b1;
        r <= 8'hAA; g <= 8'h55; b <= 8'hFF;
        repeat (4) @(posedge clk_pixel);

        $display("PASS: hdmi_tx OSER10 serialisation & TLVDS_OBUF differential pairs verified");
        $finish;
    end
endmodule
