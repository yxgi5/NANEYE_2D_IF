--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  CONFIG_REGS
-- FILENAME:    config_regs.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     24.10.2011
--------------------------------------------------------------------------------
-- DESCRIPTION: Saves a copy of the current contents of the NanEye's
--              configuratation registers
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 24.10.2011   01         M. Heil     Initial version
-- 09.03.2012   02         M. Heil     output for ROWS_IN_RESET added
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity CONFIG_REGS is
  generic (
    C_CADDR_W:                  integer:=3;                                     -- config address width
    C_CDATA_W:                  integer:=16);                                   -- config data width
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    NANEYE3A_NANEYE2B_N:        in  std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    -- control/data interface
    CONFIG_DATA_EN:             in  std_logic;                                  -- config data enable
    CONFIG_ADDR:                in  std_logic_vector(C_CADDR_W-1 downto 0);     -- config register address
    CONFIG_DATA:                in  std_logic_vector(C_CDATA_W-1 downto 0);     -- config register data
    -- register outputs
    ADC_MODE:                   out std_logic;                                  -- 0=10 bit unsigned, 1=11 bit signed
    MCLK_DIV:                   out std_logic;                                  -- 0=no division, 1=division by 2
    ROWS_DELAY_REG:             out std_logic_vector(6 downto 0);               -- ROWS_DELAY=2*ROWS_DELAY_REG+2
    ROWS_IN_RESET:              out std_logic_vector(7 downto 0));              -- content of ROWS IN RESET register
end entity CONFIG_REGS;


architecture RTL of CONFIG_REGS is


signal I_CFG_REG0:              std_logic_vector(15 downto 0):=x"8155";
signal I_CFG_REG1:              std_logic_vector(15 downto 0):=x"0000";


begin
--------------------------------------------------------------------------------
-- Configuration register 0 (NanEye3A)
--------------------------------------------------------------------------------
CFG_REG0_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    if (NANEYE3A_NANEYE2B_N = '0') then
      I_CFG_REG0 <= x"0202";
    else
      I_CFG_REG0 <= x"8155";
    end if;
  elsif (rising_edge(CLOCK)) then
    if ((CONFIG_DATA_EN = '1') and (CONFIG_ADDR = "000")) then
      I_CFG_REG0 <= CONFIG_DATA;
    else
      I_CFG_REG0 <= I_CFG_REG0;
    end if;
  end if;
end process CFG_REG0_EVAL;


--------------------------------------------------------------------------------
-- Configuration register 1 (NanEye3A)
--------------------------------------------------------------------------------
CFG_REG1_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_REG1 <= x"0000";
  elsif (rising_edge(CLOCK)) then
    if ((CONFIG_DATA_EN = '1') and (CONFIG_ADDR = "001")) then
      I_CFG_REG1 <= CONFIG_DATA;
    else
      I_CFG_REG1 <= I_CFG_REG1;
    end if;
  end if;
end process CFG_REG1_EVAL;


ADC_MODE <= I_CFG_REG0(2) when (NANEYE3A_NANEYE2B_N = '1') else '0';
MCLK_DIV <= I_CFG_REG1(8) when (NANEYE3A_NANEYE2B_N = '1') else '0';
ROWS_DELAY_REG <= I_CFG_REG1(15 downto 9) when (NANEYE3A_NANEYE2B_N = '1') else (others => '0');
ROWS_IN_RESET  <= '0' & I_CFG_REG0(15 downto 9) when (NANEYE3A_NANEYE2B_N = '1') else I_CFG_REG0(7 downto 0);

end RTL;
