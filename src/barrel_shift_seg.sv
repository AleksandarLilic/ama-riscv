`include "ama_riscv_defines.svh"

module barrel_shift_seg #(
    parameter unsigned R = 0 // reversible, i.e. use for right shift as well
)(
    input logic [31:0] a,
    input logic [4:0] shamt,
    input simd_shift_el_width_t ew,
    /* verilator lint_off UNUSEDSIGNAL */
    input simd_shift_kind_t kind, // unused on R=0
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [31:0] s
);

if (R > 1) begin: check_width
    $error("barrel_shift_seg: R must be 0 or 1");
end

localparam unsigned SHAMT = 5;

//------------------------------------------------------------------------------
// ensure shamt is in range
logic [4:0] shamt_m;
always_comb begin
    unique case (ew)
        SIMD_SHIFT_EL_WIDTH_4:  shamt_m = (shamt & 5'd3);
        SIMD_SHIFT_EL_WIDTH_8:  shamt_m = (shamt & 5'd7);
        SIMD_SHIFT_EL_WIDTH_16: shamt_m = (shamt & 5'd15);
        SIMD_SHIFT_EL_WIDTH_32: shamt_m = shamt;
        default:                shamt_m = shamt;
    endcase
end

//------------------------------------------------------------------------------
// set up first stage
logic [31:0] stage [SHAMT+1];

if (R) begin: g_rev_in
logic [31:0] a_rev;
bit_reverse #(.W(32)) br_in (.a(a), .s(a_rev));
assign stage[0] = kind[1] ? a_rev : a; // on shift right, feed in reversed input

end else begin: g_pass_in
assign stage[0] = a;
end

//------------------------------------------------------------------------------
// segmented shifts

for (genvar si = 0; si < SHAMT; si++) begin : g_stage
    localparam int unsigned SV = (1 << si); // fixed shift value this stage
    for (genvar idx = 0; idx < 32; idx++) begin : g_bit

        logic fb; // fill bit
        if (R) begin: g_fill_bit_sra
            // element sign = bottom of idx's reversed lane (8/16 only)
            logic fb_sign;
            assign fb_sign = (ew == SIMD_SHIFT_EL_WIDTH_8) ?
                stage[si][(idx/8)*8] : stage[si][(idx/16)*16];
            assign fb = (kind == SIMD_SHIFT_KIND_SRA) ? fb_sign : 1'b0;

        end else begin: g_fill_bit_0
            assign fb = 1'b0;
        end

        if (idx >= SV) begin : g_shift
            // boundary = source bit (idx-SV) is below idx's element
            logic lane_boundary; // boundary as wide as the shamt amount
            always_comb begin
                unique case (ew)
                    SIMD_SHIFT_EL_WIDTH_4:  lane_boundary = ((idx % 4)  < SV);
                    SIMD_SHIFT_EL_WIDTH_8:  lane_boundary = ((idx % 8)  < SV);
                    SIMD_SHIFT_EL_WIDTH_16: lane_boundary = ((idx % 16) < SV);
                    SIMD_SHIFT_EL_WIDTH_32: lane_boundary = ((idx % 32) < SV);
                    default:     lane_boundary = 1'b0;
                endcase
            end
            logic shift_val;
            assign shift_val = (lane_boundary ? fb : stage[si][idx-SV]);
            assign stage[si+1][idx] = shamt_m[si] ? shift_val : stage[si][idx];

        end else begin : g_fill // idx < SV: shifting always pulls in 0
            assign stage[si+1][idx] = shamt_m[si] ? fb : stage[si][idx];
        end

    end
end

//------------------------------------------------------------------------------
// align/pass output
if (R) begin: g_rev_out
logic [31:0] s_rev;
bit_reverse #(.W(32)) br_out (.a(stage[SHAMT]), .s(s_rev));
assign s = kind[1] ? s_rev : stage[SHAMT]; // reverse back on output

end else begin: g_pass_out
assign s = stage[SHAMT];
end

//------------------------------------------------------------------------------
// asserts
`ifndef SYNT
if (R) begin: g_assert_shift_right_ew
always_comb begin
    if (kind[1]) begin
        assert ((ew == SIMD_SHIFT_EL_WIDTH_16) || (ew == SIMD_SHIFT_EL_WIDTH_8))
        else $error(1,
            "BARREL SHIFT SEG: only 16 and 8-bit elements are supported on right shift - ew=%0d",
            ew
        );
    end
end
end
`endif

endmodule
