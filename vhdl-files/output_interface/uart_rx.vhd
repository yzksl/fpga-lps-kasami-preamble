library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_receiver is
    generic (
        CLK_FREQ    : integer := 50_000_000; -- 50 MHz System Clock
        BAUD_RATE   : integer := 115200      -- Match Python/Realterm Baud Rate
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Serial Input (From PC/Realterm)
        RX          : in  std_logic;
        
        -- Outputs to FIFO Buffer
        rx_w_en     : out std_logic;                    -- Write Request Pulse to FIFO
        rx_data_out : out std_logic_vector(7 downto 0); -- Signed 8-bit Sample
        
        -- Status Output (Optional/Debug)
        rx_ready    : out std_logic                     -- Active High when receiving/busy
    );
end entity uart_receiver;

architecture rtl of uart_receiver is

    -- Baud Rate Constants
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    constant HALF_BIT   : integer := BIT_PERIOD / 2;
    
    -- State Machine
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP);
    signal state : state_type;

    -- Internal Signals
    signal baud_timer   : integer range 0 to BIT_PERIOD;
    signal bit_index    : integer range 0 to 7;
    signal rx_buffer    : std_logic_vector(7 downto 0); -- Temporary storage for shifting
    
    -- Synchronization Registers (To prevent metastability on RX input)
    signal rx_sync_1    : std_logic;
    signal rx_sync_2    : std_logic;

begin

    -- =========================================================================
    -- 1. Input Synchronization
    -- =========================================================================
    -- The RX signal comes from the outside world (asynchronous). 
    -- We pass it through 2 flip-flops to synchronize it to the clk domain.
    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync_1 <= RX;
            rx_sync_2 <= rx_sync_1;
        end if;
    end process;

    -- =========================================================================
    -- 2. UART Receiver State Machine
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                rx_w_en     <= '0';
                rx_data_out <= (others => '0');
                rx_ready    <= '0';
                baud_timer  <= 0;
                bit_index   <= 0;
                rx_buffer   <= (others => '0');
            else
                case state is
                
                    -- IDLE: Wait for Falling Edge (Start Bit)
                    when IDLE =>
                        rx_w_en  <= '0';
                        rx_ready <= '0';
                        baud_timer <= 0;
                        bit_index <= 0;
                        
                        -- Detected Start Bit (Logic 0)
                        if rx_sync_2 = '0' then
                            state <= START_BIT;
                            rx_ready <= '1'; -- Indicate busy
                        end if;

                    -- START_BIT: Check middle of start bit to confirm it's valid
                    when START_BIT =>
                        if baud_timer < HALF_BIT then
                            baud_timer <= baud_timer + 1;
                        else
                            -- Check if line is still low (valid start bit)
                            if rx_sync_2 = '0' then
                                baud_timer <= 0;
                                state <= DATA_BITS;
                            else
                                state <= IDLE; -- False alarm (glitch)
                            end if;
                        end if;

                    -- DATA_BITS: Sample 8 bits (LSB First)
                    when DATA_BITS =>
                        if baud_timer < BIT_PERIOD then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            -- Sample the data in the middle of the bit period
                            rx_buffer(bit_index) <= rx_sync_2;
                            
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                bit_index <= 0;
                                state <= STOP_BIT;
                            end if;
                        end if;

                    -- STOP_BIT: Wait for Stop Bit (Logic 1)
                    when STOP_BIT =>
                        if baud_timer < BIT_PERIOD then
                            baud_timer <= baud_timer + 1;
                        else
                            -- Stop bit should be '1'
                            state <= CLEANUP;
                            baud_timer <= 0;
                        end if;

                    -- CLEANUP: Push data to FIFO
                    when CLEANUP =>
                        rx_data_out <= rx_buffer; -- Output the byte
                        rx_w_en     <= '1';       -- Pulse the Write Enable
                        state       <= IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
