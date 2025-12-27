library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bpsk_demodulator is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Inputs from FIFO Buffer (Virtual ADC)
        fifo_ready      : in  std_logic;                    -- Enables the registers
        bpsk_sample     : in  std_logic_vector(7 downto 0); -- Signed 8-bit input
        
        -- Outputs to Kasami Correlator
        demod_ready     : out std_logic;                    -- Data Valid Pulse
        demod_sample    : out std_logic_vector(9 downto 0)  -- Signed 10-bit output
    );
end entity bpsk_demodulator;

architecture rtl of bpsk_demodulator is

    -- 1. Shift Registers (Reg 0 to Reg 3)
    signal reg_3 : signed(7 downto 0); 
    signal reg_2 : signed(7 downto 0);
    signal reg_1 : signed(7 downto 0);
    signal reg_0 : signed(7 downto 0); 

    -- 2. Adder Stage Signals (10-bit)
    -- We resize inputs to 10-bit to avoid overflow during addition.
    signal sum_right : signed(9 downto 0); -- (Reg0 + Reg1)
    signal sum_left  : signed(9 downto 0); -- (Reg2 + Reg3)

    -- 3. Subtractor Stage Signal (10-bit)
    -- Max possible result is 510, which fits in 10-bit signed (-512 to +511).
    signal diff_val  : signed(9 downto 0); 

begin

    -- =========================================================================
    -- 1. Shift Register Chain (Sliding Window M=4)
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_3 <= (others => '0');
                reg_2 <= (others => '0');
                reg_1 <= (others => '0');
                reg_0 <= (others => '0');
            elsif fifo_ready = '1' then
                reg_3 <= signed(bpsk_sample);
                reg_2 <= reg_3;
                reg_1 <= reg_2;
                reg_0 <= reg_1;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 2. Arithmetic Datapath
    -- =========================================================================
    
    -- Step A: Additions
    -- Resize 8-bit regs to 10-bit to safely add them.
    sum_right <= resize(reg_0, 10) + resize(reg_1, 10);
    sum_left  <= resize(reg_2, 10) + resize(reg_3, 10);
    
    -- Step B: Subtraction (Direct 10-bit)
    -- Since max value is 510, it will not overflow 10-bit signed logic.
    diff_val <= sum_right - sum_left;

    -- Output Assignment
    demod_sample <= std_logic_vector(diff_val);

    -- =========================================================================
    -- 3. Control Logic
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                demod_ready <= '0';
            else
                demod_ready <= fifo_ready;
            end if;
        end if;
    end process;

end architecture rtl;