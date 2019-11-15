// clk_div_5_5_tb.v
// Testbench

`timescale 1ps/ 1ps
//`define CheckByteNum 6000
//`ifndef xx
//`define xx yy // or parameter xx = yy;
//`endif
//`undef XX

module TOP_tb();

reg     RESET_tb;
reg     CLOCK_tb;   // 180MHz sampling clock
reg     UCLOCK_tb;  // 48MHz system clock.
reg     ENABLE_tb;
//reg     RSYNC_tb;
reg     INPUT_tb;
reg     CONFIG_DONE_tb;

wire    CONFIG_EN_tb;
wire    SYNC_START_tb;
wire    FRAME_START_tb;
wire    OUTPUT_tb;
wire    OUTPUT_EN_tb;
wire    NANEYE3A_NANEYE2B_N_tb;
wire    ERROR_OUT_tb;
wire    [31:0]  DEBUG_OUT_tb;

wire    RSYNC_tb;

wire    [11:0]  PAR_OUTPUT_tb;
wire    PAR_OUTPUT_EN_tb;
wire    PIXEL_ERROR_tb;
wire    LINE_END_tb;
wire    [15:0]  LINE_PERIOD_tb;
wire    ERROR_OUT2_tb;
wire    [15:0]  DEBUG_OUT2_tb;

wire    [15:0]  LINE_PERIOD2_tb;

reg     addr_mem[0:80000000];
integer     j;
integer     rand;

RX_DECODER UUT
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .ENABLE                     (ENABLE_tb),
    .RSYNC                      (RSYNC_tb),
    .INPUT                      (INPUT_tb),
    .CONFIG_DONE                (CONFIG_DONE_tb),
    .CONFIG_EN                  (CONFIG_EN_tb),
    .SYNC_START                 (SYNC_START_tb),
    .FRAME_START                (FRAME_START_tb),
    .OUTPUT                     (OUTPUT_tb),
    .OUTPUT_EN                  (OUTPUT_EN_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .ERROR_OUT                  (ERROR_OUT_tb),
    .DEBUG_OUT                  (DEBUG_OUT_tb)
);

RX_DESERIALIZER UUT2
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .FRAME_START                (FRAME_START_tb),
    .SER_INPUT                  (OUTPUT_tb),
    .SER_INPUT_EN               (OUTPUT_EN_tb),
    .DEC_RSYNC                  (RSYNC_tb),
    .PAR_OUTPUT                 (PAR_OUTPUT_tb),
    .PAR_OUTPUT_EN              (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_END                   (LINE_END_tb),
    .LINE_PERIOD                (LINE_PERIOD_tb),
    .ERROR_OUT                  (ERROR_OUT2_tb),
    .DEBUG_OUT                  (DEBUG_OUT2_tb)
);

LINE_PERIOD_CALC UUT3
(
    .RESET                      (RESET_tb),
    .CLOCK                      (UCLOCK_tb),
    .SCLOCK                     (CLOCK_tb),
    .FRAME_START                (FRAME_START_tb),
    .PAR_DATA_EN                (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_END                   (LINE_END_tb),
    .LINE_PERIOD                (LINE_PERIOD2_tb)
);


parameter C_ADDR_W_tb = 9;

wire    [C_ADDR_W_tb-1:0]       DPRAM_WR_ADDR_tb;
wire    [C_ADDR_W_tb-1:0]       DPRAM_RD_ADDR_tb;
wire                            DPRAM_WE_tb;
wire                            DPRAM_RD_PAGE_tb;
wire                            LINE_FINISHED_tb;

DPRAM_WR_CTRL 
#(
    .C_ADDR_W                   (C_ADDR_W_tb)
)UUT4
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .PULSE                      (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_SYNC                  (LINE_END_tb),
    .FRAME_SYNC                 (FRAME_START_tb),
    .DPRAM_WR_ADDR              (DPRAM_WR_ADDR_tb),
    .DPRAM_WE                   (DPRAM_WE_tb),
    .DPRAM_RD_PAGE              (DPRAM_RD_PAGE_tb),
    .LINE_FINISHED              (LINE_FINISHED_tb)
);

parameter A_WIDTH_tb = C_ADDR_W_tb;
parameter D_WIDTH_tb = 10;

wire    [D_WIDTH_tb-1:0]        DOA_tb;
wire    [D_WIDTH_tb-1:0]        DOB_tb;

DPRAM
#(
    .A_WIDTH                    (A_WIDTH_tb),
    .D_WIDTH                    (D_WIDTH_tb)
)UUT5
(
    .CLKA                       (UCLOCK_tb),
    .CLKB                       (CLOCK_tb),
    .ENA                        (1'b1),
    .ENB                        (1'b1),
    .WEA                        (1'b0),
    .WEB                        (DPRAM_WE_tb),
    .ADDRA                      (DPRAM_RD_ADDR_tb),
    .ADDRB                      (DPRAM_WR_ADDR_tb),
    .DIA                        ({(D_WIDTH_tb){1'bx}}),
    .DIB                        (PAR_OUTPUT_tb[10:1]),
    .DOA                        (DOA_tb),
    .DOB                        (DOB_tb)
);

wire                            DPRAM_RDAT_VALID_tb;
wire                            H_SYNC_tb;
wire                            V_SYNC_tb;

DPRAM_RD_CTRL
#(
    .C_ADDR_W                   (C_ADDR_W_tb)
)UUT6
(
    .RESET                      (RESET_tb),
    .SCLOCK                     (CLOCK_tb),
    .CLOCK                      (UCLOCK_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .FRAMING_ERROR              (1'b0),
    .FRAME_START                (FRAME_START_tb),
    .LINE_FINISHED              (LINE_END_tb),
    .DPRAM_RD_PAGE              (DPRAM_RD_PAGE_tb),
    .DPRAM_RD_ADDR              (DPRAM_RD_ADDR_tb),
    .DPRAM_RDAT_VALID           (DPRAM_RDAT_VALID_tb),
    .H_SYNC                     (H_SYNC_tb),
    .V_SYNC                     (V_SYNC_tb)
);

initial
begin
    j=0;
    CLOCK_tb = 1;
    UCLOCK_tb = 1;
    RESET_tb = 1;

//   #40 reset = 0;
//   #100 $finish;
    ENABLE_tb = 1;
    //RSYNC_tb = 1;
    //INPUT_tb = 0;
    //CONFIG_DONE_tb = 0;

    //#500
    //INPUT_tb = 1;
    //#700
    //INPUT_tb = 0;

    #40000 
    RESET_tb = 0;
    //#2500000
    //CONFIG_DONE_tb = 1;
    //RSYNC_tb = 0;
    //#(10+2778*2)
    //CONFIG_DONE_tb = 0;
end

initial
begin
   $readmemh("./data.dat",addr_mem);
end

initial
begin
    INPUT_tb = addr_mem[0];
    $display("Begin READING-----READING-----READING-----READING");
     //for(j = 0; j <=`CheckByteNum; j = j+1)
    for (;;)
     begin
        INPUT_tb = addr_mem[j]; 
        j=j+1;
        //$display("DATA %0h ---READ RIGHT",INPUT_tb);
        //@(posedge SCLOCK or negedge SCLOCK );

        # (13889);  // 36MHz data_in

        //rand = ($random % 20);    +/-20% jitter
        //rand = ($urandom % 20); // +20% jitter
        //rand = -1*($urandom % 20); // -20% jitter
        //$display("random jitter %0d%%",rand);
        //# (13889 + rand*13889/100);  // 36MHz data_in data rate with jitter
     end
end  

always
begin
    #2778 CLOCK_tb = ~CLOCK_tb; // 180MHz sample clock
end

always
begin
    #10416 UCLOCK_tb = ~UCLOCK_tb; // 48MHz sample clock
end


always@(posedge CLOCK_tb or RESET_tb)		
begin
  if (RESET_tb == 1'b1)
  begin
	CONFIG_DONE_tb <= 0;
  end
  else
  begin
    if(CONFIG_EN_tb == 1'b1)
    begin
        CONFIG_DONE_tb <= 1;
    end
    else
    begin
        CONFIG_DONE_tb <= 0;
    end
  end
end

endmodule


