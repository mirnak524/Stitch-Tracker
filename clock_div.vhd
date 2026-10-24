library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock_div is
    generic ( clk_freq : positive := 125000000; -- input frequency
              div_freq : positive := 2 );       -- desired frequency
    port    (     clk : in  std_logic;
                  div : out std_logic );
end clock_div;

architecture behavioral of clock_div is    
    -- returns the number of bits (value) needed to represent n
    function log2 (
        n : positive )
        return natural is
        variable     value : natural := n;
        variable bit_count : natural := 0;
    begin
        while value > 1 loop
            value := value / 2;
            bit_count := bit_count + 1;
        end loop;
        return bit_count;
    end function log2;
    
    constant BIT_WIDTH : natural := log2(clk_freq / div_freq ) + 1;
    constant COUNT_CAP : natural := (clk_freq / div_freq) - 1;
          
    signal  count : unsigned(BIT_WIDTH - 1 downto 0) := (others => '0');
    signal enable : std_logic := '0';

begin
    process (clk) 
    begin
        if rising_edge (clk) then        
            enable  <= '0';
            if (count = to_unsigned(COUNT_CAP, BIT_WIDTH)) then
                count  <= (others => '0');
                enable <= '1';
            else
                count <= count + 1;
            end if;
        end if;
    end process;
    div <= enable;
end behavioral;