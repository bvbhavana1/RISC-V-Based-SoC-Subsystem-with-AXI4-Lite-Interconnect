// =============================================================================
// sram.v – AXI-Lite Read/Write SRAM
// =============================================================================
// Parameters:
//   MEM_DEPTH  : Number of 32-bit words (default 2048 = 8 KB)
//
// Full AXI-Lite slave supporting byte-enable writes.
//
// ASIC-clean version:
//   - Removed `initial` block (simulation-only, dropped silently in synthesis)
//   - Removed all inline reg initializers (= value); all state driven by reset
//   - SRAM starts uninitialized in silicon (correct — firmware writes data)
// =============================================================================

`timescale 1ns / 1ps

module sram #(
    parameter MEM_DEPTH = 2048
)(
    input         clk,
    input         reset,

    // AXI-Lite Slave – Write Address Channel
    input  [31:0] s_axi_awaddr,
    input         s_axi_awvalid,
    output        s_axi_awready,

    // AXI-Lite Slave – Write Data Channel
    input  [31:0] s_axi_wdata,
    input  [ 3:0] s_axi_wstrb,
    input         s_axi_wvalid,
    output        s_axi_wready,

    // AXI-Lite Slave – Write Response Channel
    output [ 1:0] s_axi_bresp,
    output        s_axi_bvalid,
    input         s_axi_bready,

    // AXI-Lite Slave – Read Address Channel
    input  [31:0] s_axi_araddr,
    input         s_axi_arvalid,
    output        s_axi_arready,

    // AXI-Lite Slave – Read Data Channel
    output [31:0] s_axi_rdata,
    output [ 1:0] s_axi_rresp,
    output        s_axi_rvalid,
    input         s_axi_rready
);

    // -------------------------------------------------------------------------
    // Memory array
    // -------------------------------------------------------------------------
    // NOTE: No initial block. In ASIC silicon, SRAM cells are undefined at
    // power-on. Firmware initialises all data it uses before reading.
    // In simulation (Verilator/Icarus) uninitialised reads return X — this is
    // intentional and matches silicon behaviour.
    // -------------------------------------------------------------------------
    reg [31:0] mem [0:MEM_DEPTH-1];

    // -------------------------------------------------------------------------
    // Write channel
    // All registers reset-driven; no inline = value initializers.
    // -------------------------------------------------------------------------
    reg        aw_pend;
    reg        w_pend;
    reg [31:0] aw_addr_r;
    reg [31:0] w_data_r;
    reg [ 3:0] w_strb_r;
    reg        b_vld;

    assign s_axi_awready = !aw_pend;
    assign s_axi_wready  = !w_pend;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = b_vld;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_pend   <= 1'b0;
            w_pend    <= 1'b0;
            b_vld     <= 1'b0;
            aw_addr_r <= 32'h0;
            w_data_r  <= 32'h0;
            w_strb_r  <= 4'h0;
        end else begin
            // Latch AW address
            if (s_axi_awvalid && !aw_pend) begin
                aw_addr_r <= s_axi_awaddr;
                aw_pend   <= 1'b1;
            end
            // Latch W data
            if (s_axi_wvalid && !w_pend) begin
                w_data_r <= s_axi_wdata;
                w_strb_r <= s_axi_wstrb;
                w_pend   <= 1'b1;
            end
            // Perform write when both are available
            if (aw_pend && w_pend && !b_vld) begin
                // Byte-enable write
                if (w_strb_r[0]) mem[aw_addr_r[$clog2(MEM_DEPTH)+1:2]][ 7: 0] <= w_data_r[ 7: 0];
                if (w_strb_r[1]) mem[aw_addr_r[$clog2(MEM_DEPTH)+1:2]][15: 8] <= w_data_r[15: 8];
                if (w_strb_r[2]) mem[aw_addr_r[$clog2(MEM_DEPTH)+1:2]][23:16] <= w_data_r[23:16];
                if (w_strb_r[3]) mem[aw_addr_r[$clog2(MEM_DEPTH)+1:2]][31:24] <= w_data_r[31:24];
                b_vld   <= 1'b1;
                aw_pend <= 1'b0;
                w_pend  <= 1'b0;
            end
            if (b_vld && s_axi_bready) b_vld <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Read channel
    // -------------------------------------------------------------------------
    reg        r_valid_r;
    reg [31:0] r_data_r;

    assign s_axi_arready = !r_valid_r;
    assign s_axi_rdata   = r_data_r;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = r_valid_r;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_valid_r <= 1'b0;
            r_data_r  <= 32'h0;
        end else begin
            if (s_axi_arvalid && !r_valid_r) begin
                r_data_r  <= mem[s_axi_araddr[$clog2(MEM_DEPTH)+1 : 2]];
                r_valid_r <= 1'b1;
            end
            if (r_valid_r && s_axi_rready)
                r_valid_r <= 1'b0;
        end
    end

endmodule
