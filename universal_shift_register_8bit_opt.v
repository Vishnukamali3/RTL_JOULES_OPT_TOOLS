`timescale 1ns/1ps

// ================================================================
//  8-bit Universal Shift Register — OPTIMIZED version
//  Target : Artix-7 xc7a35t-1cpg236c  |  Clock : 100 MHz
//
//  Optimizations applied:
//    1. Single clocked always block — mux merged into FF input LUT
//       Vivado packs 4:1 mux + FF into same slice. One fewer LUT level.
//    2. Intermediate 'd' node eliminated — shorter netlist, less routing
//    3. Active-low ASYNCHRONOUS reset — maps to FF dedicated CLR pin
//       No LUT consumed, fastest reset response
//    4. clk_en maps to FF CE pin — no LUT wasted, lower dynamic power
//    5. Serial outputs are WIRE TAPS — zero extra FFs, zero added delay
//    6. KEEP_HIERARCHY preserves boundary in Vivado reports
//
//  PPAC impact (vs non-optimized):
//    Performance : Passes 100 MHz timing (positive WNS)
//    Power       : Lower dynamic power (CE pin + no extra FFs)
//    Area        : Fewer LUTs + fewer FFs
//    Congestion  : Less routing (shorter netlist)
//
//  mode encoding:
//    00 -> hold
//    01 -> shift right (ser_in_r → MSB)
//    10 -> shift left  (ser_in_l → LSB)
//    11 -> parallel load
// ================================================================

(* KEEP_HIERARCHY = "YES" *)
module universal_shift_register_8bit_opt #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,        // active-low ASYNC reset → FF CLR pin
    input  wire             clk_en,       // maps to FF CE pin — no LUT used
    input  wire [1:0]       mode,
    input  wire [WIDTH-1:0] par_in,
    input  wire             ser_in_r,
    input  wire             ser_in_l,
    output reg  [WIDTH-1:0] q,
    output wire             ser_out_r,    // wire tap — zero FF delay
    output wire             ser_out_l     // wire tap — zero FF delay
);

    // ----------------------------------------------------------------
    // Serial outputs — pure wire taps, no FF
    // Non-optimized wastes 2 FFs here
    // ----------------------------------------------------------------
    assign ser_out_r = q[0];
    assign ser_out_l = q[WIDTH-1];

    // ----------------------------------------------------------------
    // Single clocked process — mux absorbed into FF input LUT
    // Vivado packs FF-with-mux into one slice
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};
        end else if (clk_en) begin
            case (mode)
                2'b00: q <= q;
                2'b01: q <= {ser_in_r, q[WIDTH-1:1]};
                2'b10: q <= {q[WIDTH-2:0], ser_in_l};
                2'b11: q <= par_in;
                default: q <= q;
            endcase
        end
    end

endmodule
