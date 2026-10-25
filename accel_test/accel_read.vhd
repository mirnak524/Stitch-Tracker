library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity accel_read is
    port ( clk, en, ready, newByte : in  std_logic;                    -- newByte is high when byteIn is valid
                            byteIn : in  std_logic_vector(7 downto 0); -- raw byte from accelerometer
                              send : out std_logic;                    -- to uart_tx
                           charOut : out std_logic_vector(7 downto 0); -- to uart_tx
                         byteIndex : out integer range 0 to 5 );       -- current byte index (0=X_L, 1=X_H, 2=Y_L, 3=Y_H, 4=Z_L, 5=Z_H) 
end accel_read;

architecture behavioral of accel_read is

        type state is (idle, busyA, busyB, busyC);
        signal curr : state := idle;

        signal index : integer range 0 to 5 := 0;

begin
    
    byteIndex <= index;

    process(clk) begin
        if rising_edge(clk) then
            if en = '1' then
                case curr is

                    when idle => 
                        if newByte = '1' then
                            curr <= busyA;
                            send <= '1';
                            charout <= byteIn;

                            -- advance byte index
                            if index = 5 then
                                index <= 0;
                            else
                                index <= index + 1;
                            end if;
                        end if;

                    -- hold send high for extra cycle
                    when busyA => 
                        curr <= busyB;

                    when busyB => 
                        curr <= busyC;
                        send <= '0';

                    when busyC => 
                        if ready = '1' then
                            curr <= idle;
                        end if;

                    when others => 
                        curr <= idle;

                end case;
            end if;
        end if;
    end process;
end behavioral;
