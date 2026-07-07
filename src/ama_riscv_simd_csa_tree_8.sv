`include "ama_riscv_defines.svh"

// lane-aware kind of generic csa_tree_8
module ama_riscv_simd_csa_tree_8 #(
    parameter unsigned W = 8,
    // stage 1 & 2 align (right shift) amounts
    parameter unsigned S1A,
    parameter unsigned S2A
)(
    input simd_d_t [7:0] a,
    input logic s1a,
    input logic s2a,
    output simd_d_t [1:0] o,
    output simd_d_t [3:0] taps
);

// S1
simd_d_t [7:0] aa; // a aligned
always_comb begin
    aa = a;
    if (s1a) begin
        aa[2] = (a[2] >> S1A);
        aa[3] = (a[3] >> S1A);
        aa[6] = (a[6] >> S1A);
        aa[7] = (a[7] >> S1A);
    end
end

simd_d_t [3:0] m; // mid-res
csa_tree_4 #(.W(W)) csa_tree_4_top_l_i (.a(aa[7:4]), .o(m[3:2]));
csa_tree_4 #(.W(W)) csa_tree_4_top_r_i (.a(aa[3:0]), .o(m[1:0]));

// S2
simd_d_t [3:0] ma; // m aligned
always_comb begin
    ma = m;
    if (s2a) begin
        ma[2] = (m[2] >> S2A);
        ma[3] = (m[3] >> S2A);
    end
end

csa_tree_4 #(.W(W)) csa_tree_4_bot_i (.a(ma), .o(o));

// taps
assign taps = m;

endmodule
