library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_clock_div_160k is
    -- Testbench has no ports
end entity tb_clock_div_160k;

architecture behavior of tb_clock_div_160k is

    -- Component Declaration
    component clock_div_160k
    port(
        clk_50    : in  std_logic;
        sys_rst   : in  std_logic;
        proc_en   : in  std_logic;
        tick_160k : out std_logic
    );
    end component;

    -- Signals
    signal clk_50    : std_logic := '0';
    signal sys_rst   : std_logic := '0';
    signal proc_en   : std_logic := '0';
    signal tick_160k : std_logic;

    -- Clock Period (20 ns = 50 MHz)
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate UUT
    uut: clock_div_160k port map (
        clk_50    => clk_50,
        sys_rst   => sys_rst,
        proc_en   => proc_en,
        tick_160k => tick_160k
    );

    -- Clock Generation
    clk_process : process
    begin
        clk_50 <= '0';
        wait for CLK_PERIOD/2;
        clk_50 <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus Process
    stim_proc: process
    begin
        -- 1. Initialize Inputs
        sys_rst <= '1'; -- Hold Reset
        proc_en <= '0';
        wait for 100 ns;

        -- 2. Release Reset
        sys_rst <= '0';
        wait for CLK_PERIOD * 2;

        -- 3. Enable the Divider
        proc_en <= '1';
        
        -- 4. Run Simulation
        -- We need to see at least 2-3 full cycles to observe the toggle logic.
        -- Period = 1/160kHz = 6.25 us.
        -- 20 us is enough to see 3 ticks.
        wait for 20 us;

        -- 5. Test Disable functionality
        proc_en <= '0';
        wait for 2 us;
        
        -- 6. Stop
        report "Testbench Completed";
        wait; -- Stops the process
    end process;

end architecture behavior;