library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kasami_correlator_system is
    port (
        clk_50        : in  std_logic;
        sys_rst       : in  std_logic;
        
        -- Inputs
        demod_ready   : in  std_logic;                    -- Sample Valid Pulse
        demod_sample  : in  std_logic_vector(9 downto 0); -- 10-bit Raw Sample
        
        -- Outputs
        time_a        : out std_logic_vector(12 downto 0);
        time_b        : out std_logic_vector(12 downto 0);
        found_a       : out std_logic;
        found_b       : out std_logic;
        score_a       : out signed(17 downto 0);
        score_b       : out signed(17 downto 0);
        score_done    : out std_logic                     -- ADDED: Valid Score Pulse
    );
end entity kasami_correlator_system;

architecture rtl of kasami_correlator_system is

    -- =========================================================================
    -- CONSTANTS
    -- =========================================================================
    constant THRESHOLD : signed(17 downto 0) := to_signed(10000, 18); 

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================
    
    -- UPDATED: Quartus IP Component Declaration
    component ram_dual_port
        PORT
        (
            clock       : IN STD_LOGIC  := '1';
            data        : IN STD_LOGIC_VECTOR (9 DOWNTO 0);
            rdaddress   : IN STD_LOGIC_VECTOR (9 DOWNTO 0);
            wraddress   : IN STD_LOGIC_VECTOR (9 DOWNTO 0);
            wren        : IN STD_LOGIC  := '0';
            q           : OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
        );
    end component;

    component memory_controller is
        port (
            clk_50      : in  std_logic;
            sys_rst     : in  std_logic;
            demod_ready : in  std_logic;
            address_lut : out std_logic_vector(7 downto 0);
            score_done  : out std_logic;
            acc_enable  : out std_logic;
            w_address   : out std_logic_vector(9 downto 0);
            r_address   : out std_logic_vector(9 downto 0)
        );
    end component;

    component kasami_lut is
        port (
            index  : in  std_logic_vector(7 downto 0);
            code_a : out std_logic;
            code_b : out std_logic
        );
    end component;

    component correlator_engine is
        port (
            clk_50           : in  std_logic;
            sys_rst          : in  std_logic;
            acc_enable       : in  std_logic;
            demod_ready      : in  std_logic;
            code             : in  std_logic;
            demod_sample_18b : in  signed(17 downto 0);
            score            : out signed(17 downto 0)
        );
    end component;

    -- =========================================================================
    -- INTERNAL SIGNALS
    -- =========================================================================
    
    -- Memory & Controller Wires
    signal ctrl_w_addr      : std_logic_vector(9 downto 0);
    signal ctrl_r_addr      : std_logic_vector(9 downto 0);
    signal ctrl_lut_addr    : std_logic_vector(7 downto 0);
    signal ctrl_acc_en      : std_logic;
    signal ctrl_score_done  : std_logic;
    
    signal ram_q_out        : std_logic_vector(9 downto 0);
    signal sample_extended  : signed(17 downto 0); 
    
    -- LUT Wires
    signal lut_code_a       : std_logic;
    signal lut_code_b       : std_logic;
    
    -- Engine Outputs
    signal eng_score_a      : signed(17 downto 0);
    signal eng_score_b      : signed(17 downto 0);

    -- Global Counter
    signal global_count     : unsigned(12 downto 0);
    
    -- Capture Logic A
    signal comp_a_flag      : std_logic;
    signal reg_a_1b_out     : std_logic;
    signal capture_pulse_a  : std_logic;
    signal reg_a_13b_out    : std_logic_vector(12 downto 0);
    
    -- Capture Logic B
    signal comp_b_flag      : std_logic;
    signal reg_b_1b_out     : std_logic;
    signal capture_pulse_b  : std_logic;
    signal reg_b_13b_out    : std_logic_vector(12 downto 0);

begin

    -- =========================================================================
    -- 1. SIGNAL PROCESSING CORE
    -- =========================================================================
    
    -- Memory Controller
    u_ctrl : memory_controller
    port map (
        clk_50      => clk_50,
        sys_rst     => sys_rst,
        demod_ready => demod_ready,
        address_lut => ctrl_lut_addr,
        score_done  => ctrl_score_done,
        acc_enable  => ctrl_acc_en,
        w_address   => ctrl_w_addr,
        r_address   => ctrl_r_addr
    );

    -- UPDATED: RAM Instantiation using your template
    ram_dual_port_inst : ram_dual_port PORT MAP (
        clock     => clk_50,            -- Connected to System Clock
        data      => demod_sample,      -- Connected to 10-bit Input
        rdaddress => ctrl_r_addr,       -- Connected to Controller Read Addr
        wraddress => ctrl_w_addr,       -- Connected to Controller Write Addr
        wren      => demod_ready,       -- Connected to Write Trigger
        q         => ram_q_out          -- Connected to Internal Output Wire
    );

    -- Sign Extension (10b -> 18b)
    sample_extended <= resize(signed(ram_q_out), 18);

    -- Kasami LUT
    u_lut : kasami_lut
    port map (
        index  => ctrl_lut_addr,
        code_a => lut_code_a,
        code_b => lut_code_b
    );

    -- Correlator Engine A
    u_eng_a : correlator_engine
    port map (
        clk_50           => clk_50,
        sys_rst          => sys_rst,
        acc_enable       => ctrl_acc_en,
        demod_ready      => demod_ready,
        code             => lut_code_a,
        demod_sample_18b => sample_extended,
        score            => eng_score_a
    );

    -- Correlator Engine B
    u_eng_b : correlator_engine
    port map (
        clk_50           => clk_50,
        sys_rst          => sys_rst,
        acc_enable       => ctrl_acc_en,
        demod_ready      => demod_ready,
        code             => lut_code_b,
        demod_sample_18b => sample_extended,
        score            => eng_score_b
    );
    
    score_a <= eng_score_a;
    score_b <= eng_score_b;
    
    -- ADDED: Drive the external score_done port
    score_done <= ctrl_score_done;

    -- =========================================================================
    -- 2. GLOBAL COUNTER (Time Base)
    -- =========================================================================
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                global_count <= (others => '0');
            elsif demod_ready = '1' then
                global_count <= global_count + 1;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 3. SEQUENCE A CAPTURE LOGIC
    -- =========================================================================
    process(eng_score_a, ctrl_score_done)
    begin
        if ctrl_score_done = '1' and (eng_score_a >= THRESHOLD) then
            comp_a_flag <= '1';
        else
            comp_a_flag <= '0';
        end if;
    end process;

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                reg_a_1b_out <= '0';
            elsif comp_a_flag = '1' then
                reg_a_1b_out <= '1';
            end if;
        end if;
    end process;

    capture_pulse_a <= comp_a_flag and (not reg_a_1b_out);

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                reg_a_13b_out <= (others => '0');
            elsif capture_pulse_a = '1' then
                -- Subtract 8 to compensate for pipeline delay
                reg_a_13b_out <= std_logic_vector(global_count - 8);
            end if;
        end if;
    end process;

    found_a <= reg_a_1b_out;
    time_a  <= reg_a_13b_out;

    -- =========================================================================
    -- 4. SEQUENCE B CAPTURE LOGIC
    -- =========================================================================
    process(eng_score_b, ctrl_score_done)
    begin
        if ctrl_score_done = '1' and (eng_score_b >= THRESHOLD) then
            comp_b_flag <= '1';
        else
            comp_b_flag <= '0';
        end if;
    end process;

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                reg_b_1b_out <= '0';
            elsif comp_b_flag = '1' then
                reg_b_1b_out <= '1';
            end if;
        end if;
    end process;

    capture_pulse_b <= comp_b_flag and (not reg_b_1b_out);

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if sys_rst = '1' then
                reg_b_13b_out <= (others => '0');
            elsif capture_pulse_b = '1' then
                -- Subtract 8 to compensate for pipeline delay
                reg_b_13b_out <= std_logic_vector(global_count - 8);
            end if;
        end if;
    end process;

    found_b <= reg_b_1b_out;
    time_b  <= reg_b_13b_out;

end architecture rtl;