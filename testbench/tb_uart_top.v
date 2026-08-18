/*
File: tb_uart_top.v
Purpose:
Standalone Verilog testbench for uart_top.
Compatible with:  Icarus Verilog (vvp)  AND  Verilator --timing --binary
DUT hierarchy (via uart_top.v)
--------------------------------
  uart_top
    |-- uart_tx  --[serial_line]--► uart_rx  (internal loopback)
    `-- uart_rx  ◄────────────────────────────
No AXI-Lite.  No CPU.  No firmware.
TX interface: tx_data[7:0] + tx_valid → tx_ready handshake.
RX interface: rx_data[7:0] + rx_valid (one-cycle pulse).

Test: Transmit "hello deepak" (12 bytes) and verify full loopback
------
  1. For each character in "hello deepak":
       a. Wait for tx_ready = 1  (transmitter is idle)
       b. Assert tx_valid=1 + tx_data=char for one clock tick
       c. Deassert tx_valid
       d. Wait for rx_valid = 1 (receiver has captured the byte)
       e. Sample rx_data, compare with sent char → PASS / FAIL

Timing
-------
  CLK_FREQ = 50 MHz  →  20 ns period
  BAUD     = 115200  →  CLKS_PER_BIT = 434
  Frame    = 10 bits = 4340 cycles/byte (TX + RX pipeline ~8700 cycles total)
  String   = 12 bytes → total ~130 000 cycles

Simulator compatibility
-----------------------
  NO fork/join/disable.
  Verilator --timing coroutine scheduler does not reliably kill fork branches
  via `disable`.  Pure posedge-clocked while-loops are used for all waits;
  they work identically in Icarus and Verilator.
  rx_valid is driven by always @(posedge clk), so sampling it after each
  posedge is timing-correct and race-free in both simulators.

Compile / Run
--------------
  # Icarus Verilog
  iverilog -g2005 -o tb_uart.vvp \
    rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/tb_uart_top.v
  vvp tb_uart.vvp

  # Verilator (--timing required for #delay / @event in initial blocks)
  verilator --binary -j 0 --trace --timing --top tb_uart_top \
    -Mdir obj_uart -o sim_uart_top \
    -Wno-fatal -Wno-DECLFILENAME -Wno-GENUNNAMED -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE -Wno-EOFNEWLINE \
    rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/tb_uart_top.v
  ./obj_uart/sim_uart_top
*/

// =============================================================================
// tb_uart_top.v -- uart_top Standalone Loopback Testbench
// =============================================================================

`timescale 1ns / 1ps

module tb_uart_top;

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    parameter CLK_PERIOD = 20;      // 50 MHz  (20 ns)
    parameter TX_TIMEOUT = 20000;   // max cycles to wait for tx_ready
    parameter RX_TIMEOUT = 20000;   // max cycles to wait for rx_valid (~8700 max)

    reg clk;
    reg reset;
    reg [7:0] tx_data;
    reg       tx_valid;

    wire        tx_ready;
    wire [7:0]  rx_data;
    wire        rx_valid;

    // String to transmit
    reg [8*13-1:0] tx_string = "hello Bhavana";
    reg [7:0]      rx_string [0:12];

    // Loop / counter variables declared at module scope (required by Verilator)
    integer i;
    integer bytes_passed;
    integer bytes_failed;
    integer _tx_cnt;
    integer _rx_cnt;
    reg     any_timeout;
    reg [7:0] current_tx_char;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    uart_top dut (
        .clk      (clk),
        .reset    (reset),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Main Test Logic
    // -------------------------------------------------------------------------
    initial begin
        // Initialise signals
        reset        = 1;
        tx_data      = 0;
        tx_valid     = 0;
        bytes_passed = 0;
        bytes_failed = 0;
        any_timeout  = 0;

        // VCD dump
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart_top);

        $display("╔══════════════════════════════════════════════════════════╗");
        $display("║   uart_top Standalone Loopback Testbench                 ║");
        $display("║   Icarus + Verilator --timing compatible                 ║");
        $display("╚══════════════════════════════════════════════════════════╝");

        // Reset Sequence
        repeat (20) @(posedge clk);
        reset = 0;
        repeat (2) @(posedge clk);
        $display("[TB] Reset released. Starting transmission...");

        // ── Per-byte Loopback Test ────────────────────────────────────────────
        // Uses only posedge-clocked while-loops (no fork/join/disable).
        //
        for (i = 0; i < 12; i = i + 1) begin

            current_tx_char = tx_string[(11-i)*8 +: 8];

            // ── 1. Wait for tx_ready ──────────────────────────────────────────
            // Advance one posedge first so we don't sample a glitch immediately
            // after the previous byte's tx_valid deassert.
            _tx_cnt = 0;
            @(posedge clk);
            while (!tx_ready && _tx_cnt < TX_TIMEOUT) begin
                @(posedge clk);
                _tx_cnt = _tx_cnt + 1;
            end

            if (!tx_ready) begin
                $display("[ERROR] TX ready timeout (byte %0d)", i);
                any_timeout  = 1;
                bytes_failed = bytes_failed + 1;

            end else begin

                // ── 2. Assert tx_valid for exactly one posedge ────────────────
                tx_data  = current_tx_char;
                tx_valid = 1;
                @(posedge clk);         // uart_tx latches data on this edge
                tx_valid = 0;
                tx_data  = 0;

                // ── 3. Wait for rx_valid ──────────────────────────────────────
                // rx_valid is produced by always @(posedge clk), so checking
                // after each posedge is race-free in both Icarus & Verilator.
                _rx_cnt = 0;
                @(posedge clk);
                while (!rx_valid && _rx_cnt < RX_TIMEOUT) begin
                    @(posedge clk);
                    _rx_cnt = _rx_cnt + 1;
                end

                if (!rx_valid) begin
                    $display("  [%2d] '%c' Sent: 0x%02h  Recv: TIMEOUT",
                             i, current_tx_char, current_tx_char);
                    any_timeout  = 1;
                    bytes_failed = bytes_failed + 1;
                end else begin
                    rx_string[i] = rx_data;
                    if (rx_string[i] == current_tx_char) begin
                        $display("  [%2d] '%c' Sent: 0x%02h  Recv: 0x%02h  Match: ✓",
                                 i, current_tx_char, current_tx_char, rx_data);
                        bytes_passed = bytes_passed + 1;
                    end else begin
                        $display("  [%2d] '%c' Sent: 0x%02h  Recv: 0x%02h  Match: ✗ FAIL",
                                 i, current_tx_char, current_tx_char, rx_data);
                        bytes_failed = bytes_failed + 1;
                    end
                end

            end // tx_ready ok

            // Short inter-byte gap
            repeat (5) @(posedge clk);
        end

        // ── Summary ──────────────────────────────────────────────────────────
        $display("\n────────────────────────────────────────────────────────────");
        if (bytes_passed == 12 && !any_timeout)
            $display(" *** TEST PASSED ✓  TX == RX == \"hello Bhavana\" ***");
        else
            $display(" *** TEST FAILED ✗  Passed: %0d/12  Failed: %0d ***",
                     bytes_passed, bytes_failed);
        $display("────────────────────────────────────────────────────────────");

        $finish;
    end

endmodule
