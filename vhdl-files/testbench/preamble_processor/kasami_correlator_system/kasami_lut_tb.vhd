library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;             -- Standard library for console printing
use ieee.std_logic_textio.all;  -- Library for printing std_logic vectors

entity kasami_lut_tb is
    -- Testbench entity is always empty
end entity kasami_lut_tb;

architecture behavior of kasami_lut_tb is

    -- 1. Component Declaration (Matches your Code exactly)
    component kasami_lut is
        port (
            index  : in  std_logic_vector(7 downto 0); -- Address (0 to 255)
            code_a : out std_logic;                    -- Output bit for Sequence A
            code_b : out std_logic                     -- Output bit for Sequence B
        );
    end component;

    -- 2. Testbench Signals
    signal tb_index  : std_logic_vector(7 downto 0) := (others => '0');
    signal tb_code_a : std_logic;
    signal tb_code_b : std_logic;

    -- Simulation Delay
    constant WAIT_TIME : time := 10 ns;

begin

    -- 3. Instantiate the Unit Under Test (UUT)
    uut: kasami_lut
        port map (
            index  => tb_index,
            code_a => tb_code_a,
            code_b => tb_code_b
        );

    -- 4. Stimulus Process
    stim_proc: process
        variable out_line : line;
    begin
        -- Header
        write(out_line, string'("=================================================="));
        writeline(output, out_line);
        write(out_line, string'("      Kasami LUT Verification (Dual Output)       "));
        writeline(output, out_line);
        write(out_line, string'("=================================================="));
        writeline(output, out_line);
        write(out_line, string'("Idx | Code A | Code B"));
        writeline(output, out_line);
        write(out_line, string'("----|--------|-------"));
        writeline(output, out_line);

        wait for 20 ns;

        -- Loop through all valid indices (0 to 254) plus the bound check (255)
        for i in 0 to 255 loop
            
            -- Drive the input
            tb_index <= std_logic_vector(to_unsigned(i, 8));
            
            -- Wait for the LUT to update
            wait for WAIT_TIME;
            
            -- Print Result to Console
            write(out_line, i, left, 4);       -- Print Index (width 4)
            write(out_line, string'("|   "));  
            write(out_line, tb_code_a);        -- Print Code A bit
            write(out_line, string'("    |   "));
            write(out_line, tb_code_b);        -- Print Code B bit
            
            -- Add note for the 255 case (Boundary Check)
            if i = 255 then
                if (tb_code_a = '0' and tb_code_b = '0') then
                    write(out_line, string'(" (PASS: Boundary Check is 0)"));
                else
                    write(out_line, string'(" (FAIL: Boundary Check is NOT 0)"));
                end if;
            end if;

            writeline(output, out_line);
            
        end loop;

        -- End Simulation
        write(out_line, string'("=================================================="));
        writeline(output, out_line);
        
        -- Stop the simulation cleanly
        assert false report "Simulation Finished Successfully" severity failure;
        wait;
    end process;

end architecture behavior;