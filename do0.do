transcript on
#compile
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -2008 -work work {./RX_DECODER.vhd}
vcom -2008 -work work {./IDDR.vhd}
vcom -2008 -work work {./RX_DESERIALIZER.vhd}
vcom -2008 -work work {./DPRAM_WR_CTRL.vhd}
vcom -2008 -work work {./DPRAM_RD_CTRL.vhd}
vcom -2008 -work work {./DPRAM.vhd}
vcom -2008 -work work {./LINE_PERIOD_CALC.vhd}
vcom -2008 -work work {./OUT_REG.vhd}
vcom -2008 -work work {./BREAK_LOGIC.vhd}
vcom -2008 -work work {./CONFIG_TX.vhd}
vcom -2008 -work work {./CLK_DIV.vhd}
vlog -vlog01compat -work work {./TOP_tb.v}

#simulate
vsim -novopt TOP_tb

#probe signals
add wave -radix unsigned *
#add wave -radix unsigned /TOP_tb/UUT/*
#add wave -radix unsigned /TOP_tb/UUT2/*
#add wave -radix unsigned /TOP_tb/UUT/king_inst/*
add wave -radix unsigned /TOP_tb/UUT9/*

view structure
view signals

#300 ns

run 120ms
