// =============================================================================
// top.v – PicoRV32 SoC Top-Level Module
// =============================================================================
// ASIC-clean version:
//   - Removed all inline reg initializers (= 0) from CPU-AXI bridge registers
//   - All state is reset-driven via the posedge reset branch
//   - No initial blocks, no simulation-only constructs
// =============================================================================

`timescale 1ns / 1ps

module top (
    input  clk,
    input  reset,
    output uart_tx,
    input  uart_rx
);


    // =========================================================================
    // PicoRV32 native memory bus wires
    // (* keep *) prevents OPT_CLEAN from eliminating these wires if the
    // optimizer ever decides they are unobservable dead signals.
    // =========================================================================
    (* keep *) wire        cpu_mem_valid;
    (* keep *) wire        cpu_mem_instr;
    (* keep *) wire        cpu_mem_ready;
    (* keep *) wire [31:0] cpu_mem_addr;
    (* keep *) wire [31:0] cpu_mem_wdata;
    (* keep *) wire [ 3:0] cpu_mem_wstrb;
    (* keep *) wire [31:0] cpu_mem_rdata;

    // =========================================================================
    // PicoRV32 CPU Instance
    // =========================================================================
    picorv32 #(
        .ENABLE_COUNTERS    (1),
        .ENABLE_COUNTERS64  (0),
        .ENABLE_REGS_16_31  (1),
        .ENABLE_REGS_DUALPORT (1),
        .TWO_STAGE_SHIFT    (1),
        .BARREL_SHIFTER     (0),
        .COMPRESSED_ISA     (0),
        .CATCH_MISALIGN     (1),
        .CATCH_ILLINSN      (1),
        .ENABLE_PCPI        (0),
        .ENABLE_MUL         (0),
        .ENABLE_FAST_MUL    (0),
        .ENABLE_DIV         (0),
        .ENABLE_IRQ         (0),
        .ENABLE_TRACE       (0),
        .PROGADDR_RESET     (32'h0000_0000),
        .STACKADDR          (32'h0001_00FC)
    ) u_cpu (
        .clk            (clk),
        .resetn         (~reset),
        .mem_valid      (cpu_mem_valid),
        .mem_instr      (cpu_mem_instr),
        .mem_ready      (cpu_mem_ready),
        .mem_addr       (cpu_mem_addr),
        .mem_wdata      (cpu_mem_wdata),
        .mem_wstrb      (cpu_mem_wstrb),
        .mem_rdata      (cpu_mem_rdata),
        .mem_la_read    (),
        .mem_la_write   (),
        .mem_la_addr    (),
        .mem_la_wdata   (),
        .mem_la_wstrb   (),
        .pcpi_valid     (),
        .pcpi_insn      (),
        .pcpi_rs1       (),
        .pcpi_rs2       (),
        .pcpi_wr        (1'b0),
        .pcpi_rd        (32'h0),
        .pcpi_wait      (1'b0),
        .pcpi_ready     (1'b0),
        .irq            (32'h0),
        .eoi            (),
        .trap           (),           // not exposed at top level
        .trace_valid    (),
        .trace_data     ()
    );

    // =========================================================================
    // PicoRV32 native mem → AXI-Lite bridge
    // =========================================================================
    // States:
    //   ST_IDLE  – waiting for cpu_mem_valid
    //   ST_WR_AW – issuing AW (and W simultaneously)
    //   ST_WR_B  – waiting for B (write response)
    //   ST_RD_AR – issuing AR
    //   ST_RD_R  – waiting for R data
    // =========================================================================

    localparam ST_IDLE  = 3'd0;
    localparam ST_WR_AW = 3'd1;
    localparam ST_WR_B  = 3'd2;
    localparam ST_RD_AR = 3'd3;
    localparam ST_RD_R  = 3'd4;

    // AXI master signals — NO inline initializers (removed for ASIC-clean)
    reg  [31:0] m_axi_awaddr;
    reg         m_axi_awvalid;
    wire        m_axi_awready;

    reg  [31:0] m_axi_wdata;
    reg  [ 3:0] m_axi_wstrb_r;
    reg         m_axi_wvalid;
    wire        m_axi_wready;

    wire [ 1:0] m_axi_bresp;
    wire        m_axi_bvalid;
    reg         m_axi_bready;

    reg  [31:0] m_axi_araddr;
    reg         m_axi_arvalid;
    wire        m_axi_arready;

    wire [31:0] m_axi_rdata;
    wire [ 1:0] m_axi_rresp;
    wire        m_axi_rvalid;
    reg         m_axi_rready;

    reg [2:0]  b_state;
    reg [31:0] rdata_r;
    reg        ready_r;

    assign cpu_mem_ready = ready_r;
    assign cpu_mem_rdata = rdata_r;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            b_state       <= ST_IDLE;
            ready_r       <= 1'b0;
            rdata_r       <= 32'h0;
            m_axi_awaddr  <= 32'h0;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata   <= 32'h0;
            m_axi_wstrb_r <= 4'h0;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_araddr  <= 32'h0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
        end else begin
            ready_r <= 1'b0;

            case (b_state)

                ST_IDLE: begin
                    if (cpu_mem_valid && !ready_r) begin
                        if (|cpu_mem_wstrb) begin
                            m_axi_awaddr  <= cpu_mem_addr;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= cpu_mem_wdata;
                            m_axi_wstrb_r <= cpu_mem_wstrb;
                            m_axi_wvalid  <= 1'b1;
                            b_state       <= ST_WR_AW;
                        end else begin
                            m_axi_araddr  <= cpu_mem_addr;
                            m_axi_arvalid <= 1'b1;
                            b_state       <= ST_RD_AR;
                        end
                    end
                end

                // ── Write: keep AW & W valid until each is accepted ──────────
                ST_WR_AW: begin
                    if (m_axi_awready && m_axi_awvalid) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready  && m_axi_wvalid)  m_axi_wvalid  <= 1'b0;

                    m_axi_bready <= 1'b1;

                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        ready_r      <= 1'b1;
                        b_state      <= ST_IDLE;
                    end else if (!m_axi_awvalid && !m_axi_wvalid &&
                                 !(m_axi_awready && m_axi_awvalid) &&
                                 !(m_axi_wready  && m_axi_wvalid)) begin
                        b_state <= ST_WR_B;
                    end
                end

                // ── Write: wait for B response ───────────────────────────────
                ST_WR_B: begin
                    m_axi_bready <= 1'b1;
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        ready_r      <= 1'b1;
                        b_state      <= ST_IDLE;
                    end
                end

                // ── Read: keep AR valid until accepted ────────────────────────
                ST_RD_AR: begin
                    if (m_axi_arready && m_axi_arvalid) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        b_state       <= ST_RD_R;
                    end
                end

                // ── Read: wait for R data ─────────────────────────────────────
                ST_RD_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        rdata_r      <= m_axi_rdata;
                        m_axi_rready <= 1'b0;
                        ready_r      <= 1'b1;
                        b_state      <= ST_IDLE;
                    end
                end

                default: b_state <= ST_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Slave wires
    // =========================================================================
    wire [31:0] s0_awaddr;  wire s0_awvalid; wire s0_awready;
    wire [31:0] s0_wdata;   wire [3:0] s0_wstrb; wire s0_wvalid; wire s0_wready;
    wire [1:0]  s0_bresp;   wire s0_bvalid; wire s0_bready;
    wire [31:0] s0_araddr;  wire s0_arvalid; wire s0_arready;
    wire [31:0] s0_rdata;   wire [1:0] s0_rresp; wire s0_rvalid; wire s0_rready;

    wire [31:0] s1_awaddr;  wire s1_awvalid; wire s1_awready;
    wire [31:0] s1_wdata;   wire [3:0] s1_wstrb; wire s1_wvalid; wire s1_wready;
    wire [1:0]  s1_bresp;   wire s1_bvalid; wire s1_bready;
    wire [31:0] s1_araddr;  wire s1_arvalid; wire s1_arready;
    wire [31:0] s1_rdata;   wire [1:0] s1_rresp; wire s1_rvalid; wire s1_rready;

    wire [31:0] s2_awaddr;  wire s2_awvalid; wire s2_awready;
    wire [31:0] s2_wdata;   wire [3:0] s2_wstrb; wire s2_wvalid; wire s2_wready;
    wire [1:0]  s2_bresp;   wire s2_bvalid; wire s2_bready;
    wire [31:0] s2_araddr;  wire s2_arvalid; wire s2_arready;
    wire [31:0] s2_rdata;   wire [1:0] s2_rresp; wire s2_rvalid; wire s2_rready;

    // =========================================================================
    // AXI-Lite Interconnect
    // =========================================================================
    axi_lite_interconnect u_interconnect (
        .clk            (clk),   .reset          (reset),
        .m_axi_awaddr   (m_axi_awaddr),  .m_axi_awvalid  (m_axi_awvalid), .m_axi_awready (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),   .m_axi_wstrb    (m_axi_wstrb_r),
        .m_axi_wvalid   (m_axi_wvalid),  .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (m_axi_bresp),   .m_axi_bvalid   (m_axi_bvalid), .m_axi_bready  (m_axi_bready),
        .m_axi_araddr   (m_axi_araddr),  .m_axi_arvalid  (m_axi_arvalid), .m_axi_arready (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),   .m_axi_rresp    (m_axi_rresp),
        .m_axi_rvalid   (m_axi_rvalid),  .m_axi_rready   (m_axi_rready),
        .s0_axi_awaddr  (s0_awaddr),  .s0_axi_awvalid (s0_awvalid), .s0_axi_awready (s0_awready),
        .s0_axi_wdata   (s0_wdata),   .s0_axi_wstrb   (s0_wstrb),
        .s0_axi_wvalid  (s0_wvalid),  .s0_axi_wready  (s0_wready),
        .s0_axi_bresp   (s0_bresp),   .s0_axi_bvalid  (s0_bvalid),  .s0_axi_bready  (s0_bready),
        .s0_axi_araddr  (s0_araddr),  .s0_axi_arvalid (s0_arvalid), .s0_axi_arready (s0_arready),
        .s0_axi_rdata   (s0_rdata),   .s0_axi_rresp   (s0_rresp),
        .s0_axi_rvalid  (s0_rvalid),  .s0_axi_rready  (s0_rready),
        .s1_axi_awaddr  (s1_awaddr),  .s1_axi_awvalid (s1_awvalid), .s1_axi_awready (s1_awready),
        .s1_axi_wdata   (s1_wdata),   .s1_axi_wstrb   (s1_wstrb),
        .s1_axi_wvalid  (s1_wvalid),  .s1_axi_wready  (s1_wready),
        .s1_axi_bresp   (s1_bresp),   .s1_axi_bvalid  (s1_bvalid),  .s1_axi_bready  (s1_bready),
        .s1_axi_araddr  (s1_araddr),  .s1_axi_arvalid (s1_arvalid), .s1_axi_arready (s1_arready),
        .s1_axi_rdata   (s1_rdata),   .s1_axi_rresp   (s1_rresp),
        .s1_axi_rvalid  (s1_rvalid),  .s1_axi_rready  (s1_rready),
        .s2_axi_awaddr  (s2_awaddr),  .s2_axi_awvalid (s2_awvalid), .s2_axi_awready (s2_awready),
        .s2_axi_wdata   (s2_wdata),   .s2_axi_wstrb   (s2_wstrb),
        .s2_axi_wvalid  (s2_wvalid),  .s2_axi_wready  (s2_wready),
        .s2_axi_bresp   (s2_bresp),   .s2_axi_bvalid  (s2_bvalid),  .s2_axi_bready  (s2_bready),
        .s2_axi_araddr  (s2_araddr),  .s2_axi_arvalid (s2_arvalid), .s2_axi_arready (s2_arready),
        .s2_axi_rdata   (s2_rdata),   .s2_axi_rresp   (s2_rresp),
        .s2_axi_rvalid  (s2_rvalid),  .s2_axi_rready  (s2_rready)
    );

    // =========================================================================
    // ROM – Slave 0
    // =========================================================================
    rom #(.MEM_DEPTH(2048), .INIT_FILE("rom.hex")) u_rom (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(s0_awaddr), .s_axi_awvalid(s0_awvalid), .s_axi_awready(s0_awready),
        .s_axi_wdata(s0_wdata),   .s_axi_wstrb(s0_wstrb),
        .s_axi_wvalid(s0_wvalid), .s_axi_wready(s0_wready),
        .s_axi_bresp(s0_bresp),   .s_axi_bvalid(s0_bvalid),   .s_axi_bready(s0_bready),
        .s_axi_araddr(s0_araddr), .s_axi_arvalid(s0_arvalid), .s_axi_arready(s0_arready),
        .s_axi_rdata(s0_rdata),   .s_axi_rresp(s0_rresp),
        .s_axi_rvalid(s0_rvalid), .s_axi_rready(s0_rready)
    );

    // =========================================================================
    // SRAM – Slave 1
    // =========================================================================
    sram #(.MEM_DEPTH(64)) u_sram (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(s1_awaddr), .s_axi_awvalid(s1_awvalid), .s_axi_awready(s1_awready),
        .s_axi_wdata(s1_wdata),   .s_axi_wstrb(s1_wstrb),
        .s_axi_wvalid(s1_wvalid), .s_axi_wready(s1_wready),
        .s_axi_bresp(s1_bresp),   .s_axi_bvalid(s1_bvalid),   .s_axi_bready(s1_bready),
        .s_axi_araddr(s1_araddr), .s_axi_arvalid(s1_arvalid), .s_axi_arready(s1_arready),
        .s_axi_rdata(s1_rdata),   .s_axi_rresp(s1_rresp),
        .s_axi_rvalid(s1_rvalid), .s_axi_rready(s1_rready)
    );

    // =========================================================================
    // UART – Slave 2
    // =========================================================================
    // uart_tx_int: connects uart_axi's tx_out port to the top-level uart_tx.
    // Port renamed tx_out (not uart_tx) to eliminate the Yosys scope-resolver
    // collision between the output port name and the uart_tx submodule type.
    wire uart_tx_int;
    assign uart_tx = uart_tx_int;

    uart_axi #(.CLK_FREQ(50_000_000), .BAUD_RATE(115_200)) u_uart (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(s2_awaddr), .s_axi_awvalid(s2_awvalid), .s_axi_awready(s2_awready),
        .s_axi_wdata(s2_wdata),   .s_axi_wstrb(s2_wstrb),
        .s_axi_wvalid(s2_wvalid), .s_axi_wready(s2_wready),
        .s_axi_bresp(s2_bresp),   .s_axi_bvalid(s2_bvalid),   .s_axi_bready(s2_bready),
        .s_axi_araddr(s2_araddr), .s_axi_arvalid(s2_arvalid), .s_axi_arready(s2_arready),
        .s_axi_rdata(s2_rdata),   .s_axi_rresp(s2_rresp),
        .s_axi_rvalid(s2_rvalid), .s_axi_rready(s2_rready),
        .tx_out (uart_tx_int),
        .uart_rx(uart_rx)
    );

endmodule
