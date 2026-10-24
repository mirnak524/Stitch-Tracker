library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Stitch codes:
--   0x01 = CH   (chain)
--   0x02 = SC   (single crochet)
--   0x04 = DC   (double crochet)
--   0xFF = END

-- Color codes:
--   0x01 = G    (green)
--   0x02 = W    (white)

entity stitch_ctrl is
    port ( clk, rst, cw, ccw : in  std_logic;
                   stitch_inc : in  std_logic;
                      curr_st : out std_logic_vector(7 downto 0);
                      next_st : out std_logic_vector(7 downto 0);
                     position : out integer range 1 to 99;
                 pattern_done : out std_logic;
                   curr_color : out std_logic_vector(7 downto 0);
                   next_color : out std_logic_vector(7 downto 0) );
end stitch_ctrl;

architecture Behavioral of stitch_ctrl is

    constant PATTERN_LEN : natural := 24;  -- 20 stitches + END + 3 padding

    type rom is array (0 to PATTERN_LEN - 1, 0 to 1) of std_logic_vector(7 downto 0);
    constant PATTERN : rom := (
        (x"02", x"01"),  -- 1:  SC, green
        (x"04", x"01"),  -- 2:  DC, green
        (x"04", x"01"),  -- 3:  DC, green
        (x"02", x"01"),  -- 4:  SC, green
        (x"02", x"02"),  -- 5:  SC, white
        (x"04", x"02"),  -- 6:  DC, white
        (x"04", x"02"),  -- 7:  DC, white
        (x"02", x"02"),  -- 8:  SC, white
        (x"02", x"01"),  -- 9:  SC, green
        (x"04", x"01"),  -- 10: DC, green
        (x"04", x"01"),  -- 11: DC, green
        (x"02", x"01"),  -- 12: SC, green
        (x"02", x"02"),  -- 13: SC, white
        (x"04", x"02"),  -- 14: DC, white
        (x"04", x"02"),  -- 15: DC, white
        (x"02", x"02"),  -- 16: SC, white
        (x"02", x"01"),  -- 17: SC, green
        (x"04", x"01"),  -- 18: DC, green
        (x"04", x"01"),  -- 19: DC, green
        (x"02", x"01"),  -- 20: SC, green
        (x"FF", x"00"),  -- END
        (x"FF", x"00"),  -- padding
        (x"FF", x"00"),  -- padding
        (x"FF", x"00")   -- padding
    );

    signal index : integer range 0 to PATTERN_LEN - 1 := 0;

begin

    curr_st      <= PATTERN(index, 0);
    next_st      <= PATTERN(index + 1, 0) when index < PATTERN_LEN - 1 else x"FF";
    curr_color   <= PATTERN(index, 1);
    next_color   <= PATTERN(index + 1, 1) when index < PATTERN_LEN - 1 else x"00";
    position     <= index + 1;
    pattern_done <= '1' when PATTERN(index, 0) = x"FF" else '0';

    process(clk) begin
        if rising_edge(clk) then
            if rst = '1' then
                index <= 0;
            else
                if (cw = '1' or stitch_inc = '1') then
                    if index < PATTERN_LEN - 1 then
                        if PATTERN(index, 0) /= x"FF" then
                            index <= index + 1;
                        end if;
                    end if;
                elsif ccw = '1' then
                    if index > 0 then
                        index <= index - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;