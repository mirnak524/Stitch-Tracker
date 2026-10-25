library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- tb_accel_sender
--
-- Tests accel_sender in isolation by driving its inputs directly and
-- checking that it produces the correct 7-byte UART packet.
--
-- We do NOT simulate the full top level here because that would require
-- a fake SPI slave pretending to be an ADXL345, which is complex and
-- not useful for checking the logic we actually wrote.
--
-- What this testbench checks:
--
--   Test 1 - Normal packet
--     Give accel_sender a known X/Y/Z reading. Pretend to be uart_tx by
--     toggling ready. Capture every byte that comes out on char and verify
--     the order is: 0xFF, X_L, X_H, Y_L, Y_H, Z_L, Z_H.
--
--   Test 2 - No retransmit
--     Present the same X value again. Sender should stay in idle and not
--     send anything (because x_prev matches accel_x).
--
--   Test 3 - Second packet
--     Change X to a new value. Sender should fire a second packet with
--     the updated data.
--
--   Test 4 - Busy uart_tx
--     Change X but hold ready='0'. Sender should stay in idle until
--     ready goes high, then send normally.

entity tb_accel is
-- testbenches have no ports
end tb_accel;

architecture sim of tb_accel is

    -- ----------------------------------------------------------------
    -- Component under test
    -- ----------------------------------------------------------------
    component accel_sender
        port (
            clk     : in  std_logic;
            en      : in  std_logic;
            ready   : in  std_logic;
            accel_x : in  std_logic_vector(15 downto 0);
            accel_y : in  std_logic_vector(15 downto 0);
            accel_z : in  std_logic_vector(15 downto 0);
            send    : out std_logic;
            char    : out std_logic_vector(7 downto 0)
        );
    end component;

    -- ----------------------------------------------------------------
    -- Testbench signals (these are the wires we'll poke and watch)
    -- ----------------------------------------------------------------
    signal clk     : std_logic := '0';
    signal en      : std_logic := '0';
    signal ready   : std_logic := '1';
    signal accel_x : std_logic_vector(15 downto 0) := (others => '0');
    signal accel_y : std_logic_vector(15 downto 0) := (others => '0');
    signal accel_z : std_logic_vector(15 downto 0) := (others => '0');
    signal send    : std_logic;
    signal char    : std_logic_vector(7 downto 0);

    -- ----------------------------------------------------------------
    -- Clock period.
    -- Real system: 125 MHz = 8 ns period.
    -- We use a faster baud_en period in simulation so the test doesn't
    -- take millions of cycles.  accel_sender only advances when en='1',
    -- so we pulse en every 4 clock cycles instead of every 1085.
    -- ----------------------------------------------------------------
    constant CLK_PERIOD : time := 8 ns;

    -- ----------------------------------------------------------------
    -- Helper: pulse en for one clock cycle (simulates baud enable)
    -- ----------------------------------------------------------------
    procedure baud_tick(signal clk : in std_logic; signal en : out std_logic) is
    begin
        wait until rising_edge(clk);
        en <= '1';
        wait until rising_edge(clk);
        en <= '0';
    end procedure;

    -- ----------------------------------------------------------------
    -- Helper: simulate uart_tx accepting one byte.
    -- In the real system uart_tx holds ready='0' while it shifts out
    -- 10 bits at baud rate.  Here we just drop ready for a few ticks.
    -- Call this after you see send='1' to model the UART being busy.
    -- ----------------------------------------------------------------
    procedure uart_accept(signal clk   : in  std_logic;
                          signal en    : out std_logic;
                          signal ready : out std_logic) is
    begin
        -- ready goes low as uart_tx starts sending
        wait until rising_edge(clk);
        ready <= '0';
        en    <= '0';

        -- hold busy for 3 baud ticks (real: 10 bits worth)
        for k in 0 to 2 loop
            wait until rising_edge(clk);
            en <= '1';
            wait until rising_edge(clk);
            en <= '0';
        end loop;

        -- uart_tx done, ready goes high again
        wait until rising_edge(clk);
        ready <= '1';
    end procedure;

    -- add this after "architecture sim of tb_accel_sender is"
    -- before any signals are declared

    function slv_to_hex(s : std_logic_vector(7 downto 0)) return string is
        variable result : string(1 to 2);
        variable nibble : integer;
        constant hex : string := "0123456789ABCDEF";
    begin
        nibble := to_integer(unsigned(s(7 downto 4)));
        result(1) := hex(nibble + 1);
        nibble := to_integer(unsigned(s(3 downto 0)));
        result(2) := hex(nibble + 1);
        return result;
    end function;

begin

    -- ----------------------------------------------------------------
    -- Instantiate accel_sender
    -- ----------------------------------------------------------------
    UUT : accel_sender
        port map (
            clk     => clk,
            en      => en,
            ready   => ready,
            accel_x => accel_x,
            accel_y => accel_y,
            accel_z => accel_z,
            send    => send,
            char    => char
        );

    -- ----------------------------------------------------------------
    -- Clock generator: toggles every half period forever
    -- ----------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    -- ----------------------------------------------------------------
    -- Stimulus process
    -- ----------------------------------------------------------------
    stimulus : process begin

        -- give everything a few cycles to settle at reset values
        wait for 5 * CLK_PERIOD;

        -- ============================================================
        -- TEST 1: Normal packet
        -- Set X=0x1234, Y=0x5678, Z=0x9ABC and check all 7 bytes out
        -- ============================================================
        report "TEST 1: Normal packet";

        accel_x <= x"1234";   -- X_L=0x34, X_H=0x12
        accel_y <= x"5678";   -- Y_L=0x78, Y_H=0x56
        accel_z <= x"9ABC";   -- Z_L=0xBC, Z_H=0x9A

        -- tick en until send goes high (sender detects x changed)
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;

        -- byte 0: sync marker 0xFF
        assert char = x"FF"
            report "FAIL T1 byte0: expected FF got " & slv_to_hex(char)
            severity error;
        report "byte 0 = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 1: X low = 0x34
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"34"
            report "FAIL T1 byte1 X_L: expected 34 got " & slv_to_hex(char)
            severity error;
        report "byte 1 X_L = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 2: X high = 0x12
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"12"
            report "FAIL T1 byte2 X_H: expected 12 got " & slv_to_hex(char)
            severity error;
        report "byte 2 X_H = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 3: Y low = 0x78
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"78"
            report "FAIL T1 byte3 Y_L: expected 78 got " & slv_to_hex(char)
            severity error;
        report "byte 3 Y_L = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 4: Y high = 0x56
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"56"
            report "FAIL T1 byte4 Y_H: expected 56 got " & slv_to_hex(char)
            severity error;
        report "byte 4 Y_H = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 5: Z low = 0xBC
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"BC"
            report "FAIL T1 byte5 Z_L: expected BC got " & slv_to_hex(char)
            severity error;
        report "byte 5 Z_L = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- byte 6: Z high = 0x9A
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"9A"
            report "FAIL T1 byte6 Z_H: expected 9A got " & slv_to_hex(char)
            severity error;
        report "byte 6 Z_H = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        report "TEST 1 PASSED";
        wait for 5 * CLK_PERIOD;

        -- ============================================================
        -- TEST 2: No retransmit when X has not changed
        -- accel_x is still 0x1234 -- sender should stay in idle
        -- ============================================================
        report "TEST 2: No retransmit on same X value";

        -- tick en 10 times and check send never goes high
        for k in 0 to 9 loop
            baud_tick(clk, en);
            assert send = '0'
                report "FAIL T2: send went high but X did not change"
                severity error;
        end loop;

        report "TEST 2 PASSED";
        wait for 5 * CLK_PERIOD;

        -- ============================================================
        -- TEST 3: Second packet after X changes
        -- ============================================================
        report "TEST 3: Second packet with new data";

        accel_x <= x"AABB";
        accel_y <= x"CCDD";
        accel_z <= x"EEFF";

        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;

        assert char = x"FF"
            report "FAIL T3 byte0: expected FF got " & slv_to_hex(char)
            severity error;
        report "T3 byte 0 = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- just check X_L and X_H to confirm new data was latched
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"BB"
            report "FAIL T3 byte1 X_L: expected BB got " & slv_to_hex(char)
            severity error;
        report "T3 byte 1 X_L = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;
        assert char = x"AA"
            report "FAIL T3 byte2 X_H: expected AA got " & slv_to_hex(char)
            severity error;
        report "T3 byte 2 X_H = 0x" & slv_to_hex(char);
        uart_accept(clk, en, ready);

        -- flush remaining 4 bytes without checking (already verified format in T1)
        for b in 0 to 3 loop
            for k in 0 to 9 loop
                baud_tick(clk, en);
                if send = '1' then exit; end if;
            end loop;
            uart_accept(clk, en, ready);
        end loop;

        report "TEST 3 PASSED";
        wait for 5 * CLK_PERIOD;

        -- ============================================================
        -- TEST 4: UART busy -- sender should wait, not drop data
        -- ============================================================
        report "TEST 4: Sender waits when uart_tx is busy";

        accel_x <= x"0001";   -- new value so sender will try to send
        ready   <= '0';        -- uart_tx is busy right now

        -- tick en several times -- send should NOT go high
        for k in 0 to 9 loop
            baud_tick(clk, en);
            assert send = '0'
                report "FAIL T4: send went high while ready was low"
                severity error;
        end loop;

        -- now free up uart_tx
        ready <= '1';

        -- sender should now fire
        for k in 0 to 9 loop
            baud_tick(clk, en);
            if send = '1' then exit; end if;
        end loop;

        assert send = '1'
            report "FAIL T4: send never went high after ready went high"
            severity error;
        assert char = x"FF"
            report "FAIL T4 byte0: expected FF got " & slv_to_hex(char)
            severity error;

        report "TEST 4 PASSED";

        -- ============================================================
        -- Done
        -- ============================================================
        report "ALL TESTS PASSED";
        wait; -- stop simulation
    end process;

end sim;