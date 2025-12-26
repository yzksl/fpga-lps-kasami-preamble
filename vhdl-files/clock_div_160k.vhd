library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_div_160k is
    port (
        clk_50    : in  std_logic; -- 50 MHz System Clock
        sys_rst   : in  std_logic; -- Synchronous System Reset
        proc_en   : in  std_logic; -- Enable signal from FSM
        tick_160k : out std_logic  -- Output Pulse (1 cycle wide)
    );
end entity clock_div_160k;

architecture rtl of clock_div_160k is

    -- Internal Signals (Mapping to Diagram Wires)
    signal count      : unsigned(8 downto 0); -- 9-bit Counter output
    signal toggle_reg : std_logic;            -- T-Flip-Flop output (selects 311/312)
    signal mux_out    : unsigned(8 downto 0); -- Output of Mux (Threshold value)
    signal flag       : std_logic;            -- Output of Comparator (a == b)

begin

    -- =========================================================================
    -- 1. Multiplexer (Combinational)
    -- =========================================================================
    -- Selects the threshold based on the T-Flip-Flop state.
    -- sel = 0 -> 311 (yields 312 cycles)
    -- sel = 1 -> 312 (yields 313 cycles)
    -- Average = 312.5 cycles * 20ns = 6.25us = 160 kHz
    mux_out <= to_unsigned(312, 9) when toggle_reg = '1' else 
               to_unsigned(311, 9);

    -- =========================================================================
    -- 2. Comparator (Combinational)
    -- =========================================================================
    -- Compares the current Counter value (a) against Mux Output (b).
    -- Flag goes high for exactly 1 clock cycle when the limit is reached.
    flag <= '1' when (count = mux_out) else '0';

    -- Output Assignment: The internal flag drives the external tick directly.
    tick_160k <= flag;

    -- =========================================================================
    -- 3. Synchronous Process (Counter + T-Flip-Flop Logic)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            -- Global Synchronous Reset (sys_rst)
            if sys_rst = '1' then
                count      <= (others => '0');
                toggle_reg <= '0';
            else
                -- T-Flip-Flop Logic
                -- Toggles strictly when the comparator flag is high
                if flag = '1' then
                    toggle_reg <= not toggle_reg;
                end if;

                -- Counter Logic (with OR Gate Reset Logic)
                -- Resets if Comparator Flag is High (Auto-Reset) OR sys_rst (handled above)
                if flag = '1' then
                    count <= (others => '0');
                elsif proc_en = '1' then
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;