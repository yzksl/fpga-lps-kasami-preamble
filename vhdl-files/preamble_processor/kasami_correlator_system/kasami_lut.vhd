library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kasami_lut is
    port (
        index  : in  std_logic_vector(7 downto 0); -- Address (0 to 255)
        code_a : out std_logic;                    -- Output bit for Sequence A
        code_b : out std_logic                     -- Output bit for Sequence B
    );
end entity kasami_lut;

architecture rtl of kasami_lut is

    -- =========================================================================
    -- KASAMI SEQUENCES (CONSTANTS)
    -- Length: 255 bits (Indices 0 to 254)
    -- =========================================================================
    
    constant SEQ_A : std_logic_vector(0 to 254) := 
        "100100001010011111010101011100000110001010110011001011111101111001101110111001010100101000100101101000110011100111100011011000010001011101011110110111110000110100110101101101010000010011101100100100110000001110100100011100010000000101100011110100001111111";

    constant SEQ_B : std_logic_vector(0 to 254) := 
        "011110111000010000000011001101111100111000111100011101101100000011011100110110000010111001011111011010111100110001110010100010100011010010001000100110001010000110111010111011000001101001011110101011100110011111011110101110011111010011110010001110111101110";

    -- Internal signal for easier integer comparison
    signal idx_int : integer range 0 to 255;

begin

    -- Convert std_logic_vector to integer for array indexing
    idx_int <= to_integer(unsigned(index));

    -- =========================================================================
    -- ROM Read Logic (With Bounds Check)
    -- =========================================================================
    -- If index is within range (0 to 254), read the bit.
    -- If index is 255 (or out of bounds), output '0' (Neutral for Adder).
    
    code_a <= SEQ_A(idx_int) when (idx_int < 255) else '0';
    code_b <= SEQ_B(idx_int) when (idx_int < 255) else '0';

end architecture rtl;