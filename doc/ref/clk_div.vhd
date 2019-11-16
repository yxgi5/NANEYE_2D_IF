--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  CLK_DIV
-- FILENAME:    clk_div.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--              tel:    +491637406294
--
-- CREATED:     15.01.2007
--------------------------------------------------------------------------------
-- DESCRIPTION: Clock Divider
--
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 15.01.2007   0.1        M. Heil     Initial version
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity CLK_DIV is
   generic (
      DIV:        integer:=16);
   port (
      RESET:      in  std_logic;
      CLOCK:      in  std_logic;
      ENABLE:     in  std_logic;
      PULSE:      out std_logic);
end entity CLK_DIV;


architecture RTL of CLK_DIV is

subtype T_CNT is integer range 0 to DIV-1;

signal I_CNT: T_CNT;
signal I_PULSE: std_logic;


begin

--------------------------------------------------------------------------------
-- Zähler
--------------------------------------------------------------------------------
CNT_PROC: process(RESET,CLOCK)
begin
   if (RESET = '1') then
      I_CNT <= 0;
  elsif (rising_edge(CLOCK)) then
      if (ENABLE = '1') then
         if (I_CNT = (DIV-1)) then
            I_CNT <= 0;
         else
            I_CNT <= I_CNT + 1;
         end if;
      else
         I_CNT <= 0;
      end if;
   end if;
end process CNT_PROC;


--------------------------------------------------------------------------------
-- Pulserzeugung bei Zählerwert CNT = 0
--------------------------------------------------------------------------------
FF_PROC: process(RESET,CLOCK)
begin
   if (RESET = '1') then
      I_PULSE <= '0';
   elsif (rising_edge(CLOCK)) then
      if (ENABLE = '1') then
         if (I_CNT = 0) then
            I_PULSE <= '1';
         else
            I_PULSE <= '0';
         end if;
      else
         I_PULSE <= '0';
      end if;
   end if;
end process FF_PROC;


PULSE <= I_PULSE;

end RTL;

