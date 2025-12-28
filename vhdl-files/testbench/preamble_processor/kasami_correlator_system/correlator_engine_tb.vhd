library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity correlator_engine_tb is
    -- Testbench has no ports
end entity correlator_engine_tb;

architecture behavior of correlator_engine_tb is

    -- 1. Component Declaration (Matches correlator_engine.vhd)
    component correlator_engine is
        port (
            clk_50            : in  std_logic;
            sys_rst           : in  std_logic;
            acc_enable        : in  std_logic;
            demod_ready       : in  std_logic;
            code              : in  std_logic;
            demod_sample_18b  : in  signed(17 downto 0);
            score             : out signed(17 downto 0)
        );
    end component;

    -- 2. Test Signals
    signal tb_clk             : std_logic := '0';
    signal tb_sys_rst         : std_logic := '0';
    signal tb_acc_enable      : std_logic := '0';
    signal tb_demod_ready     : std_logic := '0';
    signal tb_code            : std_logic := '0';
    signal tb_demod_sample    : signed(17 downto 0) := (others => '0');
    signal tb_score           : signed(17 downto 0);

    -- Clock Period Constant (50 MHz = 20 ns)
    constant CLK_PERIOD : time := 20 ns;

begin

    -- 3. Instantiate the Device Under Test (DUT)
    uut: correlator_engine
        port map (
            clk_50           => tb_clk,
            sys_rst          => tb_sys_rst,
            acc_enable       => tb_acc_enable,
            demod_ready      => tb_demod_ready,
            code             => tb_code,
            demod_sample_18b => tb_demod_sample,
            score            => tb_score
        );

    -- 4. Clock Generation Process
    clk_process : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD/2;
        tb_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 5. Stimulus Process
    stim_proc: process
    begin
        -- =====================================================================
        -- INITIALIZATION & RESET
        -- =====================================================================
        report "--- STARTING SIMULATION ---";
        
        tb_sys_rst <= '1';
        tb_acc_enable <= '0';
        wait for 50 ns;
        tb_sys_rst <= '0';
        
        -- Sync to falling edge for clean driving
        wait until falling_edge(tb_clk);

        -- =====================================================================
        -- TEST CASE 1: BASIC ACCUMULATION (POSITIVE CODE)
        -- Goal: Add +100 to the accumulator.
        -- Logic: 
        --   Cycle 1: Drive Code='1' (Because of internal delay DFF)
        --   Cycle 2: Drive Sample=100. (The MUX aligns Code from Cyc1 with Sample from Cyc2)
        -- =====================================================================
        report "Test Case 1: Add +100 (Code = '1')";
        
        -- Step 1: Set Code (Address Phase)
        tb_code <= '1';       -- Corresponds to +1 multiplier
        tb_acc_enable <= '1'; -- Turn on engine
        wait for CLK_PERIOD;

        -- Step 2: Set Data (Data Phase)
        tb_code <= '0';       -- Clear code (for next cycle testing)
        tb_demod_sample <= to_signed(100, 18);
        wait for CLK_PERIOD;

        -- Step 3: Idle / Observe
        tb_demod_sample <= (others => '0');
        wait for CLK_PERIOD;

        -- Check Result
        if to_integer(tb_score) = 100 then
            report "  [PASS] Score is 100.";
        else
            report "  [FAIL] Score is " & integer'image(to_integer(tb_score)) & " (Expected 100)";
        end if;
        report "------------------------------------------------";

        -- =====================================================================
        -- TEST CASE 2: SUBTRACTION (NEGATIVE CODE)
        -- Goal: Subtract 50 from current total (100). Result should be 50.
        -- Logic: Code='0' implies multiplier is -1.
        -- =====================================================================
        report "Test Case 2: Subtract 50 (Code = '0')";

        -- Step 1: Set Code '0' (Address Phase)
        tb_code <= '0'; 
        wait for CLK_PERIOD;

        -- Step 2: Set Data 50 (Data Phase)
        tb_code <= '0'; -- dummy
        tb_demod_sample <= to_signed(50, 18);
        wait for CLK_PERIOD;

        -- Step 3: Idle
        tb_demod_sample <= (others => '0');
        wait for CLK_PERIOD;

        -- Check Result: 100 + (-50) = 50
        if to_integer(tb_score) = 50 then
            report "  [PASS] Score is 50.";
        else
            report "  [FAIL] Score is " & integer'image(to_integer(tb_score)) & " (Expected 50)";
        end if;
        report "------------------------------------------------";

        -- =====================================================================
        -- TEST CASE 3: RESET ON DEMOD_READY
        -- Goal: Ensure the accumulator clears when a new pulse arrives.
        -- =====================================================================
        report "Test Case 3: Accumulator Reset";

        -- Pulse demod_ready
        tb_demod_ready <= '1';
        wait for CLK_PERIOD;
        tb_demod_ready <= '0';
        wait for CLK_PERIOD;

        -- Check Result
        if to_integer(tb_score) = 0 then
            report "  [PASS] Score cleared to 0.";
        else
            report "  [FAIL] Score is " & integer'image(to_integer(tb_score)) & " (Expected 0)";
        end if;
        report "------------------------------------------------";

        -- =====================================================================
        -- TEST CASE 4: PIPELINED SEQUENCE
        -- Goal: Process a stream: (+1 * 10) + (-1 * 20) + (+1 * 5) = 10 - 20 + 5 = -5
        -- =====================================================================
        report "Test Case 4: Pipeline Stream (10, -20, 5) -> Expecting -5";
        
        -- Reset first just in case
        tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';

        -- Sequence:
        -- T1: Drive Code(+1)  | Data(Don't Care)
        -- T2: Drive Code(-1)  | Data(10)  -> Processing (+1 * 10)
        -- T3: Drive Code(+1)  | Data(20)  -> Processing (-1 * 20)
        -- T4: Drive Code(x)   | Data(5)   -> Processing (+1 * 5)

        tb_acc_enable <= '1';

        -- T1
        tb_code <= '1'; 
        wait for CLK_PERIOD;

        -- T2
        tb_code <= '0'; 
        tb_demod_sample <= to_signed(10, 18);
        wait for CLK_PERIOD;

        -- T3
        tb_code <= '1';
        tb_demod_sample <= to_signed(20, 18);
        wait for CLK_PERIOD;

        -- T4
        tb_code <= '0'; -- Don't care
        tb_demod_sample <= to_signed(5, 18);
        wait for CLK_PERIOD;

        -- T5 (Drain Pipeline)
        tb_demod_sample <= (others => '0');
        wait for 2 * CLK_PERIOD;

        -- Check Result
        if to_integer(tb_score) = -5 then
            report "  [PASS] Final Score is -5.";
        else
            report "  [FAIL] Final Score is " & integer'image(to_integer(tb_score)) & " (Expected -5)";
        end if;
        report "------------------------------------------------";

        -- End Simulation
        report "--- SIMULATION FINISHED ---";
        assert false report "End of Simulation" severity failure;
        wait;
    end process;

end architecture behavior;