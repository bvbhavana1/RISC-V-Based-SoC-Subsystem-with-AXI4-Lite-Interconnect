// =============================================================================
//  tb_axi_lite_standalone.v
//  Standalone AXI-Lite Testbench  (32-bit address / 32-bit data)
// =============================================================================
//  Purpose:  emonstration of AXI-Lite read/write transactions
//            with valid/ready handshake.
//
//  Contents:
//    1.  axi_lite_slave   – simple 4-register slave (state-machine style)
//    2.  tb_axi_lite_standalone – master stimulus + VCD + $display logs
//
//  Build & Run:
//    make axi_sa                   (uses Makefile target — recommended)
//    iverilog -o sim tb/tb_axi_lite_standalone.v && vvp sim   (Icarus)

`timescale 1ns / 1ps

// =============================================================================
//  MODULE: axi_lite_slave
//  Simple AXI-Lite slave with 4 x 32-bit registers (word-addressed).
//  Register map:
//    offset 0x00  →  reg_file[0]
//    offset 0x04  →  reg_file[1]
//    offset 0x08  →  reg_file[2]
//    offset 0x0C  →  reg_file[3]
//
//  Write FSM: IDLE → WR_ADDR → WR_DATA → WR_RESP → IDLE
//  Read  FSM: IDLE → RD_ADDR → RD_DATA → IDLE
// =============================================================================
module axi_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 4
)(
    input  wire                    clk,
    input  wire                    reset,

    // ── Write Address Channel ─────────────────────────────────────────────
    input  wire  [ADDR_WIDTH-1:0]  s_awaddr,
    input  wire                    s_awvalid,
    output reg                     s_awready,

    // ── Write Data Channel ────────────────────────────────────────────────
    input  wire  [DATA_WIDTH-1:0]  s_wdata,
    input  wire  [3:0]             s_wstrb,      // byte enables  (not checked here)
    input  wire                    s_wvalid,
    output reg                     s_wready,

    // ── Write Response Channel ────────────────────────────────────────────
    output reg   [1:0]             s_bresp,      // 2'b00 = OKAY
    output reg                     s_bvalid,
    input  wire                    s_bready,

    // ── Read Address Channel ──────────────────────────────────────────────
    input  wire  [ADDR_WIDTH-1:0]  s_araddr,
    input  wire                    s_arvalid,
    output reg                     s_arready,

    // ── Read Data Channel ─────────────────────────────────────────────────
    output reg   [DATA_WIDTH-1:0]  s_rdata,
    output reg   [1:0]             s_rresp,      // 2'b00 = OKAY
    output reg                     s_rvalid,
    input  wire                    s_rready
);

    // ── Internal register file ─────────────────────────────────────────────
    reg [DATA_WIDTH-1:0] reg_file [0:NUM_REGS-1];
    integer k;

    // ── Latched address registers ──────────────────────────────────────────
    reg [ADDR_WIDTH-1:0] wr_addr_q;   // captures write address at handshake
    reg [ADDR_WIDTH-1:0] rd_addr_q;   // captures read  address at handshake

    // ── Write FSM ──────────────────────────────────────────────────────────
    localparam WR_IDLE = 2'd0,    // waiting for write address
               WR_DATA = 2'd1,    // waiting for write data
               WR_RESP = 2'd2;    // waiting for master to accept response

    reg [1:0] wstate;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wstate     <= WR_IDLE;
            s_awready  <= 1'b0;
            s_wready   <= 1'b0;
            s_bvalid   <= 1'b0;
            s_bresp    <= 2'b00;
            wr_addr_q  <= 0;
            for (k = 0; k < NUM_REGS; k = k + 1)
                reg_file[k] <= 0;
        end else begin
            // Default de-assertions each cycle
            s_awready <= 1'b0;
            s_wready  <= 1'b0;

            case (wstate)

                // ── IDLE: wait for master to present a write address ──────
                WR_IDLE: begin
                    if (s_awvalid) begin
                        s_awready <= 1'b1;          // accept address
                        wr_addr_q <= s_awaddr;      // latch it
                        wstate    <= WR_DATA;
                    end
                end

                // ── WR_DATA: wait for master to present write data ────────
                WR_DATA: begin
                    if (s_wvalid) begin
                        s_wready <= 1'b1;           // accept data

                        // Byte-enable write (supports partial writes)
                        if (s_wstrb[0]) reg_file[(wr_addr_q>>2) % NUM_REGS][ 7: 0] <= s_wdata[ 7: 0];
                        if (s_wstrb[1]) reg_file[(wr_addr_q>>2) % NUM_REGS][15: 8] <= s_wdata[15: 8];
                        if (s_wstrb[2]) reg_file[(wr_addr_q>>2) % NUM_REGS][23:16] <= s_wdata[23:16];
                        if (s_wstrb[3]) reg_file[(wr_addr_q>>2) % NUM_REGS][31:24] <= s_wdata[31:24];

                        s_bvalid  <= 1'b1;          // assert write response
                        s_bresp   <= 2'b00;         // OKAY
                        wstate    <= WR_RESP;
                    end
                end

                // ── WR_RESP: hold bvalid until master asserts bready ──────
                WR_RESP: begin
                    if (s_bready && s_bvalid) begin
                        s_bvalid <= 1'b0;
                        wstate   <= WR_IDLE;
                    end
                end

                default: wstate <= WR_IDLE;
            endcase
        end
    end

    // ── Read FSM ───────────────────────────────────────────────────────────
    localparam RD_IDLE = 2'd0,    // waiting for read address
               RD_DATA = 2'd1;    // driving read data

    reg [1:0] rstate;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rstate    <= RD_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 0;
            s_rresp   <= 2'b00;
            rd_addr_q <= 0;
        end else begin
            s_arready <= 1'b0;  // default de-assert

            case (rstate)

                // ── IDLE: wait for master to present a read address ───────
                RD_IDLE: begin
                    if (s_arvalid) begin
                        s_arready <= 1'b1;          // accept address
                        rd_addr_q <= s_araddr;      // latch it
                        // Pre-load read data from register file
                        s_rdata   <= reg_file[(s_araddr>>2) % NUM_REGS];
                        s_rresp   <= 2'b00;
                        s_rvalid  <= 1'b1;          // data is ready immediately
                        rstate    <= RD_DATA;
                    end
                end

                // ── RD_DATA: hold rvalid until master asserts rready ──────
                RD_DATA: begin
                    if (s_rready && s_rvalid) begin
                        s_rvalid <= 1'b0;
                        rstate   <= RD_IDLE;
                    end
                end

                default: rstate <= RD_IDLE;
            endcase
        end
    end

endmodule


// =============================================================================
//  MODULE: tb_axi_lite_standalone   (testbench / top)
// =============================================================================
module tb_axi_lite_standalone;

    // ──────────────────────────────────────────────────────────────────────
    //  Parameters
    // ──────────────────────────────────────────────────────────────────────
    parameter CLK_PERIOD = 10;   // 10 ns clock  →  100 MHz
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // ──────────────────────────────────────────────────────────────────────
    //  Signals (Master drives; Slave responds)
    // ──────────────────────────────────────────────────────────────────────
    reg                    clk;
    reg                    reset;

    //  Write Address
    reg  [ADDR_WIDTH-1:0]  awaddr;
    reg                    awvalid;
    wire                   awready;

    //  Write Data
    reg  [DATA_WIDTH-1:0]  wdata;
    reg  [3:0]             wstrb;
    reg                    wvalid;
    wire                   wready;

    //  Write Response
    wire [1:0]             bresp;
    wire                   bvalid;
    reg                    bready;

    //  Read Address
    reg  [ADDR_WIDTH-1:0]  araddr;
    reg                    arvalid;
    wire                   arready;

    //  Read Data
    wire [DATA_WIDTH-1:0]  rdata;
    wire [1:0]             rresp;
    wire                   rvalid;
    reg                    rready;

    // ──────────────────────────────────────────────────────────────────────
    //  DUT: AXI-Lite Slave
    // ──────────────────────────────────────────────────────────────────────
    axi_lite_slave #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (4)
    ) u_slave (
        .clk        (clk),
        .reset      (reset),
        // Write Address
        .s_awaddr   (awaddr),   .s_awvalid (awvalid),  .s_awready (awready),
        // Write Data
        .s_wdata    (wdata),    .s_wstrb   (wstrb),
        .s_wvalid   (wvalid),   .s_wready  (wready),
        // Write Response
        .s_bresp    (bresp),    .s_bvalid  (bvalid),   .s_bready  (bready),
        // Read Address
        .s_araddr   (araddr),   .s_arvalid (arvalid),  .s_arready (arready),
        // Read Data
        .s_rdata    (rdata),    .s_rresp   (rresp),
        .s_rvalid   (rvalid),   .s_rready  (rready)
    );

    // ──────────────────────────────────────────────────────────────────────
    //  Clock Generator
    // ──────────────────────────────────────────────────────────────────────
    initial clk = 0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    // ──────────────────────────────────────────────────────────────────────
    //  VCD Waveform Dump
    // ──────────────────────────────────────────────────────────────────────
    initial begin
        $dumpfile("tb_axi_lite_standalone.vcd");
        $dumpvars(0, tb_axi_lite_standalone);
    end

    // ──────────────────────────────────────────────────────────────────────
    //  Helper tasks
    // ──────────────────────────────────────────────────────────────────────

    // ── axi_write: perform a complete AXI-Lite write transaction ──────────
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            //  Phase 1: Present address (AW channel)
            @(negedge clk);
            awaddr  = addr;
            awvalid = 1'b1;

            $display("[WRITE] awvalid=1, wvalid=0 → Sending address first...");

            // Wait for awready (address handshake)
            @(posedge clk);
            while (!awready) @(posedge clk);
            $display("[WRITE] awready=1 → Handshake Done (address 0x%08h accepted)", addr);

            @(negedge clk);
            awvalid = 1'b0;   // de-assert after handshake

            //  Phase 2: Present data (W channel)
            wdata   = data;
            wstrb   = 4'hF;   // all bytes enabled
            wvalid  = 1'b1;
            $display("[WRITE] wvalid=1 → Sending data 0x%08h...", data);

            // Wait for wready (data handshake)
            @(posedge clk);
            while (!wready) @(posedge clk);
            $display("[WRITE] wready=1 → Handshake Done (data accepted)");

            @(negedge clk);
            wvalid  = 1'b0;   // de-assert after handshake
            bready  = 1'b1;   // ready to receive response

            //  Phase 3: Wait for write response (B channel)
            @(posedge clk);
            $display("[WRITE] Waiting for bvalid...");
            while (!bvalid) @(posedge clk);
            $display("[WRITE] bvalid=1 → Write Response Received (%s)\n",
                     (bresp == 2'b00) ? "OKAY" : "SLVERR");

            @(negedge clk);
            bready = 1'b0;
            @(posedge clk);
        end
    endtask

    // ── axi_read: perform a complete AXI-Lite read transaction ───────────
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] rd_data;
        begin
            //  Phase 1: Present read address (AR channel)
            @(negedge clk);
            araddr  = addr;
            arvalid = 1'b1;
            $display("[READ] arvalid=1 → Waiting for arready...");

            // Wait for arready (address handshake)
            @(posedge clk);
            while (!arready) @(posedge clk);
            $display("[READ] arready=1 → Handshake Done (address 0x%08h accepted)", addr);

            @(negedge clk);
            arvalid = 1'b0;   // de-assert after handshake
            rready  = 1'b1;   // ready to accept read data

            //  Phase 2: Wait for read data (R channel)
            @(posedge clk);
            $display("[READ] Waiting for rvalid...");
            while (!rvalid) @(posedge clk);
            rd_data = rdata;
            $display("[READ] rvalid=1 → Data Received = 0x%08h\n", rd_data);

            @(negedge clk);
            rready = 1'b0;
            @(posedge clk);
        end
    endtask

    // ──────────────────────────────────────────────────────────────────────
    //  Main Stimulus
    // ──────────────────────────────────────────────────────────────────────
    reg [DATA_WIDTH-1:0] captured_rdata;
    integer pass_cnt;
    integer fail_cnt;

    initial begin
        // Initialise all master outputs to safe defaults
        awaddr  = 0;  awvalid = 1'b0;
        wdata   = 0;  wstrb   = 4'hF;  wvalid = 1'b0;
        bready  = 1'b0;
        araddr  = 0;  arvalid = 1'b0;
        rready  = 1'b0;
        pass_cnt = 0;
        fail_cnt = 0;

        $display("");
        $display("======================================================");
        $display("  AXI-Lite Standalone Testbench  (32-bit addr/data)  ");
        $display("======================================================");

        // ── Apply Reset ──────────────────────────────────────────────────
        reset = 1'b1;
        repeat (4) @(posedge clk);   // hold reset for 4 cycles
        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);

        $display("\n[TB] Reset applied → All signals initialized\n");

        // ==================================================================
        //  WRITE TRANSACTION
        //  Goal: write 0xA5A5A5A5 to address 0x00000004 (register 1)
        // ==================================================================
        $display("[TB] Starting AXI-Lite Write Transaction...\n");
        $display("[WRITE] Address = 0x%08h", 32'h0000_0004);
        $display("[WRITE] Data    = 0x%08h", 32'hA5A5_A5A5);

        axi_write(32'h0000_0004, 32'hA5A5_A5A5);

        // ==================================================================
        //  READ TRANSACTION
        //  Goal: read back from address 0x00000004 and verify
        // ==================================================================
        $display("[TB] Starting AXI-Lite Read Transaction...\n");
        $display("[READ] Address = 0x%08h", 32'h0000_0004);

        axi_read(32'h0000_0004, captured_rdata);

        // ==================================================================
        //  RESULT CHECK
        // ==================================================================
        if (captured_rdata === 32'hA5A5_A5A5) begin
            $display("[CHECK] Write Data == Read Data → PASS ✓");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[CHECK] FAIL ✗  Expected=0xA5A5A5A5  Got=0x%08h",
                     captured_rdata);
            fail_cnt = fail_cnt + 1;
        end

        $display("");
        $display("[TB] AXI-Lite Transaction Successful");
        $display("");
        $display("======================================================");
        $display("  SUMMARY :  Passed = %0d   Failed = %0d", pass_cnt, fail_cnt);
        $display("======================================================");
        $display("[TB] Simulation Finished");
        $display("");

        #(CLK_PERIOD * 5);
        $finish;
    end

    // ──────────────────────────────────────────────────────────────────────
    //  Watchdog — prevent infinite hang on handshake deadlock
    // ──────────────────────────────────────────────────────────────────────
    initial begin
        #500000;
        $display("[ERROR] Watchdog timeout — possible handshake deadlock!");
        $finish;
    end

endmodule
