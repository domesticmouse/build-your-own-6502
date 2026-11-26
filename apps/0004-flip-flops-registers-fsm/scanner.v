`timescale 1ns / 1ps

module scanner (
    input  wire       clk,
    input  wire       reset,
    input  wire       step,
    output reg  [5:0] leds = 6'b000001
);
    localparam S_LEFT  = 1'b0;
    localparam S_RIGHT = 1'b1;

    reg state = S_LEFT;

    always @(posedge clk) begin
        if (reset) begin
            leds  <= 6'b000001;
            state <= S_LEFT;
        end else if (step) begin
            case (state)
                S_LEFT: begin
                    leds <= {leds[4:0], 1'b0};
                    if (leds == 6'b010000) begin
                        state <= S_RIGHT;
                    end
                end
                S_RIGHT: begin
                    leds <= {1'b0, leds[5:1]};
                    if (leds == 6'b000010) begin
                        state <= S_LEFT;
                    end
                end
                default: begin
                    leds  <= 6'b000001;
                    state <= S_LEFT;
                end
            endcase
        end
    end
endmodule
