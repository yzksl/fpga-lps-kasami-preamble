library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_controller is
    port (
        clk_50          : in  std_logic;
        
        -- External Inputs (Physical)
        btn_rst         : in  std_logic; -- Active HIGH Reset Button
        sw_start        : in  std_logic; -- Slide Switch (0=Load, 1=Start)
        
        -- Internal Status Inputs
        in_fifo_empty   : in  std_logic; -- From Virtual ADC (1 = No Data)
        out_fifo_empty  : in  std_logic; -- From Output Interface (1 = Upload Done)
        
        -- Control Outputs
        sys_rst         : out std_logic; -- Global Soft Reset
        rx_w_en         : out std_logic; -- Enable UART RX Write
        tx_en           : out std_logic; -- Enable UART TX Read
        proc_en         : out std_logic; -- Enable Processing Clock
        led_status      : out std_logic_vector(1 downto 0) -- Status LEDs
    );
end entity fsm_controller;

architecture rtl of fsm_controller is

    -- State Encoding
    type state_type is (S_RESET, S_DONE, S_LOAD, S_PROCESS, S_UPLOAD);
    signal current_state, next_state : state_type;

    -- DRAIN TIMER CONSTANTS
    -- 300 cycles is enough to flush the pipeline.
    constant DRAIN_LIMIT : integer := 300; 
    
    -- Timer Signals
    signal drain_timer : unsigned(8 downto 0); 
    signal draining    : std_logic; 

begin

    -- =========================================================================
    -- 1. State Register (Sequential) - SYNCHRONOUS RESET
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if btn_rst = '1' then
                current_state <= S_RESET;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 2. Drain Timer Logic
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if current_state /= S_PROCESS then
                -- Reset timer when not processing
                drain_timer <= (others => '0');
                draining    <= '0';
            else
                -- If Input FIFO is empty, start counting (Draining Phase)
                if in_fifo_empty = '1' then
                    draining <= '1';
                    -- Stop counting when we hit the limit
                    if draining = '1' and drain_timer < DRAIN_LIMIT then
                        drain_timer <= drain_timer + 1;
                    end if;
                else
                    draining <= '0';
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 3. Next State Logic (Combinational)
    -- =========================================================================
    process(current_state, sw_start, in_fifo_empty, out_fifo_empty, drain_timer)
    begin
        -- Default: Stay in current state
        next_state <= current_state;
        
        case current_state is
            
            when S_RESET =>
                -- Wait here until Switch is LOW (Load Mode)
                if sw_start = '0' then
                    next_state <= S_LOAD;
                end if;

            when S_LOAD =>
                -- Start processing only if FIFO has data AND Switch is HIGH
                if (sw_start = '1') and (in_fifo_empty = '0') then
                    next_state <= S_PROCESS;
                end if;

            when S_PROCESS =>
                -- Wait for Drain Timer to hit 300 before leaving
                if (in_fifo_empty = '1') and (drain_timer = DRAIN_LIMIT) then
                    next_state <= S_UPLOAD;
                end if;

            when S_UPLOAD =>
                -- Once upload is finished, go to S_DONE
                if out_fifo_empty = '1' then
                    next_state <= S_DONE;
                end if;
            
            when S_DONE =>
                -- Trap State: Stay here forever.
                -- Exit only via synchronous btn_rst in sequential process.
                next_state <= S_DONE;

        end case;
    end process;

    -- =========================================================================
    -- 4. Output Logic (Combinational)
    -- =========================================================================
    process(current_state)
    begin
        -- Defaults (Safe State)
        sys_rst    <= '0';
        rx_w_en    <= '0';
        tx_en      <= '0';
        proc_en    <= '0';
        led_status <= "00";

        case current_state is
            
            when S_RESET =>
                sys_rst    <= '1'; 
                led_status <= "10";

            when S_DONE =>
                led_status <= "11"; 

            when S_LOAD =>
                rx_w_en    <= '1'; 
                led_status <= "00"; 

            when S_PROCESS =>
                proc_en    <= '1'; 
                led_status <= "01"; 

            when S_UPLOAD =>
                tx_en      <= '1'; 
                led_status <= "10";
                proc_en    <= '0';

        end case;
    end process;

end architecture rtl;