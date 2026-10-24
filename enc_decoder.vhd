-- 00 -> 01 -> 11 -> 10 : cw
-- 00 -> 10 -> 11 -> 01 : CCW
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity enc_decoder is
    port ( clk, A, B, btn : in  std_logic;
           cw, ccw, press : out std_logic );
end enc_decoder;

architecture Behavioral of enc_decoder is

    signal A_reg, B_reg : std_logic_vector(1 downto 0) := "00";
    -- signal AB_reg : std_logic_vector(3 downto 0) := "0000";
    signal btn_reg : std_logic_vector(1 downto 0) := "00";

    signal AB_prev : std_logic_vector(1 downto 0) := "00";
    signal btn_prev : std_logic := '0';

begin

    process(clk) begin
        if rising_edge(clk) then

            A_reg <= A_reg(0) & A;
            B_reg <= B_reg(0) & B;
            btn_reg <= btn_reg(0) & btn;

            cw <= '0';
            ccw <= '0';
            press <= '0';

            -- 00 -> 01 -> 11 -> 10 : CW (A rises when B is low)
            -- 00 -> 10 -> 11 -> 01 : CCW (A rises when B is high)
            -- swapping, during testing behavior was swapped
            if A_reg(1) = '0' and A_reg(0) = '1' then
                if B_reg(1) = '0' then 
                    -- cw <= '1';
                    ccw <= '1';
                else
                    -- ccw <= '1';
                    cw <= '1';
                end if;
            end if;

            if btn_reg(1) = '0' and btn_reg(0) = '1' then
                press <= '1';
            end if;

        end if;
    end process;

end Behavioral;
