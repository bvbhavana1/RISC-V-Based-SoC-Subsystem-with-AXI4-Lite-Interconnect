/*
MODULE OVERVIEW
---------------
Simple AXI-Lite interconnect: 1 master → 3 slaves (ROM, SRAM, UART).

ASIC-clean version:
  - Removed all inline reg initializers (wr_sel_r, rd_sel_r, wr_active, rd_active)
  - Added explicit 32'h0 default to rdata/rresp muxes to ensure deterministic
    output when no slave is selected (prevents synthesis inferring latches)
*/

`timescale 1ns / 1ps

module axi_lite_interconnect (
    input  clk,
    input  reset,

    // ─────────────────────────────────────────────────────────────────────
    // AXI MASTER PORT (Connected to CPU)
    // ─────────────────────────────────────────────────────────────────────
    input  [31:0] m_axi_awaddr,
    input         m_axi_awvalid,
    output        m_axi_awready,

    input  [31:0] m_axi_wdata,
    input  [ 3:0] m_axi_wstrb,
    input         m_axi_wvalid,
    output        m_axi_wready,

    output [ 1:0] m_axi_bresp,
    output        m_axi_bvalid,
    input         m_axi_bready,

    input  [31:0] m_axi_araddr,
    input         m_axi_arvalid,
    output        m_axi_arready,

    output [31:0] m_axi_rdata,
    output [ 1:0] m_axi_rresp,
    output        m_axi_rvalid,
    input         m_axi_rready,


    // ─────────────────────────────────────────────────────────────────────
    // SLAVE 0 : ROM
    // ─────────────────────────────────────────────────────────────────────
    output [31:0] s0_axi_awaddr,  output s0_axi_awvalid, input s0_axi_awready,
    output [31:0] s0_axi_wdata,   output [3:0] s0_axi_wstrb,
    output        s0_axi_wvalid,  input  s0_axi_wready,
    input  [ 1:0] s0_axi_bresp,   input  s0_axi_bvalid,  output s0_axi_bready,
    output [31:0] s0_axi_araddr,  output s0_axi_arvalid, input  s0_axi_arready,
    input  [31:0] s0_axi_rdata,   input  [1:0] s0_axi_rresp,
    input         s0_axi_rvalid,  output s0_axi_rready,


    // ─────────────────────────────────────────────────────────────────────
    // SLAVE 1 : SRAM
    // ─────────────────────────────────────────────────────────────────────
    output [31:0] s1_axi_awaddr,  output s1_axi_awvalid, input s1_axi_awready,
    output [31:0] s1_axi_wdata,   output [3:0] s1_axi_wstrb,
    output        s1_axi_wvalid,  input  s1_axi_wready,
    input  [ 1:0] s1_axi_bresp,   input  s1_axi_bvalid,  output s1_axi_bready,
    output [31:0] s1_axi_araddr,  output s1_axi_arvalid, input  s1_axi_arready,
    input  [31:0] s1_axi_rdata,   input  [1:0] s1_axi_rresp,
    input         s1_axi_rvalid,  output s1_axi_rready,


    // ─────────────────────────────────────────────────────────────────────
    // SLAVE 2 : UART
    // ─────────────────────────────────────────────────────────────────────
    output [31:0] s2_axi_awaddr,  output s2_axi_awvalid, input s2_axi_awready,
    output [31:0] s2_axi_wdata,   output [3:0] s2_axi_wstrb,
    output        s2_axi_wvalid,  input  s2_axi_wready,
    input  [ 1:0] s2_axi_bresp,   input  s2_axi_bvalid,  output s2_axi_bready,
    output [31:0] s2_axi_araddr,  output s2_axi_arvalid, input  s2_axi_arready,
    input  [31:0] s2_axi_rdata,   input  [1:0] s2_axi_rresp,
    input         s2_axi_rvalid,  output s2_axi_rready
);

    // -------------------------------------------------------------------------
    // Address Decode
    // -------------------------------------------------------------------------
    wire [2:0] wr_sel_comb;
    wire [2:0] rd_sel_comb;

    axi_decoder u_wr_dec (.addr(m_axi_awaddr), .sel(wr_sel_comb));
    axi_decoder u_rd_dec (.addr(m_axi_araddr), .sel(rd_sel_comb));


    // -------------------------------------------------------------------------
    // Transaction tracking — NO inline initializers (removed for ASIC-clean)
    // -------------------------------------------------------------------------
    reg [2:0] wr_sel_r;
    reg [2:0] rd_sel_r;
    reg       wr_active;
    reg       rd_active;

    wire [2:0] wr_sel = wr_active ? wr_sel_r : wr_sel_comb;
    wire [2:0] rd_sel = rd_active ? rd_sel_r : rd_sel_comb;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_sel_r  <= 3'b001;  // default: ROM
            rd_sel_r  <= 3'b001;
            wr_active <= 1'b0;
            rd_active <= 1'b0;
        end else begin
            if (!wr_active && m_axi_awvalid) begin
                wr_sel_r  <= wr_sel_comb;
                wr_active <= 1'b1;
            end
            if (wr_active && m_axi_bvalid && m_axi_bready)
                wr_active <= 1'b0;

            if (!rd_active && m_axi_arvalid) begin
                rd_sel_r  <= rd_sel_comb;
                rd_active <= 1'b1;
            end
            if (rd_active && m_axi_rvalid && m_axi_rready)
                rd_active <= 1'b0;
        end
    end


    // =========================================================================
    // WRITE ADDRESS CHANNEL ROUTING
    // =========================================================================
    assign s0_axi_awaddr  = m_axi_awaddr;
    assign s0_axi_awvalid = m_axi_awvalid & wr_sel[0];

    assign s1_axi_awaddr  = m_axi_awaddr;
    assign s1_axi_awvalid = m_axi_awvalid & wr_sel[1];

    assign s2_axi_awaddr  = m_axi_awaddr;
    assign s2_axi_awvalid = m_axi_awvalid & wr_sel[2];

    assign m_axi_awready  = (wr_sel[0] & s0_axi_awready) |
                            (wr_sel[1] & s1_axi_awready) |
                            (wr_sel[2] & s2_axi_awready);


    // =========================================================================
    // WRITE DATA CHANNEL ROUTING
    // =========================================================================
    assign s0_axi_wdata   = m_axi_wdata;
    assign s0_axi_wstrb   = m_axi_wstrb;
    assign s0_axi_wvalid  = m_axi_wvalid & wr_sel[0];

    assign s1_axi_wdata   = m_axi_wdata;
    assign s1_axi_wstrb   = m_axi_wstrb;
    assign s1_axi_wvalid  = m_axi_wvalid & wr_sel[1];

    assign s2_axi_wdata   = m_axi_wdata;
    assign s2_axi_wstrb   = m_axi_wstrb;
    assign s2_axi_wvalid  = m_axi_wvalid & wr_sel[2];

    assign m_axi_wready   = (wr_sel[0] & s0_axi_wready) |
                            (wr_sel[1] & s1_axi_wready) |
                            (wr_sel[2] & s2_axi_wready);


    // =========================================================================
    // WRITE RESPONSE CHANNEL ROUTING
    // =========================================================================
    assign m_axi_bresp    = (wr_sel[0] ? s0_axi_bresp :
                             wr_sel[1] ? s1_axi_bresp :
                             wr_sel[2] ? s2_axi_bresp :
                                         2'b00);            // safe default

    assign m_axi_bvalid   = (wr_sel[0] & s0_axi_bvalid) |
                            (wr_sel[1] & s1_axi_bvalid) |
                            (wr_sel[2] & s2_axi_bvalid);

    assign s0_axi_bready  = m_axi_bready & wr_sel[0];
    assign s1_axi_bready  = m_axi_bready & wr_sel[1];
    assign s2_axi_bready  = m_axi_bready & wr_sel[2];


    // =========================================================================
    // READ ADDRESS CHANNEL ROUTING
    // =========================================================================
    assign s0_axi_araddr  = m_axi_araddr;
    assign s0_axi_arvalid = m_axi_arvalid & rd_sel[0];

    assign s1_axi_araddr  = m_axi_araddr;
    assign s1_axi_arvalid = m_axi_arvalid & rd_sel[1];

    assign s2_axi_araddr  = m_axi_araddr;
    assign s2_axi_arvalid = m_axi_arvalid & rd_sel[2];

    assign m_axi_arready  = (rd_sel[0] & s0_axi_arready) |
                            (rd_sel[1] & s1_axi_arready) |
                            (rd_sel[2] & s2_axi_arready);


    // =========================================================================
    // READ DATA CHANNEL ROUTING
    // =========================================================================
    // FIX: Added explicit default (32'h0 / 2'b00) to prevent synthesis
    // from inferring a latch or producing non-deterministic output when
    // rd_sel is 3'b000 (possible during reset transitional state).
    // =========================================================================
    assign m_axi_rdata    = (rd_sel[0] ? s0_axi_rdata :
                             rd_sel[1] ? s1_axi_rdata :
                             rd_sel[2] ? s2_axi_rdata :
                                         32'h0000_0013);    // NOP — safe default

    assign m_axi_rresp    = (rd_sel[0] ? s0_axi_rresp :
                             rd_sel[1] ? s1_axi_rresp :
                             rd_sel[2] ? s2_axi_rresp :
                                         2'b00);

    assign m_axi_rvalid   = (rd_sel[0] & s0_axi_rvalid) |
                            (rd_sel[1] & s1_axi_rvalid) |
                            (rd_sel[2] & s2_axi_rvalid);

    assign s0_axi_rready  = m_axi_rready & rd_sel[0];
    assign s1_axi_rready  = m_axi_rready & rd_sel[1];
    assign s2_axi_rready  = m_axi_rready & rd_sel[2];

endmodule
