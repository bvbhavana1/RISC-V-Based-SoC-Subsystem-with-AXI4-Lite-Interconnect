/*
File: tb_uart_top.cpp
Purpose :
Verilator C++ standalone testbench for uart_top.

DUT hierarchy (via uart_top.v)
--------------------------------
  uart_top
    ├── uart_tx  ──[serial_line]──► uart_rx  (internal loopback)
    └── uart_rx  ◄────────────────────────────

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
  Frame    = 10 bits = 4340 cycles per byte (TX + RX pipeline ≈ 9000 cycles)
  String   = 12 bytes → total ≈ 108 000 cycles

Compile / Run
--------------
  make uart_top_sim
*/

// =============================================================================
// tb_uart_top.cpp – uart_top Verilator C++ Testbench
// =============================================================================

#include "Vuart_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdint>
#include <cstdio>
#include <cstring>

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
#define RESET_CYCLES  20
#define TX_TIMEOUT    20000    // max cycles to wait for tx_ready
#define RX_TIMEOUT    15000    // max cycles to wait for rx_valid per byte

static const char TX_STRING[] = "hello deepak";
static const int  STR_LEN     = (int)(sizeof(TX_STRING) - 1);  // 12

// ─────────────────────────────────────────────────────────────────────────────
// Simulation globals
// ─────────────────────────────────────────────────────────────────────────────
static vluint64_t  sim_time = 0;
static Vuart_top  *dut      = nullptr;
static VerilatedVcdC *tfp   = nullptr;

double sc_time_stamp() { return (double)sim_time; }

// ─────────────────────────────────────────────────────────────────────────────
// Clock tick — one full clock cycle (rising + falling edge)
// ─────────────────────────────────────────────────────────────────────────────
static void tick()
{
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}

// ─────────────────────────────────────────────────────────────────────────────
// Send one byte via tx_valid / tx_ready handshake
//   Returns true  on success
//          false  on tx_ready timeout
// ─────────────────────────────────────────────────────────────────────────────
static bool tx_send(uint8_t byte_val)
{
    // Step 1: wait for TX to be idle (tx_ready = 1)
    int cnt = 0;
    while (!dut->tx_ready && cnt < TX_TIMEOUT) {
        tick();
        cnt++;
    }
    if (!dut->tx_ready) {
        printf("[ERROR] TX ready timeout for byte 0x%02X\n", byte_val);
        return false;
    }

    // Step 2: assert tx_data + tx_valid for exactly one clock tick
    dut->tx_data  = byte_val;
    dut->tx_valid = 1;
    tick();               // at posedge: uart_tx latches byte, state→START

    // Step 3: deassert tx_valid
    dut->tx_valid = 0;
    dut->tx_data  = 0x00;

    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Wait for one rx_valid pulse and capture rx_data
//   Returns true  on success
//          false  on timeout
// ─────────────────────────────────────────────────────────────────────────────
static bool rx_recv(uint8_t *byte_out)
{
    int cnt = 0;
    while (!dut->rx_valid && cnt < RX_TIMEOUT) {
        tick();
        cnt++;
    }
    if (!dut->rx_valid) {
        printf("[ERROR] RX valid timeout\n");
        return false;
    }

    *byte_out = dut->rx_data;
    // Note: rx_valid is a 1-cycle pulse — it will deassert on the next tick
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────
int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    dut = new Vuart_top;

    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("tb_uart.vcd");

    // ── Initialise inputs ─────────────────────────────────────────────────────
    dut->clk      = 0;
    dut->reset    = 1;
    dut->tx_data  = 0;
    dut->tx_valid = 0;

    // ── Banner ────────────────────────────────────────────────────────────────
    printf("╔══════════════════════════════════════════════════════════╗\n");
    printf("║   uart_top Standalone Loopback Testbench                 ║\n");
    printf("║   TX String : \"hello deepak\"  (12 bytes)                 ║\n");
    printf("║   CLK : 50 MHz   BAUD : 115200   CLKS/BIT : 434          ║\n");
    printf("║   Mode : TX → serial_line → RX  (hardware loopback)      ║\n");
    printf("╚══════════════════════════════════════════════════════════╝\n\n");

    // ── Reset ─────────────────────────────────────────────────────────────────
    for (int i = 0; i < RESET_CYCLES; i++) tick();
    dut->reset = 0;
    tick(); tick();
    printf("[TB] Reset released. Starting transmission of \"%s\"...\n\n", TX_STRING);

    // ── Per-byte TX → RX test ─────────────────────────────────────────────────
    char  rx_string[STR_LEN + 1];
    int   bytes_passed  = 0;
    int   bytes_failed  = 0;
    bool  any_timeout   = false;

    printf("  Byte  Char  Sent    Received  Match\n");
    printf("  ────  ────  ──────  ────────  ─────\n");

    for (int i = 0; i < STR_LEN; i++) {
        uint8_t tx_byte = (uint8_t)TX_STRING[i];
        uint8_t rx_byte = 0x00;

        // Transmit
        bool tx_ok = tx_send(tx_byte);
        // Receive (wait for loopback to complete)
        bool rx_ok = tx_ok ? rx_recv(&rx_byte) : false;

        if (!tx_ok || !rx_ok) {
            any_timeout = true;
            bytes_failed++;
            printf("  [%2d]  '%c'   0x%02X    TIMEOUT   FAIL\n",
                   i, tx_byte, tx_byte);
        } else {
            rx_string[i] = (char)rx_byte;
            bool match = (rx_byte == tx_byte);
            if (match) bytes_passed++;
            else       bytes_failed++;
            printf("  [%2d]  '%c'   0x%02X    0x%02X      %s\n",
                   i, tx_byte, tx_byte, rx_byte, match ? "✓" : "✗ FAIL");
        }

        // Short gap between bytes (optional — TX stalls naturally via tx_ready)
        for (int g = 0; g < 5; g++) tick();
    }
    rx_string[STR_LEN] = '\0';

    // ── Final comparison ─────────────────────────────────────────────────────
    bool string_match = (strcmp(rx_string, TX_STRING) == 0);

    printf("\n────────────────────────────────────────────────────────────\n");
    printf("  TX string : \"%s\"\n", TX_STRING);
    printf("  RX string : \"%s\"\n", rx_string);
    printf("────────────────────────────────────────────────────────────\n");

    printf("\n╔══════════════════════════════════════════════════════════╗\n");
    printf("║   SIMULATION SUMMARY                                     ║\n");
    printf("╠══════════════════════════════════════════════════════════╣\n");
    printf("║   String length  : %-5d                                 ║\n", STR_LEN);
    printf("║   Bytes passed   : %-5d                                 ║\n", bytes_passed);
    printf("║   Bytes failed   : %-5d                                 ║\n", bytes_failed);
    printf("║   Sim cycles     : %-10llu                            ║\n",
           (unsigned long long)sim_time);
    printf("╠══════════════════════════════════════════════════════════╣\n");
    if (string_match && !any_timeout)
        printf("║   *** TEST PASSED ✓  TX == RX == \"hello deepak\" ***      ║\n");
    else
        printf("║   *** TEST FAILED ✗  String mismatch or timeout ***        ║\n");
    printf("╚══════════════════════════════════════════════════════════╝\n");

    tfp->close();
    delete tfp;
    delete dut;

    return (string_match && !any_timeout) ? 0 : 1;
}
