`timescale 1ns / 1ps

module register_tb;
    reg        clk = 1'b0;
    reg        reset = 1'b0;
    reg        load = 1'b0;
    reg  [7:0] d = 8'h00;
    wire [7:0] q;

    reg        swap_load = 1'b0;
    reg        swap_reset = 1'b0;
    reg  [7:0] swap_d_a = 8'h00;
    reg  [7:0] swap_d_b = 8'h00;
    wire [7:0] q_a;
    wire [7:0] q_b;

    always #5 clk = ~clk;

    register dut (
        .clk(clk),
        .reset(reset),
        .load(load),
        .d(d),
        .q(q)
    );

    register u_reg_a (
        .clk(clk),
        .reset(swap_reset),
        .load(swap_load),
        .d(swap_d_a),
        .q(q_a)
    );

    register u_reg_b (
        .clk(clk),
        .reset(swap_reset),
        .load(swap_load),
        .d(swap_d_b),
        .q(q_b)
    );

    reg [7:0] reg_x = 8'hAA;
    reg [7:0] reg_y = 8'h55;

    always @(posedge clk) begin
        reg_x <= reg_y;
        reg_y <= reg_x;
    end

    task tick_and_check(input reg [7:0] exp_q);
        begin
            @(posedge clk);
            #1;
            if (q !== exp_q) begin
                $fatal(1, "register mismatch: got q=%02h expected %02h", q, exp_q);
            end
        end
    endtask

    initial begin
        $dumpfile("build/register.vcd");
        $dumpvars(0, register_tb);

        d = 8'hA5;
        load = 1'b0;
        reset = 1'b0;
        tick_and_check(8'h00);

        load = 1'b1;
        tick_and_check(8'hA5);

        load = 1'b0;
        d = 8'h3C;
        tick_and_check(8'hA5);

        reset = 1'b1;
        load = 1'b1;
        tick_and_check(8'h00);

        reset = 1'b0;
        load = 1'b1;
        d = 8'h5A;
        tick_and_check(8'h5A);

        if (reg_x !== 8'h55 || reg_y !== 8'hAA) begin
            $fatal(1, "non-blocking swap failed: reg_x=%02h reg_y=%02h", reg_x, reg_y);
        end

        swap_d_a = 8'h11;
        swap_d_b = 8'h22;
        swap_load = 1'b1;
        @(posedge clk);
        #1;
        swap_d_a = q_b;
        swap_d_b = q_a;
        @(posedge clk);
        #1;
        if (q_a !== 8'h22 || q_b !== 8'h11) begin
            $fatal(1, "register swap failed: q_a=%02h q_b=%02h", q_a, q_b);
        end

        $display("PASS: register load, hold, reset priority, and non-blocking swap passed");
        $finish;
    end
endmodule
