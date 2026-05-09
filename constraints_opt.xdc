## ============================================================
##  XDC Constraints — OPTIMIZED Design ONLY
##  Module  : universal_shift_register_8bit_opt
##  Target  : Artix-7 xc7a35t-1cpg236c
##  Clock   : 100 MHz (10 ns period)
##
##  Ports   : clk, rst_n, clk_en, mode[1:0], par_in[7:0],
##            ser_in_r, ser_in_l, q[7:0],
##            ser_out_r, ser_out_l
##
##  NOTE    : No rst (non-optimized-only port)
##            Using this XDC gives ZERO port-not-found warnings
##
##  EXPECTED RESULT @ 100 MHz:
##    WNS : Positive  → PASSES timing
##    TNS : 0.000 ns
##    Why : Single clocked block, mux in FF input LUT
##          Async reset uses FF CLR pin (no LUT)
##          CE pin used directly (no LUT for clock gating)
##          Wire taps eliminate 2 FFs
## ============================================================

## --- Primary Clock -----------------------------------------------------------
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

## --- Input Delays : Data -----------------------------------------------------
set_input_delay -clock clk -max 3.000 [get_ports {mode[*] par_in[*] ser_in_r ser_in_l}]
set_input_delay -clock clk -min 0.500 [get_ports {mode[*] par_in[*] ser_in_r ser_in_l}]

## --- Input Delay : Clock Enable ----------------------------------------------
## clk_en maps to FF CE pin — still needs input delay constraint
set_input_delay -clock clk -max 3.000 [get_ports clk_en]
set_input_delay -clock clk -min 0.500 [get_ports clk_en]

## --- Async Reset : False Path ------------------------------------------------
## rst_n is ASYNCHRONOUS — not analysed for setup/hold against clock
set_false_path -from [get_ports rst_n]

## --- Output Delays -----------------------------------------------------------
set_output_delay -clock clk -max 2.000 [get_ports {q[*]}]
set_output_delay -clock clk -min 0.000 [get_ports {q[*]}]

## ser_out are wire taps (combinational from q) — output delay from same FF
set_output_delay -clock clk -max 2.000 [get_ports {ser_out_r ser_out_l}]
set_output_delay -clock clk -min 0.000 [get_ports {ser_out_r ser_out_l}]

## --- Clock Uncertainty -------------------------------------------------------
set_clock_uncertainty 0.150 [get_clocks clk]
