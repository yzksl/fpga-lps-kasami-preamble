library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seven_seg_scanner is
    port (
        clk           : in  std_logic;
        -- Inputs: The 7-bit segment patterns for each digit (a..g)
        in_thous      : in  std_logic_vector(6 downto 0);
        in_hunds      : in  std_logic_vector(6 downto 0);
        in_tens       : in  std_logic_vector(6 downto 0);
        in_ones       : in  std_logic_vector(6 downto 0);
        
        -- Outputs: The physical pins on your board
        seg_data_out  : out std_logic_vector(7 downto 0); -- SEG0-SEG7
        dig_sel_out   : out std_logic_vector(3 downto 0)  -- DIG1-DIG4
    );
end entity seven_seg_scanner;

architecture behavioral of seven_seg_scanner is
    -- 50MHz / 50000 = 1kHz scanning frequency
    constant SCAN_LIMIT : integer := 50000; 
    signal scan_ctr     : integer range 0 to SCAN_LIMIT := 0;
    signal digit_idx    : unsigned(1 downto 0) := "00";
    
    signal current_seg  : std_logic_vector(6 downto 0);
begin

    -- 1. Scanning Timer & Counter
    process(clk)
    begin
        if rising_edge(clk) then
            if scan_ctr = SCAN_LIMIT then
                scan_ctr <= 0;
                digit_idx <= digit_idx + 1; -- Move to next digit
            else
                scan_ctr <= scan_ctr + 1;
            end if;
        end if;
    end process;

    -- 2. Multiplexer: Select which data to show based on digit_idx
    process(digit_idx, in_thous, in_hunds, in_tens, in_ones)
    begin
        case digit_idx is
            when "00" => current_seg <= in_thous; -- Leftmost
            when "01" => current_seg <= in_hunds;
            when "10" => current_seg <= in_tens;
            when "11" => current_seg <= in_ones;  -- Rightmost
            when others => current_seg <= (others => '1'); -- Off
        end case;
    end process;

    -- 3. Physical Output Drive
    -- Most FPGA boards are Active LOW for Segments and Active LOW for Digit Select
    -- SEG0..SEG6 = a..g, SEG7 = dot
    seg_data_out(6 downto 0) <= current_seg; 
    seg_data_out(7)          <= '1';         -- DP always off (Active Low)

    process(digit_idx)
    begin
        -- Activate one digit at a time (Active LOW assumption: 0 = ON)
        case digit_idx is
            when "00" => dig_sel_out <= "0111"; -- DIG1 ON
            when "01" => dig_sel_out <= "1011"; -- DIG2 ON
            when "10" => dig_sel_out <= "1101"; -- DIG3 ON
            when "11" => dig_sel_out <= "1110"; -- DIG4 ON
            when others => dig_sel_out <= "1111";
        end case;
    end process;

end architecture behavioral;