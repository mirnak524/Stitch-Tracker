library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_stitch is
end tb_stitch;

architecture Behavioral of tb_stitch is

    component stitch_ctrl
        port ( clk, rst, cw, ccw : in  std_logic;
                       stitch_inc : in  std_logic;
                          curr_st : out std_logic_vector(7 downto 0);
                          next_st : out std_logic_vector(7 downto 0);
                         position : out integer range 1 to 99;
                     pattern_done : out std_logic );
    end component;

    component enc_decoder
        port ( clk, A, B, btn : in  std_logic;
               cw, ccw, press : out std_logic );
    end component;

    component cdc_touch
        port ( clk  : in  std_logic;
               out1 : in  std_logic;
               touch : out std_logic );
    end component;

    component oled_ctrl
        port ( clk, rst             : in  std_logic;
               curr_code, next_code : in  std_logic_vector(7 downto 0);
               curr_color, next_color : in std_logic_vector(7 downto 0);
               position             : in  integer range 1 to 99;
               CS, SDIN, SCLK, DC, RES, VBAT, VDD : out std_logic );
    end component;

    constant CLK_PERIOD : time := 8 ns;
    signal clk : std_logic := '0';

    signal sc_rst  : std_logic := '1';
    signal sc_cw   : std_logic := '0';
    signal sc_ccw  : std_logic := '0';
    signal sc_inc  : std_logic := '0';
    signal sc_curr : std_logic_vector(7 downto 0);
    signal sc_next : std_logic_vector(7 downto 0);
    signal sc_pos  : integer range 1 to 99;
    signal sc_done : std_logic;

    signal enc_a     : std_logic := '0';
    signal enc_b     : std_logic := '0';
    signal enc_btn   : std_logic := '0';
    signal enc_cw    : std_logic;
    signal enc_ccw   : std_logic;
    signal enc_press : std_logic;

    signal cdc_out1      : std_logic := '0';
    signal cdc_touch_out : std_logic;

    signal oled_rst   : std_logic := '1';
    signal oled_curr  : std_logic_vector(7 downto 0) := x"02";
    signal oled_next  : std_logic_vector(7 downto 0) := x"04";
    signal oled_color_curr : std_logic_vector(7 downto 0) := x"01";
    signal oled_color_next : std_logic_vector(7 downto 0) := x"02";
    signal oled_pos   : integer range 1 to 99 := 1;
    signal oled_cs    : std_logic;
    signal oled_sdin  : std_logic;
    signal oled_sclk  : std_logic;
    signal oled_dc    : std_logic;
    signal oled_res   : std_logic;
    signal oled_vbat  : std_logic;
    signal oled_vdd   : std_logic;

    procedure pulse (signal s : out std_logic) is
    begin
        s <= '1';
        wait until rising_edge(clk);
        s <= '0';
        wait until rising_edge(clk);
    end procedure;

    -- CW: 00->01->11->10->00
    procedure enc_cw_tick (signal a : out std_logic; signal b : out std_logic) is
    begin
        a <= '0'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '1'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '1'; b <= '1'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '0'; b <= '1'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '0'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
    end procedure;

    -- CCW: 00->10->11->01->00
    procedure enc_ccw_tick (signal a : out std_logic; signal b : out std_logic) is
    begin
        a <= '0'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '0'; b <= '1'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '1'; b <= '1'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '1'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
        a <= '0'; b <= '0'; wait until rising_edge(clk); wait until rising_edge(clk);
    end procedure;

begin

    clk <= not clk after CLK_PERIOD / 2;

    DUT_STITCH : stitch_ctrl
        port map ( clk => clk, rst => sc_rst, cw => sc_cw, ccw => sc_ccw,
                   stitch_inc => sc_inc, curr_st => sc_curr, next_st => sc_next,
                   position => sc_pos, pattern_done => sc_done );

    DUT_ENC : enc_decoder
        port map ( clk => clk, A => enc_a, B => enc_b, btn => enc_btn,
                   cw => enc_cw, ccw => enc_ccw, press => enc_press );

    DUT_CDC : cdc_touch
        port map ( clk => clk, out1 => cdc_out1, touch => cdc_touch_out );

    DUT_OLED : oled_ctrl
        port map ( clk => clk, rst => oled_rst,
                   curr_code => oled_curr, next_code => oled_next,
                   curr_color => oled_color_curr, next_color => oled_color_next,
                   position => oled_pos,
                   CS => oled_cs, SDIN => oled_sdin, SCLK => oled_sclk,
                   DC => oled_dc, RES => oled_res,
                   VBAT => oled_vbat, VDD => oled_vdd );

    process begin

        -- stitch_ctrl tests
        sc_rst <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk); wait until rising_edge(clk);
        sc_rst <= '0';
        wait until rising_edge(clk);

        wait until rising_edge(clk);
        assert sc_pos = 1    report "FAIL: initial position should be 1" severity error;
        assert sc_curr = x"01" report "FAIL: initial curr_st should be CH (0x01)" severity error;
        assert sc_next = x"02" report "FAIL: initial next_st should be SC (0x02)" severity error;
        assert sc_done = '0' report "FAIL: pattern_done should be 0 at start" severity error;
        report "PASS: initial state correct";

        pulse(sc_cw);
        wait until rising_edge(clk);
        assert sc_pos = 2    report "FAIL: after cw, position should be 2" severity error;
        assert sc_curr = x"02" report "FAIL: after cw, curr_st should be SC (0x02)" severity error;
        assert sc_next = x"02" report "FAIL: after cw, next_st should be SC (0x02)" severity error;
        report "PASS: cw advance pos 1->2";

        pulse(sc_inc);
        wait until rising_edge(clk);
        assert sc_pos = 3    report "FAIL: after stitch_inc, position should be 3" severity error;
        assert sc_curr = x"02" report "FAIL: after stitch_inc, curr_st should be SC" severity error;
        report "PASS: stitch_inc advance pos 2->3";

        pulse(sc_cw);
        wait until rising_edge(clk);
        assert sc_pos = 4    report "FAIL: position should be 4" severity error;
        assert sc_curr = x"04" report "FAIL: curr_st should be DC (0x04)" severity error;
        report "PASS: pos 4 = DC";

        pulse(sc_ccw);
        wait until rising_edge(clk);
        assert sc_pos = 3    report "FAIL: after ccw, position should be 3" severity error;
        assert sc_curr = x"02" report "FAIL: after ccw, curr_st should be SC" severity error;
        report "PASS: ccw retreat pos 4->3";

        pulse(sc_cw); wait until rising_edge(clk);
        pulse(sc_cw); wait until rising_edge(clk);
        pulse(sc_cw); wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert sc_done = '1'  report "FAIL: pattern_done should be 1 at END" severity error;
        assert sc_curr = x"FF" report "FAIL: curr_st should be 0xFF at END" severity error;
        report "PASS: pattern_done asserts at END";

        pulse(sc_cw);
        wait until rising_edge(clk);
        assert sc_done = '1' report "FAIL: pattern_done should stay 1 after cw at END" severity error;
        assert sc_pos = 6    report "FAIL: position should not advance past END" severity error;
        report "PASS: blocked at END";

        sc_rst <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        sc_rst <= '0';
        wait until rising_edge(clk);
        assert sc_pos = 1    report "FAIL: after reset, position should be 1" severity error;
        assert sc_curr = x"01" report "FAIL: after reset, curr_st should be CH" severity error;
        assert sc_done = '0' report "FAIL: after reset, pattern_done should be 0" severity error;
        report "PASS: reset returns to start";

        pulse(sc_ccw);
        wait until rising_edge(clk);
        assert sc_pos = 1 report "FAIL: ccw at position 1 should not underflow" severity error;
        report "PASS: ccw blocked at position 1";

        -- enc_decoder tests
        enc_cw_tick(enc_a, enc_b);
        wait until rising_edge(clk);
        assert enc_cw = '1'  report "FAIL: enc_cw should pulse after CW quadrature" severity error;
        assert enc_ccw = '0' report "FAIL: enc_ccw should be 0 during CW" severity error;
        report "PASS: enc_decoder CW detected";
        wait until rising_edge(clk);

        enc_ccw_tick(enc_a, enc_b);
        wait until rising_edge(clk);
        assert enc_ccw = '1' report "FAIL: enc_ccw should pulse after CCW quadrature" severity error;
        assert enc_cw = '0'  report "FAIL: enc_cw should be 0 during CCW" severity error;
        report "PASS: enc_decoder CCW detected";
        wait until rising_edge(clk);

        enc_btn <= '0';
        wait until rising_edge(clk); wait until rising_edge(clk);
        enc_btn <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        assert enc_press = '1' report "FAIL: enc_press should pulse on btn rising edge" severity error;
        report "PASS: enc_decoder button press detected";
        enc_btn <= '0';
        wait until rising_edge(clk);

        -- cdc_touch tests
        cdc_out1 <= '0';
        wait until rising_edge(clk); wait until rising_edge(clk);
        cdc_out1 <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk); wait until rising_edge(clk);
        assert cdc_touch_out = '1' report "FAIL: touch should pulse on out1 rising edge" severity error;
        report "PASS: cdc_touch fires on rising edge";

        wait until rising_edge(clk);
        assert cdc_touch_out = '0' report "FAIL: touch should be 0 after one cycle" severity error;
        report "PASS: cdc_touch is single cycle pulse";

        cdc_out1 <= '0';
        wait until rising_edge(clk); wait until rising_edge(clk);
        cdc_out1 <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk); wait until rising_edge(clk);
        assert cdc_touch_out = '0' report "FAIL: touch should be blocked during lockout" severity error;
        report "PASS: cdc_touch lockout blocks re-trigger";
        report "NOTE: 200ms lockout expiry not simulated (25M cycles)";

        -- oled_ctrl startup tests
        oled_rst <= '1';
        wait until rising_edge(clk); wait until rising_edge(clk);
        oled_rst <= '0';
        wait until rising_edge(clk);

        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert oled_vdd = '0' report "FAIL: oled VDD should assert low during init" severity error;
        report "PASS: oled_ctrl VDD asserts on startup";

        wait for 125000 * 8 ns;
        wait for 125000 * 8 ns;
        assert oled_cs = '0' report "FAIL: oled CS should go low during SPI init" severity error;
        report "PASS: oled_ctrl SPI CS activates during init";
        report "NOTE: RES pulse verified by waveform inspection";

        report "=== All tests complete ===";
        wait;

    end process;

end Behavioral;