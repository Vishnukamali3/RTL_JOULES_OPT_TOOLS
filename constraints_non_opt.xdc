## ============================================================
##  XDC Constraints — NON-OPTIMIZED Design ONLY
##  Module  : universal_shift_register_8bit_non_opt
##  Target  : Artix-7 xc7a35t-1cpg236c
##  Clock   : 100 MHz (10 ns period)
##
##  Ports   : clk, rst, mode[1:0], par_in[7:0],
##            ser_in_r, ser_in_l, q[7:0],
##            ser_out_r, ser_out_l
##
##  NOTE    : No clk_en, No rst_n (optimized-only ports)
##            Using this XDC gives ZERO port-not-found warnings
##
##  EXPECTED RESULT @ 100 MHz:
##    WNS : Negative  → FAILS timing
##    TNS : Large negative value
##    Why : Separate always@(*) adds extra LUT level in path
##          Synchronous reset uses D-mux instead of FF CLR pin
## ============================================================

## --- Primary Clock -----------------------------------------------------------
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

## --- Input Delays : Data -----------------------------------------------------
set_input_delay -clock clk -max 3.000 [get_ports {mode[*] par_in[*] ser_in_r ser_in_l}]
set_input_delay -clock clk -min 0.500 [get_ports {mode[*] par_in[*] ser_in_r ser_in_l}]

## --- Input Delay : Synchronous Reset -----------------------------------------
## rst is SYNCHRONOUS — must meet setup/hold like any data input
set_input_delay -clock clk -max 3.000 [get_ports rst]
set_input_delay -clock clk -min 0.500 [get_ports rst]

## --- Output Delays -----------------------------------------------------------
set_output_delay -clock clk -max 2.000 [get_ports {q[*]}]
set_output_delay -clock clk -min 0.000 [get_ports {q[*]}]

## ser_out registered (extra FF in non-opt) — output delay from FF Q pin
set_output_delay -clock clk -max 2.000 [get_ports {ser_out_r ser_out_l}]
set_output_delay -clock clk -min 0.000 [get_ports {ser_out_r ser_out_l}]

## --- Clock Uncertainty -------------------------------------------------------
set_clock_uncertainty 0.150 [get_clocks clk]
