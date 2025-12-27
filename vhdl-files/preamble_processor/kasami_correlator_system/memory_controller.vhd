library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_controller is
    port (
        clk_50      : in  std_logic;
        sys_rst     : in  std_logic;
        demod_ready : in  std_logic; -- Trigger signal (Pulse)
        
        -- Outputs
        address_lut : out std_logic_vector(7 downto 0); -- To Kasami ROM
        score_done  : out std_logic;                    -- To Output Interface
        acc_enable  : out std_logic;                    -- To Correlator Engine
        w_address   : out std_logic_vector(7 downto 0); -- To RAM Port A
        r_address   : out std_logic_vector(7 downto 0)  -- To RAM Port B
    );
end entity memory_controller;

architecture rtl of memory_controller is

    -- 1. Counter 9b Signals (Loop Counter)
    signal loop_count : unsigned(8 downto 0);
    
    -- 2. Comparator Signals
    signal comp_flag : std_logic; -- 1 when loop_count < 255
    
    -- 3. DFF A Signals (Delay for acc_enable)
    signal dff_a_out : std_logic;

    -- 4. Edge Detection Logic
    signal score_trigger : std_logic;
    
    -- 6. Counter 8b Signals (Write Pointer)
    signal write_ptr : unsigned(7 downto 0);

    -- 7. Reg 8b Signals (Start Pointer Snapshot)
    signal start_ptr : unsigned(7 downto 0);

    -- 8, 9, 10. Adder and Modulo Signals
    signal sum_stage_a : unsigned(9 downto 0); -- 10 bits to hold sum
    signal sum_stage_b : unsigned(9 downto 0); -- 10 bits to hold +1
    signal read_calc   : unsigned(9 downto 0); -- Result before casting

begin

    -- =========================================================================
    -- 1. Counter 9b (Free Running Loop Counter)
    -- =========================================================================
    -- Resets if sys_rst is high OR if demod_ready is high.
    -- Otherwise, counts up freely on every clock cycle.
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' or demod_ready = '1' then
                loop_count <= (others => '0');
            else
                loop_count <= loop_count + 1;
            end if;
        end if;
    end process;

    -- Output Connection: Lower 8 bits go to LUT address
    address_lut <= std_logic_vector(loop_count(7 downto 0));

    -- =========================================================================
    -- 2. Comparator (a < 255)
    -- =========================================================================
    comp_flag <= '1' when (loop_count < 255) else '0';

    -- =========================================================================
    -- 3. DFF A (Pipeline Delay for acc_enable)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                dff_a_out <= '0';
            else
                dff_a_out <= comp_flag;
            end if;
        end if;
    end process;

    -- Output Connection: acc_enable comes from this delayed signal
    acc_enable <= dff_a_out;

    -- =========================================================================
    -- 4. Logic Gate (Falling Edge Detector for Window End)
    -- =========================================================================
    -- Detects when we just finished the valid loop (acc_enable is high, but new flag is low)
    score_trigger <= dff_a_out and (not comp_flag);

    -- =========================================================================
    -- 5. DFF B (Delay for score_done)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                score_done <= '0';
            else
                score_done <= score_trigger;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 6. Counter 8b (Write Pointer)
    -- =========================================================================
    -- Increments only when a new demodulated sample arrives (demod_ready)
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                write_ptr <= (others => '0');
            elsif demod_ready = '1' then
                write_ptr <= write_ptr + 1;
            end if;
        end if;
    end process;

    -- Output Connection: Write Address
    w_address <= std_logic_vector(write_ptr);

    -- =========================================================================
    -- 7. Reg 8b (Start Pointer Snapshot)
    -- =========================================================================
    -- Captures the current Write Pointer *at the moment* demod_ready fires.
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                start_ptr <= (others => '0');
            elsif demod_ready = '1' then
                start_ptr <= write_ptr;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 8, 9, 10. Address Calculation Datapath (Adders + Modulo)
    -- =========================================================================
    -- Formula: Read_Addr = (Start_Ptr + Loop_Count + 1) % 255
    
    -- Adder A: Start_Ptr + Loop_Count
    sum_stage_a <= resize(start_ptr, 10) + resize(loop_count, 10);
    
    -- Adder B: + 1
    sum_stage_b <= sum_stage_a + 1;
    
    -- Modulo 255 Block
    -- Since Max Sum = 254 (start) + 254 (loop) + 1 = 509.
    -- We can use the 'mod' operator. Synthesis is smart enough for this range.
    -- (Alternatively: if sum >= 255 then sum - 255)
    read_calc <= sum_stage_b mod 255;

    -- Output Connection: Read Address
    r_address <= std_logic_vector(read_calc(7 downto 0));

end architecture rtl;