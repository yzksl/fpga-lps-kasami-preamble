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
        
        -- Serial Input
        RX          : in  std_logic;
        
        -- Control Input
        rx_w_en     : in  std_logic;                    -- Enable signal to allow 'Ready' output
        
        -- Outputs
        rx_data_out : out std_logic_vector(7 downto 0); -- Signed 8-bit Sample
        rx_ready    : out std_logic                     -- Output: Valid Data AND rx_w_en is High
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
    signal rx_buffer    : std_logic_vector(7 downto 0); -- Temporary storage
    
    -- Synchronization
    signal rx_sync_1    : std_logic;
    signal rx_sync_2    : std_logic;

begin

    -- =========================================================================
    -- 1. Input Synchronization
    -- =========================================================================
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
                rx_data_out <= (others => '0');
                rx_ready    <= '0';
                baud_timer  <= 0;
                bit_index   <= 0;
                rx_buffer   <= (others => '0');
            else
                case state is
                
                    -- IDLE: Wait for Start Bit
                    when IDLE =>
                        rx_ready   <= '0'; -- Reset Ready Flag
                        baud_timer <= 0;
                        bit_index  <= 0;
                        
                        -- Start bit detected (falling edge on synchronized input)
                        if rx_sync_2 = '0' then
                            state <= START_BIT;
                        end if;

                    -- START_BIT: Confirm valid start bit (check middle of bit)
                    when START_BIT =>
                        if baud_timer < HALF_BIT then
                            baud_timer <= baud_timer + 1;
                        else
                            -- Check if the line is still low (valid start bit)
                            if rx_sync_2 = '0' then
                                baud_timer <= 0;
                                state <= DATA_BITS;
                            else
                                -- False alarm / glitch
                                state <= IDLE;
                            end if;
                        end if;

                    -- DATA_BITS: Sample 8 bits
                    when DATA_BITS =>
                        if baud_timer < BIT_PERIOD then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            rx_buffer(bit_index) <= rx_sync_2;
                            
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                bit_index <= 0;
                                state <= STOP_BIT;
                            end if;
                        end if;

                    -- STOP_BIT: Wait for Stop Bit
                    when STOP_BIT =>
                        -- *** FIX IS HERE ***
                        -- We only wait for half the bit period. 
                        -- This ensures we catch the stop bit state, but finish early 
                        -- enough to be ready for the NEXT start bit immediately.
                        if baud_timer < HALF_BIT then
                            baud_timer <= baud_timer + 1;
                        else
                            state <= CLEANUP;
                            baud_timer <= 0;
                        end if;

                    -- CLEANUP: Update Outputs based on Criteria
                    when CLEANUP =>
                        -- 1. Always update the data output with the received byte
                        rx_data_out <= rx_buffer;

                        -- 2. Check the CRITERIA for rx_ready:
                        --    Must have finished reception (We are in CLEANUP)
                        --    AND input rx_w_en must be '1'
                        if rx_w_en = '1' then
                            rx_ready <= '1';
                        else
                            rx_ready <= '0';
                        end if;
                        
                        -- Return to IDLE for next byte immediately
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;