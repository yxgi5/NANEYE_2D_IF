module OUT_REG # 
( 
	parameter   SAMPLE_CLOCK_PERIOD_PS = 2500,      // sample clk 400MHz
    parameter   TRANS_CLOCK_PERIOD_MIN_PS = 7987,   // max data clk 62.6MHz(Tps=7987ps)
    parameter   SYSTEM_CLOCK_PERIOD_PS = 20833,     // system clk 48MHz
    parameter   D_WIDTH = 10
) 
(
    RESET,
    SCLOCK,
    SYS_CLOCK,

    PAR_IN,
    PAR_EN,
    LINE_END,
    FRAME_SYNC,

    PAR_OUT,
    H_SYNC,
    V_SYNC,
    PCLK
);

parameter                       PIXIEL_PIREAD   =   (D_WIDTH+2) * TRANS_CLOCK_PERIOD_MIN_PS;

input                           RESET;
input                           SCLOCK;
input                           SYS_CLOCK;

input   [D_WIDTH-1:0]           PAR_IN;
input                           PAR_EN;
input                           LINE_END;
input                           FRAME_SYNC;

output  [D_WIDTH-1:0]           PAR_OUT;
output                          H_SYNC;
output                          V_SYNC;
output                          PCLK;

reg     [D_WIDTH-1:0]           PAR_OUT;
reg                             H_SYNC;
reg                             V_SYNC;
reg                             PCLK;

always @(posedge SCLOCK)
begin
    if (RESET == 1'b1) 
    begin
        PAR_OUT     <= {D_WIDTH{1'b0}};
        H_SYNC      <= 1'b0;
        V_SYNC      <= 1'b0;
        PCLK        <= 1'b0;
    end
    else
    begin
    end
end

endmodule
/*
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
    end
    else
    begin
    end
end
*/
