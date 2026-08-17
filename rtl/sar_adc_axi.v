/*
MODULE OVERVIEW
---------------
sar_adc_axi.v – AXI-Lite Slave Wrapper for SAR ADC

This module wraps adc_controller with an AXI-Lite register interface.
The CPU (PicoRV32) can control the ADC through three memory-mapped registers.

REGISTER MAP (base address 0x20000000)
---------------------------------------
  Offset 0x00 – CTRL   (write-only)
    bit[0] : Write 1 to start a new ADC conversion.
             The bit is self-clearing (start is a 1-cycle pulse).

  Offset 0x04 – STATUS (read-only)
    bit[0] : done  – 1 = last conversion completed
    bit[1] : busy  – 1 = conversion in progress

  Offset 0x08 – DATA   (read-only)
    bits[7:0] : last 8-bit ADC result

EXTERNAL ANALOG INTERFACE
--------------------------
  dac_out [7:0] : Current trial DAC value (driven to external comparator)
  comp_in       : Comparator result (1 = vin >= dac_out)

These are physical I/O signals in a real chip.
In simulation, the testbench drives comp_in based on dac_out vs. a known vin.

DEBUG PORTS
-----------
  dbg_sar   : live SAR register content
  dbg_bit   : current bit index
  dbg_state : FSM state (0=IDLE, 1=CONVERTING, 2=DONE)
*/

// =============================================================================
// sar_adc_axi.v – AXI-Lite Slave Wrapper for 8-bit SAR ADC
// =============================================================================

`timescale 1ns / 1ps

module sar_adc_axi #(
    parameter DEBUG_CYCLES = 1   // pass to adc_controller (see that file)
) (
    // ── Clock / Reset ────────────────────────────────────────────────────────
    input  wire        clk,
    input  wire        reset,

    // ── AXI-Lite Slave Interface ─────────────────────────────────────────────
    // Write Address Channel
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // Write Data Channel
    input  wire [31:0] s_axi_wdata,
    input  wire [ 3:0] s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // Write Response Channel
    output wire [ 1:0] s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // Read Address Channel
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // Read Data Channel
    output wire [31:0] s_axi_rdata,
    output wire [ 1:0] s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // ── Analog Interface ─────────────────────────────────────────────────────
    input  wire        comp_in,      // 1 = vin >= dac_out
    output wire [ 7:0] dac_out,      // trial DAC value (to comparator)

    // ── Debug ports ──────────────────────────────────────────────────────────
    output wire [ 7:0] dbg_sar,      // SAR register
    output wire [ 3:0] dbg_bit,      // bit index
    output wire [ 1:0] dbg_state,    // FSM state
    output wire        adc_active    // HIGH during conversion (GTKWave marker)
);


    // =========================================================================
    // AXI Handshake Registers
    // =========================================================================
    reg        aw_active;      // write address has been captured
    reg [31:0] aw_addr_r;      // captured write address
    reg        bvalid_r;       // write response valid
    reg        arvalid_r;      // read address captured
    reg [31:0] ar_addr_r;      // captured read address
    reg        rvalid_r;       // read data valid
    reg [31:0] rdata_r;        // read data

    // =========================================================================
    // ADC Control / Status Registers
    // =========================================================================
    reg        done_latched;   // latches done signal until CPU reads STATUS
    reg [ 7:0] result_r;       // latches ADC result until CPU reads DATA

    // =========================================================================
    // ADC Controller Wires
    // =========================================================================
    wire        adc_start;
    wire        adc_busy;
    wire        adc_done;
    wire [ 7:0] adc_result;
    wire        adc_active_w;   // from adc_controller
    assign adc_active = adc_active_w;

    // =========================================================================
    // Write Decode Signals
    // =========================================================================
    // start pulse: generated combinationally when CPU writes 1 to CTRL (0x00)
    wire        ctrl_wr  = (aw_active && s_axi_wvalid &&
                            (aw_addr_r[3:0] == 4'h0) &&
                            s_axi_wdata[0]);

    assign adc_start = ctrl_wr;    // 1-cycle combinational pulse

    // =========================================================================
    // AXI Write Channel FSM
    // =========================================================================
    //
    // Simplified handshake:
    //   1. Accept AW → latch address
    //   2. Accept W  → handle register write
    //   3. Issue B   → signal completion
    //
    always @(posedge clk) begin
        if (reset) begin
            aw_active <= 1'b0;
            aw_addr_r <= 32'd0;
            bvalid_r  <= 1'b0;
        end else begin
            // Capture write address
            if (!aw_active && s_axi_awvalid) begin
                aw_active <= 1'b1;
                aw_addr_r <= s_axi_awaddr;
            end

            // Process write data
            if (aw_active && s_axi_wvalid && !bvalid_r) begin
                aw_active <= 1'b0;    // address consumed
                bvalid_r  <= 1'b1;    // prepare write response
                // CTRL register write (adc_start is combinational, handled above)
            end

            // Clear write response when accepted
            if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    // =========================================================================
    // AXI Read Channel
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            arvalid_r <= 1'b0;
            ar_addr_r <= 32'd0;
            rvalid_r  <= 1'b0;
            rdata_r   <= 32'd0;
        end else begin
            // Capture read address
            if (!arvalid_r && s_axi_arvalid) begin
                arvalid_r <= 1'b1;
                ar_addr_r <= s_axi_araddr;
            end

            // Decode register and return data
            if (arvalid_r && !rvalid_r) begin
                arvalid_r <= 1'b0;
                rvalid_r  <= 1'b1;

                case (ar_addr_r[3:0])
                    4'h4:    rdata_r <= {30'd0, adc_busy, done_latched};  // STATUS
                    4'h8:    rdata_r <= {24'd0, result_r};                 // DATA
                    default: rdata_r <= 32'd0;
                endcase
            end

            // Clear read response when accepted
            if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Latch ADC Done / Result
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            done_latched <= 1'b0;
            result_r     <= 8'd0;
        end else begin
            if (adc_done) begin
                done_latched <= 1'b1;       // stays set until CPU reads
                result_r     <= adc_result;
            end
            // Clear done flag when CPU reads STATUS register
            if (arvalid_r && (ar_addr_r[3:0] == 4'h4) && rvalid_r && s_axi_rready) begin
                done_latched <= 1'b0;
            end
        end
    end

    // =========================================================================
    // AXI Output Assignments
    // =========================================================================
    assign s_axi_awready = !aw_active;       // ready when idle
    assign s_axi_wready  = aw_active;        // ready only after AW captured
    assign s_axi_bresp   = 2'b00;            // OKAY
    assign s_axi_bvalid  = bvalid_r;

    assign s_axi_arready = !arvalid_r;       // ready when idle
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;            // OKAY
    assign s_axi_rvalid  = rvalid_r;

    // =========================================================================
    // ADC Controller Instance
    // =========================================================================
    adc_controller #(.DEBUG_CYCLES(DEBUG_CYCLES)) u_adc (
        .clk       (clk),
        .reset     (reset),
        .start     (adc_start),
        .busy      (adc_busy),
        .done      (adc_done),
        .adc_active(adc_active_w),
        .comp_in   (comp_in),
        .dac_out   (dac_out),
        .result    (adc_result),
        .dbg_sar   (dbg_sar),
        .dbg_bit   (dbg_bit),
        .dbg_state (dbg_state)
    );

endmodule
