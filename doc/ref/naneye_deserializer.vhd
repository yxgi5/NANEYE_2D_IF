--------------------------------------------------------------------------------
-- AWAIBA GmbH
--------------------------------------------------------------------------------
-- MODUL NAME:  NANEYE_DESERIALIZER
-- FILENAME:    naneye_deserializer.vhd
-- AUTHOR:      Michael Heil - Ing. Büro für FPGA-Logic-Design
--              email:  michael.heil@fpga-logic-design.de
--
-- CREATED:     12.11.2009
--------------------------------------------------------------------------------
-- DESCRIPTION: Top level module for NANEYE_DESERIALIZER
--
--
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- REVISIONS:
-- DATE         VERSION    AUTHOR      DESCRIPTION
-- 04.12.2009   01         M. Heil     Initial version
-- 23.02.2010   02         M. Heil     Debug functions added
-- 25.03.2010   03         M. Heil     Communication with usb-board added
-- 01.01.2011   04         M. Heil     Integration of new decoder-module
-- 02.01.2011   05         M. Heil     Modifications for cesys efm 01-board
-- 01.12.2011   06         M. Heil     Modifications for NanEye3A
-- 09.03.2012   07         M. Heil     Workaround for NanEye2C
-- 05.11.2013   08         M. Heil     config_tx clocked with CLOCK, rx_decoder+
--                                     rx_deserializer reworked, new sub-module
--                                     LINE_PERIOD_CALC
-- 29.01.2016   09         R. Sousa    V_SYNC forced low if sensor is disconnected                                    
--------------------------------------------------------------------------------

library IEEE,UNISIM;
use IEEE.STD_LOGIC_1164.all;
use WORK.SENSOR_PROPERTIES_PKG.all;
use WORK.FUNCTIONS_PKG.all;
use UNISIM.VCOMPONENTS.all;


entity NANEYE_DESERIALIZER is
  generic (
    SIMULATION:                 boolean:=false;                                 -- simulation mode yes/no
    G_CLOCK_PERIOD_PS:          integer:=20833;                                 -- CLOCK period in ps
    G_SCLOCK_PERIOD_PS:         integer:=5555;                                  -- SCLOCK period in ps
    G_PDATA_W:                  integer:=10;                                    -- pixel data width
    G_CADDR_W:                  integer:=3;                                     -- configuration address width
    G_CDATA_W:                  integer:=16);                                   -- configuration data width
  port (
    RESET:                      in    std_logic;                                -- asynchronous reset
    CLOCK:                      in    std_logic;                                -- system clock
    SCLOCK:                     in    std_logic;                                -- sampling clock
    -- control/status signals
    NANEYE3A_NANEYE2B_N:        out   std_logic;                                -- '1'=NANEYE3A, '0'=NANEYE2B
    -- sensor control interface
    CONFIG_DATA_EN:             in    std_logic;                                -- CONFIG_DATA+CONFIG_ADDR valid
    CONFIG_ADDR:                in    std_logic_vector(G_CADDR_W-1 downto 0);   -- sensor register address
    CONFIG_DATA:                in    std_logic_vector(G_CDATA_W-1 downto 0);   -- sensor register data
    -- data interface
    PIXEL_DATA:                 out   std_logic_vector(G_PDATA_W-1 downto 0);   -- pixel data
    FVAL:                       out   std_logic;                                -- frame valid
    LVAL:                       out   std_logic;                                -- line valid
    -- image sensor interface
    SENSOR_IN:                  in    std_logic;                                -- serial sensor data
    CFG_TX_OE_N:                out   std_logic;                                -- output enable for CFG_TX_DAT+CFG_TX_CLK
    CFG_TX_DAT:                 out   std_logic;                                -- serial configuration data to the sensor
    CFG_TX_CLK:                 out   std_logic;                                -- shift clock for the serial configuration
    -- NanEye2C specific
    BREAK_N:                    out   std_logic_vector(1 downto 0);             -- modulate supply voltage
    DEBUG_O:                    out   std_logic_vector(31 downto 0));
end entity NANEYE_DESERIALIZER;


architecture RTL of NANEYE_DESERIALIZER is

component RX_DECODER is
  generic (
    G_CLOCK_PERIOD_PS:          integer:= 5555);                                -- CLOCK period in ps
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- sampling clock
    ENABLE:                     in  std_logic;                                  -- module activation
    RSYNC:                      in  std_logic;                                  -- resynchronize decoder
    INPUT:                      in  std_logic;                                  -- manchester coded input
    CONFIG_DONE:                in  std_logic;                                  -- end of config phase (async)
    CONFIG_EN:                  out std_logic;                                  -- start of config phase
    SYNC_START:                 out std_logic;                                  -- start of synchronisation phase
    FRAME_START:                out std_logic;                                  -- start of frame
    OUTPUT:                     out std_logic;                                  -- decoded data
    OUTPUT_EN:                  out std_logic;                                  -- output data valid
    NANEYE3A_NANEYE2B_N:        out std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    ERROR_OUT:                  out std_logic;                                  -- decoder error
    DEBUG_OUT:                  out std_logic_vector(31 downto 0));             -- debug outputs
end component RX_DECODER;


component RX_DESERIALIZER is
  generic (
    C_ROWS:                     integer:=250;                                   -- number of rows per frame
    C_COLUMNS:                  integer:=250);                                  -- number of columns per line
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    NANEYE3A_NANEYE2B_N:        in  std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAME_START:                in  std_logic;                                  -- frame start pulse
    SER_INPUT:                  in  std_logic;                                  -- serial input data
    SER_INPUT_EN:               in  std_logic;                                  -- input data valid
    DEC_RSYNC:                  out std_logic;                                  -- resynchronize decoder
    PAR_OUTPUT:                 out std_logic_vector(11 downto 0);              -- parallel output data
    PAR_OUTPUT_EN:              out std_logic;                                  -- output data valid
    PIXEL_ERROR:                out std_logic;                                  -- start/stop bit error
    LINE_END:                   out std_logic;                                  -- signals end of one line
    ERROR_OUT:                  out std_logic;                                  -- start/stop error
    DEBUG_OUT:                  out std_logic_vector(15 downto 0));             -- debug outputs
end component RX_DESERIALIZER;


component LINE_PERIOD_CALC is
  generic (
    G_CLOCK_PERIOD_PS:          integer:=20833;                                 -- CLOCK period in ps
    G_LINE_PERIOD_MIN_NS:       integer:=50000;                                 -- shortest possible time for one line
    G_LINE_PERIOD_MAX_NS:       integer:=120000);                               -- longest possible time for one line
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    SCLOCK:                     in  std_logic;                                  -- sampling clock
    FRAME_START:                in  std_logic;                                  -- frame start from decoder
    PAR_DATA_EN:                in  std_logic;                                  -- deserialized word available from deserializer
    PIXEL_ERROR:                in  std_logic;                                  -- pixel error from deserializer
    LINE_END:                   in  std_logic;                                  -- line end pulse from deserializer
    LINE_PERIOD:                out std_logic_vector(15 downto 0));             -- line period in # of CLOCK cycles
end component LINE_PERIOD_CALC;


component DPRAM is
  generic (
    A_WIDTH:                    integer:=4;
    D_WIDTH:                    integer:=16);
  port (
    CLKA:                       in  std_logic;
    CLKB:                       in  std_logic;
    ENA:                        in  std_logic;
    ENB:                        in  std_logic;
    WEA:                        in  std_logic;
    WEB:                        in  std_logic;
    ADDRA:                      in  std_logic_vector(A_WIDTH-1 downto 0);
    ADDRB:                      in  std_logic_vector(A_WIDTH-1 downto 0);
    DIA:                        in  std_logic_vector(D_WIDTH-1 downto 0);
    DIB:                        in  std_logic_vector(D_WIDTH-1 downto 0);
    DOA:                        out std_logic_vector(D_WIDTH-1 downto 0);
    DOB:                        out std_logic_vector(D_WIDTH-1 downto 0));
end component DPRAM;


component DPRAM_WR_CTRL is
  generic (
    C_ADDR_W:                   integer:=9);                                    -- address output width
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    CLOCK:                      in  std_logic;                                  -- system clock
    PULSE:                      in  std_logic;                                  -- address increment pulse
    PIXEL_ERROR:                in  std_logic;                                  -- start/stop bit error
    LINE_SYNC:                  in  std_logic;                                  -- line sync input
    FRAME_SYNC:                 in  std_logic;                                  -- frame sync input
    DPRAM_WR_ADDR:              out std_logic_vector(C_ADDR_W-1 downto 0);      -- dpram write address
    DPRAM_WE:                   out std_logic;                                  -- dpram write enable
    DPRAM_RD_PAGE:              out std_logic;                                  -- dpram read page select
    LINE_FINISHED:              out std_logic);                                 -- line finished
end component DPRAM_WR_CTRL;


component DPRAM_RD_CTRL is
  generic (
    C_ROWS:                     integer:=250;                                   -- number of rows per frame
    C_COLUMNS:                  integer:=250;                                   -- number of columns per line
    C_ADDR_W:                   integer:=9);                                    -- address output width
  port (
    RESET:                      in  std_logic;                                  -- async. Reset
    SCLOCK:                     in  std_logic;                                  -- system clock
    CLOCK:                      in  std_logic;                                  -- readout clock
    NANEYE3A_NANEYE2B_N:        in  std_logic;                                  -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAMING_ERROR:              in  std_logic;                                  -- frame sync error (sync to sclk)
    FRAME_START:                in  std_logic;                                  -- start of frame (sync to sclk)
    LINE_FINISHED:              in  std_logic;                                  -- end of line (sync to sclk)
    DPRAM_RD_PAGE:              in  std_logic;                                  -- page select signal (sync to sclk)
    DPRAM_RD_ADDR:              out std_logic_vector(C_ADDR_W-1 downto 0);      -- dpram read address
    DPRAM_RDAT_VALID:           out std_logic;                                  -- signals valid DPRAM read data
    H_SYNC:                     out std_logic;                                  -- horizontal sync
    V_SYNC:                     out std_logic);                                 -- vertical sync
end component DPRAM_RD_CTRL;


component CONFIG_TX is
  generic (
    CLOCK_PERIOD_PS:            integer:=10000;                                 -- system clock period
    BIT_PERIOD_NS:              integer:=10000);                                -- data rate
  port (
    RESET:                      in  std_logic;                                  -- async. reset
    CLOCK:                      in  std_logic;                                  -- system clock
    START:                      in  std_logic;                                  -- start of transmission (pulse)
    LINE_PERIOD:                in  std_logic_vector(15 downto 0);              -- line period in # of CLOCK cycles
    INPUT:                      in  std_logic_vector(C_NO_CFG_BITS-1 downto 0); -- parallel tx data
    TX_END:                     out std_logic;                                  -- signals end of transmission (pulse)
    TX_DAT:                     out std_logic;                                  -- serial tx data => sensor
    TX_CLK:                     out std_logic;                                  -- shift clock => sensor
    TX_OE:                      out std_logic);                                 -- output enable for TX_DAT & TX_CLK
end component CONFIG_TX;


component CONFIG_REGS is
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
end component CONFIG_REGS;


constant C_ROWS:                integer:=250;
constant C_COLUMNS:             integer:=250;
constant C_ADC_UNSIGNED:        std_logic:='0';
constant C_ADC_SIGNED:          std_logic:='1';
constant C_DPRAM_DWIDTH:        integer:=16;

subtype T_CNT is integer range 0 to integer'high;

signal I_SCLK:                  std_logic;
signal I_SCLK_N:                std_logic;
signal I_DECODER_OUT:           std_logic;
signal I_DECODER_OUT_EN:        std_logic;
signal I_NANEYE3A_NANEYE2B_N:   std_logic;
signal I_DECODER_RSYNC:         std_logic;
signal I_SYNC_START:            std_logic;
signal I_FRAME_START:           std_logic;
signal I_CONFIG_EN:             std_logic;
signal I_PAR_SENSOR_DATA:       std_logic_vector(11 downto 0);
signal I_PAR_SENSOR_DATA_EN:    std_logic;
signal I_LINE_END:              std_logic;
signal I_LINE_PERIOD:           std_logic_vector(15 downto 0);
signal I_PIXEL_ERROR:           std_logic;
signal I_DPRAM_RDAT_VALID:      std_logic;
signal I_DPRAM_WE:              std_logic;
signal I_DPRAM_DOA:             std_logic_vector(C_DPRAM_DWIDTH-1 downto 0);
signal I_DPRAM_DIB:             std_logic_vector(C_DPRAM_DWIDTH-1 downto 0);
signal I_DPRAM_ADDRA:           std_logic_vector(log2(C_COLUMNS) downto 0);
signal I_DPRAM_ADDRB:           std_logic_vector(log2(C_COLUMNS) downto 0);
signal I_DPRAM_RD_PAGE:         std_logic;
signal I_READOUT_START:         std_logic;
signal I_FRAME_CNT:             std_logic_vector(2 downto 0);
signal I_H_SYNC:                std_logic;
signal I_V_SYNC:                std_logic;
signal I_PIXEL_DATA:            std_logic_vector(G_PDATA_W-1 downto 0);
-- sensor configuration
signal I_CFG_DONE:              std_logic;
signal I_CFG_DATA:              std_logic_vector(C_NO_CFG_BITS-1 downto 0);
signal I_CFG_TX_DAT:            std_logic;
signal I_CFG_TX_CLK:            std_logic;
signal I_CFG_TX_OE:             std_logic;
-- internal register values of the sensor
signal I_ADC_MODE:              std_logic;
signal I_MCLK_DIV:              std_logic;
signal I_ROWS_DELAY_REG:        std_logic_vector(6 downto 0);
signal I_ROWS_IN_RESET:         std_logic_vector(7 downto 0);
-- workaround for NanEye2C/2D
signal I_BREAK0_N:              std_logic;
signal I_BREAK1_N:              std_logic;
-- evaluate if sensor is disconnected
signal I_VSYNC_CNT:             T_CNT;
signal I_VSYNC_SEL:             std_logic;



begin

I_RX_DECODER: RX_DECODER
  generic map (
    G_CLOCK_PERIOD_PS           => G_SCLOCK_PERIOD_PS)                          -- CLOCK period in ps
  port map (
    RESET                       => RESET,                                       -- async. Reset
    CLOCK                       => SCLOCK,                                      -- sampling clock
    ENABLE                      => '1',                                         -- module activation
    RSYNC                       => I_DECODER_RSYNC,                             -- resynchronize decoder
    INPUT                       => SENSOR_IN,                                   -- manchester coded input
    CONFIG_DONE                 => I_CFG_DONE,                                  -- end of config phase (async)
    CONFIG_EN                   => I_CONFIG_EN,                                 -- start of config phase
    SYNC_START                  => I_SYNC_START,                                -- start of synchronisation phase
    FRAME_START                 => I_FRAME_START,                               -- start of frame
    OUTPUT                      => I_DECODER_OUT,                               -- decoded data
    OUTPUT_EN                   => I_DECODER_OUT_EN,                            -- output data valid
    NANEYE3A_NANEYE2B_N         => I_NANEYE3A_NANEYE2B_N,                       -- '0'=NANEYE2B, '1'=NANEYE3A
    ERROR_OUT                   => open,                                        -- decoder error
    DEBUG_OUT                   => open);                                       -- debug outputs


I_RX_DESERIALIZER: RX_DESERIALIZER
  generic map (
    C_ROWS                      => C_ROWS,                                      -- number of rows per frame
    C_COLUMNS                   => C_COLUMNS)                                   -- number of columns per line
  port map (
    RESET                       => RESET,                                       -- async. Reset
    CLOCK                       => SCLOCK,                                      -- system clock
    NANEYE3A_NANEYE2B_N         => I_NANEYE3A_NANEYE2B_N,                       -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAME_START                 => I_FRAME_START,                               -- frame start pulse
    SER_INPUT                   => I_DECODER_OUT,                               -- serial input data
    SER_INPUT_EN                => I_DECODER_OUT_EN,                            -- input data valid
    DEC_RSYNC                   => I_DECODER_RSYNC,                             -- resynchronize decoder
    PAR_OUTPUT                  => I_PAR_SENSOR_DATA,                           -- parallel output data
    PAR_OUTPUT_EN               => I_PAR_SENSOR_DATA_EN,                        -- output data valid
    PIXEL_ERROR                 => I_PIXEL_ERROR,                               -- start/stop bit error
    LINE_END                    => I_LINE_END,                                  -- signals end of one line
    ERROR_OUT                   => open,                                        -- start/stop error (pulse)
    DEBUG_OUT                   => open);                                       -- debug outputs


I_LINE_PERIOD_CALC: LINE_PERIOD_CALC
  generic map (
    G_CLOCK_PERIOD_PS           => G_CLOCK_PERIOD_PS,                           -- CLOCK period in ps
    G_LINE_PERIOD_MIN_NS        => 50000,                                       -- shortest possible time for one line
    G_LINE_PERIOD_MAX_NS        => 120000)                                      -- longest possible time for one line
  port map (
    RESET                       => RESET,                                       -- async. Reset
    CLOCK                       => CLOCK,                                       -- system clock
    SCLOCK                      => SCLOCK,                                      -- sampling clock
    FRAME_START                 => I_FRAME_START,                               -- frame start from decoder
    PAR_DATA_EN                 => I_PAR_SENSOR_DATA_EN,                        -- deserialized word available from deserializer
    PIXEL_ERROR                 => I_PIXEL_ERROR,                               -- pixel error from deserializer
    LINE_END                    => I_LINE_END,                                  -- line end pulse from deserializer
    LINE_PERIOD                 => I_LINE_PERIOD);                              -- line period in # of CLOCK cycles


--------------------------------------------------------------------------------
-- dpram write data
--------------------------------------------------------------------------------
DPRAM_DIB_EVAL: process(I_PAR_SENSOR_DATA,I_ADC_MODE)
begin
  if ((I_NANEYE3A_NANEYE2B_N = '0') or (I_ADC_MODE = C_ADC_UNSIGNED)) then      -- NanEye2B, NanEye3A unsigned
    I_DPRAM_DIB(C_DPRAM_DWIDTH-1 downto 10) <= (others => '0');
    I_DPRAM_DIB(9 downto 0) <= I_PAR_SENSOR_DATA(10 downto 1);
  else                                                                          -- NanEye3A signed
    I_DPRAM_DIB(C_DPRAM_DWIDTH-1 downto 12) <= (others => '0');
    I_DPRAM_DIB(11 downto 0) <= I_PAR_SENSOR_DATA;
  end if;
end process DPRAM_DIB_EVAL;


I_DPRAM: DPRAM
  generic map (
    A_WIDTH                     => log2(C_COLUMNS)+1,
    D_WIDTH                     => C_DPRAM_DWIDTH)
  port map (
    CLKA                        => CLOCK,
    CLKB                        => SCLOCK,
    ENA                         => '1',
    ENB                         => '1',
    WEA                         => '0',
    WEB                         => I_DPRAM_WE,
    ADDRA                       => I_DPRAM_ADDRA,
    ADDRB                       => I_DPRAM_ADDRB,
    DIA                         => x"0000",
    DIB                         => I_DPRAM_DIB,
    DOA                         => I_DPRAM_DOA,
    DOB                         => open);


I_DPRAM_WR_CTRL: DPRAM_WR_CTRL
  generic map (
    C_ADDR_W                    => 9)                                           -- address output width
  port map (
    RESET                       => RESET,                                       -- async. Reset
    CLOCK                       => SCLOCK,                                      -- system clock
    PULSE                       => I_PAR_SENSOR_DATA_EN,                        -- address increment pulse
    PIXEL_ERROR                 => I_PIXEL_ERROR,                               -- start/stop bit error
    LINE_SYNC                   => I_LINE_END,                                  -- line sync input
    FRAME_SYNC                  => I_FRAME_START,                               -- frame sync input
    DPRAM_WR_ADDR               => I_DPRAM_ADDRB,                               -- dpram write address
    DPRAM_WE                    => I_DPRAM_WE,                                  -- dpram write enable
    DPRAM_RD_PAGE               => I_DPRAM_RD_PAGE,                             -- dpram read page select
    LINE_FINISHED               => I_READOUT_START);                            -- line finished


I_DPRAM_RD_CTRL: DPRAM_RD_CTRL
  generic map (
    C_ROWS                      => C_ROWS,                                      -- number of rows per frame
    C_COLUMNS                   => C_COLUMNS,                                   -- number of columns per line
    C_ADDR_W                    => 9)                                           -- address output width
  port map (
    RESET                       => RESET,                                       -- async. Reset
    SCLOCK                      => SCLOCK,                                      -- system clock
    CLOCK                       => CLOCK,                                       -- readout clock
    NANEYE3A_NANEYE2B_N         => I_NANEYE3A_NANEYE2B_N,                       -- '0'=NANEYE2B, '1'=NANEYE3A
    FRAMING_ERROR               => '0',                                         -- frame sync error (sync to sclk)
    FRAME_START                 => I_FRAME_START,                               -- start of frame (sync to sclk)
    LINE_FINISHED               => I_READOUT_START,                             -- end of line (sync to sclk)
    DPRAM_RD_PAGE               => I_DPRAM_RD_PAGE,                             -- page select signal (sync to sclk)
    DPRAM_RD_ADDR               => I_DPRAM_ADDRA,                               -- dpram read address
    DPRAM_RDAT_VALID            => I_DPRAM_RDAT_VALID,                          -- signals valid DPRAM read data
    H_SYNC                      => I_H_SYNC,                                    -- horizontal sync
    V_SYNC                      => I_V_SYNC);                                   -- vertical sync


--------------------------------------------------------------------------------
-- sensor configuration
--------------------------------------------------------------------------------
CFG_DATA_REG: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_CFG_DATA <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (CONFIG_DATA_EN = '1') then
      I_CFG_DATA(23 downto 20) <= "1001";         -- update code
      I_CFG_DATA(19 downto 17) <= CONFIG_ADDR;    -- register address
      I_CFG_DATA(16 downto 1)  <= CONFIG_DATA;    -- configuration data
      I_CFG_DATA(0) <= '0';                       -- reset
    else
      I_CFG_DATA <= I_CFG_DATA;
    end if;
  end if;
end process CFG_DATA_REG;


I_CONFIG_TX: CONFIG_TX
  generic map (
    CLOCK_PERIOD_PS             => G_CLOCK_PERIOD_PS,                           -- system clock period
    BIT_PERIOD_NS               => 400)                                         -- data rate
  port map(
    RESET                       => RESET,                                       -- async. reset
    CLOCK                       => CLOCK,                                       -- system clock
    START                       => I_CONFIG_EN,                                 -- start of transmission (pulse)
    LINE_PERIOD                 => I_LINE_PERIOD,                               -- line period in # of CLOCK cycles
    INPUT                       => I_CFG_DATA,                                  -- parallel tx data
    TX_END                      => I_CFG_DONE,                                  -- signals end of transmission (pulse)
    TX_DAT                      => I_CFG_TX_DAT,                                -- serial tx data => sensor
    TX_CLK                      => I_CFG_TX_CLK,                                -- shift clock => sensor
    TX_OE                       => I_CFG_TX_OE);                                -- output enable for TX_DAT & TX_CLK


I_CONFIG_REGS: CONFIG_REGS
  generic map (
    C_CADDR_W                   => G_CADDR_W,                                   -- config address width
    C_CDATA_W                   => G_CDATA_W)                                   -- config data width
  port map (
    RESET                       => RESET,                                       -- async. Reset
    CLOCK                       => CLOCK,                                       -- system clock
    NANEYE3A_NANEYE2B_N         => I_NANEYE3A_NANEYE2B_N,                       -- '0'=NANEYE2B, '1'=NANEYE3A
    -- control/data interface
    CONFIG_DATA_EN              => I_CFG_DONE,                                  -- config data enable
    CONFIG_ADDR                 => I_CFG_DATA(19 downto 17),                    -- config register address
    CONFIG_DATA                 => I_CFG_DATA(16 downto 1),                     -- config register data
    -- register outputs
    ADC_MODE                    => I_ADC_MODE,                                  -- 0=10 bit unsigned, 1=11 bit signed
    MCLK_DIV                    => I_MCLK_DIV,                                  -- 0=no division, 1=division by 2
    ROWS_DELAY_REG              => I_ROWS_DELAY_REG,                            -- ROWS_DELAY=2*ROWS_DELAY_REG+2
    ROWS_IN_RESET               => I_ROWS_IN_RESET);                            -- content of ROWS IN RESET register


--------------------------------------------------------------------------------
-- Output register
--------------------------------------------------------------------------------
OUT_REG: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_PIXEL_DATA <= (others => '0');
  elsif (rising_edge(CLOCK)) then
    if (I_DPRAM_RDAT_VALID = '1') then
      I_PIXEL_DATA <= I_DPRAM_DOA(G_PDATA_W-1 downto 0);
    else
      I_PIXEL_DATA <= (others => '0');
    end if;
  end if;
end process OUT_REG;


--------------------------------------------------------------------------------
-- BREAK0_N signal generation
--------------------------------------------------------------------------------
BREAK0_N_EVAL: process(RESET,SCLOCK)
begin
  if (RESET = '1') then
    I_BREAK0_N <= '1';
  elsif (rising_edge(SCLOCK)) then
    if (I_CONFIG_EN = '1') then             -- start of phase 252
      I_BREAK0_N <= '0';
    elsif (I_SYNC_START = '1') then         -- start of phase 253
      I_BREAK0_N <= '1';
    else
      I_BREAK0_N <= I_BREAK0_N;
    end if;
  end if;
end process BREAK0_N_EVAL;


--------------------------------------------------------------------------------
-- BREAK1_N signal generation
--------------------------------------------------------------------------------
BREAK1_N_EVAL: process(RESET,SCLOCK)
begin
  if (RESET = '1') then
    I_BREAK1_N <= '1';
  elsif (rising_edge(SCLOCK)) then
    if (I_SYNC_START = '1') then            -- start of phase 253
      I_BREAK1_N <= '0';
    elsif (I_DECODER_OUT_EN = '1') then     -- end of phase 253
      I_BREAK1_N <= '1';
    else
      I_BREAK1_N <= I_BREAK1_N;
    end if;
  end if;
end process BREAK1_N_EVAL;

--------------------------------------------------------------------------------
-- Force V_SYNC to go low if sensor is disconnected
--------------------------------------------------------------------------------
VSYNC_CNT_EVAL: process(RESET,CLOCK)
begin
  if (RESET = '1') then
    I_VSYNC_CNT <= 0;
    I_VSYNC_SEL <= '0';
  elsif (rising_edge(CLOCK)) then
	 if (I_V_SYNC = '1' and I_H_SYNC = '0') then
      --if (I_VSYNC_CNT > 25000000) then -- 25000000'd @ 50MHz => 0.5s 
		if (I_VSYNC_CNT > 12500000) then -- 12500000'd @ 50MHz => 0.25s
        I_VSYNC_CNT <= I_VSYNC_CNT;
		  I_VSYNC_SEL <= '1';
      else
		  I_VSYNC_CNT <= I_VSYNC_CNT + 1;
        I_VSYNC_SEL <= '0';
      end if;
	 else
	   I_VSYNC_CNT <= 0;
		I_VSYNC_SEL <= '0';
	 end if;
  end if;
end process VSYNC_CNT_EVAL;



DEBUG_O(31 downto 0) <= (others => '0');

BREAK_N(0) <= I_BREAK0_N;
BREAK_N(1) <= I_BREAK1_N;

NANEYE3A_NANEYE2B_N <= I_NANEYE3A_NANEYE2B_N;

PIXEL_DATA <= I_PIXEL_DATA;
LVAL <= I_H_SYNC;
FVAL <= I_V_SYNC when (I_VSYNC_SEL = '0') else '0';

CFG_TX_OE_N <= not I_CFG_TX_OE;

--------------------------------------------------------------------------------
-- Tristate select generation
--------------------------------------------------------------------------------
--TRISTATE_SEL_EVAL: process(RESET,SCLOCK)
--begin
--  if (RESET = '1') then
--    I_CFG_TRISTATE <= '1';
--  elsif (rising_edge(SCLOCK)) then
--    if (I_CONFIG_EN = '1') then       -- start of configuration phase
--      I_CFG_TRISTATE <= '0';
--    elsif (I_CFG_DONE = '1') then     -- end of configuration phase
--      I_CFG_TRISTATE <= '1';
--    else
--      I_CFG_TRISTATE <= I_CFG_TRISTATE;
--    end if;
--  end if;
--end process TRISTATE_SEL_EVAL;


CFG_TX_DAT  <= I_CFG_TX_DAT;
CFG_TX_CLK  <= I_CFG_TX_CLK;

end RTL;
