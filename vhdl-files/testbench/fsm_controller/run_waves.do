# ==========================================================================
# 1. SETUP
# ==========================================================================
quit -sim

if {[file exists work] == 0} {
    vlib work
}

# ==========================================================================
# 2. COMPILATION
# ==========================================================================
echo "Compiling Design..."
# We use "../../" to go up two folders (out of 'fsm_controller', out of 'testbench')
# to find the main file in the root.
vcom -2008 ../../fsm_controller.vhd

echo "Compiling Testbench..."
# Since the script and TB are in the same folder now, no path is needed.
vcom -2008 tb_fsm_controller.vhd

# ==========================================================================
# 3. INITIALIZE
# ==========================================================================
vsim -voptargs=+acc work.tb_fsm_controller
view wave
delete wave *
config wave -signalnamewidth 1

# ==========================================================================
# 4. ADD WAVES
# ==========================================================================
add wave -noupdate -divider "System"
add wave -noupdate -color "gray" /tb_fsm_controller/clk_50

add wave -noupdate -divider "FSM State"
add wave -noupdate -color "cyan" /tb_fsm_controller/uut/current_state
add wave -noupdate -radix unsigned /tb_fsm_controller/uut/drain_timer

add wave -noupdate -divider "Inputs"
add wave -noupdate /tb_fsm_controller/btn_rst
add wave -noupdate /tb_fsm_controller/sw_start
add wave -noupdate /tb_fsm_controller/in_fifo_empty
add wave -noupdate /tb_fsm_controller/out_fifo_empty

add wave -noupdate -divider "Outputs"
add wave -noupdate -color "orange"  /tb_fsm_controller/sys_rst
add wave -noupdate -color "orange" /tb_fsm_controller/rx_w_en
add wave -noupdate -color "orange"  /tb_fsm_controller/proc_en
add wave -noupdate -color "orange" /tb_fsm_controller/tx_en
add wave -noupdate -radix binary    /tb_fsm_controller/led_status

# ==========================================================================
# 5. RUN
# ==========================================================================
run 15 us
wave zoom full
echo "Done."