# ==========================================================================
# 1. SETUP
# ==========================================================================
quit -sim

if {[file exists work] == 0} {
    vlib work
}

# ==========================================================================
# 2. COMPILATION (Fixed Path)
# ==========================================================================
echo "Compiling Design..."
# UPDATED PATH HERE:
vcom -2008 ../../virtual_adc_interface/clock_div_160k.vhd

echo "Compiling Testbench..."
vcom -2008 tb_clock_div_160k.vhd

# ==========================================================================
# 3. INITIALIZE
# ==========================================================================
# -voptargs=+acc is CRITICAL for seeing internal signals
vsim -voptargs=+acc work.tb_clock_div_160k

# Force the Wave Window to appear
view wave

# Reset Waves
delete wave *
config wave -signalnamewidth 1

# ==========================================================================
# 4. ADD WAVES
# ==========================================================================

# Group 1: System
add wave -noupdate -divider "System"
add wave -noupdate -color "gray" /tb_clock_div_160k/clk_50
add wave -noupdate -color "orange" /tb_clock_div_160k/sys_rst
add wave -noupdate -color "green" /tb_clock_div_160k/proc_en

# Group 2: Internal Dithering Logic
add wave -noupdate -divider "Internal Logic"
# Note: "uut" must match the label in your testbench (uut: clock_div_160k...)
add wave -noupdate -format analog -height 80 -max 315 -radix unsigned /tb_clock_div_160k/uut/count
add wave -noupdate -color "magenta" /tb_clock_div_160k/uut/toggle_reg
add wave -noupdate -radix unsigned /tb_clock_div_160k/uut/mux_out

# Group 3: Output
add wave -noupdate -divider "Output"
add wave -noupdate -color "red" /tb_clock_div_160k/tick_160k

# ==========================================================================
# 5. RUN
# ==========================================================================
run 25 us

wave zoom full
echo "Simulation Done."