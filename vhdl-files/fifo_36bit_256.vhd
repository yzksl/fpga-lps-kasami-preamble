library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity fifo_36bit_256 is
    port (
        clk         : in  std_logic;
        clear       : in  std_logic;                    -- Connected to sys_rst
        
        -- Write Interface (From Kasami Correlator)
        w_req       : in  std_logic;                    -- Write Request
        d_in        : in  std_logic_vector(35 downto 0); -- Signed 36b Input
        fifo_ready  : out std_logic;                    -- "Not Full" flag
        
        -- Read Interface (To UART Transmitter)
        d_req       : in  std_logic;                    -- Read Request
        d_out       : out std_logic_vector(35 downto 0); -- Signed 36b Output
        fifo_empty  : out std_logic                     -- Empty flag
    );
end entity fifo_36bit_256;

architecture rtl of fifo_36bit_256 is

    -- Internal signal to capture the 'full' status from the IP core
    signal full_flag : std_logic;

begin

    -- =========================================================================
    -- Altera SCFIFO Instantiation
    -- =========================================================================
    -- This component maps your interface to the underlying FPGA memory blocks.
    -- Parameters are set for a 36-bit width and 256-word depth.
    
    scfifo_component : scfifo
    generic map (
        add_ram_output_register => "OFF",
        intended_device_family  => "Cyclone IV E", -- Change if using DE1-SoC (Cyclone V) etc.
        lpm_numwords            => 256,            -- Depth of the FIFO
        lpm_showahead           => "OFF",          -- "OFF" = Read req fetches next data
        lpm_type                => "scfifo",
        lpm_width               => 36,             -- Width of data (36 bits)
        lpm_widthu              => 8,              -- log2(256) = 8 bits for pointers
        overflow_checking       => "ON",
        underflow_checking      => "ON",
        use_eab                 => "ON"            -- Use Embedded Memory Blocks (BRAM)
    )
    port map (
        clock => clk,
        aclr  => clear,      -- Asynchronous Clear (Reset)
        
        -- Write side
        wrreq => w_req,
        data  => d_in,
        full  => full_flag,  -- Internal full signal
        
        -- Read side
        rdreq => d_req,
        q     => d_out,
        empty => fifo_empty,
        
        -- Unused ports maps to open or defaults
        almost_empty => open,
        almost_full  => open,
        sclr         => '0',
        usedw        => open
    );

    -- =========================================================================
    -- Logic Adaptation
    -- =========================================================================
    -- The diagram uses "fifo_ready" which implies the FIFO is ready to accept data.
    -- This is the inverse of the "full" signal.
    
    fifo_ready <= not full_flag;

end architecture rtl;
