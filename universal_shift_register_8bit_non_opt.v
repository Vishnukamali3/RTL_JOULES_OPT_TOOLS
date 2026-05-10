`timescale 1ns/1ps

// ================================================================
//  8-bit Universal Shift Register — NON-OPTIMIZED version
//  Target : Artix-7 xc7a35t-1cpg236c  |  Clock : 100 MHz
//
//  Intentional inefficiencies (for comparison study):
//    1. Separate always @(*) block — extra LUT level in critical path
//    2. Intermediate 'd' register node — extra netlist node
//    3. Active-high SYNCHRONOUS reset — uses D-input mux, not FF CLR pin
//    4. No clock enable — FF always active, higher dynamic power
//    5. Serial outputs REGISTERED — 2 extra FFs, 1 cycle extra delay
//
//  PPAC impact (vs optimized):
//    Performance : Fails 100 MHz timing (negative WNS)
//    Power       : Higher dynamic power (no CE, 2 extra FFs toggling)
//    Area        : More LUTs + more FFs
//    Congestion  : More routing due to extra nodes
//
//  mode encoding:
//    00 -> hold
//    01 -> shift right (ser_in_r → MSB)
//    10 -> shift left  (ser_in_l → LSB)
//    11 -> parallel load
// ================================================================

module universal_shift_register_8bit_non_opt #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst,          // active-high SYNCHRONOUS reset
    input  wire [1:0]       mode,
    input  wire [WIDTH-1:0] par_in,
    input  wire             ser_in_r,
    input  wire             ser_in_l,
    output reg  [WIDTH-1:0] q,
    output reg              ser_out_r,   // registered — extra FF + 1 cycle delay
    output reg              ser_out_l    // registered — extra FF + 1 cycle delay
);

    reg [WIDTH-1:0] d;   // intermediate next-state node (extra LUT level)

    // ----------------------------------------------------------------
    // Combinational block SEPARATE from FF block
    // Creates extra logic level — Vivado cannot merge into FF input LUT
    // ----------------------------------------------------------------
    always @(*) begin
        d = q;  // default assignment — prevents latch inference
        case (mode)
            2'b00: d = q;
            2'b01: d = {ser_in_r, q[WIDTH-1:1]};
            2'b10: d = {q[WIDTH-2:0], ser_in_l};
            2'b11: d = par_in;
        endcase
    end

    // ----------------------------------------------------------------
    // Clocked block — synchronous reset forces D-input mux path
    // instead of dedicated FF CLR pin → slower, wastes LUT resource
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            q         <= {WIDTH{1'b0}};
            ser_out_r <= 1'b0;
            ser_out_l <= 1'b0;
        end else begin
            q         <= d;
            ser_out_r <= d[0];          // registered — extra FF delay
            ser_out_l <= d[WIDTH-1];    // registered — extra FF delay
        end
    end

endmodule
