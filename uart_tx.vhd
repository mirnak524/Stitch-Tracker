library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    port ( clk, en, send, rst : in std_logic;
                     charSend : in std_logic_vector (7 downto 0);
                    ready, tx : out std_logic );
end uart_tx;

architecture fsm of uart_tx is

    -- state type enumeration and state variable
    type state is (idle, data);
    signal curr : state := idle;

    -- register to send data out
    signal d : std_logic_vector (9 downto 0) := (others => '0');
    
    -- counter for data state
    signal count : integer range 0 to 9 := 0;

begin
    process(clk) begin
        if rising_edge(clk) then
            -- resets the state machine and its outputs
            if rst = '1' then
                curr <= idle;
                d <= (others => '0');
                ready <= '1';
                tx <= '1';
                count <= 0;
            
            -- usual operation
            elsif en = '1' then
                case curr is
                    
                    when idle =>
                        ready <= '1';
                        tx <= '1';
                        if send = '1' then
                            curr <= data;
                            d <= '1' & charSend & '0';
                            count <= 0;
                        end if;

                    when data =>
                        ready <= '0';
                        tx <= d(count);
                        count <= count + 1; -- transmit stop bit first
                        if count = 9 then
                            curr <= idle;
                        -- else
                        --     count <= count + 1;
                        end if;

                    when others =>
                        curr <= idle;
                
                end case;
            end if;
        end if;
    end process;

end fsm;
