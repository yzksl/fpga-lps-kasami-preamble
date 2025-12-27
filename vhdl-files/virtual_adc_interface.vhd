library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity virtual_adc_interface is
    port (
        clk_50         : in  std_logic;
        sys_rst        : in  std_logic;
        
        -- Inputs from Top Level / FSM
        uart_rx_line   : in  std_logic; -- Physical Pin (RX)
        rx_w_en        : in  std_logic; -- FSM: Enable UART Writing
        proc_en        : in  std_logic; -- FSM: Enable 160kHz Playback
        
        -- Outputs to FSM
        fifo_empty     : out std_logic; -- Tells FSM "Simulation Done"
        
        -- Outputs to Preamble Processor
        fifo_data_out  : out std_logic_vector(7 downto 0); -- The "Sample"
        fifo_valid_out : out std_logic  -- Acts as 'fifo_ready' (Sample Valid)
    );
end entity virtual_adc_interface;

architecture rtl of virtual_adc_interface is

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================
    
    -- 1. Clock Divider (160kHz Generator)
    component clock_div_160k
        port (
            clk_50    : in  std_logic;
            sys_rst   : in  std_logic;
            proc_en   : in  std_logic;
            tick_160k : out std_logic
        );
    end component;

    -- 2. UART Receiver (Group Member's Code)
    component uart_receiver
        generic (
            CLK_FREQ    : integer := 50_000_000;
            BAUD_RATE   : integer := 115200
        );
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            RX          : in  std_logic;
            rx_w_en     : in  std_logic;
            rx_data_out : out std_logic_vector(7 downto 0);
            rx_ready    : out std_logic
        );
    end component;

    -- 3. FIFO Buffer (Quartus IP)
    component fifo_8bit_4096
        port (
            clock : in std_logic;
            data  : in std_logic_vector(7 downto 0);
            rdreq : in std_logic;
            sclr  : in std_logic;
            wrreq : in std_logic;
            empty : out std_logic;
            q     : out std_logic_vector(7 downto 0)
        );
    end component;

    -- =========================================================================
    -- INTERNAL SIGNALS
    -- =========================================================================
    
    -- UART <-> FIFO Connections
    signal uart_data     : std_logic_vector(7 downto 0);
    signal uart_valid    : std_logic; -- Connects to FIFO wrreq
    
    -- Clock Divider <-> FIFO Connections
    signal tick_pulse    : std_logic; -- The 160kHz heartbeat
    
    -- FIFO Read Logic
    signal fifo_read_req : std_logic;
    signal is_empty      : std_logic;

begin

    -- =========================================================================
    -- 1. UART RECEIVER INSTANCE
    -- =========================================================================
    u_uart : uart_receiver
    generic map (
        CLK_FREQ  => 50_000_000,
        BAUD_RATE => 115200 -- Ensure this matches your Python script
    )
    port map (
        clk         => clk_50,
        rst         => sys_rst,
        RX          => uart_rx_line,
        rx_w_en     => rx_w_en,     -- FSM controls when we listen
        rx_data_out => uart_data,
        rx_ready    => uart_valid   -- Goes high only if rx_w_en is high
    );

    -- =========================================================================
    -- 2. 160kHz CLOCK DIVIDER INSTANCE
    -- =========================================================================
    u_clk_div : clock_div_160k
    port map (
        clk_50    => clk_50,
        sys_rst   => sys_rst,
        proc_en   => proc_en,     -- FSM starts the simulation clock
        tick_160k => tick_pulse
    );

    -- =========================================================================
    -- 3. READ LOGIC (The Virtual ADC Trigger)
    -- =========================================================================
    -- We read from the FIFO exactly when the 160kHz tick fires.
    -- Safety: We only assert read if the FIFO is NOT empty.
    fifo_read_req <= tick_pulse and (not is_empty);

    -- =========================================================================
    -- 4. FIFO BUFFER INSTANCE
    -- =========================================================================
    u_fifo : fifo_8bit_4096
    port map (
        clock => clk_50,
        sclr  => sys_rst,       -- Clears buffer between runs
        
        -- Write Side (From UART)
        data  => uart_data,
        wrreq => uart_valid,
        
        -- Read Side (From 160kHz Logic)
        rdreq => fifo_read_req,
        empty => is_empty,
        q     => fifo_data_out
    );

    -- Output the empty flag to FSM so it knows when to stop 'S_PROCESS'
    fifo_empty <= is_empty;

    -- =========================================================================
    -- 5. VALID SIGNAL GENERATION (Delay Logic)
    -- =========================================================================
    -- The FIFO (in "Normal" mode) takes 1 clock cycle to output data after rdreq.
    -- We must delay our read pulse by 1 cycle to tell the processor:
    -- "The data on the wire is valid NOW."
    
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                fifo_valid_out <= '0';
            else
                fifo_valid_out <= fifo_read_req; -- 1 cycle delay
            end if;
        end if;
    end process;

end architecture rtl;