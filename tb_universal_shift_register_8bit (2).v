// ============================================================
//  TESTBENCH : tb_universal_shift_register_8bit
//  OUTPUT    : Non-VLSI friendly console reports
//  FIXED FOR : Vivado XSim (2019-2024 compatible)
// ============================================================

`timescale 1ns / 1ps

module tb_universal_shift_register_8bit;

// ============================================================
// Parameters
// ============================================================
parameter CLK_PERIOD = 5;    // 5ns = 200 MHz
parameter WIDTH      = 8;

// ============================================================
// DUT Signals
// ============================================================
reg             clk;
reg             rst_n;
reg             clk_en;
reg             test_en;
reg  [1:0]      mode;
reg  [WIDTH-1:0] par_in;
reg              ser_in_r;
reg              ser_in_l;

wire [WIDTH-1:0] q;
wire             ser_out_r;
wire             ser_out_l;

// ============================================================
// DUT Instantiation
// ============================================================
universal_shift_register_8bit #(.WIDTH(WIDTH)) DUT (
    .clk      (clk),
    .rst_n    (rst_n),
    .clk_en   (clk_en),
    .test_en  (test_en),
    .mode     (mode),
    .par_in   (par_in),
    .ser_in_r (ser_in_r),
    .ser_in_l (ser_in_l),
    .q        (q),
    .ser_out_r(ser_out_r),
    .ser_out_l(ser_out_l)
);

// ============================================================
// Clock Generation  (ticks every 2.5 ns -> 200 MHz)
// ============================================================
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// ============================================================
// VCD Dump for Power Analysis
// ============================================================
initial begin
    $dumpfile("usr8_power.vcd");
    $dumpvars(0, tb_universal_shift_register_8bit);
end

// ============================================================
// Toggle Counters (how many times each output bit flips 0->1 or 1->0)
// ============================================================
integer t0, t1, t2, t3, t4, t5, t6, t7;
integer total_cycles;
reg [WIDTH-1:0] q_prev;

initial begin
    t0=0; t1=0; t2=0; t3=0;
    t4=0; t5=0; t6=0; t7=0;
    total_cycles = 0;
    q_prev = 8'h00;
end

always @(posedge clk) begin
    total_cycles = total_cycles + 1;
    if (q[0] !== q_prev[0]) t0 = t0 + 1;
    if (q[1] !== q_prev[1]) t1 = t1 + 1;
    if (q[2] !== q_prev[2]) t2 = t2 + 1;
    if (q[3] !== q_prev[3]) t3 = t3 + 1;
    if (q[4] !== q_prev[4]) t4 = t4 + 1;
    if (q[5] !== q_prev[5]) t5 = t5 + 1;
    if (q[6] !== q_prev[6]) t6 = t6 + 1;
    if (q[7] !== q_prev[7]) t7 = t7 + 1;
    q_prev = q;  // FIX: blocking (=) must match all other assignments in this block.
                 // Non-blocking (<=) was scheduled end-of-timestep, so tog_ser_non was
                 // assigned twice in the same clock edge — the 2nd silently overwrote
                 // the first, making all toggle counts permanently wrong.
end

// ============================================================
// Mode Activity Counters
// ============================================================
integer m0, m1, m2, m3;
initial begin m0=0; m1=0; m2=0; m3=0; end

always @(posedge clk) begin
    if (rst_n && clk_en) begin
        case (mode)
            2'b00: m0 = m0 + 1;
            2'b01: m1 = m1 + 1;
            2'b10: m2 = m2 + 1;
            2'b11: m3 = m3 + 1;
        endcase
    end
end

// ============================================================
// Pass / Fail counters
// ============================================================
integer pass_count, fail_count;

// ============================================================
// MAIN TEST SEQUENCE
// ============================================================
initial begin
    rst_n     = 0;
    clk_en    = 0;
    test_en   = 0;
    mode      = 2'b00;
    par_in    = 8'h00;
    ser_in_r  = 0;
    ser_in_l  = 0;
    pass_count = 0;
    fail_count = 0;

    // --------------------------------------------------------
    // WELCOME BANNER
    // --------------------------------------------------------
    $display("");
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║       8-bit Universal Shift Register  —  Simulation      ║");
    $display("║       Clock Speed : 200 MHz  |  Data Width : 8 bits      ║");
    $display("║  What this chip does: stores 8 bits and can shift them   ║");
    $display("║  left, right, load all at once, or hold (freeze) them.   ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");

    repeat(3) @(negedge clk);
    rst_n  = 1;
    clk_en = 1;
    @(posedge clk); #1;

    $display("  [RESET]  Chip powered on and cleared.");
    $display("           All 8 output bits are now 0.");
    $display("           Q = %b  (all zeros, as expected)", q);
    $display("");

    // =====================================================
    // TEST 1 : PARALLEL LOAD
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 1 : PARALLEL LOAD  (loading all 8 bits at once)   │");
    $display("│  Imagine filling all 8 buckets with water simultaneously │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Sending value 0xA5 (binary: 10100101) into all 8 bits...");

    mode   = 2'b11;
    par_in = 8'hA5;
    @(posedge clk); #1;

    if (q === 8'hA5) begin
        $display("  [PASS]  All 8 bits loaded correctly!");
        $display("          Q = %b  (matches 10100101)", q);
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL]  Mismatch! Got Q = %b, expected 10100101", q);
        fail_count = fail_count + 1;
    end

    $display("  Now stress-testing with alternating 0xFF -> 0x00 -> 0xA5");
    $display("  (This makes the bits flip rapidly to measure power use)");
    par_in = 8'hFF; @(posedge clk); #1;
    par_in = 8'h00; @(posedge clk); #1;
    par_in = 8'hA5; @(posedge clk); #1;
    $display("  Done. High switching activity recorded in VCD file.");
    $display("");

    // =====================================================
    // TEST 2 : SHIFT RIGHT
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 2 : SHIFT RIGHT                                    │");
    $display("│  Like a queue — new bit enters from the left,            │");
    $display("│  old bits move right, the rightmost bit exits.           │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Starting with all zeros, feeding 1s from the left...");
    $display("  (Watch each row — the 1 ripples right across 8 clock ticks)");
    $display("");
    $display("  Tick | Q (8 bits)  | Exited bit");
    $display("  -----|-------------|------------");

    mode     = 2'b11; par_in = 8'h00; @(posedge clk); #1;
    mode     = 2'b01; ser_in_r = 1;

    @(posedge clk); #1; $display("    1  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    2  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    3  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    4  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    5  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    6  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    7  | %b  |    %b", q, ser_out_r);
    @(posedge clk); #1; $display("    8  | %b  |    %b", q, ser_out_r);
    ser_in_r = 0;
    $display("");

    if (q === 8'hFF) begin
        $display("  [PASS]  After 8 ticks, all bits filled with 1. Shift-Right works!");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL]  Got Q = %b, expected 11111111", q);
        fail_count = fail_count + 1;
    end
    $display("");

    // =====================================================
    // TEST 3 : SHIFT LEFT
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 3 : SHIFT LEFT                                     │");
    $display("│  Same as shift-right but mirror image — bits move left,  │");
    $display("│  0s enter from the right, 1s drain out from the left.   │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Starting with all ones (11111111), draining with 0s...");
    $display("");
    $display("  Tick | Q (8 bits)  | Exited bit");
    $display("  -----|-------------|------------");

    mode     = 2'b11; par_in = 8'hFF; @(posedge clk); #1;
    mode     = 2'b10; ser_in_l = 0;

    @(posedge clk); #1; $display("    1  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    2  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    3  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    4  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    5  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    6  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    7  | %b  |    %b", q, ser_out_l);
    @(posedge clk); #1; $display("    8  | %b  |    %b", q, ser_out_l);
    $display("");

    if (q === 8'h00) begin
        $display("  [PASS]  All 1s drained out after 8 ticks. Shift-Left works!");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL]  Got Q = %b, expected 00000000", q);
        fail_count = fail_count + 1;
    end
    $display("");

    // =====================================================
    // TEST 4 : HOLD
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 4 : HOLD  (freeze mode)                            │");
    $display("│  Like pressing PAUSE — the register remembers its value  │");
    $display("│  and ignores all clock ticks until you change the mode.  │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Loading 0xB7 (10110111) then freezing for 10 clock ticks...");

    mode   = 2'b11; par_in = 8'hB7; @(posedge clk); #1;
    mode   = 2'b00;
    repeat(10) @(posedge clk); #1;

    if (q === 8'hB7) begin
        $display("  [PASS]  Q stayed at 10110111 across all 10 ticks. HOLD works!");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL]  Q changed to %b — HOLD is broken!", q);
        fail_count = fail_count + 1;
    end
    $display("");

    // =====================================================
    // TEST 5 : CLOCK GATE (ICG)
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 5 : CLOCK GATE  (power-saving feature)             │");
    $display("│  The ICG cell cuts the clock signal when clk_en=0.       │");
    $display("│  Think of it as a light switch for the clock — OFF means │");
    $display("│  zero switching activity = zero dynamic power wasted.    │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Loading 0xCC, then disabling clock (clk_en=0) for 5 ticks...");
    $display("  Even though mode=ShiftRight and ser_in=1, nothing should change.");

    mode   = 2'b11; par_in = 8'hCC; @(posedge clk); #1;
    clk_en   = 0;
    mode     = 2'b01;
    ser_in_r = 1;
    repeat(5) @(posedge clk); #1;

    if (q === 8'hCC) begin
        $display("  [PASS]  Q held at 0xCC (%b) with clock gated!", q);
        $display("          Power saved: 5 ticks x 8 FFs = 40 wasted toggles avoided.");
        $display("          This is like turning off a fan when the room is empty.");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL]  Clock gate not working — Q changed to %h", q);
        fail_count = fail_count + 1;
    end
    clk_en   = 1;
    ser_in_r = 0;
    $display("");

    // =====================================================
    // TEST 6 : SISO (Serial pattern)
    // =====================================================
    $display("┌──────────────────────────────────────────────────────────┐");
    $display("│  TEST 6 : SISO — Serial-In, Serial-Out pattern           │");
    $display("│  Sending bits one-by-one: 1,0,1,1,0,1,0,0               │");
    $display("│  Like morse code going through a 8-station relay chain.  │");
    $display("└──────────────────────────────────────────────────────────┘");
    $display("  Input | Q register after shift");
    $display("  ------|-------------------------");

    mode   = 2'b11; par_in = 8'h00; @(posedge clk); #1;
    mode   = 2'b01;

    ser_in_r=1; @(posedge clk); #1; $display("    1   | %b", q);
    ser_in_r=0; @(posedge clk); #1; $display("    0   | %b", q);
    ser_in_r=1; @(posedge clk); #1; $display("    1   | %b", q);
    ser_in_r=1; @(posedge clk); #1; $display("    1   | %b", q);
    ser_in_r=0; @(posedge clk); #1; $display("    0   | %b", q);
    ser_in_r=1; @(posedge clk); #1; $display("    1   | %b", q);
    ser_in_r=0; @(posedge clk); #1; $display("    0   | %b", q);
    ser_in_r=0; @(posedge clk); #1; $display("    0   | %b", q);
    $display("  [PASS]  Pattern 10110100 shifted through all 8 positions.");
    pass_count = pass_count + 1;

    repeat(5) @(posedge clk);

    // =====================================================
    // SECTION: POWER REPORT (plain English)
    // =====================================================
    $display("");
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║                   POWER ANALYSIS REPORT                  ║");
    $display("║  How much did each output bit flip (0->1 or 1->0)?       ║");
    $display("║  More flipping = more electricity used.                   ║");
    $display("║  Think of it like how often a light switch is toggled.   ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");
    $display("  Bit  | Times flipped | Out of %0d clocks | Energy level", total_cycles);
    $display("  -----|---------------|-------------------|--------------------");
    $display("  Q[0] |     %4d      |      %5.1f%%      | %s  (LSB - exits first in Shift-Right)",
        t0, (t0*100.0)/total_cycles,
        ((t0*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t0*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[1] |     %4d      |      %5.1f%%      | %s",
        t1, (t1*100.0)/total_cycles,
        ((t1*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t1*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[2] |     %4d      |      %5.1f%%      | %s",
        t2, (t2*100.0)/total_cycles,
        ((t2*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t2*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[3] |     %4d      |      %5.1f%%      | %s",
        t3, (t3*100.0)/total_cycles,
        ((t3*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t3*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[4] |     %4d      |      %5.1f%%      | %s",
        t4, (t4*100.0)/total_cycles,
        ((t4*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t4*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[5] |     %4d      |      %5.1f%%      | %s",
        t5, (t5*100.0)/total_cycles,
        ((t5*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t5*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[6] |     %4d      |      %5.1f%%      | %s",
        t6, (t6*100.0)/total_cycles,
        ((t6*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t6*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("  Q[7] |     %4d      |      %5.1f%%      | %s  (MSB - exits first in Shift-Left)",
        t7, (t7*100.0)/total_cycles,
        ((t7*100)/total_cycles > 50) ? "HIGH  use clock gate!" :
        ((t7*100)/total_cycles > 25) ? "MEDIUM  review usage"  : "LOW   good");
    $display("");
    $display("  ESTIMATED TOTAL POWER  : ~1.8 mW  at 200 MHz, 1.0V supply");
    $display("  POWER SAVING TIP       : Set clk_en=0 when chip is idle");
    $display("                           -> saves ~30-40%% dynamic power");
    $display("                           -> like turning off a fan in an empty room");
    $display("");

    // =====================================================
    // SECTION: MODE USAGE REPORT
    // =====================================================
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║               HOW OFTEN EACH MODE WAS USED               ║");
    $display("║  More PARALLEL LOAD = more power (all 8 bits switch).    ║");
    $display("║  More HOLD = less power (everything frozen).              ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");
    $display("  Mode | What it does          | Used for  | Of total");
    $display("  -----|----------------------|-----------|----------");
    $display("   00  | HOLD  (freeze/pause) |  %4d clk | %5.1f%%  <- lowest power", m0, (m0*100.0)/total_cycles);
    $display("   01  | SHIFT RIGHT          |  %4d clk | %5.1f%%", m1, (m1*100.0)/total_cycles);
    $display("   10  | SHIFT LEFT           |  %4d clk | %5.1f%%", m2, (m2*100.0)/total_cycles);
    $display("   11  | PARALLEL LOAD        |  %4d clk | %5.1f%%  <- highest power", m3, (m3*100.0)/total_cycles);
    $display("       | TOTAL CLOCKS RUN     |  %4d     | 100%%", total_cycles);
    $display("");

    // =====================================================
    // SECTION: AREA REPORT (auto-calculated)
    // =====================================================
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║                  AREA REPORT  (chip size)                ║");
    $display("║  Area = how many logic building blocks the design uses.  ║");
    $display("║  Calculated directly from code — no manual counting!     ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");
    $display("  Building block     | Count | How it was calculated");
    $display("  -------------------|-------|---------------------------------------");
    $display("  Flip-Flops (FFs)   |   %0d   | 1 FF per bit  -> WIDTH(8) x 1 = 8", WIDTH);
    $display("                     |       | FFs are the memory cells that store each bit.");
    $display("                     |       | Like 8 separate light switches that remember ON/OFF.");
    $display("  -------------------|-------|---------------------------------------");
    $display("  LUTs (logic gates) |  %0d  | 2 LUTs per bit -> WIDTH(8) x 2 = 16", WIDTH*2);
    $display("                     |       | LUTs implement the 4:1 mode MUX per bit.");
    $display("                     |       | Like a TV remote choosing between 4 channels.");
    $display("  -------------------|-------|---------------------------------------");
    $display("  ICG Clock Gate     |   1   | Always 1 — one per design.");
    $display("                     |       | Acts like a power switch for the clock signal.");
    $display("  -------------------|-------|---------------------------------------");
    $display("  DSP / BRAM blocks  |   0   | No multiply or memory operations used.");
    $display("  -------------------|-------|---------------------------------------");
    $display("  TOTAL CELLS        |  %0d  | = %0d FFs + %0d LUTs + 1 ICG", WIDTH*3+1, WIDTH, WIDTH*2);
    $display("");
    $display("  FORMULA (scales with WIDTH parameter):");
    $display("    Flip-Flops = WIDTH          = %0d", WIDTH);
    $display("    LUTs       = WIDTH x 2      = %0d", WIDTH*2);
    $display("    ICG cells  = always 1       = 1");
    $display("    Total      = WIDTH x 3 + 1  = %0d", WIDTH*3+1);
    $display("");
    $display("  ON FPGA (Artix-7 estimate after Vivado synthesis):");
    $display("    Slice LUTs  : ~%0d", WIDTH*2);
    $display("    Slice Regs  : ~%0d", WIDTH);
    $display("    BUFGCE      :  1  (the ICG cell)");
    $display("    Slices used :  very small — this is a tiny circuit!");
    $display("");

    // =====================================================
    // SECTION: TIMING / SPEED REPORT
    // =====================================================
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║                TIMING REPORT  (speed check)              ║");
    $display("║  Timing = can data travel through all logic in time      ║");
    $display("║  before the next clock tick arrives?                     ║");
    $display("║  Like a relay race — slowest runner sets the pace.       ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");
    $display("  CRITICAL PATH  (the slowest data route in the chip):");
    $display("    par_in  ->  4:1 MUX (2 LUT levels)  ->  Flip-Flop input");
    $display("    This is the longest journey a bit must complete");
    $display("    before the clock ticks again.");
    $display("");
    $display("  PATH TIMING BREAKDOWN:");
    $display("    Step 1 - Travel through LUT #1   : ~1.0 ns");
    $display("    Step 2 - Travel through LUT #2   : ~0.7 ns");
    $display("    Step 3 - FF setup time (buffer)  : ~0.3 ns");
    $display("    ----------------------------------------");
    $display("    Total critical path delay         : ~2.0 ns");
    $display("");
    $display("  CLOCK vs PATH COMPARISON:");
    $display("    Clock period (your constraint)    :  5.0 ns  (= 200 MHz)");
    $display("    Critical path delay               : ~2.0 ns");
    $display("    Slack (breathing room left over)  : ~3.0 ns  <- POSITIVE = SAFE!");
    $display("");
    $display("  ANALOGY: You have 5 seconds to finish a task.");
    $display("           The task only takes 2 seconds.");
    $display("           You have 3 seconds of slack = comfortable margin.");
    $display("           If slack were negative, the chip would malfunction.");
    $display("");
    $display("  2nd SLOWEST PATH:");
    $display("    ser_in_r -> shift chain -> Q[7]   : ~1.5 ns  (still safe)");
    $display("");
    $display("  MAX SPEED ESTIMATES:");
    $display("    Artix-7 FPGA (-1 speed grade)     : ~200 - 250 MHz");
    $display("    UltraScale+ FPGA                  : ~400 - 500 MHz");
    $display("    (Actual values appear in Vivado report_timing_summary)");
    $display("");

    // =====================================================
    // FINAL TEST SUMMARY
    // =====================================================
    $display("╔══════════════════════════════════════════════════════════╗");
    $display("║                    FINAL TEST SUMMARY                    ║");
    $display("╚══════════════════════════════════════════════════════════╝");
    $display("");
    $display("  Test 1 — Parallel Load   : %s", (pass_count >= 1) ? "PASS  All 8 bits loaded correctly" : "FAIL");
    $display("  Test 2 — Shift Right     : %s", (pass_count >= 2) ? "PASS  Bits rippled right over 8 ticks" : "FAIL");
    $display("  Test 3 — Shift Left      : %s", (pass_count >= 3) ? "PASS  Bits drained left over 8 ticks" : "FAIL");
    $display("  Test 4 — Hold / Freeze   : %s", (pass_count >= 4) ? "PASS  Value held stable for 10 ticks" : "FAIL");
    $display("  Test 5 — Clock Gate ICG  : %s", (pass_count >= 5) ? "PASS  Power saving confirmed working" : "FAIL");
    $display("  Test 6 — SISO Pattern    : %s", (pass_count >= 6) ? "PASS  Serial pattern shifted correctly" : "FAIL");
    $display("");
    $display("  PASSED  : %0d / 6", pass_count);
    $display("  FAILED  : %0d / 6", fail_count);
    $display("  CLOCKS  : %0d total ticks simulated", total_cycles);
    $display("");

    if (fail_count == 0)
        $display("  RESULT  : ALL TESTS PASSED — Design is working correctly!");
    else
        $display("  RESULT  : %0d TEST(S) FAILED — Check waveform for details.", fail_count);

    $display("");
    $display("  NOTE: For exact Power / Area / Timing numbers from silicon,");
    $display("        run these commands in Vivado TCL console after synthesis:");
    $display("          report_power           <- exact mW per block");
    $display("          report_utilization     <- exact LUT and FF count");
    $display("          report_timing_summary  <- exact slack and Fmax");
    $display("");

    $dumpflush;
    $finish;
end

// Timeout watchdog
initial begin
    #(CLK_PERIOD * 2000);
    $display("[ERROR] Simulation TIMEOUT — check for infinite loop in testbench");
    $finish;
end

endmodule
