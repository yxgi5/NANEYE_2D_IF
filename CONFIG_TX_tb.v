// clk_div_5_5_tb.v
// Testbench

`timescale 1ps/ 1ps
//`define CheckByteNum 6000
//`ifndef xx
//`define xx yy // or parameter xx = yy;
//`endif
//`undef XX

module CONFIG_TX_tb();

reg     RESET_tb;
reg     UCLOCK_tb;  // 48MHz system clock.
reg     INPUT_tb;
reg     START_tb;

wire    CONFIG_DONE_tb;

//wire                            TX_END_tb;
wire                            TX_DAT_tb;
wire                            TX_CLK_tb;
wire                            TX_OE_N_tb;
wire                            TX_OE_tb;

CONFIG_TX
#(
    .CLOCK_PERIOD_PS            (20833),    // 48MHz
    .BIT_PERIOD_NS              (400),      // 2.5MHz
    .C_NO_CFG_BITS              (24)
)UUT9
(
    .RESET                      (RESET_tb),
    .CLOCK                      (UCLOCK_tb),
    .START                      (START_tb),
    .LINE_PERIOD                (16'd4000),
    .INPUT                      (24'b1010_1110_1100_1001_1110_1100),
    .TX_END                     (CONFIG_DONE_tb),
    .TX_DAT                     (TX_DAT_tb),
    .TX_CLK                     (TX_CLK_tb),
    .TX_OE                      (TX_OE_tb)
);

assign      TX_OE_N_tb  =       ~TX_OE_tb;

initial
begin
    UCLOCK_tb = 1;
    RESET_tb = 1;
    START_tb = 0;
    #40000 
    RESET_tb = 0;
end

always
begin
    #10416 UCLOCK_tb = ~UCLOCK_tb; // 48MHz sample clock
end

always
begin
    #1000000 START_tb = 1;
    #10000000 START_tb = 0;
end

endmodule


