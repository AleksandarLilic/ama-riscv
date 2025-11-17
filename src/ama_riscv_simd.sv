`include "ama_riscv_defines.svh"

module ama_riscv_simd (
    input  mult_op_t op,
    input  simd_t a,
    input  simd_t b,
    output simd_t p
);

localparam int unsigned W = 32;

// AND matrix for signed multiply using Baugh–Wooley, otherwise unsigned
simd_t [W-1:0] pp; // partial products matrix
always_comb begin
    for (int i = 0; i < W; i++) begin
        for (int j = 0; j < W; j++) begin
            logic y;
            y = (a[i] & b[j]);
            pp[i][j] = y; // everything else (including sign*sign)
            if (op != MULT_OP_MULHU) begin // the only unsigned multiplication
                if ((i == (W-1)) && (j < (W-1))) pp[i][j] = ~y; // sign of A
                else if ((i < (W-1)) && (j == (W-1))) pp[i][j] = ~y; // of B
            end
        end
    end
end

simd_d_t [W-1+1:0] ppv; // double-wide pp view
always_comb begin
    for (int i = 0; i < W; i++) begin
        simd_d_t x;
        x = {32'h0, pp[i]};
        ppv[i] = (x << i);
    end
    ppv[W] = {1'b1, 30'h0, 1'b1, 32'h0}; // set at index [MSB] and [W]
end

// first four trees in parallel
simd_d_t [1:0] o_tree_0, o_tree_1, o_tree_2, o_tree_3;
csa_tree_8 #(.W(64)) csa_tree_8_i0 (.a (ppv[7:0]), .o (o_tree_0));
csa_tree_8 #(.W(64)) csa_tree_8_i1 (.a (ppv[15:8]), .o (o_tree_1));
csa_tree_8 #(.W(64)) csa_tree_8_i2 (.a (ppv[23:16]), .o (o_tree_2));
csa_tree_8 #(.W(64)) csa_tree_8_i3 (.a (ppv[31:24]), .o (o_tree_3));

simd_d_t [7:0] i_tree_f, i_tree_f_d;
assign i_tree_f = {o_tree_3, o_tree_2, o_tree_1, o_tree_0};

// TODO: provisional pipeline
assign i_tree_f_d = i_tree_f;

// final tree
simd_d_t [1:0] o_tree_f;
csa_tree_8 #(.W(64)) csa_tree_8_f_i (.a (i_tree_f_d), .o(o_tree_f));

simd_d_t res_u, res_s;
assign res_u = o_tree_f[0] + o_tree_f[1];
assign res_s = res_u + ppv[W];

logic b_sign_bit;
assign b_sign_bit = b[ARCH_WIDTH-1]; // b MSB
simd_t res_su;
assign res_su = b_sign_bit ? (res_s.w[1] + a) : res_s.w[1];

always_comb begin
    p = 'h0;
    unique case (op)
        MULT_OP_MUL: p = res_s[ARCH_WIDTH-1:0];
        MULT_OP_MULH: p = res_s[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH];
        MULT_OP_MULHSU: p = res_su;
        MULT_OP_MULHU: p = res_u[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH];
    endcase
end

endmodule
