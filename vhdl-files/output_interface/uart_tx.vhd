library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_transmitter is
    generic (
        CLK_FREQ    : integer := 50_000_000;
        BAUD_RATE   : integer := 115200 -- 115200 is standard
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Control
        tx_en       : in  std_logic;
        
        -- FIFO Interface
        fifo_ready  : in  std_logic;                    -- "Empty" flag inverted (1=Data Exists) (DIFFERENT FUNCTION THAN THE ONE IN INPUT BUFFER)
        scores      : in  std_logic_vector(35 downto 0); -- Input from FIFO
        d_req       : out std_logic;                    -- Read Request (Pop)
        
        -- Serial Output
        tx_line     : out std_logic
    );
end entity uart_transmitter;

architecture rtl of uart_transmitter is

    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    
    type state_type is (IDLE, FETCH, LATCH, TX_START, TX_DATA, TX_STOP, NEXT_BYTE);
    signal state : state_type;

    signal baud_timer   : integer range 0 to BIT_PERIOD;
    signal bit_index    : integer range 0 to 7;
    signal byte_count   : integer range 0 to 5; -- Counts 0 to 5
    
    -- 40-bit Register (holds 5 bytes)
    -- We will shift this right by 8 bits after every send.
    signal sh_reg       : std_logic_vector(39 downto 0); 
    signal tx_buffer    : std_logic_vector(7 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                tx_line     <= '1'; -- UART Idle is High
                d_req       <= '0';
                baud_timer  <= 0;
                bit_index   <= 0;
                byte_count  <= 0;
                sh_reg      <= (others => '0');
                tx_buffer   <= (others => '0');
            else
                case state is
                
                    -- 1. IDLE: Wait for Master Enable + Data in FIFO
                    when IDLE =>
                        d_req <= '0';
                        tx_line <= '1';
                        byte_count <= 0;
                        
                        if (tx_en = '1') and (fifo_ready = '1') then
                            state <= FETCH;
                        end if;

                    -- 2. FETCH: Pulse FIFO Read Request
                    -- This tells the FIFO "Give me the next 36-bit word".
                    when FETCH =>
                        d_req <= '1';
                        state <= LATCH;

                    -- 3. LATCH: Capture Data (Wait 1 cycle for FIFO latency)
                    when LATCH =>
                        d_req <= '0';
                        
                        -- PACKING STRATEGY:
                        -- Pad the 36-bit score to 40 bits (5 bytes).
                        -- We add "0000" at the top.
                        -- sh_reg <= [0000] & [Score 35..0]
                        sh_reg(39 downto 36) <= "0000";
                        sh_reg(35 downto 0)  <= scores;
                        
                        state <= TX_START;

                    -- 4. TX_START: Send Start Bit (Low)
                    when TX_START =>
                        tx_line <= '0';
                        
                        -- FIX: Always grab the BOTTOM byte.
                        -- We shift the data down later in NEXT_BYTE state.
                        tx_buffer <= sh_reg(7 downto 0);

                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            state <= TX_DATA;
                        end if;

                    -- 5. TX_DATA: Send 8 bits (LSB first)
                    when TX_DATA =>
                        tx_line <= tx_buffer(bit_index);
                        
                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                bit_index <= 0;
                                state <= TX_STOP;
                            end if;
                        end if;

                    -- 6. TX_STOP: Send Stop Bit (High)
                    when TX_STOP =>
                        tx_line <= '1';
                        
                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            state <= NEXT_BYTE;
                        end if;

                    -- 7. NEXT_BYTE: Shift and Loop
                    when NEXT_BYTE =>
                        if byte_count < 4 then
                            -- FIX: Shift the whole register right by 8 bits.
                            -- This brings the next byte into position (7 downto 0).
                            sh_reg <= x"00" & sh_reg(39 downto 8);
                            
                            byte_count <= byte_count + 1;
                            state <= TX_START;
                        else
                            state <= IDLE; -- All 5 bytes sent
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end architecture rtl;