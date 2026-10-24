library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity stitch_top is
    port (
        clk, btn0 : in std_logic;

        -- rotary encoder
        enc_a, enc_b, enc_btn : in std_logic;

        -- capacative touch button
        cdc_out1 : in std_logic;

        -- oled
        oled_cs, oled_sdin, oled_sclk, oled_dc, oled_res, oled_vbat, oled_vdd : out std_logic;
        
        led : out std_logic );
end stitch_top;

architecture structural of stitch_top is

    component debounce
        port ( clk, btn : in  std_logic;
                   dbnc : out std_logic );
    end component;

    component enc_decoder 
        port ( clk, A, B, btn : in  std_logic;
               cw, ccw, press : out std_logic );
    end component;

    component cdc_touch 
        port ( clk, out1 : in  std_logic;
                   touch : out std_logic );
    end component;

    component stitch_ctrl 
        port ( clk, rst, cw, ccw : in  std_logic;
                      stitch_inc : in  std_logic;
                         curr_st : out std_logic_vector(7 downto 0);
                         next_st : out std_logic_vector(7 downto 0);
                        position : out integer range 1 to 99;
                    pattern_done : out std_logic;
                      curr_color : out std_logic_vector(7 downto 0);
                      next_color : out std_logic_vector(7 downto 0) );
    end component;

    component oled_ctrl 
        port ( clk, rst             : in  std_logic;
               curr_code, next_code : in  std_logic_vector(7 downto 0);
               curr_color, next_color : in std_logic_vector(7 downto 0);
               position             : in  integer range 1 to 99;
               CS, SDIN, SCLK, DC, RES, VBAT, VDD : out std_logic );
    end component;

    signal rst            : std_logic;
    signal cw, ccw        : std_logic;
    signal touch          : std_logic;
    signal curr_st        : std_logic_vector(7 downto 0);
    signal next_st        : std_logic_vector(7 downto 0);
    signal curr_color     : std_logic_vector(7 downto 0);
    signal next_color     : std_logic_vector(7 downto 0);
    signal position       : integer range 1 to 99;
    signal done           : std_logic;
    signal enc_a_dbnc     : std_logic;
    signal enc_b_dbnc     : std_logic;

begin

    U_DBNC : debounce
        port map ( clk => clk,
                   btn => btn0,
                   dbnc => rst );

    U_DBNC_A : debounce
        port map ( clk => clk,
                   btn => enc_a,
                   dbnc => enc_a_dbnc );

    U_DBNC_B : debounce
        port map ( clk => clk,
                   btn => enc_b,
                   dbnc => enc_b_dbnc );

    U_ENC : enc_decoder
        port map ( clk => clk,
                   A => enc_a_dbnc,
                   B => enc_b_dbnc,
                   btn => enc_btn,
                   cw => cw,
                   ccw => ccw,
                   press => open );

    U_TOUCH : cdc_touch
        port map ( clk => clk,
                   out1 => cdc_out1,
                   touch => touch );

    U_STITCH : stitch_ctrl
        port map ( clk => clk,
                   rst => rst,
                   cw => cw,
                   ccw => ccw,
                   stitch_inc => touch,
                   curr_st => curr_st,
                   next_st => next_st,
                   position => position,
                   pattern_done => done,
                   curr_color => curr_color,
                   next_color => next_color );

    U_OLED : oled_ctrl
        port map ( clk => clk, 
                   rst => rst,
                   curr_code => curr_st,
                   next_code => next_st,
                   curr_color => curr_color,
                   next_color => next_color,
                   position => position,
                   cs => oled_cs, sdin => oled_sdin, sclk => oled_sclk, dc => oled_dc,
                   res => oled_res, vbat => oled_vbat, vdd => oled_vdd );

    led <= done;

end structural;