/*
MODULE OVERVIEW
---------------
tb_axi_lite_wrap.v – Structural Verilog wrapper used as the Verilator
**top-level** for the AXI-Lite standalone testbench (tb_axi_lite.cpp).

What it contains
----------------
  • One instance of uart_axi (concrete AXI-Lite slave)
  • uart_rx tied HIGH (idle line) — tests focus on AXI-Lite protocol,
    not UART data path (use tb_uart_wrap for loopback testing)
  • All AXI-Lite ports exposed so the C++ driver can issue transactions
  • uart_tx_mon port for serial waveform visibility in GTKWave

No PicoRV32. No AXI interconnect. No firmware. No loopback.

Simulation flow
---------------
  make axilite_sim         →  build + run Verilator AXI-Lite standalone
  make axilite_wave        →  open tb_axi_lite.vcd in waveform viewer
*/

`timescale 1ns / 1ps

module tb_axi_lite_wrap #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    // Clock / Reset
    input         clk,
    input         reset,

    // AXI-Lite Write Address Channel
    input  [31:0] s_axi_awaddr,
    input         s_axi_awvalid,
    output        s_axi_awready,

    // AXI-Lite Write Data Channel
    input  [31:0] s_axi_wdata,
    input  [ 3:0] s_axi_wstrb,
    input         s_axi_wvalid,
    output        s_axi_wready,

    // AXI-Lite Write Response Channel
    output [ 1:0] s_axi_bresp,
    output        s_axi_bvalid,
    input         s_axi_bready,

    // AXI-Lite Read Address Channel
    input  [31:0] s_axi_araddr,
    input         s_axi_arvalid,
    output        s_axi_arready,

    // AXI-Lite Read Data Channel
    output [31:0] s_axi_rdata,
    output [ 1:0] s_axi_rresp,
    output        s_axi_rvalid,
    input         s_axi_rready,

    // UART TX monitor (for waveform visibility)
    output        uart_tx_mon
);

    uart_axi #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart (
        .clk           (clk),
        .reset         (reset),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .uart_tx       (uart_tx_mon),
        .uart_rx       (1'b1)    // idle — no loopback, pure AXI protocol test
    );

endmodule
