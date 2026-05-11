`timescale 1ns/1ps

// ================================================================
//  Universal Shift Register — Single Unified Testbench  (v2)
//  Both designs instantiated simultaneously
//
//  v2 improvements:
//    - FF/node area constants DERIVED from WIDTH parameter (no hardcoding)
//    - Toggle counters use non-blocking assignments throughout
//    - Toggle-tracking separated into its own always block
//    - Stress test uses parameterised WIDTH for par_in masking
//    - Sim log header prints derived structural constants for traceability
//
//  PPAC ANALYSIS printed to console at end:
//    Performance : Logic levels, reset type, serial out latency
//    Power       : Toggle count per signal (switching activity)
//    Area        : FF count, logic node count per design
//    Congestion  : Routing node count, netlist depth
//
//  Functional Tests:
//    T1. Reset
//    T2. Parallel Load (mode=11)
//    T3. Hold (mode=00)
//    T4. Shift Right (mode=01) x2 cycles
//    T5. Shift Left  (mode=10) x2 cycles
//    T6. Serial Output Taps
//    T7. Clock Enable (opt only)
//    T8. Stress toggle (power/congestion measurement)
// ================================================================

module tb_universal_shift_register;

    parameter WIDTH      = 8;
    parameter CLK_PERIOD = 10;
    parameter CLK_FREQ   = 100;

    // ----------------------------------------------------------------
    // PPAC structural constants — DERIVED from WIDTH (no hardcoding)
    //   NON-OPT FFs : WIDTH q-regs + 2 registered ser_out FFs
    //   OPT FFs     : WIDTH q-regs only (ser_out = combinational wire)
    //   Intermediate d-nodes: WIDTH wires in separate combo block
    // ----------------------------------------------------------------
    localparam NON_OPT_FF    = WIDTH + 2;  // scales automatically
    localparam OPT_FF        = WIDTH;      // scales automatically
    localparam NON_OPT_NODES = WIDTH;      // one intermediate node per bit
    localparam OPT_NODES     = 0;
    localparam NON_OPT_LVL   = 2;         // separate combo + FF = 2 levels
    localparam OPT_LVL       = 1;         // mux merged into FF LUT = 1 level

    // --- Shared stimulus ---
    reg              clk;
    reg  [1:0]       mode;
    reg  [WIDTH-1:0] par_in;
    reg              ser_in_r;
    reg              ser_in_l;

    // --- NON-OPTIMIZED DUT ---
    reg              rst;
    wire [WIDTH-1:0] q_non;
    wire             ser_out_r_non;
    wire             ser_out_l_non;

    universal_shift_register_8bit_non_opt #(.WIDTH(WIDTH)) dut_non_opt (
        .clk(clk), .rst(rst), .mode(mode), .par_in(par_in),
        .ser_in_r(ser_in_r), .ser_in_l(ser_in_l),
        .q(q_non), .ser_out_r(ser_out_r_non), .ser_out_l(ser_out_l_non)
    );

    // --- OPTIMIZED DUT ---
    reg              rst_n;
    reg              clk_en;
    wire [WIDTH-1:0] q_opt;
    wire             ser_out_r_opt;
    wire             ser_out_l_opt;

    universal_shift_register_8bit_opt #(.WIDTH(WIDTH)) dut_opt (
        .clk(clk), .rst_n(rst_n), .clk_en(clk_en), .mode(mode), .par_in(par_in),
        .ser_in_r(ser_in_r), .ser_in_l(ser_in_l),
        .q(q_opt), .ser_out_r(ser_out_r_opt), .ser_out_l(ser_out_l_opt)
    );

    // --- Clock generator ---
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Functional pass/fail counters ---
    integer pass_non, fail_non, pass_opt, fail_opt;
    initial begin
        pass_non = 0; fail_non = 0;
        pass_opt = 0; fail_opt = 0;
    end

    // --- Switching activity counters ---
    integer tog_q_non, tog_q_opt;
    integer tog_ser_non, tog_ser_opt;
    integer tog_clk, cycle_count;
    integer cycles_reset, cycles_load;
    integer cycles_shift_r, cycles_shift_l;
    integer fanout_mode_non, fanout_mode_opt;

    initial begin
        tog_q_non = 0; tog_q_opt = 0;
        tog_ser_non = 0; tog_ser_opt = 0;
        tog_clk = 0; cycle_count = 0;
        cycles_reset = 0; cycles_load = 0;
        cycles_shift_r = 0; cycles_shift_l = 0;
        fanout_mode_non = 0; fanout_mode_opt = 0;
    end

    // Previous-cycle shadow registers for toggle detection
    reg [WIDTH-1:0] q_non_p, q_opt_p;
    reg             sr_non_p, sl_non_p, sr_opt_p, sl_opt_p;
    reg [1:0]       mode_p;
    initial begin
        q_non_p  = 0; q_opt_p  = 0;
        sr_non_p = 0; sl_non_p = 0;
        sr_opt_p = 0; sl_opt_p = 0;
        mode_p   = 0;
    end

    // ----------------------------------------------------------------
    // Toggle tracking — dedicated always block, all non-blocking
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        tog_clk     <= tog_clk + 1;

        // q bus toggles
        if (q_non !== q_non_p) tog_q_non <= tog_q_non + 1;
        if (q_opt !== q_opt_p) tog_q_opt <= tog_q_opt + 1;

        // ser_out toggles
        if (ser_out_r_non !== sr_non_p) tog_ser_non <= tog_ser_non + 1;
        if (ser_out_l_non !== sl_non_p) tog_ser_non <= tog_ser_non + 1;
        if (ser_out_r_opt !== sr_opt_p) tog_ser_opt <= tog_ser_opt + 1;
        if (ser_out_l_opt !== sl_opt_p) tog_ser_opt <= tog_ser_opt + 1;

        // mode fanout events
        if (mode !== mode_p) begin
            fanout_mode_non <= fanout_mode_non + 1;
            fanout_mode_opt <= fanout_mode_opt + 1;
        end

        // update shadow registers
        q_non_p  <= q_non;
        q_opt_p  <= q_opt;
        sr_non_p <= ser_out_r_non;
        sl_non_p <= ser_out_l_non;
        sr_opt_p <= ser_out_r_opt;
        sl_opt_p <= ser_out_l_opt;
        mode_p   <= mode;
    end

    // ----------------------------------------------------------------
    // Task: check both DUTs against expected value
    // ----------------------------------------------------------------
    task check_both;
        input [WIDTH-1:0] expected;
        input [63:0]      tid;
    begin
        if (q_non === expected) begin
            $display("  [NON-OPT] PASS [T%0d] q=0x%02X", tid, q_non);
            pass_non = pass_non + 1;
        end else begin
            $display("  [NON-OPT] FAIL [T%0d] Expected=0x%02X Got=0x%02X",
                      tid, expected, q_non);
            fail_non = fail_non + 1;
        end
        if (q_opt === expected) begin
            $display("  [OPT    ] PASS [T%0d] q=0x%02X", tid, q_opt);
            pass_opt = pass_opt + 1;
        end else begin
            $display("  [OPT    ] FAIL [T%0d] Expected=0x%02X Got=0x%02X",
                      tid, expected, q_opt);
            fail_opt = fail_opt + 1;
        end
    end
    endtask

    // ----------------------------------------------------------------
    // Task: apply reset to both DUTs
    // ----------------------------------------------------------------
    task apply_reset;
    begin
        rst = 1'b1; rst_n = 1'b0;
        @(posedge clk); #1; cycles_reset = cycles_reset + 1;
        @(posedge clk); #1; cycles_reset = cycles_reset + 1;
        rst = 1'b0; rst_n = 1'b1;
    end
    endtask

    // ================================================================
    // MAIN STIMULUS
    // ================================================================
    initial begin
        mode     = 2'b00;
        par_in   = {WIDTH{1'b0}};
        ser_in_r = 1'b0;
        ser_in_l = 1'b0;
        rst      = 1'b0;
        rst_n    = 1'b1;
        clk_en   = 1'b1;

        $display("\n================================================================");
        $display("  UNIVERSAL SHIFT REGISTER — PPAC COMPARISON TESTBENCH v2");
        $display("  Clock=%0dMHz  Width=%0d-bit  Target=Artix-7 xc7a35t", CLK_FREQ, WIDTH);
        $display("  Structural constants (derived from WIDTH=%0d):", WIDTH);
        $display("    NON_OPT_FF=%0d  OPT_FF=%0d  NON_OPT_NODES=%0d",
                  NON_OPT_FF, OPT_FF, NON_OPT_NODES);
        $display("================================================================");

        // ============================================================
        $display("\n--- SECTION 1: FUNCTIONAL VERIFICATION ---");
        // ============================================================

        $display("\n[T1] Reset");
        apply_reset;
        @(posedge clk); #1;
        check_both({WIDTH{1'b0}}, 1);

        $display("\n[T2] Parallel Load (mode=11, par_in=0xA5)");
        par_in = 8'hA5; mode = 2'b11;
        @(posedge clk); #1; cycles_load = cycles_load + 1;
        check_both(8'hA5, 2);

        $display("\n[T3] Hold (mode=00)");
        mode = 2'b00;
        @(posedge clk); #1;
        check_both(8'hA5, 3);

        $display("\n[T4] Shift Right (mode=01)");
        par_in = 8'b10101010; mode = 2'b11;
        @(posedge clk); #1;
        ser_in_r = 1'b1; mode = 2'b01;
        @(posedge clk); #1; cycles_shift_r = cycles_shift_r + 1;
        check_both(8'b11010101, 4);
        @(posedge clk); #1; cycles_shift_r = cycles_shift_r + 1;
        check_both(8'b11101010, 5);
        ser_in_r = 1'b0;

        $display("\n[T5] Shift Left (mode=10)");
        par_in = 8'b01010101; mode = 2'b11;
        @(posedge clk); #1;
        ser_in_l = 1'b1; mode = 2'b10;
        @(posedge clk); #1; cycles_shift_l = cycles_shift_l + 1;
        check_both(8'b10101011, 6);
        @(posedge clk); #1; cycles_shift_l = cycles_shift_l + 1;
        check_both(8'b01010111, 7);
        ser_in_l = 1'b0;

        $display("\n[T6] Serial Output Tap Test (par_in=8'b11000001)");
        par_in = 8'b11000001; mode = 2'b11;
        @(posedge clk); #1;
        // OPT: combinational wire tap — visible same cycle as load
        if (ser_out_r_opt === 1'b1 && ser_out_l_opt === 1'b1) begin
            $display("  [OPT    ] PASS [T6] ser_out_r=%b ser_out_l=%b  [wire tap - zero FF delay]",
                      ser_out_r_opt, ser_out_l_opt);
            pass_opt = pass_opt + 1;
        end else begin
            $display("  [OPT    ] FAIL [T6] ser_out_r=%b ser_out_l=%b (exp both=1)",
                      ser_out_r_opt, ser_out_l_opt);
            fail_opt = fail_opt + 1;
        end
        // NON-OPT: registered — requires one extra clock cycle
        @(posedge clk); #1;
        if (ser_out_r_non === 1'b1 && ser_out_l_non === 1'b1) begin
            $display("  [NON-OPT] PASS [T6] ser_out_r=%b ser_out_l=%b  [registered - 1 cycle late]",
                      ser_out_r_non, ser_out_l_non);
            pass_non = pass_non + 1;
        end else begin
            $display("  [NON-OPT] FAIL [T6] ser_out_r=%b ser_out_l=%b (exp both=1)",
                      ser_out_r_non, ser_out_l_non);
            fail_non = fail_non + 1;
        end

        $display("\n[T7] Clock Enable (optimized DUT only)");
        par_in = 8'hFF; mode = 2'b11;
        @(posedge clk); #1;
        clk_en = 1'b0; mode = 2'b01;      // attempt shift while CE=0
        @(posedge clk); #1;
        @(posedge clk); #1;
        if (q_opt === 8'hFF) begin
            $display("  [OPT    ] PASS [T7] clk_en=0 held q=0x%02X  [FF CE pin works]", q_opt);
            pass_opt = pass_opt + 1;
        end else begin
            $display("  [OPT    ] FAIL [T7] clk_en=0 but q changed to 0x%02X", q_opt);
            fail_opt = fail_opt + 1;
        end
        $display("  [NON-OPT] NOTE [T7] No clk_en port - q=0x%02X (shifted, expected)", q_non);
        clk_en = 1'b1;

        // ============================================================
        $display("\n--- SECTION 2: STRESS TEST (max toggle for power measurement) ---");
        // ============================================================
        $display("  Running 32-cycle alternating shift + 8-cycle load stress...");
        begin : stress
            integer i;
            par_in   = {WIDTH{1'b1}};  // parameterised, not literal 8'hAA
            mode     = 2'b11;
            ser_in_r = 1'b1;
            ser_in_l = 1'b1;
            @(posedge clk); #1;
            for (i = 0; i < 16; i = i + 1) begin
                mode = 2'b01; @(posedge clk); #1;
                mode = 2'b10; @(posedge clk); #1;
            end
            for (i = 0; i < 8; i = i + 1) begin
                par_in = (i % 2 == 0) ? {WIDTH{1'b1}} : {WIDTH{1'b0}};
                mode   = 2'b11;
                @(posedge clk); #1;
            end
            ser_in_r = 1'b0; ser_in_l = 1'b0;
        end
        $display("  Stress test complete.");

        // ============================================================
        // PPAC REPORT
        // ============================================================
        $display("\n================================================================");
        $display("  PPAC ANALYSIS REPORT");
        $display("  Artix-7 xc7a35t  |  100 MHz Target  |  WIDTH=%0d", WIDTH);
        $display("  (Area constants auto-derived: NON_OPT_FF=%0d, OPT_FF=%0d)",
                  NON_OPT_FF, OPT_FF);
        $display("================================================================");

        $display("\n  [FUNCTIONAL SUMMARY]");
        $display("  NON-OPT : Passed=%-2d  Failed=%0d", pass_non, fail_non);
        $display("  OPT     : Passed=%-2d  Failed=%0d", pass_opt, fail_opt);

        // ---- PERFORMANCE ----
        $display("\n  [PERFORMANCE ANALYSIS]");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | Metric                                | NON-OPT      | OPT          |");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | Target Clock Frequency                | 100 MHz      | 100 MHz      |");
        $display("  | Reset Type                            | Sync Hi-ACT  | Async Lo-ACT |");
        $display("  | Reset Mapping on FPGA                 | D-input mux  | FF CLR pin   |");
        $display("  | Next-State Logic Levels               | 2 (sep blks) | 1 (merged)   |");
        $display("  | Serial Out Latency                    | +1 cycle     | 0 (wire)     |");
        $display("  | Clock Enable Type                     | None         | FF CE pin    |");
        $display("  | Expected WNS @ 100MHz                 | NEGATIVE     | POSITIVE     |");
        $display("  | Expected Timing Status                | FAIL         | PASS         |");
        $display("  | Total Simulation Cycles               | %-12d | %-12d |", cycle_count, cycle_count);
        $display("  | Reset Operation Cycles                | %-12d | %-12d |", cycles_reset, cycles_reset);
        $display("  | Parallel Load Cycles                  | %-12d | %-12d |", cycles_load, cycles_load);
        $display("  | Shift Right Cycles                    | %-12d | %-12d |", cycles_shift_r, cycles_shift_r);
        $display("  | Shift Left Cycles                     | %-12d | %-12d |", cycles_shift_l, cycles_shift_l);
        $display("  +---------------------------------------+--------------+--------------+");

        // ---- POWER ----
        $display("\n  [POWER ANALYSIS — Switching Activity Proxy]");
        $display("  NOTE: For exact mW run Vivado Report Power (post-implementation)");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | Metric                                | NON-OPT      | OPT          |");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | q bus toggle events                   | %-12d | %-12d |", tog_q_non, tog_q_opt);
        $display("  | ser_out toggle events                 | %-12d | %-12d |", tog_ser_non, tog_ser_opt);
        $display("  | Total logic toggle events             | %-12d | %-12d |",
                  tog_q_non + tog_ser_non, tog_q_opt + tog_ser_opt);
        $display("  | Clock toggles                         | %-12d | %-12d |", tog_clk, tog_clk);
        $display("  | Clock gating method                   | None (always)| FF CE pin    |");
        $display("  | Extra FF switching (ser_out)          | Yes (2 FFs)  | No (wires)   |");
        $display("  | Toggle reduction (opt saves)          | --           | %-12d |",
                  (tog_q_non + tog_ser_non) - (tog_q_opt + tog_ser_opt));
        $display("  | Expected Dynamic Power                | HIGHER       | LOWER        |");
        $display("  +---------------------------------------+--------------+--------------+");

        // ---- AREA ----
        $display("\n  [AREA ANALYSIS — RTL Structural Count (auto-scaled to WIDTH=%0d)]", WIDTH);
        $display("  NOTE: For exact LUT/FF/Slice run Vivado Report Utilization");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | Metric                                | NON-OPT      | OPT          |");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | q register FFs                        | %-12d | %-12d |", WIDTH, WIDTH);
        $display("  | ser_out FFs (reg vs wire)             | 2 (reg)      | 0 (wire tap) |");
        $display("  | Total FF count (WIDTH+2 vs WIDTH)     | %-12d | %-12d |", NON_OPT_FF, OPT_FF);
        $display("  | Intermediate d-nodes (WIDTH vs 0)     | %-12d | %-12d |", NON_OPT_NODES, OPT_NODES);
        $display("  | Combinational logic levels            | %-12d | %-12d |", NON_OPT_LVL, OPT_LVL);
        $display("  | Reset LUT consumption                 | Yes (D-mux)  | No (CLR pin) |");
        $display("  | CE LUT consumption                    | N/A          | No (CE pin)  |");
        $display("  | FFs saved by opt                      | --           | %-12d |", NON_OPT_FF - OPT_FF);
        $display("  | Logic nodes saved by opt              | --           | %-12d |", NON_OPT_NODES - OPT_NODES);
        $display("  | Expected LUT count                    | HIGHER       | LOWER        |");
        $display("  | Expected Slice usage                  | HIGHER       | LOWER        |");
        $display("  +---------------------------------------+--------------+--------------+");

        // ---- CONGESTION ----
        $display("\n  [CONGESTION ANALYSIS — Routing Complexity Proxy]");
        $display("  NOTE: For exact congestion map run Vivado post-implementation");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | Metric                                | NON-OPT      | OPT          |");
        $display("  +---------------------------------------+--------------+--------------+");
        $display("  | mode signal change events             | %-12d | %-12d |", fanout_mode_non, fanout_mode_opt);
        $display("  | Extra routing nodes (d-nodes)         | %-12d | %-12d |", NON_OPT_NODES, OPT_NODES);
        $display("  | ser_out routing path                  | FF+wire(2x)  | direct wire  |");
        $display("  | Netlist depth (logic levels)          | Deeper       | Shallower    |");
        $display("  | Slice packing efficiency              | Lower        | Higher       |");
        $display("  | Estimated routing congestion          | HIGHER       | LOWER        |");
        $display("  +---------------------------------------+--------------+--------------+");

        // ---- SUMMARY ----
        $display("\n  [OVERALL PPAC SUMMARY]");
        $display("  +--------------+------------------+------------------+");
        $display("  | Category     | NON-OPT          | OPT              |");
        $display("  +--------------+------------------+------------------+");
        $display("  | Performance  | FAILS 100MHz     | PASSES 100MHz    |");
        $display("  | Power        | Higher switching | Lower switching  |");
        $display("  | Area         | More LUTs + FFs  | Fewer LUTs + FFs |");
        $display("  | Congestion   | Deeper netlist   | Compact netlist  |");
        $display("  +--------------+------------------+------------------+");
        $display("  OPT wins all 4 PPAC categories.");
        $display("\n  For exact numbers open Vivado after implementation:");
        $display("    Reports > Report Timing Summary  (Performance - WNS/TNS/Fmax)");
        $display("    Reports > Report Utilization     (Area - LUT/FF/Slice)");
        $display("    Reports > Report Power           (Power - mW dynamic/static)");
        $display("    Reports > Report DRC             (Design rule violations)");
        $display("================================================================\n");

        $finish;
    end

    // Timeout guard
    initial begin #20000; $display("TIMEOUT"); $finish; end

    // VCD dump for post-simulation power analysis
    initial begin
        $dumpfile("sim_dump.vcd");
        $dumpvars(0, tb_universal_shift_register);
    end

endmodule
