library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_controller is
    port (
        clk_50      : in  std_logic; -- System Clock (used for synchronous logic if needed)
        rst         : in  std_logic; -- System Reset

        -- Inputs from Kasami Correlator System
        time_a      : in  std_logic_vector(12 downto 0); -- 13-bit Score/Time A
        time_b      : in  std_logic_vector(12 downto 0); -- 13-bit Score/Time B
        found_a     : in  std_logic;                     -- Signal if A was found
        found_b     : in  std_logic;                     -- Signal if B was found
        
        -- Control Input (Switch)
        sw_disp     : in  std_logic; -- Selects between displaying A (0) or B (1)

        -- Outputs to Physical Interface
        hex_thous   : out std_logic_vector(6 downto 0); -- 7-Segment Thousands
        hex_hunds   : out std_logic_vector(6 downto 0); -- 7-Segment Hundreds
        hex_tens    : out std_logic_vector(6 downto 0); -- 7-Segment Tens
        hex_ones    : out std_logic_vector(6 downto 0); -- 7-Segment Ones
        
        led_a       : out std_logic; -- LED Indicator for Found A
        led_b       : out std_logic  -- LED Indicator for Found B
    );
end entity display_controller;

architecture rtl of display_controller is

    -- 1. Multiplexer Signals
    signal mux_out : unsigned(12 downto 0);

    -- 2. Binary to BCD Intermediate Signals
    -- Integers are easier for division/modulo operations in VHDL
    signal int_val      : integer range 0 to 8191;
    signal digit_thous  : integer range 0 to 9;
    signal digit_hunds  : integer range 0 to 9;
    signal digit_tens   : integer range 0 to 9;
    signal digit_ones   : integer range 0 to 9;

    -- Helper function for BCD to 7-Segment Decoding
    -- Assumes Active LOW segments (0 = ON), common on DE1/DE2/DE10 boards.
    -- Map: "gfedcba"
    function to_seven_seg(digit : integer) return std_logic_vector is
    begin
        case digit is
            when 0 => return "1000000"; -- 0
            when 1 => return "1111001"; -- 1
            when 2 => return "0100100"; -- 2
            when 3 => return "0110000"; -- 3
            when 4 => return "0011001"; -- 4
            when 5 => return "0010010"; -- 5
            when 6 => return "0000010"; -- 6
            when 7 => return "1111000"; -- 7
            when 8 => return "0000000"; -- 8
            when 9 => return "0010000"; -- 9
            when others => return "1111111"; -- Off/Error
        end case;
    end function;

begin

    -- =========================================================================
    -- 1. Input Multiplexer
    -- =========================================================================
    -- Selects between time_a and time_b based on sw_disp input.
    -- Corresponds to the MUX symbol in the diagram.
    process(sw_disp, time_a, time_b)
    begin
        if sw_disp = '0' then
            mux_out <= unsigned(time_a);
        else
            mux_out <= unsigned(time_b);
        end if;
    end process;

    -- =========================================================================
    -- 2. 13-bit Binary to 4-Digit BCD Converter
    -- =========================================================================
    -- This block converts the 13-bit binary number into separate decimal digits.
    -- Logic: using / and mod operators (Behavioral).
    
    int_val <= to_integer(mux_out);

    process(int_val)
    begin
        -- Extract Thousands
        digit_thous <= int_val / 1000;
        
        -- Extract Hundreds: (Value / 100) % 10
        digit_hunds <= (int_val / 100) mod 10;
        
        -- Extract Tens: (Value / 10) % 10
        digit_tens  <= (int_val / 10) mod 10;
        
        -- Extract Ones: Value % 10
        digit_ones  <= int_val mod 10;
    end process;

    -- =========================================================================
    -- 3. BCD to 7-Segment Decoders
    -- =========================================================================
    -- Instantiates the logic for the 4 separate blocks shown in the diagram:
    -- BCD_3, BCD_2, BCD_1, BCD_0 to 7 Segment.
    
    process(digit_thous, digit_hunds, digit_tens, digit_ones)
    begin
        hex_thous <= to_seven_seg(digit_thous);
        hex_hunds <= to_seven_seg(digit_hunds);
        hex_tens  <= to_seven_seg(digit_tens);
        hex_ones  <= to_seven_seg(digit_ones);
    end process;

    -- =========================================================================
    -- 4. LED Output Passthrough
    -- =========================================================================
    -- As requested, mapping the found signals from Top-Level to the LEDs.
    -- This allows the user to see which signal has been detected regardless
    -- of what is currently shown on the 7-segment display.
    
    led_a <= found_a;
    led_b <= found_b;

end architecture rtl;
