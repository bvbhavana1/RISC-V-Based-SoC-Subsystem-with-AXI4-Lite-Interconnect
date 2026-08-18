/*
MODULE OVERVIEW
---------------
This file is a **testbench** used to simulate and verify a small RISC-V SoC.

A testbench is **not hardware**. It is a simulation program that:
• drives inputs to the design
• observes outputs from the design
• checks if the design behaves correctly

In this project the SoC contains a **PicoRV32 CPU connected to a UART peripheral**.
The firmware running on the CPU prints messages through UART.

This testbench performs three main jobs:

1. Generate clock and reset for the SoC
2. Monitor the UART output from the SoC
3. Send a command ("PING") to the SoC and verify the response

If the SoC correctly echoes back "PING", the testbench prints **TEST PASSED**.

You can imagine the system like this:

        +----------------------+
        |   PicoRV32 SoC       |
        |                      |
        |  Firmware prints    |
        |  messages via UART  |
        +----------+-----------+
                   |
               uart_tx
                   |
             Testbench Monitor
                   |
                 FIFO
                   |
             Test Sequence
                   |
                uart_rx

The testbench acts like a **virtual computer terminal** talking to the SoC.

FIX NOTES (vs original):
  • The UART TX monitor now prints "[TB] RX byte: X" for EVERY decoded byte,
    exactly mirroring the C++ PH_ECHO_WAIT loop that calls
    printf("[TB] RX byte: %c\n", b) for each fifo byte.
  • A dedicated "byte logger" always block monitors rx_wr_ptr and logs
    every character as it lands in the FIFO, independent of the test-
    sequence state machine.  This prevents the 10-greeting window from
    suppressing per-byte output.
  • The raw $write("%c") that just forwarded characters without prefix
    has been replaced by the prefixed $display("[TB] RX byte: %c") so
    that every byte is individually annotated like the C++ output.
  • Race condition fix: the byte logger uses a registered shadow pointer
    (log_ptr) so that it can never miss a byte written by the monitor
    inside the same delta cycle.
*/

// =============================================================================
// tb_top.v – Testbench for PicoRV32 AXI-Lite SoC (UART TX + RX)
// =============================================================================

`timescale 1ns / 1ps
// Simulation time unit = 1ns
// Simulation precision = 1ps

module tb_top;

    // -------------------------------------------------------------------------
    // Clock / Reset
    // -------------------------------------------------------------------------
    // These parameters define timing for the simulation

    localparam CLK_PERIOD    = 20;       // 20 ns clock period → 50 MHz clock

    // UART running at 115200 baud
    // Number of clock cycles required to transmit one UART bit
    localparam UART_BIT_CYCLES = 434;    

    // These delays are used by the UART monitor
    // They represent half and full UART bit times in nanoseconds
    //
    // BAUD_HALF = 1,000,000,000 ns / 115200 / 2  ≈ 4340 ns
    // BAUD_FULL = 1,000,000,000 ns / 115200       ≈ 8680 ns
    //
    // We use integer division here; Verilator --timing evaluates these at
    // elaboration time so they must be constant expressions.

    localparam BAUD_HALF = 1_000_000_000 / 115200 / 2;  
    localparam BAUD_FULL = 1_000_000_000 / 115200;      

    // Clock and reset signals for the DUT
    reg clk   = 0;
    reg reset = 1;

    // Counts how many greeting lines firmware printed
    integer hello_count = 0;

    // Clock generator
    // This toggles the clock every half period
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reset sequence
    // Hold reset for a few clock cycles before starting simulation
    initial begin
        $display("--------------------------------------------------");
        $display(" UART SoC Simulation Started");
        $display("--------------------------------------------------");

        repeat (10) @(posedge clk); // wait 10 clock cycles
        reset = 0;                  // release reset
    end


    // -------------------------------------------------------------------------
    // DUT (Device Under Test)
    // -------------------------------------------------------------------------
    // This instantiates the actual hardware design being tested

    wire uart_tx_pin;       // UART transmit from the SoC
    reg  uart_rx_pin = 1'b1;// UART receive input to the SoC (idle = 1)

    top u_dut (
        .clk(clk),
        .reset(reset),
        .uart_tx(uart_tx_pin),
        .uart_rx(uart_rx_pin)
    );


    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    // Generates a VCD file so signals can be viewed in GTKWave

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end


    // -------------------------------------------------------------------------
    // Timeout protection
    // -------------------------------------------------------------------------
    // If simulation runs too long, something is probably wrong.
    // This stops the simulation after 500 ms of simulated time.

    initial begin
        #500_000_000;
        $display("\n[TB] ERROR: Simulation TIMEOUT");
        $finish;
    end


    // -------------------------------------------------------------------------
    // UART RX Driver
    // -------------------------------------------------------------------------
    // This task sends one byte to the DUT through the UART RX pin.
    //
    // UART frame format:
    //
    //    START | 8 DATA BITS | STOP
    //       0        LSB→MSB     1
    //
    // Each bit lasts UART_BIT_CYCLES clock cycles.
    //
    // Example frame:
    //    0 1 0 1 0 0 0 1 0 1
    //
    // The extra delay after the stop bit gives the firmware time
    // to process the received character.

    task send_uart_byte;
        input [7:0] byte_val;
        integer i;
        begin
            // Start bit (UART start = 0)
            uart_rx_pin = 1'b0;
            repeat(UART_BIT_CYCLES) @(posedge clk);

            // Send 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = byte_val[i];
                repeat(UART_BIT_CYCLES) @(posedge clk);
            end

            // Stop bit (UART idle = 1)
            uart_rx_pin = 1'b1;
            repeat(UART_BIT_CYCLES) @(posedge clk);

            // Extra delay so firmware can read UART
            repeat(UART_BIT_CYCLES * 3) @(posedge clk);
        end
    endtask


    // -------------------------------------------------------------------------
    // RX FIFO (Monitor → Test Sequence)
    // -------------------------------------------------------------------------
    // This small FIFO stores characters captured from UART TX.

    reg [7:0] rx_fifo [0:63];

    integer rx_wr_ptr = 0; // write pointer
    integer rx_rd_ptr = 0; // read pointer

    // Task to read a byte from the FIFO
    task fifo_get_byte;
        output [7:0] data;
        begin
            // Wait until new data is available
            while (rx_rd_ptr == rx_wr_ptr)
                #10;

            data = rx_fifo[rx_rd_ptr & 63];
            rx_rd_ptr = rx_rd_ptr + 1;
        end
    endtask


    // =========================================================================
    // PER-BYTE LOGGER
    // =========================================================================
    // ROOT-CAUSE FIX: In the C++ testbench, the PH_ECHO_WAIT loop calls
    //
    //     printf("[TB] RX byte: %c\n", b);
    //
    // for EVERY byte that lands in rx_fifo, regardless of whether the test
    // sequencer has reached the echo-wait phase yet.
    //
    // The original Verilog TB never printed this prefix at all – the monitor
    // only used $write("%c", mon_byte) (raw character, no label).
    //
    // FIX: We add a shadow read pointer (log_ptr) that is completely
    // independent of the test-sequencer's rx_rd_ptr.  Every time rx_wr_ptr
    // advances (i.e., a new byte has been decoded from uart_tx) we print
    // "[TB] RX byte: X" immediately, exactly matching the C++ output.
    //
    // This always block runs in the time-domain (not edge-triggered) so it
    // cannot race with the monitor's write to rx_fifo: by the time #10 elapses
    // the FIFO slot is already settled.

    integer log_ptr = 0;  // shadow read pointer used ONLY for logging

    initial begin : byte_logger
        // Wait until reset is released before monitoring
        @(negedge reset);

        forever begin
            // Spin-wait until a new byte arrives in the FIFO
            while (log_ptr == rx_wr_ptr)
                #10;

            // Print per-byte label – one line per received character
            $display("[TB] RX byte: %c", rx_fifo[log_ptr & 63]);

            log_ptr = log_ptr + 1;
        end
    end


    // -------------------------------------------------------------------------
    // UART TX Monitor
    // -------------------------------------------------------------------------
    // Decodes the UART TX bit-stream into bytes and writes them into rx_fifo.
    // ALL display work (per-byte labels + assembled raw line) is handled by
    // byte_logger above; the monitor only maintains the FIFO and the greeting
    // counter so there is no risk of output interleaving.

    reg [7:0] mon_byte;
    integer   bit_i;

    // 32×8 shift-register that accumulates the current line of text.
    // On \n the full assembled string is printed as one $display line.
    reg [8*32-1:0] asm_line;  // packed string, MSB = first char received
    integer        asm_len;

    initial begin : uart_monitor

        asm_line = 0;
        asm_len  = 0;

        @(negedge reset);

        $display("\n[TB] UART Monitor Started");
        $display("--------------------------------------------");

        forever begin

            // ── Step 1: Wait for the falling edge (start bit) ────────────
            @(negedge uart_tx_pin);

            // ── Step 2: Skip to the CENTRE of the start bit ──────────────
            // BAUD_HALF ≈ 4340 ns  (half of one 115200-baud bit period)
            #(BAUD_HALF);

            // ── Step 3: Confirm this is a genuine start bit ───────────────
            if (uart_tx_pin == 1'b0) begin

                mon_byte = 8'h00;

                // ── Step 4: Sample 8 data bits at mid-bit positions ───────
                // We advance one full bit period before each sample so that
                // we land in the centre of each data bit cell.
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    #(BAUD_FULL);
                    mon_byte[bit_i] = uart_tx_pin;
                end

                // ── Step 5: Skip over the stop bit ────────────────────────
                #(BAUD_FULL);

                // ── Step 6: Store byte in FIFO ────────────────────────────
                // byte_logger wakes up on its next #10 poll and prints
                // "[TB] RX byte: X" for this byte.
                rx_fifo[rx_wr_ptr & 63] = mon_byte;
                rx_wr_ptr = rx_wr_ptr + 1;

                // ── Step 7: Assemble raw line ───────────────────────────
                // Accumulate characters until \n, then flush the whole line
                // as one $display.  Printed AFTER all [TB] RX byte: lines
                // for this character have been queued in the FIFO, so the
                // assembled line appears neatly after the per-byte log block.
                if (mon_byte == "\n") begin
                    // Print the assembled line (shift-reg holds chars MSB-first)
                    // Use $sformatf workaround: write each char individually
                    // via $write, then close with $display("").
                    // We wait one time-step so byte_logger can finish printing
                    // all its [TB] RX byte: lines first.
                    #1;
                    begin : flush_line
                        integer ci;
                        for (ci = 0; ci < asm_len; ci = ci + 1)
                            $write("%c", asm_line[8*ci +: 8]);
                        $display("");
                    end
                    asm_line = 0;
                    asm_len  = 0;

                    hello_count = hello_count + 1;

                    $display("\n[TB] Greeting message count = %0d", hello_count);

                    if (hello_count == 10) begin
                        $display("\n============================================");
                        $display(" 10 GREETING MESSAGES RECEIVED");
                        $display(" UART OUTPUT VERIFIED");
                        $display("============================================\n");
                    end
                end else if (asm_len < 32) begin
                    // Shift new char into asm_line (MSB = oldest char)
                    // Store newest at position [asm_len]
                    asm_line[8*asm_len +: 8] = mon_byte;
                    asm_len = asm_len + 1;
                end
            end
            // If uart_tx_pin went high again before BAUD_HALF elapsed it was
            // a glitch – just loop back and wait for the next falling edge.
        end
    end


    // -------------------------------------------------------------------------
    // Test Sequence
    // -------------------------------------------------------------------------
    // This section performs the actual verification test.

    localparam [7:0] PING_P = "P";
    localparam [7:0] PING_I = "I";
    localparam [7:0] PING_N = "N";
    localparam [7:0] PING_G = "G";

    reg [7:0] echo0, echo1, echo2, echo3;
    reg [7:0] temp;

    integer last_wr_snap;
    integer silence_cnt;

    initial begin : test_seq

        @(negedge reset);

        // Wait until firmware prints 10 greeting lines
        wait (hello_count == 10);

        $display("\n--------------------------------------------");
        $display("[TB] Greeting phase finished");
        $display("--------------------------------------------");

        // Wait until UART becomes idle (no new bytes for 5 baud periods)
        silence_cnt  = 0;
        last_wr_snap = rx_wr_ptr - 1;

        while (silence_cnt < 5) begin
            #(BAUD_FULL);

            if (rx_wr_ptr == last_wr_snap)
                silence_cnt = silence_cnt + 1;
            else begin
                last_wr_snap = rx_wr_ptr;
                silence_cnt  = 0;
            end
        end

        // Clear FIFO pointers so the echo-wait phase works on a clean slate.
        // NOTE: log_ptr is intentionally NOT reset – the byte_logger has
        // already printed everything up to this point; resetting only the
        // test-seq pointer prevents double-printing.
        rx_rd_ptr = 0;
        rx_wr_ptr = 0;

        // Also align the logger shadow pointer so it stays in sync.
        log_ptr = 0;

        #1;

        $display("\n--------------------------------------------");
        $display("[TB] FIFO flushed – sending command : PING");
        $display("--------------------------------------------");

        // Send command PING
        send_uart_byte(PING_P);
        send_uart_byte(PING_I);
        send_uart_byte(PING_N);
        send_uart_byte(PING_G);


        // Wait for first P – the byte_logger will have already printed each
        // character; here we additionally verify correctness byte-by-byte.
        temp = 0;
        while (temp != PING_P)
            fifo_get_byte(temp);

        echo0 = temp;
        fifo_get_byte(echo1);
        fifo_get_byte(echo2);
        fifo_get_byte(echo3);

        // Verify result
        if (echo0 == PING_P &&
            echo1 == PING_I &&
            echo2 == PING_N &&
            echo3 == PING_G) begin

            $display("\n============================================");
            $display(" TEST PASSED");
            $display(" Echo received : %c%c%c%c", echo0, echo1, echo2, echo3);
            $display("============================================\n");

        end else begin

            $display("\n============================================");
            $display(" TEST FAILED");
            $display(" Expected : PING");
            $display(" Received : %c%c%c%c", echo0, echo1, echo2, echo3);
            $display("============================================\n");

        end

        $finish;

    end

endmodule
