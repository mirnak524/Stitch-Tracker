library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- waits for data, then transmits one 7-byte packet over UART
--  byte 0 : 0xFF (sync marker))
--  byte 1 : X_L
--  byte 2 : X_H
--  byte 3 : Y_L
--  byte 4 : Y_H
--  byte 5 : Z_L
--  byte 6 : Z_H

entity accel_sender is
    port (     clk, en, ready : in  std_logic;
    accel_x, accel_y, accel_z : in  std_logic_vector(15 downto 0);
                         send : out std_logic;
                         char : out std_logic_vector(7 downto 0) );
end accel_sender;

architecture behavioral of accel_sender is

    type state is (idle, busyA, busyB, busyC);
    signal curr : state := idle;

    -- 7 byte packet
    type accel_array is array (0 to 6) of std_logic_vector(7 downto 0);
    signal latch : accel_array;
    signal i : integer range 0 to 6 := 0;

    -- remember last X val to tell when packet send is done
    signal accel_x_prev : std_logic_vector(15 downto 0) := (others => '1');

begin

    process(clk) begin
        if rising_edge(clk) then
            if en = '1' then
                case curr is

                    -- wait for accel_x to change
                    when idle =>
                        if accel_x /= accel_x_prev and ready = '1' then
                            latch <= ( x"FF",
                                       accel_x( 7 downto 0),  -- X_L
                                       accel_x(15 downto 8),  -- X_H
                                       accel_y( 7 downto 0),  -- Y_L
                                       accel_y(15 downto 8),  -- Y_H
                                       accel_z( 7 downto 0),  -- Z_L
                                       accel_z(15 downto 8)); -- Z_H

                            accel_x_prev <= accel_x;
                            
                            send <= '1';
                            char <= x"FF";
                            i    <= 1;
                            curr <= busyA;
                        end if;

                    when busyA =>
                        curr <= busyB;

                    when busyB =>
                        send <= '0';
                        curr <= busyC;

                    when busyC =>
                        if ready = '1' then
                            if i > 6 then
                                i <= 0;
                                curr <= idle;
                            else
                                send <= '1';
                                char <= latch(i);
                                i <= i + 1;
                                curr <= busyA;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
