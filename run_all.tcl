# ================================================================
#  run_all.tcl — Full Vivado automation script
#  Runs synthesis, implementation, and report generation for both
#  optimized and non-optimized Universal Shift Register designs.
#
#  Usage (Vivado Tcl Console or batch):
#    vivado -mode batch -source run_all.tcl
#
#  Outputs:
#    reports/timing_summary_non_opt.rpt
#    reports/timing_summary_opt.rpt
#    reports/utilization_non_opt.rpt
#    reports/utilization_opt.rpt
#    reports/power_non_opt.rpt
#    reports/power_opt.rpt
# ================================================================

set PART "xc7a35tcpg236-1"
set REPORTS_DIR "./reports"

file mkdir $REPORTS_DIR

proc run_design {name src_file xdc_file top_module} {
    global PART REPORTS_DIR

    puts "\n================================================================"
    puts "  Running flow for: $name"
    puts "================================================================"

    # Create in-memory project
    create_project -in_memory -part $PART

    # Add sources
    add_files $src_file
    add_files -fileset constrs_1 $xdc_file
    set_property top $top_module [current_fileset]

    # Synthesis
    puts "  \[1/3\] Running synthesis..."
    synth_design -top $top_module -part $PART -flatten_hierarchy rebuilt
    write_checkpoint -force ${REPORTS_DIR}/${name}_synth.dcp

    # Implementation
    puts "  \[2/3\] Running implementation..."
    opt_design
    place_design
    route_design
    write_checkpoint -force ${REPORTS_DIR}/${name}_impl.dcp

    # Reports
    puts "  \[3/3\] Generating reports..."
    report_timing_summary -file ${REPORTS_DIR}/timing_summary_${name}.rpt -warn_on_violation
    report_utilization    -file ${REPORTS_DIR}/utilization_${name}.rpt
    report_power          -file ${REPORTS_DIR}/power_${name}.rpt

    puts "  Done: reports saved to ${REPORTS_DIR}/"
    close_project
}

# ---- Non-optimized ----
run_design \
    "non_opt" \
    "universal_shift_register_8bit_non_opt.v" \
    "constraints_non_opt.xdc" \
    "universal_shift_register_8bit_non_opt"

# ---- Optimized ----
run_design \
    "opt" \
    "universal_shift_register_8bit_opt.v" \
    "constraints_opt.xdc" \
    "universal_shift_register_8bit_opt"

puts "\n================================================================"
puts "  ALL FLOWS COMPLETE"
puts "  Reports are in: $REPORTS_DIR"
puts "  Key things to check:"
puts "    timing_summary_non_opt.rpt -> expect NEGATIVE WNS"
puts "    timing_summary_opt.rpt     -> expect POSITIVE WNS"
puts "    utilization_*.rpt          -> compare LUT / FF counts"
puts "    power_*.rpt                -> compare dynamic power (mW)"
puts "================================================================\n"
