`include "ama_riscv_defines.svh"

module csa_tree_8 #(
    parameter unsigned W = 8,
    parameter unsigned T4 = 0
)(
    input simd_d_t [7:0] a,
    output simd_d_t [1:0] o,
    output simd_d_t [3:0] taps
);

if (T4 > 1) begin: check_tree_4
    $error("csa_tree_8 T4 > 1 - only 0 or 1 supported");
end

if (T4 == 0) begin: gen_comp
    simd_d_t [1:0] s_l0, c_l0, s_l1, c_l1;
    simd_d_t s_l2, c_l2, s_l3, c_l3;

    csa #(.W(W), .A(1)) csa_i_l0_0 (.x(a[0]), .y(a[1]), .z(a[2]), .s(s_l0[0]), .c(c_l0[0]));
    csa #(.W(W), .A(1)) csa_i_l0_1 (.x(a[3]), .y(a[4]), .z(a[5]), .s(s_l0[1]), .c(c_l0[1]));
    csa #(.W(W), .A(1)) csa_i_l1_0 (.x(s_l0[0]), .y(c_l0[0]), .z(s_l0[1]), .s(s_l1[0]), .c(c_l1[0]));
    csa #(.W(W), .A(1)) csa_i_l1_1 (.x(c_l0[1]), .y(a[6]), .z(a[7]), .s(s_l1[1]), .c(c_l1[1]));
    csa #(.W(W), .A(1)) csa_i_l2_0 (.x(s_l1[0]), .y(c_l1[0]), .z(s_l1[1]), .s(s_l2), .c(c_l2));
    csa #(.W(W), .A(1)) csa_i_l3_0 (.x(s_l2), .y(c_l2), .z(c_l1[1]), .s(s_l3), .c(c_l3));

    assign o = {c_l3, s_l3};
    assign taps = '0;

end else begin: gen_tree_4
    simd_d_t [1:0] o_top_l, o_top_r;

    csa_tree_4 #(.W(W)) csa_tree_4_top_l_i (.a(a[7:4]), .o(o_top_l));
    csa_tree_4 #(.W(W)) csa_tree_4_top_r_i (.a(a[3:0]), .o(o_top_r));
    csa_tree_4 #(.W(W)) csa_tree_4_bot_i (.a({o_top_l[1], o_top_l[0], o_top_r[1], o_top_r[0]}), .o(o));

    assign taps[3] = o_top_l[1];
    assign taps[2] = o_top_l[0];
    assign taps[1] = o_top_r[1];
    assign taps[0] = o_top_r[0];

end

endmodule
