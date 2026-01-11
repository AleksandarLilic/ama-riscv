`include "ama_riscv_defines.svh"

module ama_riscv_simd (
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  stage_ctrl_t ctrl_exe_mem,
    input  simd_arith_op_t op,
    input  simd_t a,
    input  simd_t b,
    input  simd_t c_late,
    output simd_t p
);

localparam int unsigned W = 32;

// set up masks
// select which 8x8/16x16 tile (y,x) belongs to
// set ones only on diagonal tile blocks (ty == tx)

localparam int unsigned TILE_8 = 8; // 8x8 blocks
simd_t [W-1:0] mask_8;
always_comb begin
    `IT_P(y, W) `IT_P(x, W) mask_8[y][x] = ((y / TILE_8) == (x / TILE_8));
end

localparam int unsigned TILE_16 = 16; // 16x16 blocks
simd_t [W-1:0] mask_16;
always_comb begin
    `IT_P(y, W) `IT_P(x, W) mask_16[y][x] = ((y / TILE_16) == (x / TILE_16));
end

logic op_dot16, op_dot8, op_simd;
assign op_dot16 = (op == SIMD_ARITH_OP_DOT16);
assign op_dot8 = (op == SIMD_ARITH_OP_DOT8);
assign op_simd = (op_dot16 || op_dot8);

// AND matrix for signed multiply using lane-aware Baugh–Wooley
simd_t [W-1:0] pp; // partial products matrix
always_comb begin
    int lane_sz;
    if (op_dot8) lane_sz = 8;
    else if (op_dot16) lane_sz = 16;
    else lane_sz = W; // plain 32x32 signed

    `IT_P(i, W) begin
        `IT_P(j, W) begin
            logic y, flip;
            int li, lj; // lane-local indices

            // lane-local positions
            li = i % lane_sz;
            lj = j % lane_sz;

            // Baugh–Wooley rule per lane:
            // flip last row / last col, except 'sign × sign' intersection
            flip = 1'b0;
            if (op != SIMD_ARITH_OP_MULHU) begin // the only unsigned mult
                flip = (
                    ((li == lane_sz-1) && (lj != lane_sz-1)) || // "row sign"
                    ((lj == lane_sz-1) && (li != lane_sz-1)) // "col sign"
                );
            end
            y = a[i] & b[j];
            pp[i][j] = flip ? ~y : y;
        end
    end
end

simd_d_t [W-1:0] ppv; // double-wide pp view
always_comb begin
    `IT_P(i, W) begin
        simd_d_t x;
        x = {32'h0, pp[i]};
        ppv[i] = x; // idk whatever
        if (!op_simd) begin // MULT 32x32
            ppv[i] = (x << i);
        end else if (op_dot16) begin // DOT16
            // every 16 rows (one lane) shifted left per the algorithm
            // but every lane is shifted right to start at idx 0 for dotp
            ppv[i] = (
                ({32'h0, (x.w[0] & mask_16[i])} << (i % 16)) >> ((i / 16) * 16)
            );
        end else if (op_dot8) begin // DOT8
            // same as above, but done on 8-bit blocks
            ppv[i] = (
                ({32'h0, (x.w[0] & mask_8[i])} << (i % 8)) >> ((i / 8) * 8)
            );
        end
    end
end

simd_d_t corr; // correction for modified BW
always_comb begin
    corr = '0;
    if (!op_simd) begin
        // 32x32 signed MBW
        corr[32] = 1'b1;
        corr[63] = 1'b1;
    end else if (op_dot16) begin
        // 2 lanes of 16x16 signed
        corr[17] = 1'b1; // idx [16] set twice (1x per lane)
    end else if (op_dot8) begin
        // 4 lanes of 8x8 signed
        corr[10] = 1'b1; // idx [8] set four times (1x per lane)
    end
end

// first four trees in parallel
simd_d_t [1:0] o_tree_0, o_tree_1, o_tree_2, o_tree_3;
csa_tree_8 #(.W(64)) csa_tree_8_i0 (.a (ppv[7:0]), .o (o_tree_0));
csa_tree_8 #(.W(64)) csa_tree_8_i1 (.a (ppv[15:8]), .o (o_tree_1));
csa_tree_8 #(.W(64)) csa_tree_8_i2 (.a (ppv[23:16]), .o (o_tree_2));
csa_tree_8 #(.W(64)) csa_tree_8_i3 (.a (ppv[31:24]), .o (o_tree_3));

simd_t a_d;
simd_arith_op_t op_d;
simd_d_t corr_d;
simd_d_t [1:0] o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d;
logic b_sign_bit, b_sign_bit_d;
assign b_sign_bit = b[ARCH_WIDTH-1]; // b MSB

// in general case, simple FFs are fine, e.g.
//`DFF_CI_RI_RV(SIMD_ARITH_OP_MUL, op, op_d)

// but, in CPU, make sure it's aligned with stage its using
`STAGE(ctrl_exe_mem, en, o_tree_0, o_tree_0_d, 'h0)
`STAGE(ctrl_exe_mem, en, o_tree_1, o_tree_1_d, 'h0)
`STAGE(ctrl_exe_mem, en, o_tree_2, o_tree_2_d, 'h0)
`STAGE(ctrl_exe_mem, en, o_tree_3, o_tree_3_d, 'h0)
`STAGE(ctrl_exe_mem, en, op, op_d, SIMD_ARITH_OP_MUL)
`STAGE(ctrl_exe_mem, en, corr, corr_d, 'h0)
`STAGE(ctrl_exe_mem, (en && !op_simd), b_sign_bit, b_sign_bit_d, 1'b0)
`STAGE(ctrl_exe_mem, (en && !op_simd), a, a_d, 'h0)

// final tree (multiplication)
simd_d_t [7:0] i_tree_f;
simd_d_t [1:0] o_tree_f;
simd_d_t tree_sum;
assign i_tree_f = {o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d};
csa_tree_8 #(.W(64)) csa_tree_8_f_i (.a (i_tree_f), .o(o_tree_f));
assign tree_sum = (o_tree_f[0] + o_tree_f[1]);

// wrap up multiplication
simd_t mul_hu;
assign mul_hu = tree_sum.w[1];

simd_d_t [1:0] mul_s_tree;
csa #(.W(64)) csa_i_mul_s (
    .x(o_tree_f[0]),
    .y(o_tree_f[1]),
    .z(corr_d),
    .s(mul_s_tree[0]),
    .c(mul_s_tree[1])
);

simd_d_t mul_s_tree_1_aligned, mul_s;
assign mul_s_tree_1_aligned = (mul_s_tree[1] << 1);
assign mul_s = (mul_s_tree[0] + mul_s_tree_1_aligned);

simd_d_t [1:0] mul_hsu_tree;
csa #(.W(64)) csa_i_mul_hsu (
    .x(mul_s_tree[0]),
    .y(mul_s_tree_1_aligned),
    .z({a_d, 32'h0}),
    .s(mul_hsu_tree[0]),
    .c(mul_hsu_tree[1])
);

simd_d_t mul_hsu_tree_1_aligned, mul_hsu_signed;
assign mul_hsu_tree_1_aligned = (mul_hsu_tree[1] << 1);
assign mul_hsu_signed = (mul_hsu_tree[0] + mul_hsu_tree_1_aligned);

simd_t mul_hsu;
assign mul_hsu = b_sign_bit_d ? mul_hsu_signed.w[1] : mul_s.w[1];

// wrap up simd
localparam unsigned DOT8_W = (ARCH_WIDTH_H + 1); // dot8 result width, 17 bits
localparam unsigned DOT8_SIGN_EXT = (ARCH_WIDTH - DOT8_W); // sign ext, 15 bits

simd_t dot_r, dot16_r, dot8_r, dot_acc_in, dot_acc_out;
assign dot_r = mul_s.w[0];
assign dot16_r = dot_r[ARCH_WIDTH-1:0];
logic dot8_sign; // overflow detection on 65536
assign dot8_sign = (&dot_r[DOT8_W:DOT8_W-1]) ? 1'b0 : dot_r[DOT8_W-1];
assign dot8_r = {{DOT8_SIGN_EXT{dot8_sign}}, dot_r[DOT8_W-1:0]};
assign dot_acc_in = (op_d == SIMD_ARITH_OP_DOT16) ? dot16_r : dot8_r;
assign dot_acc_out = (dot_acc_in + c_late);

// output assignment based on the operation
always_comb begin
    unique case (op_d)
        SIMD_ARITH_OP_MUL: p = mul_s[ARCH_WIDTH-1:0];
        SIMD_ARITH_OP_MULH: p = mul_s[ARCH_WIDTH_D-1:ARCH_WIDTH];
        SIMD_ARITH_OP_MULHSU: p = mul_hsu;
        SIMD_ARITH_OP_MULHU: p = mul_hu;
        SIMD_ARITH_OP_DOT16,
        SIMD_ARITH_OP_DOT8: p = dot_acc_out;
        default: p = 'h0;
    endcase
end

endmodule
