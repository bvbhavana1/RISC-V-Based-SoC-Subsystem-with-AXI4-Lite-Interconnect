/*
adc_tb_wrap.v – Updated with vin_debug support for waveform visibility
*/

`timescale 1ns / 1ps

module adc_tb_wrap (
    // Clock / Reset
    input  wire        clk,
    input  wire        reset,

    // AXI-Lite Slave interface
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [ 3:0] s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [ 1:0] s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output wire [31:0] s_axi_rdata,
    output wire [ 1:0] s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // 🔥 NEW: Analog input (visible in GTKWave)
    input  wire [7:0]  vin_debug,

    // Internal comparator signal
    output wire        comp_in,

    // DAC output
    output wire [7:0]  dac_out,

    // Debug ports
    output wire [7:0]  dbg_sar,
    output wire [3:0]  dbg_bit,
    output wire [1:0]  dbg_state
);

    // 🔥 Comparator modeling INSIDE RTL
    assign comp_in = (vin_debug > dac_out);

    // SAR ADC instance
    sar_adc_axi u_sar_adc (
        .clk            (clk),
        .reset          (reset),

        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),

        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),

        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),

        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        .comp_in        (comp_in),
        .dac_out        (dac_out),

        .dbg_sar        (dbg_sar),
        .dbg_bit        (dbg_bit),
        .dbg_state      (dbg_state)
    );

endmodule
