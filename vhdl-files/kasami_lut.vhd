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
        "1010101010101010101010101010101010101010101010101010101010101010" &
        "1010101010101010101010101010101010101010101010101010101010101010" &
        "1010101010101010101010101010101010101010101010101010101010101010" &
        "101010101010101010101010101010101010101010101010101010101010101";

    constant SEQ_B : std_logic_vector(0 to 254) := 
        "1111111111111111111111111111111111111111111111111111111111111111" &
        "1111111111111111111111111111111111111111111111111111111111111111" &
        "1111111111111111111111111111111111111111111111111111111111111111" &
        "111111111111111111111111111111111111111111111111111111111111111";

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