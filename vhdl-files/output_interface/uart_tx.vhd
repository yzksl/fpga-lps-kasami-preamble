library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_transmitter is
    generic (
        CLK_FREQ    : integer := 50_000_000; -- 50 MHz
        BAUD_RATE   : integer := 115200      -- Target Baud Rate
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Control Interface (From FSM Controller)
        tx_en       : in  std_logic;                    -- Global Enable for Transmission
        
        -- FIFO Interface
        fifo_ready  : in  std_logic;                    -- Input: FIFO has data (Not Empty)
        scores      : in  std_logic_vector(35 downto 0); -- Input: 36-bit Signed Data
        d_req       : out std_logic;                    -- Output: Read Request to FIFO
        
        -- Serial Output
        tx_line     : out std_logic                     -- UART TX Pin
    );
end entity uart_transmitter;

architecture rtl of uart_transmitter is

    -- Baud Rate Generator Constants
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    
    -- State Machine
    type state_type is (IDLE, FETCH_FIFO, WAIT_RAM, LOAD_PACKET, TX_START, TX_DATA, TX_STOP, NEXT_BYTE);
    signal state : state_type;

    -- Internal Signals
    signal baud_timer   : integer range 0 to BIT_PERIOD;
    signal bit_index    : integer range 0 to 7;          -- 0 to 7 for 8 data bits
    signal byte_index   : integer range 0 to 4;          -- 0 to 4 for 5 bytes (36 bits fit in 5 bytes)
    
    -- Data Registers
    signal data_latch   : std_logic_vector(39 downto 0); -- 40 bits to hold 5 bytes (36b data + 4b padding)
    signal tx_shifter   : std_logic_vector(7 downto 0);  -- Current byte being sent

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                tx_line     <= '1'; -- UART Idle state is High
                d_req       <= '0';
                baud_timer  <= 0;
                bit_index   <= 0;
                byte_index  <= 0;
                data_latch  <= (others => '0');
            else
                case state is
                
                    -- 1. IDLE: Wait for Enable and Data Available
                    when IDLE =>
                        d_req <= '0';
                        tx_line <= '1';
                        byte_index <= 0;
                        
                        if (tx_en = '1' and fifo_ready = '1') then
                            state <= FETCH_FIFO;
                        end if;

                    -- 2. FETCH_FIFO: Pulse Read Request
                    when FETCH_FIFO =>
                        d_req <= '1'; -- Pop data from FIFO
                        state <= WAIT_RAM;

                    -- 3. WAIT_RAM: Wait for FIFO/RAM latency (1 cycle for scfifo)
                    when WAIT_RAM =>
                        d_req <= '0';
                        state <= LOAD_PACKET;

                    -- 4. LOAD_PACKET: Latch 36-bit data into 40-bit frame
                    when LOAD_PACKET =>
                        -- Mapping: Padding upper 4 bits with '0', then the 36-bit score
                        -- Sending LSB First (Little Endian) usually preferred for raw data
                        data_latch(35 downto 0)  <= scores;
                        data_latch(39 downto 36) <= (others => '0'); -- Padding
                        
                        state <= TX_START;

                    -- 5. TX_START: Send Start Bit (0)
                    when TX_START =>
                        tx_line <= '0'; -- Start Bit
                        
                        -- Load the specific byte based on byte_index
                        -- Byte 0: 7..0, Byte 1: 15..8, etc.
                        tx_shifter <= data_latch((byte_index * 8 + 7) downto (byte_index * 8));
                        
                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            state <= TX_DATA;
                        end if;

                    -- 6. TX_DATA: Send 8 Data Bits (LSB first)
                    when TX_DATA =>
                        tx_line <= tx_shifter(bit_index);
                        
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

                    -- 7. TX_STOP: Send Stop Bit (1)
                    when TX_STOP =>
                        tx_line <= '1'; -- Stop Bit
                        
                        if baud_timer < BIT_PERIOD - 1 then
                            baud_timer <= baud_timer + 1;
                        else
                            baud_timer <= 0;
                            state <= NEXT_BYTE;
                        end if;

                    -- 8. NEXT_BYTE: Check if we sent all 5 bytes
                    when NEXT_BYTE =>
                        if byte_index < 4 then
                            byte_index <= byte_index + 1;
                            state <= TX_START; -- Send next byte
                        else
                            state <= IDLE; -- Packet done
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
