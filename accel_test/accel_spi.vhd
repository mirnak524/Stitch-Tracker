library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- SPI mode 3: CPOL=1, CPHA=1
-- init seq: CS held low across both bytes of each write
--   write 0x08 to DATA_FORMAT (0x31) : full resolution
--   write 0x08 to POWER_CTL  (0x2D) : measurement mode
-- read seq:
--   send read command (0xF2) via SpiCtrl
--   take over CS/SCLK; clock in 48 MISO bits
-- done held high for DONE_HOLD clocks to cross into baud domain

entity accel_spi is
    port ( clk, spi_clk, rst : in  std_logic;
                        MISO : in  std_logic;
              CS, MOSI, SCLK : out std_logic;
                   accelData : out std_logic_vector(47 downto 0);
                        done : out std_logic );
end accel_spi;

architecture behavioral of accel_spi is

    component SpiCtrl
        port ( CLK      : in  std_logic;
               RST      : in  std_logic;
               SPI_EN   : in  std_logic;
               SPI_DATA : in  std_logic_vector(7 downto 0);
               CS       : out std_logic;
               SDO      : out std_logic;
               SCLK     : out std_logic;
               SPI_FIN  : out std_logic );
    end component;

    type init_array is array (0 to 3) of std_logic_vector(7 downto 0);
    constant INIT_SEQ : init_array := (
        x"31", x"08",   -- DATA_FORMAT <- 0x08
        x"2D", x"08"    -- POWER_CTL  <- 0x08
    );

    constant READ_CMD  : std_logic_vector(7 downto 0) := x"F2";
    constant DONE_HOLD : natural := 2048;

    type state is (init_load,  init_wait,         init_gap,
                   read_cmd_send, read_cmd_wait,  read_cmd_deassert,
                   read_bits,    read_done,        read_gap);
    signal curr : state := init_load;

    signal spi_en_r   : std_logic := '0';
    signal spi_data_r : std_logic_vector(7 downto 0) := (others => '0');
    signal spi_fin    : std_logic;
    signal spi_cs     : std_logic;
    signal spi_sdo    : std_logic;
    signal spi_sclk   : std_logic;

    -- '1': manual signals own CS/SCLK; '0': SpiCtrl owns them
    signal manual_cs   : std_logic := '1';
    signal manual_sclk : std_logic := '1';
    signal use_manual  : std_logic := '0';

    signal init_idx  : integer range 0 to 3  := 0;
    signal bit_cnt   : integer range 0 to 47 := 0;
    signal rx_shift  : std_logic_vector(47 downto 0) := (others => '0');
    signal gap_cnt   : integer range 0 to 15 := 0;
    signal done_cnt  : integer range 0 to DONE_HOLD := 0;
    signal done_reg  : std_logic := '0';

begin

    CS   <= manual_cs   when use_manual = '1' else spi_cs;
    SCLK <= manual_sclk when use_manual = '1' else spi_sclk;
    MOSI <= spi_sdo;
    done <= done_reg;

    U_SPI : SpiCtrl
        port map (
            CLK      => clk,
            RST      => rst,
            SPI_EN   => spi_en_r,
            SPI_DATA => spi_data_r,
            CS       => spi_cs,
            SDO      => spi_sdo,
            SCLK     => spi_sclk,
            SPI_FIN  => spi_fin
        );

    process(clk) begin
        if rising_edge(clk) then
            if rst = '1' then
                curr        <= init_load;
                init_idx    <= 0;
                bit_cnt     <= 0;
                gap_cnt     <= 0;
                done_cnt    <= 0;
                done_reg    <= '0';
                spi_en_r    <= '0';
                spi_data_r  <= (others => '0');
                use_manual  <= '0';
                manual_cs   <= '1';
                manual_sclk <= '1';
                rx_shift    <= (others => '0');
                accelData   <= (others => '0');

            else
                case curr is

                    when init_load =>
                        spi_data_r <= INIT_SEQ(init_idx);
                        spi_en_r   <= '1';
                        curr       <= init_wait;

                    when init_wait =>
                        if spi_fin = '1' then
                            if init_idx = 1 or init_idx = 3 then
                                -- value byte done: drop EN, CS rises
                                spi_en_r <= '0';
                                if init_idx = 3 then
                                    gap_cnt <= 0;
                                    curr    <= read_gap;
                                else
                                    gap_cnt <= 0;
                                    curr    <= init_gap;
                                end if;
                            else
                                -- addr byte done: load value, keep EN high so CS stays low
                                init_idx   <= init_idx + 1;
                                spi_data_r <= INIT_SEQ(init_idx + 1);
                                curr       <= init_wait;
                            end if;
                        end if;

                    -- 16 spi_clk ticks between register writes
                    when init_gap =>
                        if spi_clk = '1' then
                            if gap_cnt = 15 then
                                gap_cnt  <= 0;
                                init_idx <= init_idx + 1;
                                curr     <= init_load;
                            else
                                gap_cnt <= gap_cnt + 1;
                            end if;
                        end if;

                    when read_cmd_send =>
                        spi_data_r <= READ_CMD;
                        spi_en_r   <= '1';
                        curr       <= read_cmd_wait;

                    when read_cmd_wait =>
                        if spi_fin = '1' then
                            spi_en_r <= '0';
                            curr     <= read_cmd_deassert;
                        end if;

                    -- one cycle for SpiCtrl to return to idle; take over bus
                    when read_cmd_deassert =>
                        use_manual  <= '1';
                        manual_cs   <= '0';
                        manual_sclk <= '1';
                        bit_cnt     <= 0;
                        rx_shift    <= (others => '0');
                        curr        <= read_bits;

                    -- toggle SCLK each spi_clk tick; sample MISO on rising edge
                    when read_bits =>
                        if spi_clk = '1' then
                            manual_sclk <= not manual_sclk;
                            if manual_sclk = '0' then
                                rx_shift <= rx_shift(46 downto 0) & MISO;
                                if bit_cnt = 47 then
                                    curr <= read_done;
                                else
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            end if;
                        end if;

                    when read_done =>
                        manual_cs   <= '1';
                        manual_sclk <= '1';
                        accelData   <= rx_shift;
                        done_reg    <= '1';
                        done_cnt    <= 0;
                        curr        <= read_gap;

                    when read_gap =>
                        use_manual <= '0';
                        if done_reg = '1' then
                            if done_cnt = DONE_HOLD then
                                done_reg <= '0';
                                done_cnt <= 0;
                                curr     <= read_cmd_send;
                            else
                                done_cnt <= done_cnt + 1;
                            end if;
                        else
                            -- arriving from init: gap before first read
                            if spi_clk = '1' then
                                if gap_cnt = 15 then
                                    gap_cnt <= 0;
                                    curr    <= read_cmd_send;
                                else
                                    gap_cnt <= gap_cnt + 1;
                                end if;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
