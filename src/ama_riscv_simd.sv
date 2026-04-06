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
    output simd_t p
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

logic op_simd;
assign op_simd = (op[3]);

logic op_dot16, op_dot16u, op_dot8, op_dot8u;
assign op_dot16 = (op == SIMD_ARITH_OP_DOT16);
assign op_dot16u = (op == SIMD_ARITH_OP_DOT16U);
assign op_dot8 = (op == SIMD_ARITH_OP_DOT8);
assign op_dot8u = (op == SIMD_ARITH_OP_DOT8U);

logic op_dot4, op_dot4u, op_dot2, op_dot2u;
assign op_dot4 = (op == SIMD_ARITH_OP_DOT4);
assign op_dot4u = (op == SIMD_ARITH_OP_DOT4U);
assign op_dot2 = (op == SIMD_ARITH_OP_DOT2);
assign op_dot2u = (op == SIMD_ARITH_OP_DOT2U);

logic op_dot16_any, op_dot8_any, op_dot4_any, op_dot2_any;
assign op_dot16_any = (op_dot16 || op_dot16u);
assign op_dot8_any = (op_dot8 || op_dot8u);
assign op_dot4_any = (op_dot4 || op_dot4u);
assign op_dot2_any = (op_dot2 || op_dot2u);

logic unsigned_op;
assign unsigned_op = ((op == SIMD_ARITH_OP_MULHU) || (op[3] && op[0]));

logic signed_mul;
assign signed_mul = ((!op[3]) && (op != SIMD_ARITH_OP_MULHU));

//------------------------------------------------------------------------------
// AND matrix for signed multiply using lane-aware Baugh–Wooley

logic [W-1:0] sign_mask;
always_comb begin
    unique case (1'b1)
        unsigned_op: sign_mask = 'h0000_0000;
        op_dot2: sign_mask = 'hAAAA_AAAA;
        op_dot4: sign_mask = 'h8888_8888;
        op_dot8: sign_mask = 'h8080_8080;
        op_dot16: sign_mask = 'h8000_8000;
        default: sign_mask = 'h8000_0000;
    endcase
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
            op_dot16_any: begin
                // every 16 rows (one lane) shifted left per the algorithm
                // but every lane is shifted right to start at idx 0 for dotp
                x = {32'h0, (pp[i] & mask_16[i])};
                ppv[i] = ((x << (i % 16)) >> ((i / 16) * 16));
            end
            op_dot8_any: begin
                x = {32'h0, (pp[i] & mask_8[i])};
                ppv[i] = ((x << (i % 8)) >> ((i / 8) * 8));
            end
            op_dot4_any: begin
                x = {32'h0, (pp[i] & mask_4[i])};
                ppv[i] = ((x << (i % 4)) >> ((i / 4) * 4));
            end
            op_dot2_any: begin
                x = {32'h0, (pp[i] & mask_2[i])};
                ppv[i] = ((x << (i % 2)) >> ((i / 2) * 2));
            end
            default: begin // MULT 32x32
                x = {32'h0, pp[i]};
                ppv[i] = (x << i);
            end
        endcase
    end
end

simd_d_t corr; // correction for modified BW for signed operations
always_comb begin
    corr = '0;
    unique case (1'b1)
        signed_mul: begin
            // 32x32 signed MBW
            corr[32] = 1'b1;
            corr[63] = 1'b1;
        end
        op_dot16: begin
            // 2 lanes of 16x16 signed
            corr[17] = 1'b1; // idx [16] set twice (1x per lane)
        end
        op_dot8: begin
            // 4 lanes of 8x8 signed
            corr[10] = 1'b1; // idx [8] set four times (1x per lane)
        end
        op_dot4: begin
            // 8 lanes of 4x4 signed
            corr[7] = 1'b1; // idx [4] set eight times (1x per lane)
        end
        op_dot2: begin
            // 16 lanes of 2x2 signed
            corr[6] = 1'b1; // idx [2] set sixteen times (1x per lane)
        end
        default: begin
            corr = '0;
        end
    endcase
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
// final tree rv32 mul & simd dot
simd_d_t [7:0] i_tree_f;
simd_d_t [1:0] o_tree_f;
assign i_tree_f = {o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d};
/* verilator lint_off PINCONNECTEMPTY */
csa_tree_8 #(.W(64)) csa_tree_8_f_i (
    .a (i_tree_f), .o(o_tree_f), .taps ()
);
/* verilator lint_on PINCONNECTEMPTY */

//------------------------------------------------------------------------------
// wrap up rv32 mul

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
// output assignment
always_comb begin
    unique case (op_d)
        SIMD_ARITH_OP_MUL: p = tree_sum[ARCH_WIDTH-1:0];
        SIMD_ARITH_OP_MULH: p = tree_sum[ARCH_WIDTH_D-1:ARCH_WIDTH];
        SIMD_ARITH_OP_MULHSU: p = mul_hsu;
        SIMD_ARITH_OP_MULHU: p = mul_hu;
        SIMD_ARITH_OP_DOT16,
        SIMD_ARITH_OP_DOT16U,
        SIMD_ARITH_OP_DOT8,
        SIMD_ARITH_OP_DOT8U,
        SIMD_ARITH_OP_DOT4,
        SIMD_ARITH_OP_DOT4U,
        SIMD_ARITH_OP_DOT2,
        SIMD_ARITH_OP_DOT2U: p = dot_out;
        default: p = 'h0;
    endcase
end

endmodule
