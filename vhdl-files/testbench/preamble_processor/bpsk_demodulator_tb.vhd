library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all; -- Standard library for console printing

entity bpsk_demodulator_tb is
    -- Testbench has no ports
end entity bpsk_demodulator_tb;

architecture  behavior of bpsk_demodulator_tb is

    -- 1. Component Declaration
    -- Matches the 10-bit output design
    component bpsk_demodulator is
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            fifo_ready      : in  std_logic;
            bpsk_sample     : in  std_logic_vector(7 downto 0);
            demod_ready     : out std_logic;
            demod_sample    : out std_logic_vector(9 downto 0) -- 10-bit output
        );
    end component;

    -- 2. Testbench Signals
    signal tb_clk           : std_logic := '0';
    signal tb_rst           : std_logic := '0';
    signal tb_fifo_ready    : std_logic := '0';
    signal tb_bpsk_sample   : std_logic_vector(7 downto 0) := (others => '0');
    signal tb_demod_ready   : std_logic;
    signal tb_demod_sample  : std_logic_vector(9 downto 0); -- 10-bit signal

    -- Clock Period Constant (50 MHz = 20 ns)
    constant CLK_PERIOD : time := 20 ns;

begin

    -- 3. Instantiate the Device Under Test (DUT)
    uut: bpsk_demodulator
        port map (
            clk          => tb_clk,
            rst          => tb_rst,
            fifo_ready   => tb_fifo_ready,
            bpsk_sample  => tb_bpsk_sample,
            demod_ready  => tb_demod_ready,
            demod_sample => tb_demod_sample
        );

    -- 4. Clock Generation Process
    clk_process : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD/2;
        tb_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 5. Stimulus Process (The actual test logic)
    stim_proc: process
    begin
        -- Initial Reset (Asynchronous)
        tb_rst <= '1';
        wait for 50 ns;
        tb_rst <= '0';
        wait for 20 ns;

        -- =====================================================================
        -- IMPORTANT: Sync with Falling Edge before starting inputs
        -- =====================================================================
        -- This ensures we change data halfway through the clock cycle.
        -- Result: Inputs change on Falling Edge -> DUT reads on Rising Edge.
        wait until falling_edge(tb_clk);

        report "--- STARTING SIMULATION (FALLING EDGE DRIVING) ---"; 

        -- =====================================================================
        -- TEST CASE 1: DC OFFSET REMOVAL
        -- Goal: Feed constant positive value (+10). 
        -- Math: (10 + 10) - (10 + 10) should equal 0.
        -- =====================================================================
        report "Test Case 1: DC Input (Value 10) -> Expecting 0 Output";
        
        -- Feed 5 samples to fill the pipeline
        for i in 1 to 5 loop
            tb_fifo_ready <= '1';
            tb_bpsk_sample <= std_logic_vector(to_signed(10, 8)); -- Input = 10
            wait for CLK_PERIOD; -- Pulse valid for 1 clock
            
            tb_fifo_ready <= '0'; -- Idle between samples
            wait for CLK_PERIOD; 
        end loop;

        -- Verify the result
        wait for CLK_PERIOD;
        if to_integer(signed(tb_demod_sample)) = 0 then
            report "  [PASS] Output stabilized at 0.";
        else
            report "  [FAIL] Output is " & integer'image(to_integer(signed(tb_demod_sample))) & " (Expected 0)";
        end if;
        report "------------------------------------------------";


        -- =====================================================================
        -- TEST CASE 2: MATCHED FILTER (Positive Correlation)
        -- Goal: Feed the pattern that perfectly matches the kernel [+1, +1, -1, -1].
        -- Input Sequence (Oldest to Newest): 100, 100, -100, -100
        -- Math: (100 + 100) - (-100 + -100) = 200 - (-200) = +400
        -- =====================================================================
        report "Test Case 2: Perfect Pattern Match -> Expecting +400 Output";

        -- 1. Push Oldest Sample (+100)
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(100, 8)); wait for CLK_PERIOD;
        
        -- 2. Push 2nd Oldest (+100)
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(100, 8)); wait for CLK_PERIOD;
        
        -- 3. Push 2nd Newest (-100)
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(-100, 8)); wait for CLK_PERIOD;
        
        -- 4. Push Newest Sample (-100)
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(-100, 8)); wait for CLK_PERIOD;

        tb_fifo_ready <= '0'; -- Stop pushing
        wait for CLK_PERIOD;  -- Wait for pipeline to compute
        
        -- Check Result
        if to_integer(signed(tb_demod_sample)) = 400 then
            report "  [PASS] Output is +400.";
        else
            report "  [FAIL] Output is " & integer'image(to_integer(signed(tb_demod_sample))) & " (Expected 400)";
        end if;
        report "------------------------------------------------";

        -- =====================================================================
        -- TEST CASE 3: INVERSE PATTERN (Negative Correlation)
        -- Goal: Feed the opposite pattern [-100, -100, +100, +100]
        -- Math: (-100 + -100) - (100 + 100) = -200 - 200 = -400
        -- =====================================================================
        report "Test Case 3: Inverse Pattern Match -> Expecting -400 Output";

        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(-100, 8)); wait for CLK_PERIOD;
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(-100, 8)); wait for CLK_PERIOD;
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(100, 8)); wait for CLK_PERIOD;
        tb_fifo_ready <= '1'; tb_bpsk_sample <= std_logic_vector(to_signed(100, 8)); wait for CLK_PERIOD;
        
        tb_fifo_ready <= '0';
        wait for CLK_PERIOD;

        -- Check Result
        if to_integer(signed(tb_demod_sample)) = -400 then
            report "  [PASS] Output is -400.";
        else
            report "  [FAIL] Output is " & integer'image(to_integer(signed(tb_demod_sample))) & " (Expected -400)";
        end if;
        report "------------------------------------------------";

        -- End Simulation
        report "--- SIMULATION FINISHED SUCCESSFULY ---";
        assert false report "End of Simulation" severity failure;
        wait;
    end process;

end architecture behavior;