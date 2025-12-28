library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level is
    port (
        clk_50      : in  std_logic;
        
        -- Physical Inputs
        btn_rst     : in  std_logic; 
        sw_start    : in  std_logic; 
        rx          : in  std_logic; 
        sw_disp     : in  std_logic; 
        
        -- Physical Outputs
        tx          : out std_logic; 
        led_a       : out std_logic;
        led_b       : out std_logic;
        led_status  : out std_logic_vector(1 downto 0);

        -- Multiplexed Display Pins
        fpga_dig_sel : out std_logic_vector(3 downto 0); -- DIG1..DIG4
        fpga_seg_out : out std_logic_vector(7 downto 0)  -- SEG0..SEG7
    );
end entity top_level;

architecture structural of top_level is

    -- Signals to hold the static 7-segment codes inside the FPGA
    signal internal_hex_thous : std_logic_vector(6 downto 0);
    signal internal_hex_hunds : std_logic_vector(6 downto 0);
    signal internal_hex_tens  : std_logic_vector(6 downto 0);
    signal internal_hex_ones  : std_logic_vector(6 downto 0);

    -- NEW: Intermediate signals for LED Inversion
    signal sig_led_a        : std_logic;
    signal sig_led_b        : std_logic;
    signal sig_led_status   : std_logic_vector(1 downto 0);

    -- Other existing signals...
    signal rst_btn_inverted   : std_logic;
    signal sys_rst_global     : std_logic;
    signal sig_in_fifo_empty  : std_logic;
    signal sig_out_fifo_empty : std_logic;
    signal sig_rx_w_en        : std_logic;
    signal sig_tx_en          : std_logic;
    signal sig_proc_en        : std_logic;
    signal sig_adc_data       : std_logic_vector(7 downto 0);
    signal sig_adc_valid      : std_logic;
    signal sig_time_a         : std_logic_vector(12 downto 0);
    signal sig_time_b         : std_logic_vector(12 downto 0);
    signal sig_found_a        : std_logic;
    signal sig_found_b        : std_logic;
    signal sig_score_a        : signed(17 downto 0);
    signal sig_score_b        : signed(17 downto 0);
    signal sig_score_done     : std_logic;

    -- Component Declarations
    component fsm_controller is
        port (
            clk_50 : in std_logic; btn_rst : in std_logic; sw_start : in std_logic;
            in_fifo_empty : in std_logic; out_fifo_empty : in std_logic;
            sys_rst : out std_logic; rx_w_en : out std_logic; tx_en : out std_logic;
            proc_en : out std_logic; led_status : out std_logic_vector(1 downto 0)
        );
    end component;

    component virtual_adc_interface is
        port (
            clk_50 : in std_logic; sys_rst : in std_logic; uart_rx_line : in std_logic;
            rx_w_en : in std_logic; proc_en : in std_logic; fifo_empty : out std_logic;
            fifo_data_out : out std_logic_vector(7 downto 0); fifo_valid_out : out std_logic
        );
    end component;

    component preamble_processor is
        port (
            clk_50 : in std_logic; sys_rst : in std_logic; fifo_ready : in std_logic;
            bpsk_sample : in std_logic_vector(7 downto 0); time_a : out std_logic_vector(12 downto 0);
            time_b : out std_logic_vector(12 downto 0); found_a : out std_logic; found_b : out std_logic;
            score_a : out signed(17 downto 0); score_b : out signed(17 downto 0); score_done : out std_logic
        );
    end component;

    component output_interface is
        port (
            clk_50 : in std_logic; sys_rst : in std_logic; tx_en : in std_logic; sw_disp : in std_logic;
            score_a : in signed(17 downto 0); score_b : in signed(17 downto 0); score_done : in std_logic;
            time_a : in std_logic_vector(12 downto 0); time_b : in std_logic_vector(12 downto 0);
            found_a : in std_logic; found_b : in std_logic; tx : out std_logic; out_fifo_empty : out std_logic;
            
            hex_thous : out std_logic_vector(6 downto 0);
            hex_hunds : out std_logic_vector(6 downto 0);
            hex_tens  : out std_logic_vector(6 downto 0);
            hex_ones  : out std_logic_vector(6 downto 0);
            led_a : out std_logic; led_b : out std_logic
        );
    end component;

    component seven_seg_scanner is
        port (
            clk : in std_logic;
            in_thous : in std_logic_vector(6 downto 0);
            in_hunds : in std_logic_vector(6 downto 0);
            in_tens  : in std_logic_vector(6 downto 0);
            in_ones  : in std_logic_vector(6 downto 0);
            seg_data_out : out std_logic_vector(7 downto 0);
            dig_sel_out  : out std_logic_vector(3 downto 0)
        );
    end component;

begin

    rst_btn_inverted <= not btn_rst;

    -------------------------------------------------------------------------
    -- LED OUTPUT INVERSION LOGIC
    -------------------------------------------------------------------------
    -- 1. Components drive the 'sig_' signals (active high internally)
    -- 2. We invert them here before assigning to physical 'led_' ports
    
    led_a       <= not sig_led_a;
    led_b       <= not sig_led_b;
    led_status  <= not sig_led_status;

    -------------------------------------------------------------------------
    -- COMPONENT INSTANTIATION
    -------------------------------------------------------------------------

    inst_fsm_controller : fsm_controller
    port map (
        clk_50 => clk_50, btn_rst => rst_btn_inverted, sw_start => sw_start,
        in_fifo_empty => sig_in_fifo_empty, out_fifo_empty => sig_out_fifo_empty,
        sys_rst => sys_rst_global, rx_w_en => sig_rx_w_en, tx_en => sig_tx_en,
        proc_en => sig_proc_en, 
        
        -- Mapped to intermediate signal
        led_status => sig_led_status 
    );

    inst_virtual_adc : virtual_adc_interface
    port map (
        clk_50 => clk_50, sys_rst => sys_rst_global, uart_rx_line => rx,
        rx_w_en => sig_rx_w_en, proc_en => sig_proc_en, fifo_empty => sig_in_fifo_empty,
        fifo_data_out => sig_adc_data, fifo_valid_out => sig_adc_valid
    );

    inst_preamble_processor : preamble_processor
    port map (
        clk_50 => clk_50, sys_rst => sys_rst_global, fifo_ready => sig_adc_valid,
        bpsk_sample => sig_adc_data, time_a => sig_time_a, time_b => sig_time_b,
        found_a => sig_found_a, found_b => sig_found_b, score_a => sig_score_a,
        score_b => sig_score_b, score_done => sig_score_done
    );

    inst_output_interface : output_interface
    port map (
        clk_50 => clk_50, sys_rst => sys_rst_global, tx_en => sig_tx_en, sw_disp => sw_disp,
        score_a => sig_score_a, score_b => sig_score_b, score_done => sig_score_done,
        time_a => sig_time_a, time_b => sig_time_b, found_a => sig_found_a, found_b => sig_found_b,
        tx => tx, out_fifo_empty => sig_out_fifo_empty,
        
        -- Connect internal hex signals
        hex_thous => internal_hex_thous,
        hex_hunds => internal_hex_hunds,
        hex_tens  => internal_hex_tens,
        hex_ones  => internal_hex_ones,
        
        -- Mapped to intermediate signals
        led_a => sig_led_a, 
        led_b => sig_led_b  
    );

    inst_scanner : seven_seg_scanner
    port map (
        clk      => clk_50,
        in_thous => internal_hex_thous,
        in_hunds => internal_hex_hunds,
        in_tens  => internal_hex_tens,
        in_ones  => internal_hex_ones,
        seg_data_out => fpga_seg_out, 
        dig_sel_out  => fpga_dig_sel  
    );

end architecture structural;