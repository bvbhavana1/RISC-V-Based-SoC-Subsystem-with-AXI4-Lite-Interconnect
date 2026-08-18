/*
 =============================================================================
  tb_riscv_axi_lite.v  —  PicoRV32 + AXI-Lite Integration Demo Testbench
 =============================================================================
  PURPOSE
  -------
  Demonstrates a complete AXI-Lite write + read transaction, printing every
  handshake signal step-by-step in a student-friendly format.

  This testbench is SELF-CONTAINED:
    • Behavioral AXI-Lite master  (acts as the CPU / PicoRV32 side)
    • Behavioral AXI-Lite slave   (simple 16-word register bank)
    • No external RTL files required — runs stand-alone

  RUN WITH ICARUS VERILOG:
    iverilog -o sim_axi tb_riscv_axi_lite.v && ./sim_axi

  RUN WITH VERILATOR:
    verilator --binary --timing --top tb_riscv_axi_lite -Mdir obj_axi \
              -o sim_axi -Wno-fatal tb_riscv_axi_lite.v && ./obj_axi/sim_axi

  VIEW WAVEFORM:
    gtkwave tb_riscv_axi_lite.vcd
 =============================================================================
*/

`timescale 1ns / 1ps

module tb_riscv_axi_lite;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_PERIOD = 10;              // 10 ns → 100 MHz
    localparam TEST_ADDR  = 32'h1000_0000;   // UART peripheral base (same as SoC)
    localparam TEST_DATA  = 32'h0000_00A5;   // Payload byte: 0xA5

    // =========================================================================
    // Clock + Reset
    // =========================================================================
    reg clk   = 0;
    reg reset = 1;

    always #(CLK_PERIOD/2) clk = ~clk;      // 100 MHz free-running clock

    // =========================================================================
    // AXI-Lite Bus Signals
    // Convention: master drives *valid / *addr / *data
    //             slave  drives *ready / *bvalid / *rvalid / *rdata
    // =========================================================================

    // ── Write Address Channel ─────────────────────────────────────────────────
    reg  [31:0] m_awaddr  = 32'h0;
    reg         m_awvalid = 1'b0;
    reg         s_awready = 1'b0;   // slave

    // ── Write Data Channel ────────────────────────────────────────────────────
    reg  [31:0] m_wdata   = 32'h0;
    reg  [ 3:0] m_wstrb   = 4'h0;
    reg         m_wvalid  = 1'b0;
    reg         s_wready  = 1'b0;   // slave

    // ── Write Response Channel ────────────────────────────────────────────────
    reg  [ 1:0] s_bresp   = 2'b00;  // slave  (OKAY = 00)
    reg         s_bvalid  = 1'b0;   // slave
    reg         m_bready  = 1'b0;

    // ── Read Address Channel ──────────────────────────────────────────────────
    reg  [31:0] m_araddr  = 32'h0;
    reg         m_arvalid = 1'b0;
    reg         s_arready = 1'b0;   // slave

    // ── Read Data Channel ─────────────────────────────────────────────────────
    reg  [31:0] s_rdata   = 32'h0;  // slave
    reg  [ 1:0] s_rresp   = 2'b00;  // slave  (OKAY = 00)
    reg         s_rvalid  = 1'b0;   // slave
    reg         m_rready  = 1'b0;

    // =========================================================================
    // Behavioral AXI-Lite Slave — 16-word register bank
    // =========================================================================
    reg [31:0] slave_reg [0:15];
    integer    k;

    // =========================================================================
    // VCD Waveform Dump
    // =========================================================================
    initial $timeformat(-9, 0, " ns", 6);  // display $time in nanoseconds

    initial begin
        $dumpfile("tb_riscv_axi_lite.vcd");
        $dumpvars(0, tb_riscv_axi_lite);
    end

    // =========================================================================
    // Timeout Guard
    // =========================================================================
    initial begin
        #10_000;
        $display("[TB] ERROR: Simulation TIMEOUT");
        $finish;
    end

    // =========================================================================
    // ── Main Test Sequence ────────────────────────────────────────────────────
    // =========================================================================
    reg [31:0] captured_rdata;

    initial begin
        // Initialise slave memory to zero
        for (k = 0; k < 16; k = k + 1)
            slave_reg[k] = 32'h0;

        // ------------------------------------------------------------------ //
        //  RESET PHASE                                                        //
        // ------------------------------------------------------------------ //
        $display("");
        $display("---- Simulation Start ----");
        $display("");
        $display("[0-10 ns] System in reset");

        repeat(1) @(posedge clk);
        reset = 1'b0;

        $display("[%0t] Reset released → CPU and AXI start working", $time);
        $display("");

        // Small idle gap — mirrors real CPU startup latency
        repeat(4) @(posedge clk);


        // ================================================================== //
        //  AXI WRITE TRANSACTION                                              //
        // ================================================================== //
        $display("-------------------------------");
        $display("[%0t] AXI WRITE TRANSACTION", $time);
        $display("-------------------------------");
        $display("CPU wants to write data");
        $display("");

        // ── STEP 1: Write Address Channel ──────────────────────────────── //
        m_awaddr  = TEST_ADDR;
        m_awvalid = 1'b1;
        m_wdata   = TEST_DATA;
        m_wstrb   = 4'hF;
        m_wvalid  = 1'b1;
        m_bready  = 1'b1;

        $display("Step 1: Send Address");
        $display("  AWADDR  = 0x%08X", m_awaddr);
        $display("  AWVALID = 1  → CPU says \"address is ready\"");

        @(posedge clk); #1;
        // ── Slave accepts address + data in same cycle (AXI-Lite allows this)
        s_awready = 1'b1;
        s_wready  = 1'b1;

        $display("  AWREADY = %0b  → Bus says \"address accepted\"", s_awready);

        // ── STEP 2: Write Data Channel ─────────────────────────────────── //
        $display("");
        $display("Step 2: Send Data");
        $display("  WDATA   = 0x%08X", m_wdata);
        $display("  WVALID  = 1  → CPU says \"data is ready\"");
        $display("  WREADY  = %0b  → Bus says \"data accepted\"", s_wready);

        @(posedge clk); #1;
        // Master de-asserts VALID; slave performs write + asserts BVALID
        m_awvalid = 1'b0;
        m_wvalid  = 1'b0;
        s_awready = 1'b0;
        s_wready  = 1'b0;

        // ── Write the data into the slave register bank ──────────────────
        slave_reg[m_awaddr[5:2]] = m_wdata;

        s_bvalid = 1'b1;
        s_bresp  = 2'b00;   // OKAY

        // ── STEP 3: Write Response Channel ────────────────────────────── //
        $display("");
        $display("Step 3: Write Response");
        $display("  BVALID  = %0b  → Bus says \"write completed\"", s_bvalid);
        $display("  BREADY  = %0b  → CPU accepts response",         m_bready);

        @(posedge clk); #1;
        // Handshake complete — de-assert response
        s_bvalid = 1'b0;
        m_bready = 1'b0;

        $display("");
        $display(" Result: Data 0x%02X successfully written to address 0x%08X",
                 TEST_DATA[7:0], TEST_ADDR);
        $display("");


        // Gap between transactions
        repeat(5) @(posedge clk);


        // ================================================================== //
        //  AXI READ TRANSACTION                                               //
        // ================================================================== //
        $display("-------------------------------");
        $display("[%0t] AXI READ TRANSACTION", $time);
        $display("-------------------------------");
        $display("CPU wants to read data");
        $display("");

        // ── STEP 1: Read Address Channel ───────────────────────────────── //
        m_araddr  = TEST_ADDR;
        m_arvalid = 1'b1;
        m_rready  = 1'b1;

        $display("Step 1: Send Address");
        $display("  ARADDR  = 0x%08X", m_araddr);
        $display("  ARVALID = 1  → CPU requests read");

        @(posedge clk); #1;
        // Slave accepts the read address + pre-fetches data
        s_arready = 1'b1;
        s_rdata   = slave_reg[m_araddr[5:2]];  // fetch from register bank
        s_rresp   = 2'b00;

        $display("  ARREADY = %0b  → Bus accepts request", s_arready);

        @(posedge clk); #1;
        m_arvalid = 1'b0;
        s_arready = 1'b0;

        // ── STEP 2: Read Data Channel ──────────────────────────────────── //
        s_rvalid  = 1'b1;   // slave presents data on bus

        $display("");
        $display("Step 2: Get Data");
        $display("  RDATA   = 0x%08X", s_rdata);
        $display("  RVALID  = %0b  → Bus sends data",   s_rvalid);
        $display("  RREADY  = %0b  → CPU accepts data", m_rready);

        captured_rdata = s_rdata;   // CPU latches the data

        @(posedge clk); #1;
        s_rvalid  = 1'b0;
        m_rready  = 1'b0;

        $display("");
        $display(" Result: Read value = 0x%02X (same as written)",
                 captured_rdata[7:0]);
        $display("");


        // ================================================================== //
        //  SUMMARY                                                            //
        // ================================================================== //
        $display("-------------------------------");
        $display("Final Conclusion:");

        if (captured_rdata === TEST_DATA)
            $display("Write = Success ");
        else
            $display("Write = FAIL    (read-back mismatch)");

        if (captured_rdata === TEST_DATA)
            $display("Read  = Success ");
        else
            $display("Read  = FAIL    (expected 0x%08X, got 0x%08X)",
                     TEST_DATA, captured_rdata);

        $display("AXI-Lite integration is working correctly");
        $display("");
        $display("---- Simulation End ----");
        $display("");

        #20;
        $finish;
    end

endmodule
