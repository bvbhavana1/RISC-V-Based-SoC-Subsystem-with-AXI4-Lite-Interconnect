create_clock -period 20 -name clk [get_ports clk]
set_clock_uncertainty   0.25 [get_clocks clk]
set_clock_transition    0.25 [get_clocks clk]

set_driving_cell \
    -lib_cell sky130_fd_sc_hd__clkbuf_16 \
    -pin X \
    [get_ports clk]
set_input_delay -min -rise 0.0 [get_ports {reset uart_rx}] -clock clk
set_input_delay -min -fall 0.0 [get_ports {reset uart_rx}] -clock clk
set_input_delay -max -rise 4.0 [get_ports {reset uart_rx}] -clock clk
set_input_delay -max -fall 4.0 [get_ports {reset uart_rx}] -clock clk
set_input_transition -min -rise 0.15 [get_ports {reset uart_rx}]
set_input_transition -min -fall 0.15 [get_ports {reset uart_rx}]
set_input_transition -max -rise 0.50 [get_ports {reset uart_rx}]
set_input_transition -max -fall 0.50 [get_ports {reset uart_rx}]
set_output_delay -min -rise 0.0 [get_ports uart_tx] -clock clk
set_output_delay -min -fall 0.0 [get_ports uart_tx] -clock clk
set_output_delay -max -rise 4.0 [get_ports uart_tx] -clock clk
set_output_delay -max -fall 4.0 [get_ports uart_tx] -clock clk
set_load -pin_load 0.017 [get_ports uart_tx]
set_max_transition 1.500 [current_design]
set_false_path -from [get_ports reset]
