/*
MODULE OVERVIEW
---------------
adc_controller.v – 8-bit SAR (Successive Approximation Register) ADC Core

This module implements the digital part of a Successive Approximation ADC.

HOW SAR ADC WORKS
-----------------------------------------
An SAR ADC works like a binary search game:
  1. We have an unknown analog voltage (vin).
  2. We generate a trial "guess" using a DAC.
  3. A comparator tells us: is vin >= guess?
  4. If YES → keep that bit (1). If NO → clear that bit (0).
  5. We try bit-by-bit from MSB (bit 7) to LSB (bit 0).
  6. After 8 steps, the SAR register holds the digital result.

DEBUG_CYCLES PARAMETER
-----------------------
  DEBUG_CYCLES = 1  →  real-time (1 clock per bit, default)
  DEBUG_CYCLES = N  →  each bit decision takes N clock cycles

  Setting DEBUG_CYCLES = 200 in the SoC makes every one of the 8 SAR steps
  last 200 clock periods → a complete conversion spans 1600 clock periods,
  making dac_out transitions clearly visible in GTKWave even when the full
  simulation covers millions of clock cycles.

  Functional result is identical; only timing is stretched.

PORTS
-----
  clk       – system clock
  reset     – synchronous active-high reset
  start     – pulse high for 1 cycle to begin conversion
  comp_in   – comparator result (1 = vin >= dac_out)
  dac_out   – current trial DAC value (updated each bit step)
  result    – final 8-bit ADC result (valid when done=1)
  done      – pulses high for 1 cycle when conversion is complete
  busy      – high while conversion is in progress
  adc_active– alias for busy – GTKWave conversion window marker

DEBUG SIGNALS (real internal values, not registered copies)
  dbg_sar   – live SAR register contents
  dbg_bit   – current bit index being tested (7→0)
  dbg_state – FSM state (0=IDLE, 1=CONVERTING, 2=DONE)
*/

`timescale 1ns / 1ps

module adc_controller #(
    // DEBUG_CYCLES – slow-down multiplier for GTKWave visibility.
    //   1 (default) = 1 clock per bit (real-time).
    //   N           = N clocks per bit; each SAR step is N cycles wide.
    // Set to 200 in the SoC instantiation so each conversion spans 1600 cycles.
    parameter DEBUG_CYCLES = 1
) (
    // ── Clock / Reset ──────────────────────────────────────────────────────────
    input  wire       clk,
    input  wire       reset,

    // ── Control / Status ───────────────────────────────────────────────────────
    input  wire       start,      // pulse to begin conversion
    output wire       busy,       // high during conversion
    output wire       done,       // pulses 1 cycle when conversion finishes
    output wire       adc_active, // GTKWave marker – alias for busy

    // ── Comparator Interface ───────────────────────────────────────────────────
    input  wire       comp_in,    // 1 = vin >= dac_out
    output wire [7:0] dac_out,    // trial DAC value (held between steps)

    // ── Result ─────────────────────────────────────────────────────────────────
    output wire [7:0] result,     // final ADC code (valid when done=1)

    // ── Debug signals (direct, non-registered) ─────────────────────────────────
    output wire [7:0] dbg_sar,    // SAR register contents
    output wire [3:0] dbg_bit,    // current bit index (7 downto 0)
    output wire [1:0] dbg_state   // FSM state
);

    // =========================================================================
    // FSM State Encoding
    // =========================================================================
    localparam ST_IDLE       = 2'd0;
    localparam ST_CONVERTING = 2'd1;
    localparam ST_DONE       = 2'd2;

    // =========================================================================
    // Internal Registers
    // =========================================================================
    reg [1:0] state;
    reg [7:0] sar_reg;    // accumulates the ADC result bit by bit
    reg [3:0] bit_idx;    // current bit being tested (7 → 0)
    reg [7:0] result_r;
    reg       done_r;

    // ── Debug slow-down counter ───────────────────────────────────────────────
    // Counts 0 .. DEBUG_CYCLES-1 for each bit position.
    // The SAR decision is made only when cyc_cnt reaches DEBUG_CYCLES-1.
    // At DEBUG_CYCLES=1 the condition (0 < 0) is always false → zero overhead.
    reg [9:0] cyc_cnt;   // supports up to 1023 wait cycles per bit

    // =========================================================================
    // Combinational Trial DAC Value
    // =========================================================================
    wire [7:0] trial_val;
    assign trial_val = sar_reg | (8'd1 << bit_idx);

    // =========================================================================
    // DAC Output – hold last trial value for GTKWave visibility
    // =========================================================================
    // During CONVERTING : dac_out = trial_val (live, steps with each bit)
    // After DONE / IDLE : dac_out holds the last trial value (non-zero, stable)
    reg [7:0] dac_hold;
    always @(posedge clk) begin
        if (reset)
            dac_hold <= 8'd0;
        else if (state == ST_CONVERTING)
            dac_hold <= trial_val;
    end
    assign dac_out    = (state == ST_CONVERTING) ? trial_val : dac_hold;
    assign busy       = (state == ST_CONVERTING);
    assign adc_active = (state == ST_CONVERTING);
    assign done       = done_r;
    assign result     = result_r;

    assign dbg_sar    = sar_reg;
    assign dbg_bit    = bit_idx;
    assign dbg_state  = state;

    // =========================================================================
    // SAR FSM
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            state    <= ST_IDLE;
            sar_reg  <= 8'd0;
            bit_idx  <= 4'd7;
            result_r <= 8'd0;
            done_r   <= 1'b0;
            cyc_cnt  <= 10'd0;

        end else begin

            done_r <= 1'b0;   // default: not pulsing

            case (state)

                // ── IDLE: wait for start pulse ────────────────────────────────
                ST_IDLE: begin
                    cyc_cnt <= 10'd0;
                    if (start) begin
                        sar_reg <= 8'd0;
                        bit_idx <= 4'd7;
                        state   <= ST_CONVERTING;
                    end
                end

                // ── CONVERTING: binary search ─────────────────────────────────
                //
                // Normal (DEBUG_CYCLES=1): one decision per clock.
                // Slow   (DEBUG_CYCLES=N): hold dac_out for N clocks, then
                //   sample comp_in and advance to the next bit.
                //
                // comp_in is sampled ONLY on the last cycle of the window so
                // the combinational comparator has the full window to settle.
                //
                ST_CONVERTING: begin
                    if (cyc_cnt < (DEBUG_CYCLES - 1)) begin
                        // ── Hold phase: dac_out stable, wait ─────────────────
                        cyc_cnt <= cyc_cnt + 10'd1;
                    end else begin
                        // ── Decision phase: sample comp_in, advance SAR ───────
                        cyc_cnt <= 10'd0;

                        if (comp_in)
                            sar_reg <= trial_val;   // keep this bit
                        // else: sar_reg unchanged (bit stays 0)

                        if (bit_idx == 4'd0) begin
                            // Last bit – latch result and finish
                            result_r <= comp_in ? trial_val : sar_reg;
                            done_r   <= 1'b1;
                            state    <= ST_DONE;
                        end else begin
                            bit_idx <= bit_idx - 4'd1;
                        end
                    end
                end

                // ── DONE: 1-cycle pulse then return to IDLE ───────────────────
                ST_DONE: begin
                    cyc_cnt <= 10'd0;
                    state   <= ST_IDLE;
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule
