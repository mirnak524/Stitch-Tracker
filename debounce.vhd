library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce is
    port (  clk : in  std_logic;
            btn : in  std_logic;
           dbnc : out std_logic );
end debounce;

architecture behavioral of debounce is
    constant TICK_CAP : natural := 2499999;
    
    signal shft_reg : std_logic_vector(1 downto 0) := (others => '0');
    signal    ticks : unsigned(21 downto 0) := (others => '0');
    signal    press : std_logic := '0';

begin
    process (clk) 
    begin
        if rising_edge (clk) then        
            shft_reg <= shft_reg(0) & btn;            
            if shft_reg(1) = '1' then
                if ticks = to_unsigned(TICK_CAP, 22) then
                    press <= '1';
                else
                    ticks <= ticks + 1;
                    press <= '0';
                end if;
            else 
                ticks <= (others => '0');
                press <= '0';
            end if;
        end if;
    end process;
    dbnc <= press;
end behavioral;