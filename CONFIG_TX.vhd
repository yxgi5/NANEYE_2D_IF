--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  CONFIG_TX
-- FILENAME:    config_tx.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     18.02.2010
--------------------------------------------------------------------------------
-- DESCRIPTION: transmits configuration to the naneye2b sensor
--
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 19.02.2010   01         M. Heil     Initial version
-- 02.01.2011   02         M. Heil     START input asynchronous
-- 14.03.2012   03         M. Heil     Activation of TX_OE until the start of
--                                     the next frame
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
-- use WORK.SENSOR_PROPERTIES_PKG.all;


entity CONFIG_TX is
  generic (
    CLOCK_PERIOD_PS:            integer:=10000;                                 -- system clock period
    BIT_PERIOD_NS:              integer:=10000;                                 -- data rate
    C_NO_CFG_BITS:              integer:=24);                                   -- serial bits
  port (
    RESET:                      in  std_logic;                                  -- async. reset
    CLOCK:                      in  std_logic;                                  -- system clock
    START:                      in  std_logic;                                  -- start of transmission (async. pulse)
    LINE_PERIOD:                in  std_logic_vector(15 downto 0);              -- line period in # of CLOCK cycles
    INPUT:                      in  std_logic_vector(C_NO_CFG_BITS-1 downto 0); -- parallel tx data
    TX_END:                     out std_logic;                                  -- signals end of transmission (pulse)
    TX_DAT:                     out std_logic;                                  -- serial tx data => sensor
    TX_CLK:                     out std_logic;                                  -- shift clock => sensor
    TX_OE:                      out std_logic);                                 -- output enable for TX_DAT & TX_CLK
end entity CONFIG_TX;


architecture RTL of CONFIG_TX is

subtype T_BIT_CNT is            integer range 0 to C_NO_CFG_BITS;
--constant C_CLK_DIV:             integer:=((BIT_PERIOD_NS*1000) / (2*CLOCK_PERIOD_PS));
constant C_CLK_DIV:             integer:=((((BIT_PERIOD_NS*1000) / (2*CLOCK_PERIOD_PS))+1)/2)*2;

component CLK_DIV is
   generic (
      DIV:                      integer:=16);
   port (
      RESET:                    in  std_logic;
      CLOCK:                    in  std_logic;
      ENABLE:                   in  std_logic;
      PULSE:                    out std_logic);
end component CLK_DIV;


signal I_START_1:               std_logic;
signal I_START_2:               std_logic;
signal I_START_3:               std_logic;
signal I_START_P:               std_logic;
signal I_ENABLE:                std_logic;
signal I_PULSE:                 std_logic;
signal I_PULSE_1:               std_logic;
--signal I_PULSE_2:               std_logic;
--signal I_PULSE_3:               std_logic;
signal I_PULSE_P:               std_logic;
signal I_PULSE_N:               std_logic;
signal I_BIT_CNT:               T_BIT_CNT;
signal I_SREG:                  std_logic_vector(C_NO_CFG_BITS-1 downto 0);
--signal I_TX_CLK:                std_logic;
signal I_TX_OE:                 std_logic;
signal I_TX_OE_1:               std_logic;
signal I_CFG_PERIOD:            std_logic;
signal I_CFG_PERIOD_1:          std_logic;
signal I_CFG_PERIOD_CNT:        std_logic_vector(16 downto 0);
signal I_CFG_PERIOD_END:        std_logic_vector(16 downto 0);
signal I_SET_TX_CLK:            std_logic;


begin
--------------------------------------------------------------------------------
-- synchronization of START signal
--------------------------------------------------------------------------------
START_SYNC: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_START_1 <= '0';
    I_START_2 <= '0';
    I_START_3 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_START_1 <= START;
    I_START_2 <= I_START_1;
    I_START_3 <= I_START_2;
  end if;
end process START_SYNC;

I_START_P <= I_START_2 and not I_START_3;


--------------------------------------------------------------------------------
-- generation of divided clock
--------------------------------------------------------------------------------
I_CLK_DIV: CLK_DIV
   generic map (
      DIV                       => C_CLK_DIV)
   port map (
      RESET                     => RESET,
      CLOCK                     => CLOCK,
      ENABLE                    => I_ENABLE,
      PULSE                     => I_PULSE);


--------------------------------------------------------------------------------
-- synchronization of I_PULSE signal
--------------------------------------------------------------------------------
I_PULSE_SYNC: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_PULSE_1 <= '0';
    --I_PULSE_2 <= '0';
    --I_PULSE_3 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_PULSE_1 <= I_PULSE;
    --I_PULSE_2 <= I_PULSE_1;
    --I_PULSE_3 <= I_PULSE_2;
  end if;
end process I_PULSE_SYNC;

I_PULSE_P <= I_PULSE and not I_PULSE_1;
I_PULSE_N <= not I_PULSE and I_PULSE_1;

--------------------------------------------------------------------------------
-- Activate I_ENABLE after receiving a start-pulse
--------------------------------------------------------------------------------
ENABLE_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_ENABLE <= '0';
  elsif (rising_edge(CLOCK)) then
    -- if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_TX_CLK = '1') and (I_PULSE = '1')) then
    if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1')) then
      I_ENABLE <= '0';
    elsif (I_START_P = '1') then
      I_ENABLE <= '1';
    else
      I_ENABLE <= I_ENABLE;
    end if;
  end if;
end process ENABLE_EVAL;


--------------------------------------------------------------------------------
-- bit counter
--------------------------------------------------------------------------------
BIT_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_BIT_CNT <= 0;
  elsif (rising_edge(CLOCK)) then
    if (I_TX_OE = '1') then
      -- if ((I_TX_CLK = '1') and (I_PULSE = '1')) then
      if (I_PULSE_P = '1') then
        I_BIT_CNT <= I_BIT_CNT + 1;
      else
        I_BIT_CNT <= I_BIT_CNT;
      end if;
    else
      I_BIT_CNT <= 0;
    end if;
  end if;
end process BIT_CNT_EVAL;


--------------------------------------------------------------------------------
-- Shift register
--------------------------------------------------------------------------------
SREG_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_SREG <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_ENABLE = '0') then
      if (I_START_P = '1') then
        I_SREG <= INPUT;
      else
        I_SREG <= I_SREG;
      end if;
    else
      -- if ((I_PULSE = '1') and (I_TX_CLK = '1')) then
      if (I_PULSE_N = '1') then
        I_SREG(C_NO_CFG_BITS-1 downto 1) <= I_SREG(C_NO_CFG_BITS-2 downto 0);
        I_SREG(0) <= '0';
      else
        I_SREG <= I_SREG;
      end if;
    end if;
  end if;
end process SREG_EVAL;


--------------------------------------------------------------------------------
-- TX clock generation
--------------------------------------------------------------------------------
--TX_CLK_EVAL: process(RESET,CLOCK)
--begin
--  if (RESET = '1') then
--    I_TX_CLK <= '0';
--  elsif (rising_edge(CLOCK)) then
--    if (I_TX_OE = '1') then
--      if (I_PULSE = '1') then
--        I_TX_CLK <= not I_TX_CLK;
--      else
--        I_TX_CLK <= I_TX_CLK;
--      end if;
--    else
--      I_TX_CLK <= '0';
--    end if;
--  end if;
--end process TX_CLK_EVAL;


--------------------------------------------------------------------------------
-- TX output enable generation
--------------------------------------------------------------------------------
TX_OE_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_TX_OE <= '0';
    I_TX_OE_1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_TX_OE_1 <= I_TX_OE;
    -- if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_TX_CLK = '1') and (I_PULSE = '1')) then
    if ((I_BIT_CNT = C_NO_CFG_BITS-1) and (I_PULSE_N = '1')) then
      I_TX_OE <= '0';
    -- elsif ((I_ENABLE = '1') and (I_PULSE = '1')) then
    elsif ((I_ENABLE = '1') and (I_PULSE_P = '1')) then
      I_TX_OE <= '1';
    else
      I_TX_OE <= I_TX_OE;
    end if;
  end if;
end process TX_OE_EVAL;


--------------------------------------------------------------------------------
-- counter for determining the duration of the configuration period
--------------------------------------------------------------------------------
CFG_PERIOD_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD_CNT <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_CFG_PERIOD = '1') then
      I_CFG_PERIOD_CNT <= I_CFG_PERIOD_CNT + "01";
    else
      I_CFG_PERIOD_CNT <= (others => '0');
    end if;
  end if;
end process CFG_PERIOD_CNT_EVAL;


--------------------------------------------------------------------------------
-- I_CFG_END pipeleine register
--------------------------------------------------------------------------------
CFG_END_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD_END <= (others => '1');
  elsif (rising_edge(CLOCK)) then
    I_CFG_PERIOD_END <= LINE_PERIOD-x"120" & '0';
  end if;
end process CFG_END_EVAL;


--------------------------------------------------------------------------------
-- I_CFG_PERIOD signals that the configuration period is active
--------------------------------------------------------------------------------
CFG_PERIOD_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_PERIOD   <= '0';
    I_CFG_PERIOD_1 <= '0';
  elsif (rising_edge(CLOCK)) then
    I_CFG_PERIOD_1 <= I_CFG_PERIOD;
    if (I_START_P = '1') then
      I_CFG_PERIOD <= '1';
    elsif (I_CFG_PERIOD_CNT = I_CFG_PERIOD_END) then
      I_CFG_PERIOD <= '0';
    else
      I_CFG_PERIOD <= I_CFG_PERIOD;
    end if;
  end if;
end process CFG_PERIOD_EVAL;


--------------------------------------------------------------------------------
-- activate I_SET_TX_CLK at the end of the configuration phase
--------------------------------------------------------------------------------
SET_TX_CLK_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_SET_TX_CLK   <= '0';
  elsif (rising_edge(CLOCK)) then
    if (I_START_P = '1') then
      I_SET_TX_CLK <= '0';
    elsif (I_CFG_PERIOD_CNT = I_CFG_PERIOD_END-x"10") then
      I_SET_TX_CLK <= '1';
    else
      I_SET_TX_CLK <= I_SET_TX_CLK;
    end if;
  end if;
end process SET_TX_CLK_EVAL;


TX_END <= I_CFG_PERIOD_1 and not I_CFG_PERIOD;

TX_DAT <= I_SREG(C_NO_CFG_BITS-1);
-- TX_CLK <= I_TX_CLK or I_SET_TX_CLK;
TX_CLK <= I_PULSE or I_SET_TX_CLK;
TX_OE  <= I_CFG_PERIOD;

end RTL;

