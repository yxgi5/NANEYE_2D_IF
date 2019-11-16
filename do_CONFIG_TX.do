transcript on
#compile
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -2008 -work work {./CONFIG_TX.vhd}
vcom -2008 -work work {./CLK_DIV.vhd}
vlog -vlog01compat -work work {./CONFIG_TX_tb.v}

#simulate
vsim -novopt CONFIG_TX_tb

#probe signals
add wave -radix unsigned *
add wave -radix unsigned /CONFIG_TX_tb/UUT9/*

view structure
view signals

#300 ns

run 5ms
