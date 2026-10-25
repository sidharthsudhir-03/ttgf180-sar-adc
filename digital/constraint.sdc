# constraint.sdc: SAR logic timing
current_design sar_logic

set clk_period 20.0   ;# ns (50 MHz)
create_clock -name clk -period $clk_period [get_ports clk]

set io_delay [expr {$clk_period * 0.2}]
set_input_delay  $io_delay -clock clk [all_inputs -no_clocks]
set_output_delay $io_delay -clock clk [all_outputs]
