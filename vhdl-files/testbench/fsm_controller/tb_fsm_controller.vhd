library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fsm_controller is
    -- Testbench has no ports
end entity tb_fsm_controller;

architecture behavior of tb_fsm_controller is

    -- Component Declaration for the Unit Under Test (UUT)
    component fsm_controller
    port(
        clk_50          : in  std_logic;
        btn_rst         : in  std_logic;
        sw_start        : in  std_logic;
        in_fifo_empty   : in  std_logic;
        out_fifo_empty  : in  std_logic;
        sys_rst         : out std_logic;
        rx_w_en         : out std_logic;
        tx_en           : out std_logic;
        proc_en         : out std_logic;
        led_status      : out std_logic_vector(1 downto 0)
    );
    end component;

    -- Signal Declarations
    signal clk_50         : std_logic := '0';
    signal btn_rst        : std_logic := '0';
    signal sw_start       : std_logic := '0';
    signal in_fifo_empty  : std_logic := '1'; -- Assume empty initially
    signal out_fifo_empty : std_logic := '0'; -- Output FIFO not done

    -- Outputs
    signal sys_rst        : std_logic;
    signal rx_w_en        : std_logic;
    signal tx_en          : std_logic;
    signal proc_en        : std_logic;
    signal led_status     : std_logic_vector(1 downto 0);

    -- Clock Period Definition (50 MHz = 20 ns)
    constant CLK_PERIOD : time := 20 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: fsm_controller port map (
        clk_50         => clk_50,
        btn_rst        => btn_rst,
        sw_start       => sw_start,
        in_fifo_empty  => in_fifo_empty,
        out_fifo_empty => out_fifo_empty,
        sys_rst        => sys_rst,
        rx_w_en        => rx_w_en,
        tx_en          => tx_en,
        proc_en        => proc_en,
        led_status     => led_status
    );

    -- =========================================================================
    -- Clock Generation Process
    -- =========================================================================
    clk_process : process
    begin
        clk_50 <= '0';
        wait for CLK_PERIOD/2;
        clk_50 <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- =========================================================================
    -- Stimulus Process
    -- =========================================================================
    stim_proc: process
    begin
        -- 1. Initialize Inputs
        wait for 100 ns;
        btn_rst <= '1'; -- Active Reset
        sw_start <= '0';
        in_fifo_empty <= '1';
        out_fifo_empty <= '0';
        
        wait for CLK_PERIOD * 5;
        
        -- 2. Release Reset -> Should go to S_RESET
        btn_rst <= '0';
        wait for CLK_PERIOD * 2;
        
        -- Check: Are we in Reset state? (sys_rst should be '1')
        assert sys_rst = '1' report "Error: Should be in S_RESET (sys_rst=1)" severity error;

        -- 3. Transition to S_LOAD
        -- Condition: sw_start = '0' (Already set)
        wait for CLK_PERIOD * 2;
        
        -- Check: Are we loading? (rx_w_en should be '1')
        assert rx_w_en = '1' report "Error: Should be in S_LOAD (rx_w_en=1)" severity error;

        -- 4. Prepare for Processing
        -- Simulate data arriving in FIFO (not empty)
        in_fifo_empty <= '0'; 
        wait for CLK_PERIOD * 2;
        
        -- 5. Transition to S_PROCESS
        -- Condition: sw_start = '1' AND in_fifo_empty = '0'
        sw_start <= '1';
        wait for CLK_PERIOD * 2;
        
        -- Check: Are we processing? (proc_en should be '1')
        assert proc_en = '1' report "Error: Should be in S_PROCESS (proc_en=1)" severity error;

        -- 6. Simulate Draining Phase (The 300 Cycle Timer)
        wait for CLK_PERIOD * 20; -- Process some data normally...
        
        report "Simulating Input FIFO Empty - Starting Drain Timer (300 cycles)...";
        in_fifo_empty <= '1'; -- FIFO runs dry
        
        -- We must wait > 300 clock cycles. Let's wait 310 to be safe.
        wait for CLK_PERIOD * 310;

        -- 7. Verify Transition to S_UPLOAD
        -- After timer expires, tx_en should go high
        wait for CLK_PERIOD * 2;
        assert tx_en = '1' report "Error: Should be in S_UPLOAD after drain timer" severity error;
        assert proc_en = '0' report "Error: Processing should stop in S_UPLOAD" severity error;

        -- 8. Finish Uploading
        wait for CLK_PERIOD * 10;
        out_fifo_empty <= '1'; -- Signal that upload is complete
        
        wait for CLK_PERIOD * 2;
        
        -- 9. Verify S_DONE
        assert led_status = "11" report "Error: Should be in S_DONE (LEDs=11)" severity error;

        -- 10. Test Trap State
        -- Even if inputs change, we should stay stuck here
        sw_start <= '0';
        out_fifo_empty <= '0';
        wait for CLK_PERIOD * 5;
        assert led_status = "11" report "Error: S_DONE should be a trap state" severity error;

        -- 11. Final Reset (Optional)
        btn_rst <= '1';
        wait for CLK_PERIOD * 2;
        assert sys_rst = '1' report "Error: Failed to reset from S_DONE" severity error;

        report "Testbench Completed Successfully";
        wait; -- Stop simulation
    end process;

end architecture behavior;