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
vcom -2008 -work work {./LINE_PERIOD_CALC.vhd}
vlog -vlog01compat -work work {./TOP_tb.v}

#simulate
vsim -novopt TOP_tb

#probe signals
add wave -radix unsigned *
#add wave -radix unsigned /RX_DECODER_tb/UUT/*
#add wave -radix unsigned /RX_DECODER_tb/UUT2/*
#add wave -radix unsigned /RX_DECODER_tb/UUT/king_inst/*

view structure
view signals

#300 ns

run 120ms
