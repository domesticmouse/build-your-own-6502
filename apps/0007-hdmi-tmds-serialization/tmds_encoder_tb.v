`timescale 1ns / 1ps

module tmds_encoder_tb;
    reg        clk     = 1'b0;
    reg        reset   = 1'b0;
    reg  [7:0] data    = 8'd0;
    reg  [1:0] ctrl    = 2'b00;
    reg        visible = 1'b0;
    wire [9:0] tmds;

    tmds_encoder dut (
        .clk(clk),
        .reset(reset),
        .data(data),
        .ctrl(ctrl),
        .visible(visible),
        .tmds(tmds)
    );

    always #5 clk = ~clk;

    function automatic [7:0] decode_tmds(input [9:0] sym);
        reg [7:0] q;
        integer k;
        begin
            q = sym[9] ? ~sym[7:0] : sym[7:0];
            decode_tmds[0] = q[0];
            if (sym[8]) begin
                for (k = 1; k < 8; k = k + 1) begin
                    decode_tmds[k] = q[k] ^ q[k - 1];
                end
            end else begin
                for (k = 1; k < 8; k = k + 1) begin
                    decode_tmds[k] = ~(q[k] ^ q[k - 1]);
                end
            end
        end
    endfunction

    function automatic integer count_transitions(input [9:0] sym);
        integer k;
        begin
            count_transitions = 0;
            for (k = 0; k < 9; k = k + 1) begin
                if (sym[k] !== sym[k + 1]) begin
                    count_transitions = count_transitions + 1;
                end
            end
        end
    endfunction

    function automatic integer symbol_disparity(input [9:0] sym);
        integer k;
        integer ones;
        begin
            ones = 0;
            for (k = 0; k < 10; k = k + 1) begin
                if (sym[k]) ones = ones + 1;
            end
            symbol_disparity = (2 * ones) - 10;
        end
    endfunction

    task automatic check_ctrl(input [1:0] c, input [9:0] expected);
        begin
            visible = 1'b0;
            ctrl    = c;
            @(posedge clk);
            #1;
            if (tmds !== expected) begin
                $display("FAIL: ctrl=%b expected %b, got %b", c, expected, tmds);
                $fatal(1);
            end
        end
    endtask

    integer val;
    integer total_disp;
    integer max_trans;
    integer tr;
    reg [7:0] decoded;

    task automatic run_dc_sweep(input [7:0] byte_val);
        integer step;
        begin
            visible = 1'b0; ctrl = 2'b00;
            @(posedge clk);
            #1;
            total_disp = 0;
            visible    = 1'b1;
            data       = byte_val;
            for (step = 0; step < 500; step = step + 1) begin
                @(posedge clk);
                #1;
                decoded = decode_tmds(tmds);
                if (decoded !== byte_val) begin
                    $display("FAIL: decode mismatch for 0x%02x -> %b -> 0x%02x", byte_val, tmds, decoded);
                    $fatal(1);
                end
                total_disp = total_disp + symbol_disparity(tmds);
                if (total_disp > 10 || total_disp < -10) begin
                    $display("FAIL: DC disparity out of bounds (%0d) on 0x%02x", total_disp, byte_val);
                    $fatal(1);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("build/tmds_encoder.vcd");
        $dumpvars(0, tmds_encoder_tb);

        // 1. Verify all 4 DVI control tokens during blanking
        check_ctrl(2'b00, 10'b1101010100);
        check_ctrl(2'b01, 10'b0010101011);
        check_ctrl(2'b10, 10'b0101010100);
        check_ctrl(2'b11, 10'b1010101011);

        // 2. Exhaustive lossless round-trip & transition-count check over all 256 byte values
        visible    = 1'b1;
        total_disp = 0;
        max_trans  = 0;
        for (val = 0; val < 256; val = val + 1) begin
            data = val[7:0];
            @(posedge clk);
            #1;
            decoded = decode_tmds(tmds);
            if (decoded !== val[7:0]) begin
                $display("FAIL: round-trip failed for 0x%02x (got 0x%02x from %b)", val, decoded, tmds);
                $fatal(1);
            end
            tr = count_transitions(tmds);
            if (tr > max_trans) max_trans = tr;
            if (tr > 5) begin
                $display("FAIL: >5 transitions (%0d) on 0x%02x -> %b", tr, val, tmds);
                $fatal(1);
            end
            total_disp = total_disp + symbol_disparity(tmds);
        end
        if (total_disp > 10 || total_disp < -10) begin
            $display("FAIL: ramp DC disparity out of bounds: %0d", total_disp);
            $fatal(1);
        end

        // 3. Long constant-colour runs to stress DC balancing
        run_dc_sweep(8'h00);
        run_dc_sweep(8'hFF);
        run_dc_sweep(8'h55);
        run_dc_sweep(8'hAA);
        run_dc_sweep(8'h0F);
        run_dc_sweep(8'hE0);

        $display("PASS: TMDS encoder verified (4 ctrl tokens, all 256 bytes lossless, max %0d transitions, DC balanced)", max_trans);
        $finish;
    end
endmodule
