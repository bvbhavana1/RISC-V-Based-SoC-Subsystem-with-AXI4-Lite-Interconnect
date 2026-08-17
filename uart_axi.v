/* 
MODULE OVERVIEW
---------------
UART peripheral connected to an AXI-Lite bus (full-duplex TX+RX).

ASIC-clean version:
  - Removed all inline reg initializers (= value)
  - Fixed TX write backpressure: CPU write is not accepted while buf_valid=1
    (prevents silent byte drop that causes CPU B-channel deadlock)
  - AXI write channel now properly holds awready/wready low when buffer full
*/

`timescale 1ns / 1ps

// UART with AXI-Lite interface
module uart_axi #(
    parameter CLK_FREQ  = 50_000_000,   // System clock frequency
    parameter BAUD_RATE = 115_200       // UART baud rate
)(
    input         clk,
    input         reset,

    // AXI Write Address Channel
    input  [31:0] s_axi_awaddr,
    input         s_axi_awvalid,
    output        s_axi_awready,

    // AXI Write Data Channel
    input  [31:0] s_axi_wdata,
    input  [ 3:0] s_axi_wstrb,
    input         s_axi_wvalid,
    output        s_axi_wready,

    // AXI Write Response Channel
    output [ 1:0] s_axi_bresp,
    output        s_axi_bvalid,
    input         s_axi_bready,

    // AXI Read Address Channel
    input  [31:0] s_axi_araddr,
    input         s_axi_arvalid,
    output        s_axi_arready,

    // AXI Read Data Channel
    output [31:0] s_axi_rdata,
    output [ 1:0] s_axi_rresp,
    output        s_axi_rvalid,
    input         s_axi_rready,

    // UART signals
    output        tx_out,      // renamed: avoids collision with submodule type `uart_tx`
    input         uart_rx
);

    // -------------------------------
    // UART TX interface signals
    // -------------------------------
    reg  [7:0] tx_data;     // Byte to transmit
    reg        tx_valid;    // Trigger transmit
    wire       tx_ready;    // TX ready for new data

    // ── TX serial output: directly connected from u_tx instance ────────────
    // Port renamed tx_out (was uart_tx) to avoid Yosys scope-resolution
    // confusion between the output PORT name and the submodule TYPE name
    // `uart_tx`.  With identical identifiers, opt_clean removes the driver
    // of the port after flatten, producing "uart_tx has no driver".
    // Renaming the port eliminates the ambiguity at the source.

    // UART Transmitter instance
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk   (clk),
        .reset (reset),
        .data  (tx_data),
        .valid (tx_valid),
        .ready (tx_ready),
        .tx    (tx_out)     // FF Q drives tx_out port directly
    );

    // -------------------------------
    // UART RX interface signals
    // -------------------------------
    wire [7:0] rx_data_raw;         // Received byte
    wire       rx_data_valid_pulse; // Pulse when data received

    // UART Receiver instance
    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk        (clk),
        .reset      (reset),
        .rx         (uart_rx),
        .data_out   (rx_data_raw),
        .data_valid (rx_data_valid_pulse)
    );

    // -------------------------------
    // TX buffer (1-byte buffer)
    // -------------------------------
    reg [7:0] buf_data;   // Buffered data
    reg       buf_valid;  // Buffer valid flag

    // AXI write control signals
    reg       aw_got;     // Address received
    reg       w_got;      // Data received
    reg [7:0] w_byte;     // Extracted byte from AXI write
    reg       b_vld;      // Write response valid

    // -----------------------------------------
    // TX datapath + buffer management
    // -----------------------------------------
    // Single always block owns buf_data and buf_valid
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_valid  <= 1'b0;
            tx_data   <= 8'h00;
            buf_valid <= 1'b0;
            buf_data  <= 8'h00;
        end else begin
            tx_valid <= 1'b0;

            // If UART TX is ready and buffer has data → send
            if (tx_ready && buf_valid) begin
                tx_data   <= buf_data;
                tx_valid  <= 1'b1;
                buf_valid <= 1'b0;
            end

            // Load new byte from AXI write into buffer
            if (aw_got && w_got && !b_vld && !buf_valid) begin
                buf_data  <= w_byte;
                buf_valid <= 1'b1;
            end
        end
    end

    // -------------------------------
    // RX buffer (1-byte buffer)
    // -------------------------------
    reg [7:0] rx_buf_data;   // Stored received byte
    reg       rx_buf_valid;  // RX data valid flag

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_buf_data  <= 8'h00;
            rx_buf_valid <= 1'b0;
        end else begin
            // Capture received byte
            if (rx_data_valid_pulse) begin
                rx_buf_data  <= rx_data_raw;
                rx_buf_valid <= 1'b1;
            end

            // Clear buffer after read (data register read only)
            if (r_vld && s_axi_rready && !r_is_stat)
                rx_buf_valid <= 1'b0;
        end
    end

    // -------------------------------
    // AXI Write Channel Logic
    // -------------------------------
    assign s_axi_awready = !aw_got && !buf_valid; // Ready if no pending write
    assign s_axi_wready  = !w_got  && !buf_valid;
    assign s_axi_bresp   = 2'b00; // OKAY response
    assign s_axi_bvalid  = b_vld;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_got <= 1'b0;
            w_got  <= 1'b0;
            w_byte <= 8'h00;
            b_vld  <= 1'b0;
        end else begin

            // Capture write address
            if (s_axi_awvalid && !aw_got && !buf_valid)
                aw_got <= 1'b1;

            // Capture write data and select correct byte via strobe
            if (s_axi_wvalid && !w_got && !buf_valid) begin
                if      (s_axi_wstrb[0]) w_byte <= s_axi_wdata[ 7: 0];
                else if (s_axi_wstrb[1]) w_byte <= s_axi_wdata[15: 8];
                else if (s_axi_wstrb[2]) w_byte <= s_axi_wdata[23:16];
                else                     w_byte <= s_axi_wdata[31:24];
                w_got <= 1'b1;
            end

            // When both address and data received → generate response
            if (aw_got && w_got && !b_vld && !buf_valid) begin
                b_vld  <= 1'b1;
                aw_got <= 1'b0;
                w_got  <= 1'b0;
            end

            // Clear response when master accepts it
            if (b_vld && s_axi_bready)
                b_vld <= 1'b0;
        end
    end

    // -------------------------------
    // AXI Read Channel Logic
    // -------------------------------
    reg        r_vld;       // Read valid
    reg [31:0] r_data;      // Read data
    reg        r_is_stat;   // Indicates status register read

    assign s_axi_arready = !r_vld;
    assign s_axi_rdata   = r_data;
    assign s_axi_rresp   = 2'b00; // OKAY response
    assign s_axi_rvalid  = r_vld;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_vld     <= 1'b0;
            r_data    <= 32'b0;
            r_is_stat <= 1'b0;
        end else begin
            // Capture read request
            if (s_axi_arvalid && !r_vld) begin
                r_vld     <= 1'b1;

                // Address decode: 0x8 → status register
                r_is_stat <= (s_axi_araddr[3:0] == 4'h8);

                // Status register: [rx_valid]
                if (s_axi_araddr[3:0] == 4'h8)
                    r_data <= {30'b0, rx_buf_valid, 1'b0};
                else
                    // Data register: [rx_valid + rx_data]
                    r_data <= {23'b0, rx_buf_valid, rx_buf_data};
            end

            // Complete read transaction
            if (r_vld && s_axi_rready)
                r_vld <= 1'b0;
        end
    end

endmodule
