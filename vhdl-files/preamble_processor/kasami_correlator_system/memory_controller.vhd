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
        w_address   : out std_logic_vector(9 downto 0); -- To RAM Port A  (10-bit now)
        r_address   : out std_logic_vector(9 downto 0)  -- To RAM Port B  (10-bit now)
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
    
    -- 6. Counter (Write Pointer) now 10-bit
    signal write_ptr : unsigned(9 downto 0);

    -- 7. Reg (Start Pointer Snapshot) now 10-bit
    signal start_ptr : unsigned(9 downto 0);

    -- 8, 9, 10. Address Calculation Datapath (Now 10-bit domain)
    signal shifted_loop : unsigned(9 downto 0);
    signal sum_stage_a  : unsigned(9 downto 0);
    signal sum_stage_b  : unsigned(9 downto 0);
    signal read_calc    : unsigned(9 downto 0);

    -- To stop score_done from sending when uploading
    signal processing_active : std_logic := '0';
begin

    -- =========================================================================
    -- 1. Counter 9b (Free Running Loop Counter)
    -- =========================================================================
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

    address_lut <= std_logic_vector(loop_count(7 downto 0));

    -- =========================================================================
    -- NEW LOGIC: BUSY FLAG
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                processing_active <= '0';
            elsif demod_ready = '1' then
                processing_active <= '1'; -- Start processing
            elsif loop_count = 255 then   -- End of valid window
                processing_active <= '0'; -- Stop processing
            end if;
        end if;
    end process;

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

    acc_enable <= dff_a_out;

    -- =========================================================================
    -- 4. Logic Gate (End Detection)
    -- =========================================================================
    score_trigger <= dff_a_out and (not comp_flag);

    -- =========================================================================
    -- 5. DFF B (score_done)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                score_done <= '0';
            else
                -- GATE THE OUTPUT: Only fire if we are actively processing a sample.
                -- If processing_active is '0' (because loop_count > 255), this forces 
                -- score_done to '0', preventing the FIFO overflow.
                score_done <= score_trigger and processing_active;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 6. Counter (Write Pointer) 10-bit now
    -- =========================================================================
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

    w_address <= std_logic_vector(write_ptr);

    -- =========================================================================
    -- 7. Reg (Start Pointer Snapshot) 10-bit now
    -- =========================================================================
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
    -- 8, 9, 10. Address Calculation (M = 4, Buffer = 1024)
    -- =========================================================================
    -- Read_Addr = (Start_Ptr + 1 + (Loop_Count << 2)) mod 1024

    shifted_loop <= resize(loop_count, 10) sll 2;  -- loop * 4
    sum_stage_a  <= start_ptr + shifted_loop;     -- Start + loop*4
    sum_stage_b  <= sum_stage_a + 1;              -- +1 offset
    read_calc    <= sum_stage_b;                  -- natural 10-bit wrap

    r_address <= std_logic_vector(read_calc);

end architecture rtl;
