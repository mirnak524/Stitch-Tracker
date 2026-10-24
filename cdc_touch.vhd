library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- standalone GPIO mode.
-- OUT1 goes HIGH when touch is detected, otherwise LOW

entity cdc_touch is
    port ( clk   : in  std_logic;
           out1  : in  std_logic;   -- raw OUT1 from button
           touch : out std_logic );
end cdc_touch;

architecture Behavioral of cdc_touch is

    -- 200 ms debounce
    constant TICKS : natural := 25000000; -- 200ms at 125MHz

    signal ff1, ff2     : std_logic := '0';
    signal prev, locked : std_logic := '0';
    signal count        : unsigned(24 downto 0) := (others => '0');

begin

    process(clk) begin
        if rising_edge(clk) then

            touch <= '0';

            -- flip-flip synchonizer
            ff1 <= out1;
            ff2 <= ff1;

            -- edge detect
            prev <= ff2;

            if locked = '0' then
                if ff2 = '1' and prev = '0' then
                    touch <= '1';
                    locked <= '1';
                    count <= (others => '0');
                end if;
            else
                if count = to_unsigned(TICKS - 1, 25) then 
                    locked <= '0';
                    count <= (others => '0');
                else
                    count <= count + 1;
                end if;
            end if;

        end if;
    end process;

end Behavioral;