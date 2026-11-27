`timescale 1ns / 1ps

module tmds_encoder (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] data,
    input  wire [1:0] ctrl,
    input  wire       visible,
    output reg  [9:0] tmds = 10'd0
);
    // Stage 1: transition minimisation (XOR vs XNOR)
    wire [3:0] n1_d = data[0] + data[1] + data[2] + data[3] +
                      data[4] + data[5] + data[6] + data[7];
    wire use_xnor = (n1_d > 4'd4) || ((n1_d == 4'd4) && (data[0] == 1'b0));

    wire [8:0] q_m;
    assign q_m[0] = data[0];
    assign q_m[1] = use_xnor ? ~(q_m[0] ^ data[1]) : (q_m[0] ^ data[1]);
    assign q_m[2] = use_xnor ? ~(q_m[1] ^ data[2]) : (q_m[1] ^ data[2]);
    assign q_m[3] = use_xnor ? ~(q_m[2] ^ data[3]) : (q_m[2] ^ data[3]);
    assign q_m[4] = use_xnor ? ~(q_m[3] ^ data[4]) : (q_m[3] ^ data[4]);
    assign q_m[5] = use_xnor ? ~(q_m[4] ^ data[5]) : (q_m[4] ^ data[5]);
    assign q_m[6] = use_xnor ? ~(q_m[5] ^ data[6]) : (q_m[5] ^ data[6]);
    assign q_m[7] = use_xnor ? ~(q_m[6] ^ data[7]) : (q_m[6] ^ data[7]);
    assign q_m[8] = ~use_xnor;

    // Stage 2: DC balance using running disparity (N_1 - N_0)
    wire [3:0] n1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                       q_m[4] + q_m[5] + q_m[6] + q_m[7];
    wire [3:0] n0_qm = 4'd8 - n1_qm;
    wire signed [4:0] diff = $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});

    reg signed [4:0] bias = 5'sd0;

    always @(posedge clk) begin
        if (reset || !visible) begin
            bias <= 5'sd0;
            case (ctrl)
                2'b00: tmds <= 10'b1101010100;
                2'b01: tmds <= 10'b0010101011;
                2'b10: tmds <= 10'b0101010100;
                2'b11: tmds <= 10'b1010101011;
            endcase
        end else if ((bias == 5'sd0) || (n1_qm == 4'd4)) begin
            tmds <= {~q_m[8], q_m[8], (q_m[8] ? q_m[7:0] : ~q_m[7:0])};
            if (q_m[8] == 1'b0) begin
                bias <= bias - diff;
            end else begin
                bias <= bias + diff;
            end
        end else if (((bias > 5'sd0) && (n1_qm > 4'd4)) ||
                     ((bias < 5'sd0) && (n1_qm < 4'd4))) begin
            tmds <= {1'b1, q_m[8], ~q_m[7:0]};
            bias <= bias + (q_m[8] ? 5'sd2 : 5'sd0) - diff;
        end else begin
            tmds <= {1'b0, q_m[8], q_m[7:0]};
            bias <= bias - (q_m[8] ? 5'sd0 : 5'sd2) + diff;
        end
    end
endmodule
