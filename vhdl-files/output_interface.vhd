library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_interface is
    port (
        clk_50         : in  std_logic;
        sys_rst        : in  std_logic;
        
        -- Control Inputs
        tx_en          : in  std_logic; -- From FSM (starts UART upload)
        sw_disp        : in  std_logic; -- From Switch (selects A or B on 7-seg)
        
        -- Data Inputs (From Preamble Processor)
        score_a        : in  signed(17 downto 0);
        score_b        : in  signed(17 downto 0);
        score_done     : in  std_logic; -- Write trigger for FIFO
        
        -- Display Inputs (From Preamble Processor)
        time_a         : in  std_logic_vector(12 downto 0);
        time_b         : in  std_logic_vector(12 downto 0);
        found_a        : in  std_logic;
        found_b        : in  std_logic;
        
        -- Outputs
        tx             : out std_logic; -- UART TX Line
        out_fifo_empty : out std_logic; -- To FSM (tells when upload finishes)
        
        -- Physical Outputs
        hex_thous      : out std_logic_vector(6 downto 0);
        hex_hunds      : out std_logic_vector(6 downto 0);
        hex_tens       : out std_logic_vector(6 downto 0);
        hex_ones       : out std_logic_vector(6 downto 0);
        led_a          : out std_logic;
        led_b          : out std_logic
    );
end entity output_interface;

architecture rtl of output_interface is

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================

    -- 1. FIFO (36-bit, 4096 depth)
    component fifo_36bit_4096
        port (
            clock    : IN  STD_LOGIC;
            data     : IN  STD_LOGIC_VECTOR (35 DOWNTO 0);
            rdreq    : IN  STD_LOGIC;
            sclr     : IN  STD_LOGIC;
            wrreq    : IN  STD_LOGIC;
            empty    : OUT STD_LOGIC;
            full     : OUT STD_LOGIC;
            q        : OUT STD_LOGIC_VECTOR (35 DOWNTO 0);
            usedw    : OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
        );
    end component;

    -- 2. UART Transmitter (Our custom block)
    component uart_transmitter
        generic (
            CLK_FREQ  : integer := 50_000_000;
            BAUD_RATE : integer := 115200
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            tx_en      : in  std_logic;
            fifo_ready : in  std_logic; -- DIFFERENT THAN THE ONE IN INPUT FIFO
            scores     : in  std_logic_vector(35 downto 0);
            d_req      : out std_logic;
            tx_line    : out std_logic
        );
    end component;

    -- 3. Display Controller
    component display_controller
        port (
            clk_50    : in  std_logic;
            rst       : in  std_logic;
            time_a    : in  std_logic_vector(12 downto 0);
            time_b    : in  std_logic_vector(12 downto 0);
            found_a   : in  std_logic;
            found_b   : in  std_logic;
            sw_disp   : in  std_logic;
            hex_thous : out std_logic_vector(6 downto 0);
            hex_hunds : out std_logic_vector(6 downto 0);
            hex_tens  : out std_logic_vector(6 downto 0);
            hex_ones  : out std_logic_vector(6 downto 0);
            led_a     : out std_logic;
            led_b     : out std_logic
        );
    end component;

    -- =========================================================================
    -- INTERNAL SIGNALS
    -- =========================================================================
    
    -- Data Packing
    signal fifo_data_in : std_logic_vector(35 downto 0);
    
    -- FIFO -> UART Connections
    signal fifo_q       : std_logic_vector(35 downto 0);
    signal fifo_empty   : std_logic;
    signal fifo_ready   : std_logic; -- Inverted empty (-- DIFFERENT THAN THE ONE IN INPUT FIFO)
    signal uart_read_req: std_logic;

begin

    -- =========================================================================
    -- 1. DATA PACKING (18b + 18b -> 36b)
    -- =========================================================================
    -- Concatenate Score A (MSB) and Score B (LSB)
    fifo_data_in <= std_logic_vector(score_a) & std_logic_vector(score_b);

    -- =========================================================================
    -- 2. FIFO INSTANCE
    -- =========================================================================
    u_fifo : fifo_36bit_4096
    port map (
        clock => clk_50,
        sclr  => sys_rst,
        
        -- Write Side (From Processor)
        data  => fifo_data_in,
        wrreq => score_done,
        
        -- Read Side (From UART)
        rdreq => uart_read_req,
        q     => fifo_q,
        empty => fifo_empty,
        
        -- Unused Ports
        full  => open,
        usedw => open
    );

    -- Output FIFO Empty status to FSM
    out_fifo_empty <= fifo_empty;

    -- Create "Ready" signal for UART (Active High when data exists) (-- DIFFERENT THAN THE ONE IN INPUT FIFO)
    fifo_ready <= not fifo_empty;

    -- =========================================================================
    -- 3. UART TRANSMITTER INSTANCE
    -- =========================================================================
    u_uart : uart_transmitter
    generic map (
        CLK_FREQ  => 50_000_000,
        BAUD_RATE => 115200
    )
    port map (
        clk        => clk_50,
        rst        => sys_rst,
        
        -- Control
        tx_en      => tx_en,      -- Triggered by FSM state S_UPLOAD
        
        -- FIFO Interface
        fifo_ready => fifo_ready, -- Tells UART "We have data" (-- DIFFERENT THAN THE ONE IN INPUT FIFO)
        scores     => fifo_q,     -- 36-bit data
        d_req      => uart_read_req, -- UART asks for next data
        
        -- Output
        tx_line    => tx
    );

    -- =========================================================================
    -- 4. DISPLAY CONTROLLER INSTANCE
    -- =========================================================================
    u_disp : display_controller
    port map (
        clk_50    => clk_50,
        rst       => sys_rst,
        
        -- Inputs
        time_a    => time_a,
        time_b    => time_b,
        found_a   => found_a,
        found_b   => found_b,
        sw_disp   => sw_disp,
        
        -- Outputs
        hex_thous => hex_thous,
        hex_hunds => hex_hunds,
        hex_tens  => hex_tens,
        hex_ones  => hex_ones,
        led_a     => led_a,
        led_b     => led_b
    );

end architecture rtl;