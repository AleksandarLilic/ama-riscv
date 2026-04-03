`include "ama_riscv_defines.svh"

module csa_tree_4 #(
    parameter unsigned W = 8
)(
    input simd_d_t [3:0] a,
    output simd_d_t [1:0] o
);

simd_d_t s_l0, c_l0, s_l1, c_l1;

csa #(.W(W)) csa_i_l0_0 (.x(a[0]), .y(a[1]), .z(a[2]), .s(s_l0), .c(c_l0));
csa #(.W(W)) csa_i_l1_0 (.x(s_l0), .y(c_l0<<1), .z(a[3]), .s(s_l1), .c(c_l1));

assign o[0] = s_l1;
assign o[1] = (c_l1 << 1);

endmodule
