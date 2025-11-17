`include "ama_riscv_defines.svh"

module csa_tree_8 #(
    parameter unsigned W = 8
)(
    input simd_d_t [7:0] a,
    output simd_d_t [1:0] o
);

simd_d_t [1:0] s_l0, c_l0, s_l1, c_l1;
simd_d_t s_l2, c_l2, s_l3, c_l3;

csa #(.W(64)) csa_i_l0_0 (.x(a[0]), .y(a[1]), .z(a[2]), .s(s_l0[0]), .c(c_l0[0]));
csa #(.W(64)) csa_i_l0_1 (.x(a[3]), .y(a[4]), .z(a[5]), .s(s_l0[1]), .c(c_l0[1]));
csa #(.W(64)) csa_i_l1_0 (.x(s_l0[0]), .y(c_l0[0]<<1), .z(s_l0[1]), .s(s_l1[0]), .c(c_l1[0]));
csa #(.W(64)) csa_i_l1_1 (.x(c_l0[1]<<1), .y(a[6]), .z(a[7]), .s(s_l1[1]), .c(c_l1[1]));
csa #(.W(64)) csa_i_l2_0 (.x(s_l1[0]), .y(c_l1[0]<<1), .z(s_l1[1]), .s(s_l2), .c(c_l2));
csa #(.W(64)) csa_i_l3_0 (.x(s_l2), .y(c_l2<<1), .z(c_l1[1]<<1), .s(s_l3), .c(c_l3));

assign o[0] = s_l3;
assign o[1] = (c_l3 << 1);

endmodule
