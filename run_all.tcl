# =============================================================
#  run_all.tcl  —  Universal Shift Register  (8-bit)
#  PURPOSE : Full synthesis + PPAC report generation
#  USAGE   : vivado -mode batch -source run_all.tcl
#            (or source run_all.tcl from the Vivado TCL console)
#  OUTPUT  : reports/timing_summary.rpt
#            reports/utilization.rpt
#            reports/power.rpt
# =============================================================

puts ""
puts "╔══════════════════════════════════════════════════════════╗"
puts "║   run_all.tcl  —  Starting PPAC Report Generation        ║"
puts "╚══════════════════════════════════════════════════════════╝"
puts ""

# ── 0. Configuration ─────────────────────────────────────────────────────────
set TOP          universal_shift_register_8bit
set PART         xc7a35tcpg236-1          ;# Artix-7  — change to your board
set CLK_PORT     clk
set CLK_PERIOD   5.000                    ;# ns  (200 MHz)
set REPORTS_DIR  reports

# Source files (adjust paths if your project layout differs)
set RTL_SOURCES  [list \
    universal_shift_register_8bit.v \
]

# ── 1. Create reports directory ───────────────────────────────────────────────
file mkdir $REPORTS_DIR
puts "  \[INFO\]  Reports will be written to: [file normalize $REPORTS_DIR]"
puts ""

# ── 2. Create in-memory project ───────────────────────────────────────────────
puts "  \[STEP 1/6\]  Creating in-memory Vivado project …"
create_project -in_memory -part $PART

# ── 3. Add RTL sources ────────────────────────────────────────────────────────
puts "  \[STEP 2/6\]  Adding RTL source files …"
foreach f $RTL_SOURCES {
    if {[file exists $f]} {
        add_files -norecurse $f
        puts "              Added: $f"
    } else {
        puts "  \[WARN\]   File not found, skipping: $f"
    }
}

# ── 4. Set top module ─────────────────────────────────────────────────────────
set_property top $TOP [current_fileset]
puts "  \[INFO\]  Top module set to: $TOP"
puts ""

# ── 5. Clock constraint ───────────────────────────────────────────────────────
puts "  \[STEP 3/6\]  Applying clock constraint (${CLK_PERIOD} ns = [expr {1000.0/$CLK_PERIOD}] MHz) …"
create_clock -period $CLK_PERIOD -name sys_clk [get_ports $CLK_PORT]

# ── 6. Synthesise ─────────────────────────────────────────────────────────────
puts "  \[STEP 4/6\]  Running synthesis (synth_design) …"
puts "              This converts RTL to gates — may take 30-60 seconds."
puts ""
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt
puts ""
puts "  \[INFO\]  Synthesis complete."
puts ""

# ── 7. Optimise for better area/timing estimates ──────────────────────────────
puts "  \[STEP 5/6\]  Running post-synthesis optimisation …"
opt_design

# ── 8. Generate all three PPAC reports ───────────────────────────────────────
puts ""
puts "  \[STEP 6/6\]  Generating PPAC reports …"
puts ""

# ── 8a. TIMING SUMMARY ───────────────────────────────────────────────────────
set timing_rpt "$REPORTS_DIR/timing_summary.rpt"
puts "  Timing summary  →  $timing_rpt"
report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 10 \
    -input_pins \
    -file $timing_rpt
puts "              Done."

# ── 8b. UTILISATION (area) ───────────────────────────────────────────────────
set util_rpt "$REPORTS_DIR/utilization.rpt"
puts "  Utilization     →  $util_rpt"
report_utilization \
    -hierarchical \
    -file $util_rpt
puts "              Done."

# ── 8c. POWER ────────────────────────────────────────────────────────────────
set power_rpt "$REPORTS_DIR/power.rpt"
puts "  Power           →  $power_rpt"

# Annotate switching activity from VCD if it exists
if {[file exists usr8_power.vcd]} {
    puts "              VCD found — annotating toggle rates for accuracy."
    read_vcd -cell /tb_universal_shift_register_8bit/DUT usr8_power.vcd
} else {
    puts "  \[WARN\]   usr8_power.vcd not found — using default switching activity."
    puts "              Run the testbench first to generate the VCD file."
}

report_power \
    -hier all \
    -file $power_rpt
puts "              Done."

# ── 9. Console summary ───────────────────────────────────────────────────────
puts ""
puts "╔══════════════════════════════════════════════════════════╗"
puts "║                  REPORT GENERATION COMPLETE              ║"
puts "╚══════════════════════════════════════════════════════════╝"
puts ""
puts "  Files written:"
puts "    $timing_rpt"
puts "    $util_rpt"
puts "    $power_rpt"
puts ""
puts "  To view quickly in TCL console:"
puts "    report_timing_summary"
puts "    report_utilization"
puts "    report_power"
puts ""
puts "  Commit the reports/ folder to turn PPAC claims into evidence."
puts "    git add reports/"
puts "    git commit -m \"ci: add PPAC synthesis reports\""
puts ""

# ── 10. Print key metrics inline so CI log is self-contained ─────────────────
puts "── INLINE TIMING SNAPSHOT ──────────────────────────────────"
report_timing_summary -no_header -quiet
puts ""
puts "── INLINE UTILISATION SNAPSHOT ─────────────────────────────"
report_utilization -no_header -quiet
puts ""
puts "── INLINE POWER SNAPSHOT ───────────────────────────────────"
report_power -no_header -quiet
puts ""
puts "  run_all.tcl finished successfully."
