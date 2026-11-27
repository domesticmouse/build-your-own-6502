`timescale 1ns / 1ps

module top #(
    parameter integer STEP_PERIOD = 13500000
) (
    input  wire       clk,
    input  wire       s1,
    input  wire       s2,
    output wire [5:0] led
);
    localparam [1:0]
        MODE_ROM_READ = 2'd0,
        MODE_RAM_WR   = 2'd1,
        MODE_RAM_RD   = 2'd2,
        MODE_RAM_SHOW = 2'd3;

    reg [1:0] rst_sync  = 2'b00;
    reg [1:0] mode_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], s1};
        mode_sync <= {mode_sync[0], s2};
    end
    wire reset    = rst_sync[1];
    wire ram_mode = mode_sync[1];

    wire step;
    timer #(
        .PERIOD(STEP_PERIOD)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .tick(step)
    );

    reg  [15:0] bus_addr     = 16'hC000;
    reg  [7:0]  bus_data_out = 8'h00;
    reg         bus_write    = 1'b0;
    wire [7:0]  bus_data_in;

    bus u_bus (
        .clk(clk),
        .address(bus_addr),
        .data_out(bus_data_out),
        .write(bus_write),
        .data_in(bus_data_in)
    );

    reg [14:0] addr_cnt     = 15'd0;
    reg [1:0]  phase        = MODE_ROM_READ;
    reg        rom_armed    = 1'b0;
    reg [7:0]  display_byte = 8'h00;

    always @(posedge clk) begin
        if (reset) begin
            addr_cnt     <= 15'd0;
            phase        <= MODE_ROM_READ;
            rom_armed    <= 1'b0;
            bus_addr     <= 16'hC000;
            bus_data_out <= 8'h00;
            bus_write    <= 1'b0;
            display_byte <= 8'h00;
        end else if (step) begin
            if (!ram_mode) begin
                phase     <= MODE_ROM_READ;
                bus_write <= 1'b0;
                bus_addr  <= {2'b11, addr_cnt[13:0]};
                rom_armed <= 1'b1;
                if (rom_armed) begin
                    display_byte <= bus_data_in;
                end
                addr_cnt <= addr_cnt + 15'd1;
            end else begin
                rom_armed <= 1'b0;
                case (phase)
                    MODE_RAM_WR: begin
                        bus_addr     <= {1'b0, addr_cnt};
                        bus_data_out <= addr_cnt[7:0] ^ 8'h5A;
                        bus_write    <= 1'b1;
                        phase        <= MODE_RAM_RD;
                    end
                    MODE_RAM_RD: begin
                        bus_write <= 1'b0;
                        phase     <= MODE_RAM_SHOW;
                    end
                    MODE_RAM_SHOW: begin
                        display_byte <= bus_data_in;
                        addr_cnt     <= addr_cnt + 15'd1;
                        phase        <= MODE_RAM_WR;
                    end
                    default: begin
                        bus_write <= 1'b0;
                        phase     <= MODE_RAM_WR;
                    end
                endcase
            end
        end
    end

    assign led = ~display_byte[5:0];
endmodule
