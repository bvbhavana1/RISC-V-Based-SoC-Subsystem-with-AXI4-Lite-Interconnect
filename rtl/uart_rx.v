/*
MODULE OVERVIEW
---------------
UART Receiver (8N1 format).

ASIC-clean version:
  - Removed all inline reg initializers (= value); state driven by reset only
  - rx_sync0/rx_sync1 now reset to 1'b1 (line-idle) via reset block
  - data_out/data_valid outputs declared without initializers
*/

`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input            clk,
    input            reset,

    input            rx,

    output reg [7:0] data_out,
    output reg       data_valid
);

    // -------------------------------------------------------------------------
    // Baud rate timing constants
    // -------------------------------------------------------------------------
    localparam integer CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam integer CLKS_HALF_BIT = CLKS_PER_BIT / 2;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    // -------------------------------------------------------------------------
    // 2-FF Synchronizer — NO inline initializers (removed for ASIC-clean)
    // -------------------------------------------------------------------------
    reg rx_sync0;
    reg rx_sync1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync0 <= 1'b1;   // idle = HIGH
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    wire rx_s = rx_sync1;

    // -------------------------------------------------------------------------
    // Receiver registers — NO inline initializers
    // -------------------------------------------------------------------------
    reg  [1:0]                    state;
    reg  [$clog2(CLKS_PER_BIT):0] clk_cnt;
    reg  [2:0]                    bit_cnt;
    reg  [7:0]                    shift_reg;

    // -------------------------------------------------------------------------
    // UART Receiver FSM
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            clk_cnt    <= 0;
            bit_cnt    <= 0;
            shift_reg  <= 8'h00;
            data_out   <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;  // default: pulse low

            case (state)

                IDLE: begin
                    if (!rx_s) begin
                        clk_cnt <= 0;
                        state   <= START;
                    end
                end

                START: begin
                    if (clk_cnt == CLKS_HALF_BIT - 1) begin
                        if (!rx_s) begin
                            clk_cnt <= 0;
                            bit_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state <= IDLE;   // false glitch
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt   <= 0;
                        shift_reg <= {rx_s, shift_reg[7:1]};
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (rx_s) begin
                            data_out   <= shift_reg;
                            data_valid <= 1'b1;
                        end
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
