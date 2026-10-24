library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity oled_ctrl is
    port ( CLK        : in  STD_LOGIC;
           RST        : in  STD_LOGIC;
           curr_code  : in  STD_LOGIC_VECTOR(7 downto 0);
           next_code  : in  STD_LOGIC_VECTOR(7 downto 0);
           curr_color : in  STD_LOGIC_VECTOR(7 downto 0);
           next_color : in  STD_LOGIC_VECTOR(7 downto 0);
           position   : in  integer range 1 to 99;
           CS         : out STD_LOGIC;
           SDIN       : out STD_LOGIC;
           SCLK       : out STD_LOGIC;
           DC         : out STD_LOGIC;
           RES        : out STD_LOGIC;
           VBAT       : out STD_LOGIC;
           VDD        : out STD_LOGIC );
end oled_ctrl;

architecture Behavioral of oled_ctrl is

    -- Digilent components
    component SpiCtrl
        port ( CLK      : in  STD_LOGIC;
               RST      : in  STD_LOGIC;
               SPI_EN   : in  STD_LOGIC;
               SPI_DATA : in  STD_LOGIC_VECTOR(7 downto 0);
               CS       : out STD_LOGIC;
               SDO      : out STD_LOGIC;
               SCLK     : out STD_LOGIC;
               SPI_FIN  : out STD_LOGIC );
    end component;

    component Delay
        port ( CLK       : in  STD_LOGIC;
               RST       : in  STD_LOGIC;
               DELAY_MS  : in  STD_LOGIC_VECTOR(11 downto 0);
               DELAY_EN  : in  STD_LOGIC;
               DELAY_FIN : out STD_LOGIC );
    end component;

    component charLib
        port ( clka  : in  STD_LOGIC;
               ena   : in  STD_LOGIC;
               addra : in  STD_LOGIC_VECTOR(10 downto 0);
               douta : out STD_LOGIC_VECTOR(7 downto 0) );
    end component;

    -- Screen buffer
    type OledMem is array(0 to 3, 0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    signal current_screen : OledMem;

    -- States
    type states is (
        -- Init
        Idle,
        VddOn, Wait1, DispOff, ResetOn, Wait2, ResetOff,
        ChargePump1, ChargePump2, PreCharge1, PreCharge2,
        VbatOn, Wait3,
        DispContrast1, DispContrast2,
        InvertDisp1, InvertDisp2,
        ComConfig1, ComConfig2,
        DispOn,
        -- Display
        BuildScreen,
        UpdateScreen,
        ClearDC, SetPage, PageNum, LeftColumn1, LeftColumn2, SetDC,
        SendChar1, SendChar2, SendChar3, SendChar4,
        SendChar5, SendChar6, SendChar7, SendChar8,
        ReadMem, ReadMem2,
        WatchForChange,
        -- Shared
        Transition1, Transition2,
        Transition3, Transition4,
        Transition5
    );

    signal current_state     : states := Idle;
    signal after_state       : states;
    signal after_page_state  : states;
    signal after_char_state  : states;
    signal after_update_state: states;

    -- SPI / Delay / charLib signals
    -signal temp_spi_en   : STD_LOGIC := '0';
    signal temp_spi_data : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal temp_spi_fin  : STD_LOGIC;

    signal temp_delay_ms  : STD_LOGIC_VECTOR(11 downto 0);
    signal temp_delay_en  : STD_LOGIC := '0';
    signal temp_delay_fin : STD_LOGIC;

    signal temp_char : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal temp_addr : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
    signal temp_dout : STD_LOGIC_VECTOR(7 downto 0);

    signal temp_page  : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    signal temp_index : integer range 0 to 15 := 0;

    signal temp_dc   : STD_LOGIC := '0';
    signal temp_res  : STD_LOGIC := '1';
    signal temp_vbat : STD_LOGIC := '1';
    signal temp_vdd  : STD_LOGIC := '1';

    -- Change detection
    signal prev_code : STD_LOGIC_VECTOR(7 downto 0) := (others => '1');
    signal prev_pos  : integer range 1 to 99 := 1;

    -- Stitch code
    function code_hi (code : STD_LOGIC_VECTOR(7 downto 0))
            return STD_LOGIC_VECTOR is
    begin
        case code is
            when X"01"  => return X"43"; -- C (CH)
            when X"02"  => return X"53"; -- S (SC)
            when X"04"  => return X"44"; -- D (DC)
            when X"FF"  => return X"45"; -- E (EN)
            when others => return X"3F"; -- ?
        end case;
    end function;

    -- Stitch code
    function code_lo (code : STD_LOGIC_VECTOR(7 downto 0))
            return STD_LOGIC_VECTOR is
    begin
        case code is
            when X"01"  => return X"48"; -- H (CH)
            when X"02"  => return X"43"; -- C (SC)
            when X"04"  => return X"43"; -- C (DC)
            when X"FF"  => return X"4E"; -- N (EN)
            when others => return X"3F"; -- ?
        end case;
    end function;

    -- Color code 
    function color_char (color : STD_LOGIC_VECTOR(7 downto 0))
            return STD_LOGIC_VECTOR is
    begin
        case color is
            when X"01"  => return X"47"; -- G (green)
            when X"02"  => return X"57"; -- W (white)
            when others => return X"20"; -- space
        end case;
    end function;

    function tens_digit (n : integer range 1 to 99)
            return STD_LOGIC_VECTOR is
    begin
        return CONV_STD_LOGIC_VECTOR((n / 10) + 48, 8);
    end function;

    function ones_digit (n : integer range 1 to 99)
            return STD_LOGIC_VECTOR is
    begin
        return CONV_STD_LOGIC_VECTOR((n mod 10) + 48, 8);
    end function;

begin

    DC   <= temp_dc;
    RES  <= temp_res;
    VBAT <= temp_vbat;
    VDD  <= temp_vdd;

    -- 100ms delay after VbatOn, 1ms for everything else
    temp_delay_ms <= "000001100100" when (after_state = DispContrast1) else
                     "000000000001";

    SPI_COMP : SpiCtrl
        port map ( CLK      => CLK,  RST     => RST,
                   SPI_EN   => temp_spi_en,
                   SPI_DATA => temp_spi_data,
                   CS       => CS,   SDO     => SDIN,
                   SCLK     => SCLK, SPI_FIN => temp_spi_fin );

    DELAY_COMP : Delay
        port map ( CLK       => CLK,  RST       => RST,
                   DELAY_MS  => temp_delay_ms,
                   DELAY_EN  => temp_delay_en,
                   DELAY_FIN => temp_delay_fin );

    CHAR_LIB_COMP : charLib
        port map ( clka  => CLK,
                   ena   => '1',
                   addra => temp_addr,
                   douta => temp_dout );

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                current_state <= Idle;
                temp_res      <= '0';
                temp_vbat     <= '1';
                temp_vdd      <= '1';
                temp_spi_en   <= '0';
                temp_delay_en <= '0';
            else
                temp_res <= '1';

                case current_state is

                    -- INIT (from OledInit.vhd)
                    when Idle =>
                        temp_dc       <= '0';
                        current_state <= VddOn;

                    when VddOn =>
                        temp_vdd      <= '0';
                        current_state <= Wait1;

                    when Wait1 =>
                        after_state   <= DispOff;
                        current_state <= Transition3;

                    when DispOff =>
                        temp_spi_data <= X"AE";
                        after_state   <= ResetOn;
                        current_state <= Transition1;

                    when ResetOn =>
                        temp_res      <= '0';
                        current_state <= Wait2;

                    when Wait2 =>
                        after_state   <= ResetOff;
                        current_state <= Transition3;

                    when ResetOff =>
                        after_state   <= ChargePump1;
                        current_state <= Transition3;

                    when ChargePump1 =>
                        temp_spi_data <= X"8D";
                        after_state   <= ChargePump2;
                        current_state <= Transition1;

                    when ChargePump2 =>
                        temp_spi_data <= X"14";
                        after_state   <= PreCharge1;
                        current_state <= Transition1;

                    when PreCharge1 =>
                        temp_spi_data <= X"D9";
                        after_state   <= PreCharge2;
                        current_state <= Transition1;

                    when PreCharge2 =>
                        temp_spi_data <= X"F1";
                        after_state   <= VbatOn;
                        current_state <= Transition1;

                    when VbatOn =>
                        temp_vbat     <= '0';
                        current_state <= Wait3;

                    when Wait3 =>
                        after_state   <= DispContrast1;
                        current_state <= Transition3;

                    when DispContrast1 =>
                        temp_spi_data <= X"81";
                        after_state   <= DispContrast2;
                        current_state <= Transition1;

                    when DispContrast2 =>
                        temp_spi_data <= X"0F";
                        after_state   <= InvertDisp1;
                        current_state <= Transition1;

                    when InvertDisp1 =>
                        temp_spi_data <= X"A1";
                        after_state   <= InvertDisp2;
                        current_state <= Transition1;

                    when InvertDisp2 =>
                        temp_spi_data <= X"C8";
                        after_state   <= ComConfig1;
                        current_state <= Transition1;

                    when ComConfig1 =>
                        temp_spi_data <= X"DA";
                        after_state   <= ComConfig2;
                        current_state <= Transition1;

                    when ComConfig2 =>
                        temp_spi_data <= X"20";
                        after_state   <= DispOn;
                        current_state <= Transition1;

                    when DispOn =>
                        temp_spi_data <= X"AF";
                        after_state   <= BuildScreen;
                        current_state <= Transition1;

                    -- BUILD SCREEN
                    -- Row 0: "ROW N   "  
                    -- Row 1: "n XX C  "  (position, curr_code, curr_color)
                    -- Row 2: "n XX C  "  (position+1, next_code, next_color)
                    -- Row 3: blank
                    when BuildScreen =>

                        -- Row 0: R O W   N
                        current_screen(0,0)  <= X"52"; -- R
                        current_screen(0,1)  <= X"4F"; -- O
                        current_screen(0,2)  <= X"57"; -- W
                        current_screen(0,3)  <= X"20"; -- space
                        current_screen(0,4)  <= X"34"; -- N
                        current_screen(0,5)  <= X"20";
                        current_screen(0,6)  <= X"20";
                        current_screen(0,7)  <= X"20";
                        current_screen(0,8)  <= X"20";
                        current_screen(0,9)  <= X"20";
                        current_screen(0,10) <= X"20";
                        current_screen(0,11) <= X"20";
                        current_screen(0,12) <= X"20";
                        current_screen(0,13) <= X"20";
                        current_screen(0,14) <= X"20";
                        current_screen(0,15) <= X"20";

                        -- Row 1: tens ones space CH/SC/DC space G/W
                        current_screen(1,0)  <= tens_digit(position);
                        current_screen(1,1)  <= ones_digit(position);
                        current_screen(1,2)  <= X"20"; -- space
                        current_screen(1,3)  <= code_hi(curr_code);
                        current_screen(1,4)  <= code_lo(curr_code);
                        current_screen(1,5)  <= X"20"; -- space
                        current_screen(1,6)  <= color_char(curr_color);
                        current_screen(1,7)  <= X"20";
                        current_screen(1,8)  <= X"20";
                        current_screen(1,9)  <= X"20";
                        current_screen(1,10) <= X"20";
                        current_screen(1,11) <= X"20";
                        current_screen(1,12) <= X"20";
                        current_screen(1,13) <= X"20";
                        current_screen(1,14) <= X"20";
                        current_screen(1,15) <= X"20";

                        -- Row 2: position+1, next stitch, next color
                        -- clamp to 99 to stay in range
                        if position < 99 then
                            current_screen(2,0) <= tens_digit(position + 1);
                            current_screen(2,1) <= ones_digit(position + 1);
                        else
                            current_screen(2,0) <= X"39"; -- '9'
                            current_screen(2,1) <= X"39"; -- '9'
                        end if;
                        current_screen(2,2)  <= X"20";
                        current_screen(2,3)  <= code_hi(next_code);
                        current_screen(2,4)  <= code_lo(next_code);
                        current_screen(2,5)  <= X"20"; -- space
                        current_screen(2,6)  <= color_char(next_color);
                        current_screen(2,7)  <= X"20";
                        current_screen(2,8)  <= X"20";
                        current_screen(2,9)  <= X"20";
                        current_screen(2,10) <= X"20";
                        current_screen(2,11) <= X"20";
                        current_screen(2,12) <= X"20";
                        current_screen(2,13) <= X"20";
                        current_screen(2,14) <= X"20";
                        current_screen(2,15) <= X"20";

                        -- Row 3: blank
                        current_screen(3,0)  <= X"20"; current_screen(3,1)  <= X"20";
                        current_screen(3,2)  <= X"20"; current_screen(3,3)  <= X"20";
                        current_screen(3,4)  <= X"20"; current_screen(3,5)  <= X"20";
                        current_screen(3,6)  <= X"20"; current_screen(3,7)  <= X"20";
                        current_screen(3,8)  <= X"20"; current_screen(3,9)  <= X"20";
                        current_screen(3,10) <= X"20"; current_screen(3,11) <= X"20";
                        current_screen(3,12) <= X"20"; current_screen(3,13) <= X"20";
                        current_screen(3,14) <= X"20"; current_screen(3,15) <= X"20";

                        prev_code          <= curr_code;
                        prev_pos           <= position;
                        temp_page          <= "00";
                        after_page_state   <= UpdateScreen;
                        after_update_state <= WatchForChange;
                        current_state      <= ClearDC;

                    -- UPDATE SCREEN (mirrors OledExample)
                    when UpdateScreen =>
                        temp_char <= current_screen(CONV_INTEGER(temp_page), temp_index);
                        if temp_index = 15 then
                            temp_index       <= 0;
                            temp_page        <= temp_page + 1;
                            after_char_state <= ClearDC;
                            if temp_page = "11" then
                                after_page_state <= after_update_state;
                            else
                                after_page_state <= UpdateScreen;
                            end if;
                        else
                            temp_index       <= temp_index + 1;
                            after_char_state <= UpdateScreen;
                        end if;
                        current_state <= SendChar1;

                    when ClearDC =>
                        temp_dc       <= '0';
                        current_state <= SetPage;

                    when SetPage =>
                        temp_spi_data <= "00100010";
                        after_state   <= PageNum;
                        current_state <= Transition1;

                    when PageNum =>
                        temp_spi_data <= "000000" & temp_page;
                        after_state   <= LeftColumn1;
                        current_state <= Transition1;

                    when LeftColumn1 =>
                        temp_spi_data <= "00000000";
                        after_state   <= LeftColumn2;
                        current_state <= Transition1;

                    when LeftColumn2 =>
                        temp_spi_data <= "00010000";
                        after_state   <= SetDC;
                        current_state <= Transition1;

                    when SetDC =>
                        temp_dc       <= '1';
                        current_state <= after_page_state;

                    when SendChar1 =>
                        temp_addr     <= temp_char & "000";
                        after_state   <= SendChar2;
                        current_state <= ReadMem;

                    when SendChar2 =>
                        temp_addr     <= temp_char & "001";
                        after_state   <= SendChar3;
                        current_state <= ReadMem;

                    when SendChar3 =>
                        temp_addr     <= temp_char & "010";
                        after_state   <= SendChar4;
                        current_state <= ReadMem;

                    when SendChar4 =>
                        temp_addr     <= temp_char & "011";
                        after_state   <= SendChar5;
                        current_state <= ReadMem;

                    when SendChar5 =>
                        temp_addr     <= temp_char & "100";
                        after_state   <= SendChar6;
                        current_state <= ReadMem;

                    when SendChar6 =>
                        temp_addr     <= temp_char & "101";
                        after_state   <= SendChar7;
                        current_state <= ReadMem;

                    when SendChar7 =>
                        temp_addr     <= temp_char & "110";
                        after_state   <= SendChar8;
                        current_state <= ReadMem;

                    when SendChar8 =>
                        temp_addr     <= temp_char & "111";
                        after_state   <= after_char_state;
                        current_state <= ReadMem;

                    when ReadMem =>
                        current_state <= ReadMem2;

                    when ReadMem2 =>
                        temp_spi_data <= temp_dout;
                        current_state <= Transition1;

                    -- WATCH FOR CHANGE
                    when WatchForChange =>
                        if curr_code /= prev_code or position /= prev_pos then
                            temp_page          <= "00";
                            after_page_state   <= UpdateScreen;
                            after_update_state <= WatchForChange;
                            current_state      <= BuildScreen;
                        end if;

                    -- SHARED TRANSITIONS
                    when Transition1 =>
                        temp_spi_en   <= '1';
                        current_state <= Transition2;

                    when Transition2 =>
                        if temp_spi_fin = '1' then
                            current_state <= Transition5;
                        end if;

                    when Transition3 =>
                        temp_delay_en <= '1';
                        current_state <= Transition4;

                    when Transition4 =>
                        if temp_delay_fin = '1' then
                            current_state <= Transition5;
                        end if;

                    when Transition5 =>
                        temp_spi_en   <= '0';
                        temp_delay_en <= '0';
                        current_state <= after_state;

                    when others =>
                        current_state <= Idle;

                end case;
            end if;
        end if;
    end process;

end Behavioral;