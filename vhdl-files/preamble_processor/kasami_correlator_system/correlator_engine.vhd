library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity correlator_engine is
    port (
        clk_50            : in  std_logic;
        sys_rst           : in  std_logic;
        acc_enable        : in  std_logic; -- Enables the accumulator register
        demod_ready       : in  std_logic; -- Resets the accumulator for next run
        code              : in  std_logic; -- Kasami Code bit (1=+1, 0=-1)
        demod_sample_18b  : in  signed(17 downto 0); -- Input Sample
        
        score             : out signed(17 downto 0)  -- Final Correlation Score
    );
end entity correlator_engine;

architecture rtl of correlator_engine is

    -- 1. DFF Signals (Code Alignment)
    signal code_delayed : std_logic;

    -- 2. 2's Complement / Inverter Signals
    signal sample_neg   : signed(17 downto 0);

    -- 3. Mux Signals
    signal mux_out      : signed(17 downto 0);

    -- 4. Adder Signals
    signal sum_result   : signed(17 downto 0);

    -- 5. Score Register Signals
    signal score_reg    : signed(17 downto 0);

begin

    -- =========================================================================
    -- 1. DFF (Code Alignment)
    -- =========================================================================
    -- Delays the Kasami code bit by 1 cycle to align with the data arriving
    -- from RAM (which has 1 cycle read latency).
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                code_delayed <= '0';
            else
                code_delayed <= code;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 2. 2's Complement Logic (Negator)
    -- =========================================================================
    -- Calculates the negative value of the input sample.
    -- Equivalent to multiplying by -1.
    sample_neg <= -demod_sample_18b;

    -- =========================================================================
    -- 3. Multiplexer (Correlation Logic)
    -- =========================================================================
    -- Logic: Demod_Sample * Code
    -- If Code is '1' (+1), pass the normal sample.
    -- If Code is '0' (-1), pass the negated sample.
    mux_out <= demod_sample_18b when code_delayed = '1' else sample_neg;

    -- =========================================================================
    -- 4. Adder 18b (Accumulation Math)
    -- =========================================================================
    -- Adds the current calculated term (mux_out) to the running total (score_reg).
    sum_result <= score_reg + mux_out;

    -- =========================================================================
    -- 5. Score Register 18b (Accumulator)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            -- Reset Logic: Clears on System Reset OR when a new Demod pulse arrives.
            -- This ensures the accumulator is fresh for the new sweep.
            if sys_rst = '1' or demod_ready = '1' then
                score_reg <= (others => '0');
            
            -- Enable Logic: Only updates when valid correlation data is present.
            elsif acc_enable = '1' then
                score_reg <= sum_result;
            end if;
        end if;
    end process;

    -- Output Connection
    score <= score_reg;

end architecture rtl;