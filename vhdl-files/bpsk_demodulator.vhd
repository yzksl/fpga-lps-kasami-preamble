library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bpsk_demodulator is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Inputs from FIFO Buffer (Virtual ADC)
        fifo_ready      : in  std_logic;                     -- Enables the registers (New sample available)
        bpsk_sample     : in  std_logic_vector(7 downto 0);  -- Signed 8-bit input
        
        -- Outputs to Kasami Correlator
        demod_ready     : out std_logic;                     -- Data Valid Pulse
        demod_sample    : out std_logic_vector(11 downto 0)  -- Signed 12-bit output
    );
end entity bpsk_demodulator;

architecture rtl of bpsk_demodulator is

    -- 1. Shift Registers (Reg 0 to Reg 3)
    -- Using signed types for arithmetic ease
    signal reg_3 : signed(7 downto 0); -- Newest sample
    signal reg_2 : signed(7 downto 0);
    signal reg_1 : signed(7 downto 0);
    signal reg_0 : signed(7 downto 0); -- Oldest sample

    -- 2. Adder Stage Signals (10-bit to prevent overflow from 8-bit additions)
    signal sum_right : signed(9 downto 0); -- Output of Right Adder (Reg0 + Reg1)
    signal sum_left  : signed(9 downto 0); -- Output of Left Adder (Reg2 + Reg3)

    -- 3. Subtractor Stage Signal
    signal diff_val  : signed(10 downto 0); -- Result can be slightly larger

begin

    -- =========================================================================
    -- 1. Shift Register Chain (Reg 3 -> Reg 2 -> Reg 1 -> Reg 0)
    -- =========================================================================
    -- Implements the sliding window for M=4 oversampling.
    -- Only shifts when 'fifo_ready' is high (valid data from FIFO).
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_3 <= (others => '0');
                reg_2 <= (others => '0');
                reg_1 <= (others => '0');
                reg_0 <= (others => '0');
            elsif fifo_ready = '1' then
                -- Shift pipeline: Newest data enters Reg 3, oldest leaves Reg 0
                reg_3 <= signed(bpsk_sample);
                reg_2 <= reg_3;
                reg_1 <= reg_2;
                reg_0 <= reg_1;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 2. Arithmetic Datapath (Adders and Subtractor)
    -- =========================================================================
    -- As per diagram:
    -- Right Adder: Sums the two oldest samples (Reg 0, Reg 1)
    -- Left Adder:  Sums the two newest samples (Reg 2, Reg 3)
    -- Subtractor:  (Reg 0 + Reg 1) - (Reg 2 + Reg 3)
    
    -- Sign extension is handled automatically by resize function
    sum_right <= resize(reg_0, 10) + resize(reg_1, 10);
    sum_left  <= resize(reg_2, 10) + resize(reg_3, 10);
    
    -- Final Calculation: (a_in - b_in) from the diagram
    diff_val  <= resize(sum_right, 11) - resize(sum_left, 11);

    -- Output Assignment (Resizing 11-bit result to 12-bit output standard)
    demod_sample <= std_logic_vector(resize(diff_val, 12));

    -- =========================================================================
    -- 3. Control Logic (D Flip-Flop for Ready Signal)
    -- =========================================================================
    -- Delays the fifo_ready signal by 1 clock cycle to align with the 
    -- register update. This tells the next block "The data on demod_sample is valid now".
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
