/*
File: tb_axi_lite.cpp
Purpose :
Verilator C++ standalone testbench for the AXI-Lite protocol layer.

DUT: uart_axi (via tb_axi_lite_wrap.v)
  uart_rx = 1'b1 (line idle)
  Focus: AXI-Lite write/read handshake correctness, backpressure, RDATA values

Tests
------
  T1  single_write         Write 0x41 to offset 0x00; verify BRESP=OKAY
  T2  single_read_status   Read offset 0x08 (STATUS); rx_buf_valid=0 expected
  T3  single_read_data     Read offset 0x00 (DATA); bit[8]=rx_buf_valid=0
  T4  back_to_back_writes  3 successive writes; all must complete without error
  T5  write_then_poll_aw   After write, awready must be LOW while buf_valid=1
  T6  multiple_reads       Repeated STATUS reads; all must return RRESP=OKAY
  T7  wstrb_byte_lanes     Write with different wstrb values; no crash/deadlock

Compile / Run
--------------
  make axilite_sim
*/
// =============================================================================
// tb_axi_lite.cpp – AXI-Lite Verilator C++ Testbench (protocol-level)
// =============================================================================
#include "Vtb_axi_lite_wrap.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdint>
#include <cstdio>
#include <cstring>
// ─────────────────────────────────────────────────────────────────────────────
// uart_axi Register Offsets
// ─────────────────────────────────────────────────────────────────────────────
#define REG_DATA    0x00u   // TX write / RX read
#define REG_STATUS  0x08u   // STATUS: bit[1]=rx_buf_valid (read-only, no clear)

// ─────────────────────────────────────────────────────────────────────────────
// Simulation globals
// ─────────────────────────────────────────────────────────────────────────────
#define RESET_CYCLES  20
// uart_axi stalls awready/wready while buf_valid=1 (TX serialising).
// One UART frame at 50 MHz/115200 baud ≈ 4340 cycles.  Use a generous
// 10 000 cycle timeout so back-to-back writes can drain the TX buffer.
#define AXI_TIMEOUT   10000  // max cycles per handshake step

static vluint64_t      sim_time = 0;
static Vtb_axi_lite_wrap *dut  = nullptr;
static VerilatedVcdC   *tfp    = nullptr;

double sc_time_stamp() { return (double)sim_time; }

// ─────────────────────────────────────────────────────────────────────────────
// Clock tick
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
// AXI-Lite Write
//   Returns true if transaction completed with BRESP=OKAY.
//   Drives AW+W simultaneously.
// ─────────────────────────────────────────────────────────────────────────────
static bool axi_write(uint32_t addr, uint32_t data,
                      uint8_t strb = 0xF, uint8_t *bresp_out = nullptr)
{
    dut->s_axi_awaddr  = addr;
    dut->s_axi_awvalid = 1;
    dut->s_axi_wdata   = data;
    dut->s_axi_wstrb   = strb;
    dut->s_axi_wvalid  = 1;
    dut->s_axi_bready  = 0;

    bool aw_done = false, w_done = false;
    int  cnt = 0;

    while ((!aw_done || !w_done) && cnt < AXI_TIMEOUT) {
        tick();
        if (dut->s_axi_awready && dut->s_axi_awvalid) {
            aw_done            = true;
            dut->s_axi_awvalid = 0;
        }
        if (dut->s_axi_wready && dut->s_axi_wvalid) {
            w_done            = true;
            dut->s_axi_wvalid = 0;
        }
        cnt++;
    }

    if (!aw_done || !w_done) {
        printf("[ERROR] axi_write: AW/W timeout at addr=0x%08X\n", addr);
        dut->s_axi_awvalid = 0;
        dut->s_axi_wvalid  = 0;
        return false;
    }

    // B-channel
    dut->s_axi_bready = 1;
    cnt = 0;
    while (!dut->s_axi_bvalid && cnt < AXI_TIMEOUT) { tick(); cnt++; }
    uint8_t bresp = dut->s_axi_bresp;
    if (bresp_out) *bresp_out = bresp;
    tick();
    dut->s_axi_bready = 0;

    if (cnt >= AXI_TIMEOUT) {
        printf("[ERROR] axi_write: B-channel timeout at addr=0x%08X\n", addr);
        return false;
    }
    return (bresp == 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// AXI-Lite Read
// ─────────────────────────────────────────────────────────────────────────────
static uint32_t axi_read(uint32_t addr, uint8_t *rresp_out = nullptr)
{
    dut->s_axi_araddr  = addr;
    dut->s_axi_arvalid = 1;
    dut->s_axi_rready  = 1;

    int cnt = 0;
    while (!dut->s_axi_arready && cnt < AXI_TIMEOUT) { tick(); cnt++; }
    tick();
    dut->s_axi_arvalid = 0;

    cnt = 0;
    while (!dut->s_axi_rvalid && cnt < AXI_TIMEOUT) { tick(); cnt++; }
    uint32_t rdata = dut->s_axi_rdata;
    uint8_t  rresp = dut->s_axi_rresp;
    if (rresp_out) *rresp_out = rresp;
    tick();
    dut->s_axi_rready = 0;

    if (cnt >= AXI_TIMEOUT)
        printf("[ERROR] axi_read: timeout at addr=0x%08X\n", addr);

    return rdata;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────
static int g_tests_run    = 0;
static int g_tests_passed = 0;

static void check(bool cond, const char *name)
{
    g_tests_run++;
    if (cond) {
        g_tests_passed++;
        printf("  [PASS] %s\n", name);
    } else {
        printf("  [FAIL] %s\n", name);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────
int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    dut = new Vtb_axi_lite_wrap;

    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("tb_axi_lite.vcd");

    // ── Initialise inputs ─────────────────────────────────────────────────────
    dut->clk           = 0;
    dut->reset         = 1;
    dut->s_axi_awaddr  = 0;
    dut->s_axi_awvalid = 0;
    dut->s_axi_wdata   = 0;
    dut->s_axi_wstrb   = 0;
    dut->s_axi_wvalid  = 0;
    dut->s_axi_bready  = 0;
    dut->s_axi_araddr  = 0;
    dut->s_axi_arvalid = 0;
    dut->s_axi_rready  = 0;

    printf("╔══════════════════════════════════════════════════════════╗\n");
    printf("║   AXI-Lite Standalone Verilator Testbench                ║\n");
    printf("║   DUT : uart_axi  (uart_rx=1, no loopback)               ║\n");
    printf("║   Focus: AXI-Lite protocol correctness                   ║\n");
    printf("╚══════════════════════════════════════════════════════════╝\n\n");

    // ── Reset ─────────────────────────────────────────────────────────────────
    for (int i = 0; i < RESET_CYCLES; i++) tick();
    dut->reset = 0;
    tick(); tick();
    printf("[TB] Reset released. Running tests...\n\n");

    uint8_t  bresp, rresp;
    uint32_t rdata;
    bool     ok;

    // ── T1: Single write ──────────────────────────────────────────────────────
    printf("── T1: Single write to TX register ─────────────────────────\n");
    ok = axi_write(REG_DATA, 0x41u, 0x1, &bresp);   // write 'A', strb=0001
    check(ok,           "T1a: axi_write returns true (no timeout)");
    check(bresp == 0x0, "T1b: BRESP = 0x0 (OKAY)");
    for (int i = 0; i < 5; i++) tick();

    // ── T2: Read STATUS register (should be empty) ────────────────────────────
    printf("\n── T2: Read STATUS register (offset 0x08) ───────────────────\n");
    rdata = axi_read(REG_STATUS, &rresp);
    printf("  STATUS rdata = 0x%08X  rresp=0x%X\n", rdata, rresp);
    check(rresp == 0x0,              "T2a: RRESP = 0x0 (OKAY)");
    check(((rdata >> 1) & 1u) == 0, "T2b: STATUS.rx_buf_valid = 0 (RX empty)");
    for (int i = 0; i < 5; i++) tick();

    // ── T3: Read DATA register when RX empty ─────────────────────────────────
    printf("\n── T3: Read DATA register (offset 0x00) while RX empty ──────\n");
    rdata = axi_read(REG_DATA, &rresp);
    printf("  DATA  rdata = 0x%08X  rresp=0x%X\n", rdata, rresp);
    check(rresp == 0x0,             "T3a: RRESP = 0x0 (OKAY)");
    check(((rdata >> 8) & 1u) == 0, "T3b: DATA.rx_buf_valid = 0 (RX empty)");
    for (int i = 0; i < 5; i++) tick();

    // ── T4: Back-to-back writes ───────────────────────────────────────────────
    // Each write stalls until buf drains (previous TX serialization completes).
    // AXI_TIMEOUT = 2000 cycles, each byte ≈ 4340 cycles → this is intentional.
    printf("\n── T4: Back-to-back writes (B, C, D) ────────────────────────\n");
    uint8_t bytes[3] = { 0x42, 0x43, 0x44 };
    for (int i = 0; i < 3; i++) {
        char label[64];
        snprintf(label, sizeof(label), "T4%c: byte 0x%02X BRESP=OKAY",
                 (char)('a'+i), bytes[i]);
        ok = axi_write(REG_DATA, (uint32_t)bytes[i], 0x1, &bresp);
        check(ok && bresp == 0x0, label);
        for (int j = 0; j < 5; j++) tick();
    }

    // ── T5: awready must be LOW immediately after write (backpressure) ────────
    printf("\n── T5: Backpressure — awready LOW while TX buffer busy ───────\n");
    // Write a byte, then immediately (next tick) check awready
    dut->s_axi_awaddr  = REG_DATA;
    dut->s_axi_awvalid = 1;
    dut->s_axi_wdata   = 0x45;   // 'E'
    dut->s_axi_wstrb   = 0x1;
    dut->s_axi_wvalid  = 1;
    dut->s_axi_bready  = 0;

    // Wait for first handshake
    int cnt2 = 0;
    while ((!dut->s_axi_awready || !dut->s_axi_wready) && cnt2 < AXI_TIMEOUT) {
        tick(); cnt2++;
    }
    tick();  // handshake complete; buf_valid now goes HIGH
    dut->s_axi_awvalid = 0;
    dut->s_axi_wvalid  = 0;

    // Accept B response
    dut->s_axi_bready = 1;
    cnt2 = 0;
    while (!dut->s_axi_bvalid && cnt2 < AXI_TIMEOUT) { tick(); cnt2++; }
    tick();
    dut->s_axi_bready = 0;

    // Now buf_valid=1 → awready must be LOW
    dut->eval();
    bool awready_low = (dut->s_axi_awready == 0);
    check(awready_low, "T5: awready=0 immediately after write (buf_valid=1)");
    for (int i = 0; i < 5; i++) tick();

    // ── T6: Multiple reads return RRESP OKAY consistently ─────────────────────
    printf("\n── T6: Multiple STATUS reads (RRESP consistency) ────────────\n");
    for (int i = 0; i < 4; i++) {
        char label[64];
        snprintf(label, sizeof(label), "T6[%d]: STATUS RRESP=OKAY", i);
        rdata = axi_read(REG_STATUS, &rresp);
        check(rresp == 0x0, label);
    }

    // ── T7: Write with different byte-lane strobes ────────────────────────────
    printf("\n── T7: wstrb byte-lane selection ────────────────────────────\n");
    // Wait for previous TX (from T5) to fully drain (one frame = ~4340 cycles)
    for (int drain = 0; drain < 5000; drain++) tick();
    // uart_axi uses the first set strb bit to select the byte:
    //   strb[0] → wdata[7:0], strb[1] → wdata[15:8], etc.
    struct { uint32_t data; uint8_t strb; const char *desc; } strb_tests[] = {
        { 0x00004600, 0x2, "strb=0010 byte 'F' from [15:8]" },
        { 0x00470000, 0x4, "strb=0100 byte 'G' from [23:16]" },
        { 0x48000000, 0x8, "strb=1000 byte 'H' from [31:24]" },
    };
    for (int i = 0; i < 3; i++) {
        char label[80];
        snprintf(label, sizeof(label), "T7[%d]: %s BRESP=OKAY", i, strb_tests[i].desc);
        ok = axi_write(REG_DATA, strb_tests[i].data, strb_tests[i].strb, &bresp);
        check(ok && bresp == 0x0, label);
        // Drain TX between strb tests
        for (int j = 0; j < 5000; j++) tick();
    }

    // ── Summary ───────────────────────────────────────────────────────────────
    printf("\n╔══════════════════════════════════════════════════════════╗\n");
    printf("║   SIMULATION SUMMARY                                     ║\n");
    printf("╠══════════════════════════════════════════════════════════╣\n");
    printf("║   Tests run    : %-5d                                   ║\n", g_tests_run);
    printf("║   Tests passed : %-5d                                   ║\n", g_tests_passed);
    printf("║   Tests failed : %-5d                                   ║\n", g_tests_run - g_tests_passed);
    printf("║   Sim cycles   : %-10llu                              ║\n",
           (unsigned long long)sim_time);
    printf("╠══════════════════════════════════════════════════════════╣\n");
    if (g_tests_passed == g_tests_run)
        printf("║   *** ALL TESTS PASSED ✓ ***                             ║\n");
    else
        printf("║   *** SOME TESTS FAILED ✗ ***                            ║\n");
    printf("╚══════════════════════════════════════════════════════════╝\n");

    tfp->close();
    delete tfp;
    delete dut;

    return (g_tests_passed == g_tests_run) ? 0 : 1;
}
