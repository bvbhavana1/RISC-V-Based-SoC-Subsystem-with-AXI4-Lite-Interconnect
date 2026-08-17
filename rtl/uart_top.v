/*
MODULE OVERVIEW
---------------
uart_top.v – Top-level module connecting uart_tx and uart_rx with an
             internal TX→RX loopback wire.

No AXI. No CPU. Pure UART datapath.

Interface
---------
  clk       : 50 MHz system clock
  reset     : active-high synchronous reset

  tx_data   : 8-bit byte to transmit
  tx_valid  : assert 1 cycle when tx_data is valid (handshake with tx_ready)
  tx_ready  : high when transmitter is idle and ready to accept new data

  rx_data   : 8-bit byte received (valid when rx_valid pulses HIGH for 1 cycle)
  rx_valid  : 1-cycle pulse when a byte has been successfully received

Loopback
--------
  uart_tx output (serial_line) is wired directly to uart_rx input.
  This means every byte sent via tx_data/tx_valid will be echoed back
  as rx_data/rx_valid after the full 8N1 frame has been serialised and
  re-deserialised by the RX engine.

  Latency: 10 bits × 434 cycles/bit (at 50 MHz/115200) ≈ 4340 clock cycles
           TX + RX pipeline ≈ 8700–9000 cycles total per byte.

Parameters
----------
  CLK_FREQ  : system clock frequency (Hz)   default 50 000 000
  BAUD_RATE : UART baud rate                default 115 200
*/

`timescale 1ns / 1ps

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input            clk,
    input            reset,

    // ── Transmit interface ───────────────────────────────────────────────────
    input      [7:0] tx_data,   // byte to send
    input            tx_valid,  // pulse high for 1+ cycles when tx_data valid
    output           tx_ready,  // high when TX is idle (ready to accept)

    // ── Receive interface ────────────────────────────────────────────────────
    output     [7:0] rx_data,   // received byte
    output           rx_valid   // 1-cycle pulse when rx_data is valid
);

    // ── Internal serial loopback wire ────────────────────────────────────────
    wire serial_line;           // TX serial output → RX serial input

    // ── UART Transmitter ─────────────────────────────────────────────────────
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk   (clk),
        .reset (reset),
        .data  (tx_data),
        .valid (tx_valid),
        .ready (tx_ready),
        .tx    (serial_line)
    );

    // ── UART Receiver ────────────────────────────────────────────────────────
    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk        (clk),
        .reset      (reset),
        .rx         (serial_line),   // loopback from TX
        .data_out   (rx_data),
        .data_valid (rx_valid)
    );

endmodule
