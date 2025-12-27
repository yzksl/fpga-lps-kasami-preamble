library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity preamble_processor is
    port (
        clk_50        : in  std_logic;
        sys_rst       : in  std_logic;
        
        -- Inputs from Virtual ADC / FIFO
        fifo_ready    : in  std_logic;                    -- From Input FIFO
        bpsk_sample   : in  std_logic_vector(7 downto 0); -- From Input FIFO (8b)
        
        -- Outputs to System Controller / Output Interface
        time_a        : out std_logic_vector(12 downto 0);
        time_b        : out std_logic_vector(12 downto 0);
        found_a       : out std_logic;
        found_b       : out std_logic;
        score_a       : out signed(17 downto 0);
        score_b       : out signed(17 downto 0);
        score_done    : out std_logic                     -- Sync Pulse
    );
end entity preamble_processor;

architecture rtl of preamble_processor is

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================

    -- 1. BPSK Demodulator (Updated Version)
    component bpsk_demodulator
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            fifo_ready      : in  std_logic;
            bpsk_sample     : in  std_logic_vector(7 downto 0);
            demod_ready     : out std_logic;
            demod_sample    : out std_logic_vector(9 downto 0) -- Now 10-bit
        );
    end component;

    -- 2. Kasami Correlator System
    component kasami_correlator_system
        port (
            clk_50        : in  std_logic;
            sys_rst       : in  std_logic;
            demod_ready   : in  std_logic;
            demod_sample  : in  std_logic_vector(9 downto 0); -- 10-bit input
            time_a        : out std_logic_vector(12 downto 0);
            time_b        : out std_logic_vector(12 downto 0);
            found_a       : out std_logic;
            found_b       : out std_logic;
            score_a       : out signed(17 downto 0);
            score_b       : out signed(17 downto 0);
            score_done    : out std_logic
        );
    end component;

    -- =========================================================================
    -- INTERNAL SIGNALS
    -- =========================================================================
    
    -- Interconnect wires
    signal w_demod_ready  : std_logic;
    signal w_demod_sample : std_logic_vector(9 downto 0); -- Direct 10-bit link

begin

    -- =========================================================================
    -- 1. INSTANTIATE BPSK DEMODULATOR
    -- =========================================================================
    u_demod : bpsk_demodulator
    port map (
        clk             => clk_50,
        rst             => sys_rst,
        fifo_ready      => fifo_ready,
        bpsk_sample     => bpsk_sample,
        demod_ready     => w_demod_ready,
        demod_sample    => w_demod_sample -- Direct 10-bit connection
    );

    -- =========================================================================
    -- 2. INSTANTIATE KASAMI CORRELATOR SYSTEM
    -- =========================================================================
    u_correlator : kasami_correlator_system
    port map (
        clk_50        => clk_50,
        sys_rst       => sys_rst,
        
        -- Inputs from Demodulator
        demod_ready   => w_demod_ready,
        demod_sample  => w_demod_sample, 
        
        -- Outputs (Pass-through to Top Level)
        time_a        => time_a,
        time_b        => time_b,
        found_a       => found_a,
        found_b       => found_b,
        score_a       => score_a,
        score_b       => score_b,
        score_done    => score_done
    );

end architecture rtl;