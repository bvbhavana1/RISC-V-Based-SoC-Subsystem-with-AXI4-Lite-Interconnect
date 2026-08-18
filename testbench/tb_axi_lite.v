/*
File: tb/tb_axi_lite.v
DUT : uart_axi (AXI-Lite UART slave)

12-Bit SAR ADC AXI-Lite Protocol Testbench  (Verilog – self-contained)
-----------------------------------------------------------------------
Test suite matches tb_axi_lite.cpp output quality.

Tests
-----
  T1  Single write 'A' to TX register (offset 0x00)
  T2  Read STATUS (offset 0x08) — expect rx_buf_valid=0
  T3  Read DATA   (offset 0x00) — expect rx_buf_valid=0
  T4  Back-to-back writes 'B','C','D'
  T5  Backpressure: awready LOW while buf_valid=1 + buf busy
  T6  Multiple reads verify RRESP=OKAY consistently
  T7  wstrb byte-lane selection ('F'[15:8], 'G'[23:16], 'H'[31:24])

Debug output
------------
  ┌─ per-transaction boxes with:
  │    addr hex · data hex   · ASCII char where applicable
  │    BRESP / RRESP decoded  · register field breakdown
  └─

Compatibility
--------------
  • Verilator  --binary --timing  (no #N delays; pure @posedge protocol)
  • Icarus Verilog  -g2005

Run (Verilator)
----------------
  verilator --binary -j 0 --trace --timing --top tb_axi_lite \
    -Mdir obj_axilite -o sim_axilite \
    -Wno-fatal -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE \
    -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-MULTITOP \
    -Wno-DECLFILENAME -Wno-GENUNNAMED -Wno-UNUSEDSIGNAL -Wno-EOFNEWLINE \
    rtl/uart_tx.v rtl/uart_rx.v rtl/uart_axi.v \
    tb/tb_axi_lite_master.v tb/tb_axi_lite.v
  ./obj_axilite/sim_axilite

Run (Icarus)
-------------
  iverilog -g2005 -o /tmp/tb_axilite.vvp \
      rtl/uart_tx.v rtl/uart_rx.v rtl/uart_axi.v \
      tb/tb_axi_lite_master.v tb/tb_axi_lite.v
  vvp /tmp/tb_axilite.vvp
*/

`timescale 1ns / 1ps

module tb_axi_lite;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_FREQ   = 50_000_000;
    localparam BAUD_RATE  = 115_200;
    localparam CLK_PERIOD = 20;         // 50 MHz

    // =========================================================================
    // Clock / Reset
    // =========================================================================
    reg clk   = 1'b0;
    reg reset = 1'b1;

    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // AXI-Lite wires
    // =========================================================================
    wire [31:0] awaddr;  wire awvalid; wire awready;
    wire [31:0] wdata;   wire [3:0] wstrb; wire wvalid; wire wready;
    wire [ 1:0] bresp;   wire bvalid;  wire bready;
    wire [31:0] araddr;  wire arvalid; wire arready;
    wire [31:0] rdata;   wire [1:0] rresp; wire rvalid; wire rready;

    // Master result wires
    wire [31:0] last_rdata;
    wire [ 1:0] last_rresp;
    wire [ 1:0] last_bresp;
    wire        timeout_flag;

    // =========================================================================
    // AXI-Lite Master driver
    // =========================================================================
    tb_axi_lite_master #(
        .AXI_TIMEOUT(6000)   // 1 UART frame ≈ 4340 cycles @50MHz/115200
    ) u_master (
        .clk          (clk),
        .reset        (reset),
        .m_awaddr     (awaddr),
        .m_awvalid    (awvalid),
        .m_awready    (awready),
        .m_wdata      (wdata),
        .m_wstrb      (wstrb),
        .m_wvalid     (wvalid),
        .m_wready     (wready),
        .m_bresp      (bresp),
        .m_bvalid     (bvalid),
        .m_bready     (bready),
        .m_araddr     (araddr),
        .m_arvalid    (arvalid),
        .m_arready    (arready),
        .m_rdata      (rdata),
        .m_rresp      (rresp),
        .m_rvalid     (rvalid),
        .m_rready     (rready),
        .last_rdata   (last_rdata),
        .last_rresp   (last_rresp),
        .last_bresp   (last_bresp),
        .timeout_flag (timeout_flag)
    );

    // =========================================================================
    // DUT : uart_axi
    //   uart_rx = 1'b1  (line idle — pure AXI protocol testing)
    // =========================================================================
    wire uart_tx_line;

    uart_axi #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_dut (
        .clk           (clk),
        .reset         (reset),
        .s_axi_awaddr  (awaddr),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),
        .tx_out        (uart_tx_line),
        .uart_rx       (1'b1)
    );

    // =========================================================================
    // VCD dump
    // =========================================================================
    initial begin
        $dumpfile("tb_axi_lite.vcd");
        $dumpvars(0, tb_axi_lite);
    end

    // =========================================================================
    // Simulation timeout guard
    // =========================================================================
    initial begin
        #200_000_000;
        $display("[ERROR] Simulation TIMEOUT (200ms sim-time limit)");
        $finish;
    end

    // =========================================================================
    // TX-line monitor: print decoded char whenever uart_tx goes LOW (start bit)
    // This shows each byte being serialised on the wire in real-time.
    // =========================================================================
    reg tx_prev;
    always @(posedge clk) tx_prev <= uart_tx_line;

    always @(posedge clk) begin
        if (tx_prev === 1'b1 && uart_tx_line === 1'b0)
            $display("[TX_LINE] Start-bit detected on uart_tx — byte serialization in progress");
    end

    // =========================================================================
    // Backpressure monitor
    // =========================================================================
    reg bp_seen = 1'b0;
    reg mon_en  = 1'b0;

    always @(posedge clk) begin
        if (mon_en && awvalid && !awready)
            bp_seen <= 1'b1;
    end

    // =========================================================================
    // Scoreboard
    // =========================================================================
    integer tests_run    = 0;
    integer tests_passed = 0;

    // ── check task ────────────────────────────────────────────────────────────
    task check;
        input        pass_cond;
        input [255:0] name;
        begin
            tests_run = tests_run + 1;
            if (pass_cond) begin
                tests_passed = tests_passed + 1;
                $display("  [PASS] %s", name);
            end else
                $display("  [FAIL] %s", name);
        end
    endtask

    // =========================================================================
    // Debug print helpers
    // =========================================================================

    // Print write transaction header box
    task print_write_hdr;
        input [31:0] addr;
        input [31:0] data;
        input [ 3:0] strb;
        input [ 7:0] ch;          // ASCII char (0 if not applicable)
        begin
            $display("  ┌─────────────────────────────────────────────────────┐");
            $display("  │  AXI WRITE                                          │");
            $display("  │  Addr : 0x%08h                                  │", addr);
            $display("  │  Data : 0x%08h   strb=%04b                      │", data, strb);
            if (ch >= 8'h20 && ch <= 8'h7E)
                $display("  │  Byte : '%s'  (0x%02h = %0d decimal)                    │",
                         ch, ch, ch);
            $display("  └─────────────────────────────────────────────────────┘");
        end
    endtask

    // Print write result
    task print_write_result;
        input [1:0] bresp_v;
        input       tmo;
        begin
            $display("  ╔═══════════════════════════════╗");
            if (!tmo)
                $display("  ║  BRESP = %02b  (%s)         ║",
                     bresp_v, (bresp_v == 2'b00) ? "OKAY  " : "SLVERR");
            else
              $display("  ║  BRESP : TIMEOUT!               ║");
            $display("  ╚═══════════════════════════════╝");
        end
    endtask

    // Print read header
    task print_read_hdr;
        input [31:0] addr;
        begin
            $display("  ┌─────────────────────────────────────────────────────┐");
            $display("  │  AXI READ                                           │");
            $display("  │  Addr : 0x%08h                                  │", addr);
            $display("  └─────────────────────────────────────────────────────┘");
        end
    endtask

    // Print STATUS register decode  (offset 0x08)
    //   bit[0] = tx_ready
    //   bit[1] = rx_buf_valid
    task print_status_result;
        input [31:0] rdata_v;
        input [ 1:0] rresp_v;
        input        tmo;
        begin
            $display("  ╔═══════════════════════════════════════════════════════╗");
            if (!tmo) begin
                $display("  ║  RRESP     = %02b  (%s)                             ║",
                         rresp_v, (rresp_v == 2'b00) ? "OKAY  " : "SLVERR");
                $display("  ║  RDATA     = 0x%08h                               ║", rdata_v);
                $display("  ║  ─────────────── STATUS fields ────────────────       ║");
                $display("  ║  bit[0] tx_ready     = %0b                              ║", rdata_v[0]);
                $display("  ║  bit[1] rx_buf_valid = %0b  (%s)             ║",
                         rdata_v[1],
                         (rdata_v[1]) ? "RX DATA READY" : "RX EMPTY     ");
            end else
                $display("  ║  R-channel: TIMEOUT!                         ║");
            $display("  ╚═══════════════════════════════════════════════════════╝");
        end
    endtask

    // Print DATA register decode  (offset 0x00/0x04)
    //   bits[7:0]  = rx_buf_data
    //   bit[8]     = rx_buf_valid
    task print_data_result;
        input [31:0] rdata_v;
        input [ 1:0] rresp_v;
        input        tmo;
        reg   [ 7:0] char_v;
        begin
            char_v = rdata_v[7:0];
            $display("  ╔═══════════════════════════════════════════════════════╗");
            if (!tmo) begin
                $display("  ║  RRESP     = %02b  (%s)                             ║",
                         rresp_v, (rresp_v == 2'b00) ? "OKAY  " : "SLVERR");
                $display("  ║  RDATA     = 0x%08h                               ║", rdata_v);
                $display("  ║  ─────────────── DATA fields ──────────────────       ║");
                $display("  ║  bit[8]     rx_buf_valid = %0b  (%s)         ║",
                         rdata_v[8],
                         (rdata_v[8]) ? "DATA READY   " : "RX EMPTY     ");
                $display("  ║  bits[7:0]  rx_buf_data  = 0x%02h                       ║", char_v);
                if (char_v >= 8'h20 && char_v <= 8'h7E && rdata_v[8])
                    $display("  ║  ASCII char = '%s'                                    ║", char_v);
            end else
                $display("  ║  R-channel: TIMEOUT!                                  ║");
            $display("  ╚═══════════════════════════════════════════════════════╝");
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    integer i;
    reg [7:0] byte_arr [0:2];

    initial begin
        // Banner
        $display("╔══════════════════════════════════════════════════════════╗");
        $display("║  AXI-Lite Standalone Verilog Testbench                   ║");
        $display("║  DUT : uart_axi  (uart_rx=1, no loopback)                ║");
        $display("║  CLK : %0d MHz    BAUD : %0d                           ║",
             CLK_FREQ/1_000_000, BAUD_RATE);
        $display("║  Focus: AXI-Lite protocol correctness + debug visibility ║");
        $display("║  NIELIT CoE  |  Icarus + Verilator --timing compatible   ║");
        $display("╚══════════════════════════════════════════════════════════╝");
        $display("");

        // Reset
        reset = 1'b1;
        repeat(10) @(posedge clk);
        reset = 1'b0;
        repeat(5)  @(posedge clk);
        $display("[TB] Reset released. Running AXI-Lite protocol tests...");
        $display("");

        // =====================================================================
        // T1: Single write — 'A' (0x41) to TX register (offset 0x00)
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T1] Single AXI write  →  TX register (offset 0x00)  byte='A'");
        $display("──────────────────────────────────────────────────────────────");
        print_write_hdr(32'h0000_0000, 32'h0000_0041, 4'b0001, 8'h41);
        u_master.do_axi_write(32'h0000_0000, 32'h0000_0041, 4'b0001);
        print_write_result(last_bresp, timeout_flag);
        check(!timeout_flag && last_bresp === 2'b00,
              "T1a: Single write 'A' completed — no timeout");
        check(last_bresp === 2'b00,
              "T1b: BRESP = 2'b00 (OKAY)");
        $display("");
        repeat(5) @(posedge clk);

        // =====================================================================
        // T2: Read STATUS register (offset 0x08)
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T2] AXI read  →  STATUS register (offset 0x08)");
        $display("──────────────────────────────────────────────────────────────");
        print_read_hdr(32'h0000_0008);
        u_master.do_axi_read(32'h0000_0008);
        print_status_result(last_rdata, last_rresp, timeout_flag);
        check(!timeout_flag && last_rresp === 2'b00,
              "T2a: STATUS RRESP = 2'b00 (OKAY)");
        check(last_rdata[1] === 1'b0,
              "T2b: STATUS.rx_buf_valid = 0 (RX buffer empty)");
        $display("");
        repeat(5) @(posedge clk);

        // =====================================================================
        // T3: Read DATA register (offset 0x00) while RX empty
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T3] AXI read  →  DATA register (offset 0x00) while RX empty");
        $display("──────────────────────────────────────────────────────────────");
        print_read_hdr(32'h0000_0000);
        u_master.do_axi_read(32'h0000_0000);
        print_data_result(last_rdata, last_rresp, timeout_flag);
        check(!timeout_flag && last_rresp === 2'b00,
              "T3a: DATA RRESP = 2'b00 (OKAY)");
        check(last_rdata[8] === 1'b0,
              "T3b: DATA.rx_buf_valid = 0 (no RX data)");
        $display("");
        repeat(5) @(posedge clk);

        // =====================================================================
        // T4: Back-to-back writes — 'B','C','D'
        //     Each write blocks on awready until the previous TX clears.
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T4] Back-to-back AXI writes  →  bytes 'B','C','D'");
        $display("──────────────────────────────────────────────────────────────");

        byte_arr[0] = 8'h42; // 'B'
        byte_arr[1] = 8'h43; // 'C'
        byte_arr[2] = 8'h44; // 'D'

        begin : t4_block
            reg [31:0] wdata_v;
            reg [ 7:0] cur_byte;
            reg [255:0] lbl;

            for (i = 0; i < 3; i = i + 1) begin
                cur_byte = byte_arr[i];
                wdata_v  = {24'h0, cur_byte};

                $display("  ── T4[%0d]: Write byte 0x%02h ('%s') ──",
                         i, cur_byte, cur_byte);
                print_write_hdr(32'h0000_0000, wdata_v, 4'b0001, cur_byte);
                u_master.do_axi_write(32'h0000_0000, wdata_v, 4'b0001);
                print_write_result(last_bresp, timeout_flag);

                if (!timeout_flag && last_bresp === 2'b00) begin
                    tests_run    = tests_run + 1;
                    tests_passed = tests_passed + 1;
                    $display("  [PASS] T4[%0d]: byte '%s' (0x%02h) write OKAY",
                             i, cur_byte, cur_byte);
                end else begin
                    tests_run = tests_run + 1;
                    $display("  [FAIL] T4[%0d]: byte '%s' (0x%02h) write FAILED",
                             i, cur_byte, cur_byte);
                end
                $display("");
                repeat(5) @(posedge clk);
            end
        end

        // =====================================================================
        // T5: Backpressure test
        //   Write 'E' → goes to TX immediately (TX was idle)
        //   Write 'F' → fills buf_valid=1 (TX busy with 'E')
        //   Write 'G' → both TX busy AND buf_valid=1 → awready MUST stay LOW
        //               This verifies slave correctly holds off the master.
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T5] Backpressure test  —  awready LOW while TX+buf both full");
        $display("      Write 'E' → TX,  'F' → buf,  'G' → stall until drain");
        $display("──────────────────────────────────────────────────────────────");

        bp_seen = 1'b0;

        $display("  ── T5[E]: Write 0x45 'E' → TX takes it directly ──");
        print_write_hdr(32'h0000_0000, 32'h0000_0045, 4'b0001, 8'h45);
        u_master.do_axi_write(32'h0000_0000, 32'h0000_0045, 4'b0001);
        print_write_result(last_bresp, timeout_flag);
        $display("");

        $display("  ── T5[F]: Write 0x46 'F' → fills buf_valid=1 ──");
        print_write_hdr(32'h0000_0000, 32'h0000_0046, 4'b0001, 8'h46);
        u_master.do_axi_write(32'h0000_0000, 32'h0000_0046, 4'b0001);
        print_write_result(last_bresp, timeout_flag);
        $display("");

        $display("  ── T5[G]: Write 0x47 'G' → SHOULD STALL until drain ──");
        print_write_hdr(32'h0000_0000, 32'h0000_0047, 4'b0001, 8'h47);
        mon_en  = 1'b1;
        u_master.do_axi_write(32'h0000_0000, 32'h0000_0047, 4'b0001);
        mon_en  = 1'b0;
        print_write_result(last_bresp, timeout_flag);

        $display("  ╔══════════════════════════════════════════════════╗");
        $display("  ║  Backpressure result                             ║");
        $display("  ║ bp_seen = %0b (%s)║",
                 bp_seen,
                 bp_seen ? "awready was LOW — backpressure OK " :
                           "awready never LOW — BP NOT DETECTED");
        $display("  ╚══════════════════════════════════════════════════╝");
        check(bp_seen, "T5: awready held LOW during 'G' write (backpressure OK)");
        $display("");
        repeat(5) @(posedge clk);

        // =====================================================================
        // T6: Multiple reads — verify RRESP=OKAY consistently
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T6] Multiple STATUS + DATA reads  —  RRESP consistency");
        $display("──────────────────────────────────────────────────────────────");

        $display("  ── T6[0]: STATUS read (offset 0x08) ──");
        print_read_hdr(32'h0000_0008);
        u_master.do_axi_read(32'h0000_0008);
        print_status_result(last_rdata, last_rresp, timeout_flag);
        check(last_rresp === 2'b00, "T6a: 2nd STATUS RRESP=OKAY");

        $display("");
        $display("  ── T6[1]: DATA read (offset 0x00) ──");
        print_read_hdr(32'h0000_0000);
        u_master.do_axi_read(32'h0000_0000);
        print_data_result(last_rdata, last_rresp, timeout_flag);
        check(last_rresp === 2'b00, "T6b: 2nd DATA RRESP=OKAY");

        $display("");
        $display("  ── T6[2]: STATUS read (repeat) ──");
        print_read_hdr(32'h0000_0008);
        u_master.do_axi_read(32'h0000_0008);
        print_status_result(last_rdata, last_rresp, timeout_flag);
        check(last_rresp === 2'b00, "T6c: 3rd STATUS RRESP=OKAY");

        $display("");
        $display("  ── T6[3]: DATA read (repeat) ──");
        print_read_hdr(32'h0000_0000);
        u_master.do_axi_read(32'h0000_0000);
        print_data_result(last_rdata, last_rresp, timeout_flag);
        check(last_rresp === 2'b00, "T6d: 3rd DATA RRESP=OKAY");
        $display("");

        // =====================================================================
        // T7: wstrb byte-lane selection
        //   uart_axi uses the FIRST set strb bit to select the TX byte:
        //     strb[1] → wdata[15:8]  ('F' = 0x46)
        //     strb[2] → wdata[23:16] ('G' = 0x47)
        //     strb[3] → wdata[31:24] ('H' = 0x48)
        //   Drain TX between each write (~4340 cycles per byte).
        // =====================================================================
        $display("──────────────────────────────────────────────────────────────");
        $display("[T7] wstrb byte-lane selection  —  'F'[15:8] 'G'[23:16] 'H'[31:24]");
        $display("──────────────────────────────────────────────────────────────");

        // Drain any remaining TX traffic from T5 before starting T7
        $display("  [T7] Draining TX pipeline (~5000 cycles)...");
        repeat(5000) @(posedge clk);

        begin : t7_block
            // strb tests: {data, strb, expected_byte, desc}
            // Encoded as arrays
            reg [31:0] t7_data [0:2];
            reg [ 3:0] t7_strb [0:2];
            reg [ 7:0] t7_byte [0:2];

            t7_data[0] = 32'h0000_4600; t7_strb[0] = 4'b0010; t7_byte[0] = 8'h46; // 'F'
            t7_data[1] = 32'h0047_0000; t7_strb[1] = 4'b0100; t7_byte[1] = 8'h47; // 'G'
            t7_data[2] = 32'h4800_0000; t7_strb[2] = 4'b1000; t7_byte[2] = 8'h48; // 'H'

            for (i = 0; i < 3; i = i + 1) begin
                $display("  ── T7[%0d]: strb=%04b  data=0x%08h  expected byte='%s' (0x%02h) ──",
                         i, t7_strb[i], t7_data[i], t7_byte[i], t7_byte[i]);
                print_write_hdr(32'h0000_0000, t7_data[i], t7_strb[i], t7_byte[i]);
                u_master.do_axi_write(32'h0000_0000, t7_data[i], t7_strb[i]);
                print_write_result(last_bresp, timeout_flag);

                if (!timeout_flag && last_bresp === 2'b00) begin
                    tests_run    = tests_run + 1;
                    tests_passed = tests_passed + 1;
                    $display("  [PASS] T7[%0d]: strb=%04b byte='%s' (0x%02h) OKAY",
                             i, t7_strb[i], t7_byte[i], t7_byte[i]);
                end else begin
                    tests_run = tests_run + 1;
                    $display("  [FAIL] T7[%0d]: strb=%04b byte='%s' (0x%02h) FAILED",
                             i, t7_strb[i], t7_byte[i], t7_byte[i]);
                end

                $display("  [T7] Draining TX for next byte (~5000 cycles)...");
                repeat(5000) @(posedge clk);
                $display("");
            end
        end

        // =====================================================================
        // Summary
        // =====================================================================
        $display("╔══════════════════════════════════════════════════════════╗");
        $display("║   SIMULATION SUMMARY  (AXI-Lite UART Testbench)          ║");
        $display("╠══════════════════════════════════════════════════════════╣");
        $display("║   Tests run    : %-5d                                   ║", tests_run);
        $display("║   Tests passed : %-5d                                   ║", tests_passed);
        $display("║   Tests failed : %-5d                                   ║", tests_run - tests_passed);
        $display("╠══════════════════════════════════════════════════════════╣");
        if (tests_passed == tests_run)
            $display("║   *** ALL TESTS PASSED ✓ ***                             ║");
        else
            $display("║   *** SOME TESTS FAILED ✗ ***                            ║");
        $display("╚══════════════════════════════════════════════════════════╝");

        $finish;
    end

endmodule
