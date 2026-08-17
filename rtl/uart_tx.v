/*
MODULE OVERVIEW
---------------
Simple 8N1 UART Transmitter.

ASIC-clean version:
  - Removed all inline reg initializers (= value); state driven by reset only
  - FSM and data path are purely synchronous and synthesizable
*/

// =============================================================================
// uart_tx.v – Simple 8N1 UART Transmitter
// =============================================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input            clk,
    input            reset,

    input      [7:0] data,
    input            valid,
    output           ready,

    output reg       tx
);

    // -------------------------------------------------------------------------
    // Baud rate clock divider
    // -------------------------------------------------------------------------
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    // -------------------------------------------------------------------------
    // Internal registers — NO inline initializers (removed for ASIC-clean)
    // -------------------------------------------------------------------------
    reg  [1:0]                    state;
    reg  [$clog2(CLKS_PER_BIT):0] clk_cnt;
    reg  [2:0]                    bit_cnt;
    reg  [7:0]                    shift_reg;

    assign ready = (state == IDLE);

    // -------------------------------------------------------------------------
    // UART Transmitter FSM
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            clk_cnt   <= 0;
            bit_cnt   <= 0;
            shift_reg <= 8'h00;
            tx        <= 1'b1;  // UART idle = HIGH
        end else begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    if (valid) begin
                        shift_reg <= data;
                        clk_cnt   <= 0;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        bit_cnt <= 0;
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    tx <= shift_reg[0];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt   <= 0;
                        shift_reg <= {1'b0, shift_reg[7:1]};
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
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
