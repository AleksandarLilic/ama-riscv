`include "ama_riscv_defines.svh"

module ama_riscv_simd (
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  stage_ctrl_t ctrl_exe_mem,
    input  simd_arith_op_t op,
    input  simd_t a,
    input  simd_t b,
    input  arch_width_t c_late,
    output simd_d_t p
);

localparam int unsigned W = 32;

//------------------------------------------------------------------------------
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

localparam int unsigned TILE_4 = 4; // 4x4 blocks
simd_t [W-1:0] mask_4;
always_comb begin
    `IT_P(y, W) `IT_P(x, W) mask_4[y][x] = ((y / TILE_4) == (x / TILE_4));
end

localparam int unsigned TILE_2 = 2; // 2x2 blocks
simd_t [W-1:0] mask_2;
always_comb begin
    `IT_P(y, W) `IT_P(x, W) mask_2[y][x] = ((y / TILE_2) == (x / TILE_2));
end

logic op_rv32_mul, op_simd, /* op_simd_mul, op_simd_wmul, */ op_simd_dot;
assign op_rv32_mul = (op[5:3] == SIMD_ARITH_CLASS_RV32M);
assign op_simd = (op[5:3] != SIMD_ARITH_CLASS_RV32M);
//assign op_simd_mul = (op[5:3] == SIMD_ARITH_CLASS_MUL);
//assign op_simd_wmul = (op[5:3] == SIMD_ARITH_CLASS_WMUL);
assign op_simd_dot = (op[5:3] == SIMD_ARITH_CLASS_DOT);

logic ew_32, ew_16, ew_8, ew_4, ew_2;
assign ew_2 = (op_simd_dot && (op[2:1] == 2'b11));
assign ew_4 = (op_simd_dot && (op[2:1] == 2'b10));
assign ew_8 = (op_simd && (op[1] == 1'b1) && !ew_2);
assign ew_16 = (op_simd && (op[1] == 1'b0) && !ew_4);
assign ew_32 = op_rv32_mul;

logic op_unsigned;
assign op_unsigned = ((op == SIMD_ARITH_OP_MULHU) || (op_simd && op[0]));

//------------------------------------------------------------------------------
// AND matrix for signed multiply using lane-aware Baugh–Wooley

logic [W-1:0] sign_mask;
always_comb begin
    sign_mask = '0;
    if (!op_unsigned) begin
        unique case (1'b1)
            ew_2: sign_mask = 'hAAAA_AAAA;
            ew_4: sign_mask = 'h8888_8888;
            ew_8: sign_mask = 'h8080_8080;
            ew_16: sign_mask = 'h8000_8000;
            ew_32: sign_mask = 'h8000_0000;
            default: sign_mask = '0;
        endcase
    end
end

simd_t [W-1:0] pp; // partial products matrix
logic [W-1:0][W-1:0] y;
logic [W-1:0][W-1:0] flip;
for (genvar ai = 0; ai < W; ai++) begin : g_pp_ai
    for (genvar bi = 0; bi < W; bi++) begin : g_pp_bi
        assign y[ai][bi] = (a[ai] & b[bi]);
        assign flip[ai][bi] = (sign_mask[ai] ^ sign_mask[bi]);
        assign pp[ai][bi] = flip[ai][bi] ? ~y[ai][bi] : y[ai][bi];
    end
end

simd_d_t [W-1:0] ppv; // double-wide pp view
always_comb begin
    `IT_P(i, W) begin
        simd_d_t x;
        ppv[i] = '0;
        unique case (1'b1)
            ew_32: begin // MULT 32x32
                x = {32'h0, pp[i]};
                ppv[i] = (x << i);
            end
            ew_16: begin
                // every 16 rows (one lane) shifted left per the algorithm
                // but every lane is shifted right to start at idx 0 for dotp
                x = {32'h0, (pp[i] & mask_16[i])};
                ppv[i] = ((x << (i % 16)) >> ((i / 16) * 16));
            end
            ew_8: begin
                x = {32'h0, (pp[i] & mask_8[i])};
                ppv[i] = ((x << (i % 8)) >> ((i / 8) * 8));
            end
            ew_4: begin
                x = {32'h0, (pp[i] & mask_4[i])};
                ppv[i] = ((x << (i % 4)) >> ((i / 4) * 4));
            end
            ew_2: begin
                x = {32'h0, (pp[i] & mask_2[i])};
                ppv[i] = ((x << (i % 2)) >> ((i / 2) * 2));
            end
            default: ppv[i] = '0;
        endcase
    end
end

simd_d_t corr; // correction for modified BW for signed operations
always_comb begin
    corr = '0;
    if (!op_unsigned) begin
        unique case (1'b1)
            ew_32: begin corr[32] = 1'b1; corr[63] = 1'b1; end
            (ew_16 && op_simd_dot): begin corr[17] = 1'b1; end
            (ew_16 && !op_simd_dot): begin corr[16] = 1'b1; corr[31] = 1'b1; end
            (ew_8 && op_simd_dot): begin corr[10] = 1'b1; end
            (ew_8 && !op_simd_dot): begin corr[8] = 1'b1; corr[15] = 1'b1; end
            ew_4: begin corr[7] = 1'b1; end // idx [4] set 8 times
            ew_2: begin corr[6] = 1'b1; end // idx [2] set 16 times
        endcase
    end
end

//------------------------------------------------------------------------------
// first four trees in parallel
simd_d_t [1:0] o_tree_0, o_tree_1, o_tree_2, o_tree_3;
/* verilator lint_off PINCONNECTEMPTY */
csa_tree_8 #(.W(64)) csa_tree_8_i0 (.a (ppv[7:0]), .o (o_tree_0), .taps ());
csa_tree_8 #(.W(64)) csa_tree_8_i1 (.a (ppv[15:8]), .o (o_tree_1), .taps ());
csa_tree_8 #(.W(64)) csa_tree_8_i2 (.a (ppv[23:16]), .o (o_tree_2), .taps ());
csa_tree_8 #(.W(64)) csa_tree_8_i3 (.a (ppv[31:24]), .o (o_tree_3), .taps ());
/* verilator lint_on PINCONNECTEMPTY */

//------------------------------------------------------------------------------
// pipeline
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

//------------------------------------------------------------------------------
// final tree rv32m mul & simd dot
simd_d_t [7:0] i_tree_f;
simd_d_t [1:0] o_tree_f;
simd_d_t [3:0] mul16_taps;
assign i_tree_f = {o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d};
csa_tree_8 #(.W(64), .T4(1)) csa_tree_8_f_i (
    .a (i_tree_f), .o(o_tree_f), .taps (mul16_taps)
);

//------------------------------------------------------------------------------
// wrap up rv32m mul

// multiply signed, high signed, & simd dot signed
simd_d_t [1:0] tree_sum_mbw;
csa #(.W(64), .A(1)) csa_i_tree_sum_mbw (
    .x(o_tree_f[0]),
    .y(o_tree_f[1]),
    .z(corr_d),
    .s(tree_sum_mbw[0]),
    .c(tree_sum_mbw[1])
);

simd_d_t tree_sum;
assign tree_sum = (tree_sum_mbw[0] + tree_sum_mbw[1]);

// multiply high signed x unsigned
simd_d_t [1:0] mul_hsu_tree;
csa #(.W(64), .A(1)) csa_i_mul_hsu (
    .x(tree_sum_mbw[0]),
    .y(tree_sum_mbw[1]),
    .z({a_d, 32'h0}),
    .s(mul_hsu_tree[0]),
    .c(mul_hsu_tree[1])
);

simd_d_t mul_hsu_signed;
assign mul_hsu_signed = (mul_hsu_tree[0] + mul_hsu_tree[1]);

arch_width_t mul_hsu;
assign mul_hsu = b_sign_bit_d ? mul_hsu_signed.w[1] : tree_sum.w[1];

// multiply high unsigned
simd_t mul_hu;
assign mul_hu = tree_sum.w[1];

//------------------------------------------------------------------------------
// wrap up simd dot
localparam unsigned DOT8_W = 17; // dot8 result width
localparam unsigned DOT8_SIGN_EXT = (ARCH_WIDTH - DOT8_W);
localparam unsigned DOT4_W = 10; // dot4 result width
localparam unsigned DOT4_SIGN_EXT = (ARCH_WIDTH - DOT4_W);
localparam unsigned DOT2_W = 7; // dot2 result width
localparam unsigned DOT2_SIGN_EXT = (ARCH_WIDTH - DOT2_W);

// signed
arch_width_t dot_r, dot16_r, dot8_r, dot4_r, dot2_r;
assign dot_r = tree_sum.w[0];
assign dot16_r = dot_r[ARCH_WIDTH-1:0];

logic dot8_msb;
assign dot8_msb = (&dot_r[DOT8_W:DOT8_W-1]) ? 1'b0 : dot_r[DOT8_W-1];
assign dot8_r = {{DOT8_SIGN_EXT{dot8_msb}}, dot_r[DOT8_W-1:0]};

logic dot4_msb;
assign dot4_msb = (&dot_r[DOT4_W:DOT4_W-1]) ? 1'b0 : dot_r[DOT4_W-1];
assign dot4_r = {{DOT4_SIGN_EXT{dot4_msb}}, dot_r[DOT4_W-1:0]};

logic dot2_msb;
assign dot2_msb = (&dot_r[DOT2_W:DOT2_W-1]) ? 1'b0 : dot_r[DOT2_W-1];
assign dot2_r = {{DOT2_SIGN_EXT{dot2_msb}}, dot_r[DOT2_W-1:0]};

// unsigned: no BW bias, tree gives exact result
arch_width_t dotu_r;
assign dotu_r = tree_sum.w[0];

// accumulator common
arch_width_t dot_acc_in, dot_out;
always_comb begin
    case (op_d)
        SIMD_ARITH_OP_DOT16: dot_acc_in = dot16_r;
        SIMD_ARITH_OP_DOT8: dot_acc_in = dot8_r;
        SIMD_ARITH_OP_DOT4: dot_acc_in = dot4_r;
        SIMD_ARITH_OP_DOT2: dot_acc_in = dot2_r;
        SIMD_ARITH_OP_DOT16U,
        SIMD_ARITH_OP_DOT8U,
        SIMD_ARITH_OP_DOT4U,
        SIMD_ARITH_OP_DOT2U: dot_acc_in = dotu_r;
        default: dot_acc_in = 'h0;
    endcase
end
assign dot_out = (dot_acc_in + c_late);

//------------------------------------------------------------------------------
// wrap up simd (w)mul

// (w)mul16
simd_t [1:0] wmul16_csa_0, wmul16_csa_1;
csa #(.W(32), .A(1)) csa_i_wmul16_0 (
    .x(mul16_taps[0].w[0]), .y(mul16_taps[1].w[0]), .z(corr_d.w[0]),
    .s(wmul16_csa_0[0]), .c(wmul16_csa_0[1])
);

csa #(.W(32), .A(1)) csa_i_wmul16_1 (
    .x(mul16_taps[2].w[0]), .y(mul16_taps[3].w[0]), .z(corr_d.w[0]),
    .s(wmul16_csa_1[0]), .c(wmul16_csa_1[1])
);

simd_d_t wmul16;
assign wmul16.w[0] = (wmul16_csa_0[0] + wmul16_csa_0[1]);
assign wmul16.w[1] = (wmul16_csa_1[0] + wmul16_csa_1[1]);

simd_t mul16, mul16h;
assign mul16 = {wmul16.h[2], wmul16.h[0]};
assign mul16h = {wmul16.h[3], wmul16.h[1]};

// (w)mul8
simd_h_t [1:0] wmul8_csa_0, wmul8_csa_1, wmul8_csa_2, wmul8_csa_3;
csa #(.W(16), .A(1)) csa_i_wmul8_0 (
    .x(i_tree_f[0].h[0]), .y(i_tree_f[1].h[0]), .z(corr_d.h[0]),
    .s(wmul8_csa_0[0]), .c(wmul8_csa_0[1])
);

csa #(.W(16), .A(1)) csa_i_wmul8_1 (
    .x(i_tree_f[2].h[0]), .y(i_tree_f[3].h[0]), .z(corr_d.h[0]),
    .s(wmul8_csa_1[0]), .c(wmul8_csa_1[1])
);

csa #(.W(16), .A(1)) csa_i_wmul8_2 (
    .x(i_tree_f[4].h[0]), .y(i_tree_f[5].h[0]), .z(corr_d.h[0]),
    .s(wmul8_csa_2[0]), .c(wmul8_csa_2[1])
);

csa #(.W(16), .A(1)) csa_i_wmul8_3 (
    .x(i_tree_f[6].h[0]), .y(i_tree_f[7].h[0]), .z(corr_d.h[0]),
    .s(wmul8_csa_3[0]), .c(wmul8_csa_3[1])
);

simd_d_t wmul8;
assign wmul8.h[0] = (wmul8_csa_0[0] + wmul8_csa_0[1]);
assign wmul8.h[1] = (wmul8_csa_1[0] + wmul8_csa_1[1]);
assign wmul8.h[2] = (wmul8_csa_2[0] + wmul8_csa_2[1]);
assign wmul8.h[3] = (wmul8_csa_3[0] + wmul8_csa_3[1]);

simd_t mul8, mul8h;
assign mul8 = {wmul8.b[6], wmul8.b[4], wmul8.b[2], wmul8.b[0]};
assign mul8h = {wmul8.b[7], wmul8.b[5], wmul8.b[3], wmul8.b[1]};

//------------------------------------------------------------------------------
// output assignment
always_comb begin
    p = '0;
    unique case (op_d)
        // rv32m mul
        SIMD_ARITH_OP_MUL: p.w[0] = tree_sum[ARCH_WIDTH-1:0];
        SIMD_ARITH_OP_MULH: p.w[0] = tree_sum[ARCH_WIDTH_D-1:ARCH_WIDTH];
        SIMD_ARITH_OP_MULHSU: p.w[0] = mul_hsu;
        SIMD_ARITH_OP_MULHU: p.w[0] = mul_hu;
        // simd mul
        SIMD_ARITH_OP_MUL16: p.w[0] = mul16;
        SIMD_ARITH_OP_MUL8: p.w[0] = mul8;
        SIMD_ARITH_OP_MULH16,
        SIMD_ARITH_OP_MULH16U: p.w[0] = mul16h;
        SIMD_ARITH_OP_MULH8,
        SIMD_ARITH_OP_MULH8U: p.w[0] = mul8h;
        // simd wmul
        SIMD_ARITH_OP_WMUL16,
        SIMD_ARITH_OP_WMUL16U: p = wmul16;
        SIMD_ARITH_OP_WMUL8,
        SIMD_ARITH_OP_WMUL8U: p = wmul8;
        // simd dot
        SIMD_ARITH_OP_DOT16,
        SIMD_ARITH_OP_DOT16U,
        SIMD_ARITH_OP_DOT8,
        SIMD_ARITH_OP_DOT8U,
        SIMD_ARITH_OP_DOT4,
        SIMD_ARITH_OP_DOT4U,
        SIMD_ARITH_OP_DOT2,
        SIMD_ARITH_OP_DOT2U: p.w[0] = dot_out;
        default: p = '0;
    endcase
end

endmodule
