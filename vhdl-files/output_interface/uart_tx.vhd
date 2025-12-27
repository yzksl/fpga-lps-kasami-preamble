library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_transmitter is
    generic (
        CLK_FREQ    : integer := 50_000_000; -- 50 MHz Clock
        BAUD_RATE   : integer := 115200      -- Standard Baud Rate
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Control Interface
        tx_en       : in  std_logic;                    -- Global Enable
        
        -- FIFO Interface (Matches Top-Level)
        fifo_ready  : in  std_logic;                    -- Input: Data Available
        scores      : in  std_logic_vector(35 downto 0); -- Input: 36-bit Score
        d_req       : out std_logic;                    -- Output: Read from FIFO
        
        -- Serial Output
        tx_line     : out std_logic                     -- UART TX Pin
    );
end entity uart_transmitter;

architecture rtl of uart_transmitter is

    -- Timing Constants
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    
    -- State Machine Definition
    type state_type is (IDLE, FETCH, LATCH, TX_START, TX_DATA, TX_STOP, NEXT_BYTE);
    signal state : state_type;

    -- Internal Registers
    signal baud_timer   : integer range 0 to BIT_PERIOD;
    signal bit_index    : integer range 0 to 7;         -- 0..7 (Standard Byte)
    signal byte_count   : integer range 0 to 4;         -- 0..4 (5 Bytes total)
    
    -- Datapath Registers
    -- We pad the 36-bit input to 40 bits (5 bytes * 8 bits)
    signal sh_reg       : std_logic_vector(39 downto 0); 
    signal tx_buffer    : std_logic_vector(7 downto 0); -- Current byte to send

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                tx_line     <= '1'; -- Idle High
                d_req       <= '0';
                baud_timer  <= 0;
                bit_index   <= 0;
                byte_count  <= 0;
                sh_reg      <= (others => '0');
                tx_buffer   <= (others => '0');
            else
                case state is
                
                    -- 1. IDLE: Wait for Enable and Data
                    when IDLE =>
                        d_req <= '0';
                        tx_line <= '1';
                        byte_count <= 0;
                        if tx_en = '1' and fifo_ready = '1' then
                            state <= FETCH;
                        end if;

                    -- 2. FETCH: Pulse FIFO Read
                    when FETCH =>
                        d_req <= '1'; -- Pop 36-bit data
                        state <= LATCH;

                    -- 3. LATCH: Store Data & Prepare Padded Frame
                    when LATCH =>
                        d_req <= '0';
                        -- PACKING STRATEGY:
                        -- We put the 36 bits into the lower part of a 40-bit register.
                        -- Upper 4 bits are '0' (Padding).
                        -- Format: [0000][Score 35..0]
                        sh_reg(35 downto 0)  <= scores;
                        sh_reg(39 downto 36) <= "0000"; 
                        state <= TX_START;

                    -- 4. TX_START: Send Start Bit (Low)
                    when TX_START =>
                        tx_line <= '0';
                        
                        -- SLICING STRATEGY:
                        -- Extract the specific byte we need to send now.
                        -- We shift the big register down by 8 bits * byte_count
                        tx_buffer <= sh_reg((byte_count*8 + 7) downto (byte_count*8));

                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            state <= TX_DATA;
                        end if;

                    -- 5. TX_DATA: Shift out 8 bits of the current byte
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

                    -- 7. NEXT_BYTE: Check if we sent all 5 bytes
                    when NEXT_BYTE =>
                        if byte_count < 4 then
                            byte_count <= byte_count + 1; -- Move to next byte
                            state <= TX_START;            -- Send it
                        else
                            state <= IDLE;                -- Done with all 36 bits
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end architecture rtl;