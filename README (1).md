# RTL JOULES OPT TOOLS
**8-bit Universal Shift Register — PPAC Analysis using Verilog HDL and Vivado**

This project designs, verifies, and compares two RTL implementations of an 8-bit Universal Shift Register on an Artix-7 FPGA. The goal is to study **PPAC (Power, Performance, Area, Congestion)** trade-offs between an intentionally non-optimized design and an optimization-aware design, inspired by industrial Joules RTL Design Studio methodology.

---

## Repository Structure

```
├── universal_shift_register_8bit_non_opt.v   # Non-optimized RTL (sync reset, extra FFs, separate always blocks)
├── universal_shift_register_8bit_opt.v       # Optimized RTL (async reset, CE pin, wire taps, single always block)
├── tb_universal_shift_register.v             # Unified testbench — functional + PPAC proxy analysis
├── constraints_non_opt.xdc                   # Timing constraints for non-optimized design (Artix-7, 100 MHz)
├── constraints_opt.xdc                       # Timing constraints for optimized design (Artix-7, 100 MHz)
├── reports/                                  # Vivado synthesis + implementation reports (see below)
│   ├── timing_summary_non_opt.rpt
│   ├── timing_summary_opt.rpt
│   ├── utilization_non_opt.rpt
│   ├── utilization_opt.rpt
│   ├── power_non_opt.rpt
│   └── power_opt.rpt
└── README.md
```

---

## Design Summary

| Feature | Non-Optimized | Optimized |
|---|---|---|
| Always block style | Separate combo + clocked | Single clocked block |
| Reset type | Active-high synchronous | Active-low asynchronous |
| Reset FPGA mapping | D-input mux (wastes LUT) | Dedicated FF CLR pin |
| Clock enable | None (FF always active) | FF CE pin (no LUT) |
| Serial outputs | Registered (2 extra FFs) | Wire taps (zero FF delay) |
| Intermediate nodes | 8 `d` nodes | None |
| Expected timing @ 100 MHz | **FAILS (negative WNS)** | **PASSES (positive WNS)** |
| Expected dynamic power | Higher | Lower |
| Expected area | More LUTs + FFs | Fewer LUTs + FFs |

**Mode encoding** (same for both designs):

| `mode[1:0]` | Operation |
|---|---|
| `2'b00` | Hold |
| `2'b01` | Shift Right (`ser_in_r` → MSB) |
| `2'b10` | Shift Left (`ser_in_l` → LSB) |
| `2'b11` | Parallel Load |

---

## Simulation (Vivado xsim)

### Step 1 — Compile
```bash
xvlog universal_shift_register_8bit_non_opt.v
xvlog universal_shift_register_8bit_opt.v
xvlog tb_universal_shift_register.v
```

### Step 2 — Elaborate
```bash
xelab -debug typical tb_universal_shift_register -s tb_sim
```

### Step 3 — Simulate
```bash
xsim tb_sim -runall
```

The testbench prints a full PPAC comparison report to the console covering functional pass/fail, toggle counts, FF counts, logic levels, and routing node counts. It also generates `sim_dump.vcd` for use in power analysis (see below).

### Expected Console Output (summary)
```
  FUNCTIONAL SUMMARY
  NON-OPT : Passed=9  Failed=0
  OPT     : Passed=9  Failed=0

  OVERALL PPAC SUMMARY
  Performance  : NON-OPT FAILS 100MHz  | OPT PASSES 100MHz
  Power        : NON-OPT Higher switching | OPT Lower switching
  Area         : NON-OPT More LUTs + FFs  | OPT Fewer LUTs + FFs
  Congestion   : NON-OPT Deeper netlist   | OPT Compact netlist
```

---

## Synthesis and Implementation (Vivado GUI)

### Non-Optimized Design
1. Create a new RTL project targeting **xc7a35tcpg236-1**
2. Add `universal_shift_register_8bit_non_opt.v` as source
3. Add `constraints_non_opt.xdc` as constraint
4. Run **Synthesis** → Run **Implementation**
5. Open **Report Timing Summary** — expect negative WNS
6. Open **Report Utilization** — note LUT and FF counts
7. Open **Report Power** — note dynamic power (mW)
8. Save reports to `reports/` folder

### Optimized Design
Repeat the same steps with `universal_shift_register_8bit_opt.v` and `constraints_opt.xdc`.
Expect positive WNS, fewer LUTs/FFs, and lower dynamic power.

---

## VCD-Based Power Analysis (Vivado Tcl)

After simulation, `sim_dump.vcd` is generated. To perform VCD-based power analysis instead of the toggle-proxy approach:

```tcl
# In Vivado Tcl Console (after implementation)
read_vcd sim_dump.vcd -strip_path tb_universal_shift_register/dut_opt
report_power -file reports/power_vcd_opt.rpt
```

This gives exact mW dynamic power based on actual switching activity from simulation.

---

## Target Device

- **Part:** Artix-7 xc7a35tcpg236-1
- **Clock:** 100 MHz (10 ns period)
- **Tool:** Vivado Design Suite 2023.x or later

---

## Technologies Used

Verilog HDL · Vivado Design Suite · Xilinx FPGA Flow · RTL Design Methodology · PPAC Analysis · VCD Switching Activity Analysis · Behavioral Simulation · Synthesis and Timing Analysis · Optimization-Aware RTL Coding
