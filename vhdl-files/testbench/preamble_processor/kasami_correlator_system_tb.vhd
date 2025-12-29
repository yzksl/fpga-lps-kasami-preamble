library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity kasami_correlator_system_tb is
end entity kasami_correlator_system_tb;

architecture behavior of kasami_correlator_system_tb is

    -- DUT Component
    component kasami_correlator_system is
        port (
            clk_50        : in  std_logic;
            sys_rst       : in  std_logic;
            demod_ready   : in  std_logic;
            demod_sample  : in  std_logic_vector(9 downto 0);
            time_a        : out std_logic_vector(12 downto 0);
            time_b        : out std_logic_vector(12 downto 0);
            found_a       : out std_logic;
            found_b       : out std_logic;
            score_a       : out signed(17 downto 0);
            score_b       : out signed(17 downto 0);
            score_done    : out std_logic
        );
    end component;

    -- Sequence Definitions
    constant SEQ_A_REF : std_logic_vector(0 to 254) := 
        "100100001010011111010101011100000110001010110011001011111101111001101110111001010100101000100101101000110011100111100011011000010001011101011110110111110000110100110101101101010000010011101100100100110000001110100100011100010000000101100011110100001111111";

    constant SEQ_B_REF : std_logic_vector(0 to 254) := 
        "011110111000010000000011001101111100111000111100011101101100000011011100110110000010111001011111011010111100110001110010100010100011010010001000100110001010000110111010111011000001101001011110101011100110011111011110101110011111010011110010001110111101110";

    -- Signals
    signal tb_clk          : std_logic := '0';
    signal tb_rst          : std_logic := '0';
    signal tb_demod_ready  : std_logic := '0';
    signal tb_demod_sample : std_logic_vector(9 downto 0) := (others => '0');
    
    signal tb_time_a, tb_time_b : std_logic_vector(12 downto 0);
    signal tb_found_a, tb_found_b, tb_score_done : std_logic;
    signal tb_score_a, tb_score_b : signed(17 downto 0);

    constant CLK_PERIOD : time := 20 ns;

    -- Helper Function to convert '1'/'0' to +100/-100
    function get_val(bit_in : std_logic) return integer is
    begin
        if bit_in = '1' then return 100; else return -100; end if;
    end function;

begin

    uut: kasami_correlator_system port map (
        clk_50 => tb_clk, sys_rst => tb_rst, demod_ready => tb_demod_ready, demod_sample => tb_demod_sample,
        time_a => tb_time_a, time_b => tb_time_b, found_a => tb_found_a, found_b => tb_found_b,
        score_a => tb_score_a, score_b => tb_score_b, score_done => tb_score_done
    );

    process begin
        tb_clk <= '0'; wait for CLK_PERIOD/2;
        tb_clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- =========================================================================
    -- MAIN STIMULUS
    -- =========================================================================
    process
        variable v_val_a : integer;
        variable v_val_b : integer;
        variable v_total : integer;
        variable idx_b   : integer;
    begin
        -- RESET
        tb_rst <= '1'; wait for 100 ns; tb_rst <= '0'; wait for 100 ns;
        wait until falling_edge(tb_clk);

        -- =====================================================================
        -- CASE 1: ENTIRELY SEPARATED (A first, then gap, then B)
        -- =====================================================================
        report "---------------------------------------------";
        report "CASE 1: SEPARATED (Sequence A, Gap, Sequence B)";
        report "---------------------------------------------";

        -- 1.1 Send Sequence A
        for repeat in 1 to 2 loop -- Repeat twice to fill circular buffer
            for i in 0 to 254 loop
                v_total := get_val(SEQ_A_REF(i)); -- Only A contributes
                
                -- Drive M=4
                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;

        if tb_found_a = '1' then report " [PASS] Case 1: A Found."; else report " [FAIL] Case 1: A Missing."; end if;

        -- 1.2 Gap
        tb_demod_sample <= (others => '0');
        for i in 1 to 20 loop 
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- 1.3 Send Sequence B
        for repeat in 1 to 2 loop 
            for i in 0 to 254 loop
                v_total := get_val(SEQ_B_REF(i)); -- Only B contributes
                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;

        if tb_found_b = '1' then report " [PASS] Case 1: B Found."; else report " [FAIL] Case 1: B Missing."; end if;

        -- Gap before next case
        tb_demod_sample <= (others => '0');
        for i in 1 to 1100 loop -- Clear Buffer completely
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- =====================================================================
        -- CASE 2: HALF SEPARATED / OVERLAPPING
        -- A starts. 128 symbols later, B starts. They will overlap in the middle.
        -- =====================================================================
        report "---------------------------------------------";
        report "CASE 2: OVERLAPPING (B starts halfway through A)";
        report "---------------------------------------------";

        -- Total Length = 255 (A) + 128 (Offset) = 383 symbols
        -- Sequence A is valid from 0 to 254
        -- Sequence B is valid from 128 to 382 (relative to start)

        for i in 0 to 382 loop
            v_val_a := 0;
            v_val_b := 0;

            -- Calculate A contribution
            if i <= 254 then
                v_val_a := get_val(SEQ_A_REF(i));
            end if;

            -- Calculate B contribution (Delayed by 128)
            idx_b := i - 128;
            if idx_b >= 0 and idx_b <= 254 then
                v_val_b := get_val(SEQ_B_REF(idx_b));
            end if;

            v_total := v_val_a + v_val_b; -- SUM THE SIGNALS (Interference!)

            -- Drive M=4
            for k in 1 to 4 loop
                tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                wait until tb_score_done = '1'; wait for CLK_PERIOD;
            end loop;
        end loop;

        -- Verification
        -- Note: Due to overlap, scores might be slightly noisy, but strong enough to trigger.
        if tb_found_a = '1' then report " [PASS] Case 2: A Found despite overlap."; else report " [FAIL] Case 2: A lost in noise."; end if;
        if tb_found_b = '1' then report " [PASS] Case 2: B Found despite overlap."; else report " [FAIL] Case 2: B lost in noise."; end if;
        
        -- Check Timestamps difference
        if unsigned(tb_time_b) > unsigned(tb_time_a) then
             report " [PASS] Case 2: Time B > Time A (Correct Order).";
        end if;

        -- Clear Buffer
        tb_demod_sample <= (others => '0');
        for i in 1 to 1100 loop 
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- =====================================================================
        -- CASE 3: NOT SEPARATED AT ALL (SIMULTANEOUS)
        -- A and B are added together perfectly aligned.
        -- =====================================================================
        report "---------------------------------------------";
        report "CASE 3: SIMULTANEOUS (A + B Combined)";
        report "---------------------------------------------";

        for i in 0 to 254 loop
            v_val_a := get_val(SEQ_A_REF(i));
            v_val_b := get_val(SEQ_B_REF(i));
            
            v_total := v_val_a + v_val_b; -- Perfect overlap sum

            for k in 1 to 4 loop
                tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                wait until tb_score_done = '1'; wait for CLK_PERIOD;
            end loop;
        end loop;

        wait for CLK_PERIOD;
        
        -- Both flags should go HIGH at roughly the same time
        if tb_found_a = '1' and tb_found_b = '1' then 
            report " [PASS] Case 3: Both A and B found simultaneously!";
        else 
            report " [FAIL] Case 3: One or both sequences missing."; 
        end if;

        -- Check if timestamps are identical (or very close)
        if tb_time_a = tb_time_b then
            report " [PASS] Case 3: Timestamps are identical.";
        else
            report " [INFO] Case 3: Timestamps differ slightly (acceptable due to processing latency).";
        end if;

        report "--- SIMULATION FINISHED ---";
        wait;
    end process;

end architecture behavior;