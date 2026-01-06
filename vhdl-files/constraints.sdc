# 1. DEFINE THE CLOCK (50 MHz = 20 ns cycle)
create_clock -name clk_50 -period 20.000 [get_ports {clk_50}]

# 2. IGNORE TIMING ON INPUTS (Buttons, Switches, UART RX)
# We list all input ports inside the curly braces
set_false_path -from [get_ports {btn_rst sw_start sw_disp rx}] -to *

# 3. IGNORE TIMING ON OUTPUTS (LEDs, UART TX, 7-Segment Display)
# We list all output ports inside the curly braces. 
# The [*] tells Quartus to include all bits of the vectors (like led_status[0] and [1])
set_false_path -from * -to [get_ports {tx led_a led_b led_status[*] fpga_dig_sel[*] fpga_seg_out[*]}]