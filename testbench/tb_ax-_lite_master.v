/*
MODULE OVERVIEW
---------------
tb_axi_lite_master.v – Reusable AXI-Lite master driver module.

This module acts as an AXI-Lite bus master in simulation.  Connect its
output ports to the slave DUT's input ports, and its input ports to the
slave DUT's output ports.  Then call the tasks from an enclosing initial
block to drive read/write transactions.

Provided tasks
--------------
  axi_write(addr, data, strb)
      Drives AW+W simultaneously, waits for B-channel OKAY.
      Result (bresp) available in `last_bresp`.

  axi_read(addr)
      Drives AR, waits for R-channel valid.
      Result available in `last_rdata` and `last_rresp`.

Usage pattern
-------------
  initial begin
      ...
      do_axi_write(32'h0000, 32'h0041, 4'b0001);
      do_axi_read (32'h0008);
      if (last_rdata[1]) $display("rx_valid asserted");
      ...
  end

Compatibility
-------------
  • Verilog-2001 / -g2005  (Icarus-compatible)
  • Verilator-compatible for structural use (tasks NOT synthesisable)
*/

`timescale 1ns / 1ps

module tb_axi_lite_master #(
    parameter AXI_TIMEOUT = 1000   // max cycles per handshake step
)(
    input clk,
    input reset,

    // ── AXI-Lite Master Output ports (connect to slave DUT inputs) ───────────
    output reg [31:0] m_awaddr,
    output reg        m_awvalid,
    input             m_awready,

    output reg [31:0] m_wdata,
    output reg [ 3:0] m_wstrb,
    output reg        m_wvalid,
    input             m_wready,

    input  [ 1:0]     m_bresp,
    input             m_bvalid,
    output reg        m_bready,

    output reg [31:0] m_araddr,
    output reg        m_arvalid,
    input             m_arready,

    input  [31:0]     m_rdata,
    input  [ 1:0]     m_rresp,
    input             m_rvalid,
    output reg        m_rready,

    // ── Transaction results (read by enclosing testbench) ────────────────────
    output reg [31:0] last_rdata,
    output reg [ 1:0] last_rresp,
    output reg [ 1:0] last_bresp,
    output reg        timeout_flag   // asserted if any transaction timed out
);

    // ── Reset all outputs ─────────────────────────────────────────────────────
    initial begin
        m_awaddr    = 32'h0;
        m_awvalid   = 1'b0;
        m_wdata     = 32'h0;
        m_wstrb     = 4'h0;
        m_wvalid    = 1'b0;
        m_bready    = 1'b0;
        m_araddr    = 32'h0;
        m_arvalid   = 1'b0;
        m_rready    = 1'b0;
        last_rdata  = 32'h0;
        last_rresp  = 2'b00;
        last_bresp  = 2'b00;
        timeout_flag = 1'b0;
    end

    // Shared scratch variables (static in Verilog-2001)
    integer  _cnt;
    reg      _aw_done, _w_done;

    // =========================================================================
    // Task: AXI-Lite Write
    //   Drives AW + W simultaneously so the slave can latch both in one cycle.
    //   Handles the case where awready/wready fire on the same clock edge.
    // =========================================================================
    task do_axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [ 3:0] strb;
        begin
            // Drive AW and W together
            m_awaddr  = addr;
            m_awvalid = 1'b1;
            m_wdata   = data;
            m_wstrb   = strb;
            m_wvalid  = 1'b1;
            m_bready  = 1'b0;

            _aw_done = 1'b0;
            _w_done  = 1'b0;
            _cnt     = 0;

            // Wait for both handshakes (may occur on the same clock edge)
            while ((!_aw_done || !_w_done) && _cnt < AXI_TIMEOUT) begin
                @(posedge clk); #1;
                if (m_awready && m_awvalid) begin
                    _aw_done  = 1'b1;
                    m_awvalid = 1'b0;
                end
                if (m_wready && m_wvalid) begin
                    _w_done  = 1'b1;
                    m_wvalid = 1'b0;
                end
                _cnt = _cnt + 1;
            end

            if (!_aw_done || !_w_done) begin
                $display("[MASTER] ERROR: AXI Write channel TIMEOUT addr=0x%08X", addr);
                timeout_flag = 1'b1;
            end

            // B-channel: accept write response
            m_bready = 1'b1;
            _cnt     = 0;
            while (!m_bvalid && _cnt < AXI_TIMEOUT) begin
                @(posedge clk); #1;
                _cnt = _cnt + 1;
            end
            last_bresp = m_bresp;
            @(posedge clk); #1;
            m_bready = 1'b0;

            if (_cnt >= AXI_TIMEOUT) begin
                $display("[MASTER] ERROR: B-channel TIMEOUT addr=0x%08X", addr);
                timeout_flag = 1'b1;
            end else if (m_bresp !== 2'b00) begin
                $display("[MASTER] WARN: BRESP=0x%0X (non-OKAY) addr=0x%08X",
                         m_bresp, addr);
            end
        end
    endtask

    // =========================================================================
    // Task: AXI-Lite Read (result in last_rdata / last_rresp)
    // =========================================================================
    task do_axi_read;
        input [31:0] addr;
        begin
            m_araddr  = addr;
            m_arvalid = 1'b1;
            m_rready  = 1'b0;   // FIX: keep rready LOW so r_vld is not cleared
                                 //      the instant it is set by the AR handshake

            // AR handshake: wait for arready
            _cnt = 0;
            while (!m_arready && _cnt < AXI_TIMEOUT) begin
                @(posedge clk); #1;
                _cnt = _cnt + 1;
            end
            @(posedge clk); #1;   // confirmation clock: handshake fires here
            m_arvalid = 1'b0;

            // R channel: wait for rvalid WITH rready still LOW
            // This prevents r_vld from being cleared before we sample it.
            _cnt = 0;
            while (!m_rvalid && _cnt < AXI_TIMEOUT) begin
                @(posedge clk); #1;
                _cnt = _cnt + 1;
            end

            // Now assert rready to complete the handshake and capture data
            m_rready  = 1'b1;
            last_rdata = m_rdata;
            last_rresp = m_rresp;
            @(posedge clk); #1;   // DUT clears r_vld on this edge
            m_rready = 1'b0;

            if (_cnt >= AXI_TIMEOUT) begin
                $display("[MASTER] ERROR: R-channel TIMEOUT addr=0x%08X", addr);
                timeout_flag = 1'b1;
            end
        end
    endtask

endmodule
