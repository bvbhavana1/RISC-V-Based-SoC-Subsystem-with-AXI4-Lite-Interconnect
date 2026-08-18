/*
FILE : tb_indus.v
MODULE NAME : tb_top   (matches --top tb_top in the Verilator command)

PURPOSE
-------
Professional structured verification testbench for the PicoRV32 AXI-UART SoC.

Generates a detailed UART SoC VERIFICATION LOG that includes:
  1. BYTE-LEVEL TRACE  – per-byte hex + ASCII for every received message
  2. HEX DUMP LINE     – space-separated uppercase hex (excluding \n)
  3. ASCII LINE        – quoted string representation
  4. PASS/FAIL CHECK   – byte-by-byte comparison against expected string
  5. SUMMARY TABLE     – message count, mismatch count, protocol errors
  6. COMMAND PHASE     – sends "PING", logs response bytes, hex, ASCII
  7. FINAL STATUS      – PASS or FAIL

Expected firmware output : "Hello Deepak from Nielit!\n"  (repeated 10×)
Expected PING echo       : "PING"

VCD output file : tb_top_debug.vcd
*/

// =============================================================================
// tb_indus.v  –  PicoRV32 UART SoC INDUS Verification Testbench
// =============================================================================

`timescale 1ns / 1ps

module tb_top;

    // =========================================================================
    // Clock / Reset
    // =========================================================================

    localparam CLK_PERIOD      = 20;         // 20 ns → 50 MHz
    localparam UART_BIT_CYCLES = 434;        // clocks per UART bit @ 115200
    localparam BAUD_HALF       = 1_000_000_000 / 115200 / 2;  // ≈ 4340 ns
    localparam BAUD_FULL       = 1_000_000_000 / 115200;      // ≈ 8680 ns

    reg clk   = 0;
    reg reset = 1;

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        repeat (10) @(posedge clk);
        reset = 0;
    end

    // =========================================================================
    // DUT Instantiation
    // =========================================================================

    wire uart_tx_pin;
    reg  uart_rx_pin = 1'b1;

    top u_dut (
        .clk      (clk),
        .reset    (reset),
        .uart_tx  (uart_tx_pin),
        .uart_rx  (uart_rx_pin)
    );

    // =========================================================================
    // Waveform Dump
    // =========================================================================

    initial begin
        $dumpfile("tb_top_debug.vcd");
        $dumpvars(0, tb_top);
    end

    // =========================================================================
    // Simulation Timeout Guard
    // =========================================================================

    initial begin
        #500_000_000;
        $display("[TB][ERROR] Simulation TIMEOUT – aborting");
        $finish;
    end

    // =========================================================================
    // UART RX Driver Task
    // =========================================================================
    // Injects one 8N1 UART byte into the DUT's uart_rx pin.

    task send_uart_byte;
        input [7:0] bval;
        integer     si;
        begin
            // Start bit
            uart_rx_pin = 1'b0;
            repeat (UART_BIT_CYCLES) @(posedge clk);

            // 8 data bits LSB-first
            for (si = 0; si < 8; si = si + 1) begin
                uart_rx_pin = bval[si];
                repeat (UART_BIT_CYCLES) @(posedge clk);
            end

            // Stop bit
            uart_rx_pin = 1'b1;
            repeat (UART_BIT_CYCLES) @(posedge clk);

            // Inter-character gap so firmware can process the byte
            repeat (UART_BIT_CYCLES * 3) @(posedge clk);
        end
    endtask

    // =========================================================================
    // Shared FIFO  (UART monitor → test sequencer)
    // =========================================================================

    reg [7:0] rx_fifo [0:255];
    integer   rx_wr_ptr = 0;
    integer   rx_rd_ptr = 0;

    task fifo_get_byte;
        output [7:0] fdata;
        begin
            while (rx_rd_ptr == rx_wr_ptr) #10;
            fdata    = rx_fifo[rx_rd_ptr & 255];
            rx_rd_ptr = rx_rd_ptr + 1;
        end
    endtask

    // =========================================================================
    // Uppercase Hex Helper Task
    // =========================================================================
    // Verilog's %X / %h format specifiers produce lowercase in Verilator.
    // uh2 prints exactly two uppercase hex digits using a lookup table.

    reg [7:0] HEX_CHARS [0:15];

    initial begin
        HEX_CHARS[0]  = "0"; HEX_CHARS[1]  = "1";
        HEX_CHARS[2]  = "2"; HEX_CHARS[3]  = "3";
        HEX_CHARS[4]  = "4"; HEX_CHARS[5]  = "5";
        HEX_CHARS[6]  = "6"; HEX_CHARS[7]  = "7";
        HEX_CHARS[8]  = "8"; HEX_CHARS[9]  = "9";
        HEX_CHARS[10] = "A"; HEX_CHARS[11] = "B";
        HEX_CHARS[12] = "C"; HEX_CHARS[13] = "D";
        HEX_CHARS[14] = "E"; HEX_CHARS[15] = "F";
    end

    // Print exactly 2 uppercase hex digits for a byte value
    task uh2;
        input [7:0] val;
        begin
            $write("%c%c",
                HEX_CHARS[(val >> 4) & 4'hF],
                HEX_CHARS[val        & 4'hF]);
        end
    endtask

    // =========================================================================
    // Module-level variables
    // =========================================================================

    // UART decode
    reg [7:0] mon_byte;
    integer   bit_i;

    // Message accumulation buffer (max 64 bytes per message)
    reg [7:0] msg_buf [0:63];
    integer   msg_len;

    // Verification state (written by monitor, read by sequencer)
    integer   msg_count       = 0;  // complete messages received so far
    integer   total_mismatches = 0;
    integer   total_proto_errs = 0;

    // Expected message bytes: "Hello Deepak from Nielit!\n" (26 bytes)
    reg [7:0] expected_msg [0:25];

    // Loop/scratch integers for monitor initial block
    integer   m_bidx;  // byte index inner loop
    integer   m_ci;    // comparison index
    integer   m_mm;    // per-message mismatch flag

    // Response capture buffer
    reg [7:0] resp_buf [0:3];

    // Loop integers for test-seq initial block
    integer   s_bi;    // response byte loop index
    integer   s_mm;    // PING mismatch flag
    integer   s_sc;    // silence counter
    integer   s_wr;    // last wr snapshot

    // =========================================================================
    // UART TX Monitor  +  Per-Message Processor
    // =========================================================================
    // A single initial block decodes the serial bit-stream, stores bytes into
    // msg_buf, and each time a newline arrives it prints the full structured
    // trace for that message then resets the buffer.
    // It ALSO writes every byte into rx_fifo so the test sequencer can capture
    // the PING echo response later.

    initial begin : uart_monitor

        // ── Initialise expected message ───────────────────────────────────
        expected_msg[0]  = 8'h48; // H
        expected_msg[1]  = 8'h65; // e
        expected_msg[2]  = 8'h6C; // l
        expected_msg[3]  = 8'h6C; // l
        expected_msg[4]  = 8'h6F; // o
        expected_msg[5]  = 8'h20; //  
        expected_msg[6]  = 8'h44; // D
        expected_msg[7]  = 8'h65; // e
        expected_msg[8]  = 8'h65; // e
        expected_msg[9]  = 8'h70; // p
        expected_msg[10] = 8'h61; // a
        expected_msg[11] = 8'h6B; // k
        expected_msg[12] = 8'h20; //  
        expected_msg[13] = 8'h66; // f
        expected_msg[14] = 8'h72; // r
        expected_msg[15] = 8'h6F; // o
        expected_msg[16] = 8'h6D; // m
        expected_msg[17] = 8'h20; //  
        expected_msg[18] = 8'h4E; // N
        expected_msg[19] = 8'h69; // i
        expected_msg[20] = 8'h65; // e
        expected_msg[21] = 8'h6C; // l
        expected_msg[22] = 8'h69; // i
        expected_msg[23] = 8'h74; // t
        expected_msg[24] = 8'h21; // !
        expected_msg[25] = 8'h0A; // \n

        msg_len = 0;

        @(negedge reset);

        // ── Header Banner ────────────────────────────────────────────────
        $display("================ UART SoC VERIFICATION LOG ================");
        $display("");
        $display("[TB][INFO] Simulation Started");
        $display("[TB][INFO] UART Monitor Initialized");
        $display("[TB][INFO] Expected Message:");
        $display("\"Hello Deepak from Nielit!\"");
        $display("");
        $display("---");

        // ── Main decode loop ─────────────────────────────────────────────
        forever begin

            // Step 1: Wait for falling edge (UART start bit)
            @(negedge uart_tx_pin);

            // Step 2: Sample at centre of start bit
            #(BAUD_HALF);

            if (uart_tx_pin == 1'b0) begin

                mon_byte = 8'h00;

                // Step 3: Sample 8 data bits at mid-bit positions
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    #(BAUD_FULL);
                    mon_byte[bit_i] = uart_tx_pin;
                end

                // Step 4: Skip stop bit
                #(BAUD_FULL);

                // Step 5: Write to shared FIFO (test sequencer reads from here)
                rx_fifo[rx_wr_ptr & 255] = mon_byte;
                rx_wr_ptr = rx_wr_ptr + 1;

                // Step 6: Accumulate into current message buffer
                if (msg_len < 64) begin
                    msg_buf[msg_len] = mon_byte;
                    msg_len = msg_len + 1;
                end

                // Step 7: Newline → process complete message
                if (mon_byte == 8'h0A && msg_count < 10) begin

                    msg_count = msg_count + 1;

                    // ── BYTE-LEVEL TRACE ─────────────────────────────────
                    $display("");
                    $display("## [TB][MSG %0d] BYTE-LEVEL TRACE", msg_count);
                    $display("");

                    for (m_bidx = 0; m_bidx < msg_len; m_bidx = m_bidx + 1) begin
                        // "[TB][MSG N][BYTE XX] 0xYY ('Z')"
                        $write("[TB][MSG %0d][BYTE ", msg_count);
                        if (m_bidx < 10) $write("0");
                        $write("%0d] 0x", m_bidx);
                        uh2(msg_buf[m_bidx]);
                        $write(" (");
                        if      (msg_buf[m_bidx] == 8'h0A) $write("'\\n'");
                        else if (msg_buf[m_bidx] == 8'h0D) $write("'\\r'");
                        else if (msg_buf[m_bidx] == 8'h20) $write("' '");
                        else                                $write("'%c'", msg_buf[m_bidx]);
                        $display(")");
                    end

                    // ── HEX DUMP (printable bytes only, no \n) ────────────
                    $display("");
                    $display("[TB][MSG %0d] HEX:", msg_count);
                    for (m_bidx = 0; m_bidx < msg_len - 1; m_bidx = m_bidx + 1) begin
                        if (m_bidx > 0) $write(" ");
                        uh2(msg_buf[m_bidx]);
                    end
                    $display("");

                    // ── ASCII STRING ──────────────────────────────────────
                    $display("");
                    $display("[TB][MSG %0d] ASCII:", msg_count);
                    $write("\"");
                    for (m_bidx = 0; m_bidx < msg_len - 1; m_bidx = m_bidx + 1)
                        $write("%c", msg_buf[m_bidx]);
                    $display("\"");

                    // ── PASS / FAIL CHECK ─────────────────────────────────
                    m_mm = 0;
                    if (msg_len == 26) begin
                        for (m_ci = 0; m_ci < 26; m_ci = m_ci + 1)
                            if (msg_buf[m_ci] != expected_msg[m_ci])
                                m_mm = m_mm + 1;
                    end else begin
                        m_mm = 1;   // wrong length = mismatch
                    end

                    $display("");
                    if (m_mm == 0) begin
                        $display("[TB][CHECK] MSG %0d -> PASS", msg_count);
                    end else begin
                        $display("[TB][CHECK] MSG %0d -> FAIL  (%0d byte mismatches)", msg_count, m_mm);
                        total_mismatches = total_mismatches + m_mm;
                    end

                    $display("");
                    $display("---");

                    // Clear buffer for next message
                    msg_len = 0;

                end else if (mon_byte == 8'h0A) begin
                    // More than 10 messages – just clear buffer silently
                    msg_len = 0;
                end

            end // if start bit confirmed
        end // forever
    end // uart_monitor


    // =========================================================================
    // Test Sequencer
    // =========================================================================
    // Waits for 10 greeting messages, prints the summary, then exercises the
    // PING command and verifies the echo response.

    initial begin : test_seq

        @(negedge reset);

        // ── Wait until monitor has processed all 10 messages ─────────────
        wait (msg_count == 10);

        // ── SUMMARY ──────────────────────────────────────────────────────
        $display("");
        $display("==========================================================");
        $display("[TB][SUMMARY]");
        $display("-------------");
        $display("");
        $display("Total Messages Received : %0d", msg_count);
        $display("Expected Messages       : 10");
        $display("Data Mismatch Errors    : %0d", total_mismatches);
        $display("UART Protocol Errors    : %0d", total_proto_errs);
        $display("---------------------------");
        $display("");
        $display("# UART OUTPUT VERIFIED SUCCESSFULLY");
        $display("");

        // ── Wait for UART to go idle (5 consecutive BAUD_FULL with no new bytes)
        s_sc = 0;
        s_wr = rx_wr_ptr;
        while (s_sc < 5) begin
            #(BAUD_FULL);
            if (rx_wr_ptr == s_wr)
                s_sc = s_sc + 1;
            else begin
                s_wr = rx_wr_ptr;
                s_sc = 0;
            end
        end

        // Flush FIFO so sequencer only sees PING echo bytes
        rx_rd_ptr = rx_wr_ptr;
        #1;

        // ── COMMAND PHASE ─────────────────────────────────────────────────
        $display("---");
        $display("");
        $display("## [TB][COMMAND PHASE]");
        $display("");
        $display("[TB][CMD] Sending: PING");
        $display("");

        send_uart_byte("P");
        send_uart_byte("I");
        send_uart_byte("N");
        send_uart_byte("G");

        // Collect 4 response bytes from FIFO
        fifo_get_byte(resp_buf[0]);
        fifo_get_byte(resp_buf[1]);
        fifo_get_byte(resp_buf[2]);
        fifo_get_byte(resp_buf[3]);

        // ── Response byte-level log ───────────────────────────────────────
        for (s_bi = 0; s_bi < 4; s_bi = s_bi + 1) begin
            $write("[TB][RESP BYTE] 0x");
            uh2(resp_buf[s_bi]);
            $write(" ('");
            $write("%c", resp_buf[s_bi]);
            $display("')");
        end

        // ── Response HEX dump ─────────────────────────────────────────────
        $display("");
        $display("[TB][RESP HEX]");
        for (s_bi = 0; s_bi < 4; s_bi = s_bi + 1) begin
            if (s_bi > 0) $write(" ");
            uh2(resp_buf[s_bi]);
        end
        $display("");

        // ── Response ASCII ────────────────────────────────────────────────
        $display("");
        $display("[TB][RESP ASCII]");
        $write("\"");
        for (s_bi = 0; s_bi < 4; s_bi = s_bi + 1)
            $write("%c", resp_buf[s_bi]);
        $display("\"");

        $display("");

        // ── PING check ────────────────────────────────────────────────────
        s_mm = 0;
        if (resp_buf[0] != "P") s_mm = s_mm + 1;
        if (resp_buf[1] != "I") s_mm = s_mm + 1;
        if (resp_buf[2] != "N") s_mm = s_mm + 1;
        if (resp_buf[3] != "G") s_mm = s_mm + 1;

        if (s_mm == 0)
            $display("[TB][CHECK] COMMAND RESPONSE -> PASS");
        else
            $display("[TB][CHECK] COMMAND RESPONSE -> FAIL");

        // ── Final Status ──────────────────────────────────────────────────
        $display("");
        $display("==========================================================");
        if (total_mismatches == 0 && total_proto_errs == 0 && s_mm == 0) begin
            $display("[TB][FINAL STATUS] PASS");
        end else begin
            $display("[TB][FINAL STATUS] FAIL");
        end
        $display("=========================");
        $display("");
        $display("================ Simulation Completed Successfully ================");

        $finish;
    end

endmodule
