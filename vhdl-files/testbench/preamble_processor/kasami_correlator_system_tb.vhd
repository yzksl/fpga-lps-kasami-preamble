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

    -- Helper Function
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

    -- Clock Gen
    process begin
        tb_clk <= '0'; wait for CLK_PERIOD/2;
        tb_clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- =========================================================================
    -- MAIN STIMULUS
    -- =========================================================================
    process
        variable v_val_a, v_val_b, v_total, idx_b : integer;
    begin
        
        -- =====================================================================
        -- CASE 1: SEPARATED (A then B)
        -- =====================================================================
        report "--- CASE 1 STARTING: SEPARATED ---";
        -- RESET THE SYSTEM BEFORE CASE 1
        tb_rst <= '1'; wait for 100 ns; tb_rst <= '0'; wait for 100 ns;
        wait until falling_edge(tb_clk);

        -- Send Sequence A
        for repeat in 1 to 2 loop
            for i in 0 to 254 loop
                v_total := get_val(SEQ_A_REF(i));
                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;

        -- Small gap
        tb_demod_sample <= (others => '0');
        for i in 1 to 50 loop 
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- Send Sequence B
        for repeat in 1 to 2 loop
            for i in 0 to 254 loop
                v_total := get_val(SEQ_B_REF(i));
                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;
        
        -- Wait a moment to see the result
        wait for 500 ns;

        -- =====================================================================
        -- CLEANING BUFFER (Prevents "Ghost" Detections in Next Case)
        -- =====================================================================
        report "--- CLEANING BUFFER BEFORE CASE 2 ---";
        tb_demod_sample <= (others => '0');
        -- Send 1100 zeros to fully flush the 1024-deep RAM
        for i in 1 to 1100 loop 
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- =====================================================================
        -- CASE 2: OVERLAPPING (B starts halfway through A)
        -- =====================================================================
        report "--- CASE 2 STARTING: OVERLAPPING ---";
        -- RESET THE SYSTEM BEFORE CASE 2 (Clears Time A and Time B to 0)
        tb_rst <= '1'; wait for 100 ns; tb_rst <= '0'; wait for 100 ns;
        wait until falling_edge(tb_clk);

        for repeat in 1 to 2 loop
            for i in 0 to 382 loop
                v_val_a := 0; v_val_b := 0;
                -- Logic for Overlapping
                if i <= 254 then v_val_a := get_val(SEQ_A_REF(i)); end if;
                idx_b := i - 128;
                if idx_b >= 0 and idx_b <= 254 then v_val_b := get_val(SEQ_B_REF(idx_b)); end if;
                v_total := v_val_a + v_val_b;

                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;

        -- Wait a moment to see the result
        wait for 500 ns;

        -- =====================================================================
        -- CLEANING BUFFER (Prevents "Ghost" Detections in Next Case)
        -- =====================================================================
        report "--- CLEANING BUFFER BEFORE CASE 3 ---";
        tb_demod_sample <= (others => '0');
        for i in 1 to 1100 loop 
            tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
            wait until tb_score_done = '1'; wait for CLK_PERIOD;
        end loop;

        -- =====================================================================
        -- CASE 3: SIMULTANEOUS (A + B Combined)
        -- =====================================================================
        report "--- CASE 3 STARTING: SIMULTANEOUS ---";
        -- RESET THE SYSTEM BEFORE CASE 3 (Clears Time A and Time B to 0)
        tb_rst <= '1'; wait for 100 ns; tb_rst <= '0'; wait for 100 ns;
        wait until falling_edge(tb_clk);

        for repeat in 1 to 2 loop
            for i in 0 to 254 loop
                v_val_a := get_val(SEQ_A_REF(i));
                v_val_b := get_val(SEQ_B_REF(i));
                v_total := v_val_a + v_val_b;

                for k in 1 to 4 loop
                    tb_demod_sample <= std_logic_vector(to_signed(v_total, 10));
                    tb_demod_ready <= '1'; wait for CLK_PERIOD; tb_demod_ready <= '0';
                    wait until tb_score_done = '1'; wait for CLK_PERIOD;
                end loop;
            end loop;
        end loop;

        -- Final verification
        wait for 200 ns;
        report "--- SIMULATION FINISHED ---";
        wait;
    end process;

end architecture behavior;