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
assign op_rv32_mul = (op[6:3] == SIMD_ARITH_CLASS_RV32M);
assign op_simd = (op[6:3] != SIMD_ARITH_CLASS_RV32M);
//assign op_simd_mul = (op[6:3] == SIMD_ARITH_CLASS_MUL);
//assign op_simd_wmul = (op[6:3] == SIMD_ARITH_CLASS_WMUL);
assign op_simd_dot = (op[6:3] == SIMD_ARITH_CLASS_DOT);

logic op_lane_arith; // add/sub, qadd/qsub, min/max -> lane uses a/b operands
assign op_lane_arith = (
    (op[6:3] == SIMD_ARITH_CLASS_ADDSUB) ||
    (op[6:3] == SIMD_ARITH_CLASS_QADDSUB) ||
    (op[6:3] == SIMD_ARITH_CLASS_COMPARE)
);

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
for (genvar r = 0; r < W; r++) begin : g_pp_rows
    for (genvar c = 0; c < W; c++) begin : g_pp_columns
        assign y[r][c] = (b[r] & a[c]);
        assign flip[r][c] = (sign_mask[r] ^ sign_mask[c]);
        assign pp[r][c] = flip[r][c] ? ~y[r][c] : y[r][c];
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
simd_t a_d, b_d;
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
`STAGE(ctrl_exe_mem, (en && (!op_simd || op_lane_arith)), a, a_d, 'h0)
`STAGE(ctrl_exe_mem, (en && op_lane_arith), b, b_d, 'h0)

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
simd_d_t [1:0] sum_mbw;
csa #(.W(64), .A(1)) csa_sum_mbw_i (
    .x(o_tree_f[0]),
    .y(o_tree_f[1]),
    .z(corr_d),
    .ckl(1'b0),
    .s(sum_mbw[0]),
    .c(sum_mbw[1])
);

simd_d_t tree_sum;
/* verilator lint_off PINCONNECTEMPTY */
add #(.W(ARCH_WIDTH_D)) add_tree_sum_i (
    .a(sum_mbw[0]), .b(sum_mbw[1]), .ci(1'b0), .s(tree_sum), .co()
);
/* verilator lint_on PINCONNECTEMPTY */

// multiply high signed x unsigned
simd_d_t [1:0] sum_mul_hsu;
csa #(.W(64), .A(1)) csa_mul_hsu_i (
    .x(sum_mbw[0]),
    .y(sum_mbw[1]),
    .z({a_d, 32'h0}),
    .ckl(1'b0),
    .s(sum_mul_hsu[0]),
    .c(sum_mul_hsu[1])
);

simd_d_t mul_hsu_signed;
/* verilator lint_off PINCONNECTEMPTY */
add #(.W(ARCH_WIDTH_D)) add_mul_hsu_i (
    .a(sum_mul_hsu[0]), .b(sum_mul_hsu[1]), .ci(1'b0), .s(mul_hsu_signed), .co()
);
/* verilator lint_on PINCONNECTEMPTY */

arch_width_t mul_hsu;
assign mul_hsu = b_sign_bit_d ? mul_hsu_signed.w[1] : tree_sum.w[1];

// multiply high unsigned
simd_t mul_hu;
assign mul_hu = tree_sum.w[1];

arch_width_t mul_res;

always_comb begin
    mul_res = '0;
    unique case (op_d[2:0])
        SIMD_ARITH_OP_MUL[2:0]: mul_res = tree_sum.w[0];
        SIMD_ARITH_OP_MULH[2:0]: mul_res = tree_sum.w[1];
        SIMD_ARITH_OP_MULHSU[2:0]: mul_res = mul_hsu;
        SIMD_ARITH_OP_MULHU[2:0]: mul_res = mul_hu;
        default: mul_res = '0;
    endcase
end

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
    case (op_d[2:0])
        SIMD_ARITH_OP_DOT16[2:0]: dot_acc_in = dot16_r;
        SIMD_ARITH_OP_DOT8[2:0]: dot_acc_in = dot8_r;
        SIMD_ARITH_OP_DOT4[2:0]: dot_acc_in = dot4_r;
        SIMD_ARITH_OP_DOT2[2:0]: dot_acc_in = dot2_r;
        SIMD_ARITH_OP_DOT16U[2:0],
        SIMD_ARITH_OP_DOT8U[2:0],
        SIMD_ARITH_OP_DOT4U[2:0],
        SIMD_ARITH_OP_DOT2U[2:0]: dot_acc_in = dotu_r;
        default: dot_acc_in = 'h0;
    endcase
end

/* verilator lint_off PINCONNECTEMPTY */
add #(.W(ARCH_WIDTH)) add_dot_out_i (
    .a(dot_acc_in), .b(c_late), .ci(1'b0), .s(dot_out), .co()
);
/* verilator lint_on PINCONNECTEMPTY */

//------------------------------------------------------------------------------
// per-lane wrap-up: (w)mul + add/sub + qadd/qsub + min/max
// 4 byte lanes (W=8) over i_tree_f taps, 2 half lanes (W=16) over mul16_taps
logic [3:0][15:0] lane_b_y; // byte-lane outputs (2W = 16b each)
logic [1:0][31:0] lane_h_y; // half-lane outputs (2W = 32b each)

for (genvar k = 0; k < 4; k++) begin : g_lane_b
    ama_riscv_simd_lane_wrapup #(.W(8)) lane_b_i (
        .op_d(op_d),
        .a_lane(a_d.b[k]), .b_lane(b_d.b[k]),
        .t0(i_tree_f[2*k].h[0]), .t1(i_tree_f[2*k+1].h[0]),
        .corr(corr_d.h[0]),
        .y(lane_b_y[k])
    );
end

for (genvar k = 0; k < 2; k++) begin : g_lane_h
    ama_riscv_simd_lane_wrapup #(.W(16)) lane_h_i (
        .op_d(op_d),
        .a_lane(a_d.h[k]), .b_lane(b_d.h[k]),
        .t0(mul16_taps[2*k].w[0]), .t1(mul16_taps[2*k+1].w[0]),
        .corr(corr_d.w[0]),
        .y(lane_h_y[k])
    );
end

// assemble packed results (narrow ops take [W-1:0] per lane, wmul full 2W)
arch_width_t res_narrow_b, res_narrow_h;
assign res_narrow_b = {
    lane_b_y[3][7:0], lane_b_y[2][7:0], lane_b_y[1][7:0], lane_b_y[0][7:0]};
assign res_narrow_h = {lane_h_y[1][15:0], lane_h_y[0][15:0]};

simd_d_t res_wmul8, res_wmul16;
assign res_wmul8 = {lane_b_y[3], lane_b_y[2], lane_b_y[1], lane_b_y[0]};
assign res_wmul16 = {lane_h_y[1], lane_h_y[0]};

//------------------------------------------------------------------------------
// output assignment
arch_width_t simd_narrow; // op[1] width: 1 -> 8b lanes, 0 -> 16b lanes
assign simd_narrow = op_d[1] ? res_narrow_b : res_narrow_h;
simd_d_t simd_wmul;
assign simd_wmul = op_d[1] ? res_wmul8 : res_wmul16;

always_comb begin
    p = '0;
    unique case (op_d[6:3])
        SIMD_ARITH_CLASS_RV32M: p.w[0] = mul_res;
        SIMD_ARITH_CLASS_WMUL: p = simd_wmul;
        SIMD_ARITH_CLASS_MUL,
        SIMD_ARITH_CLASS_ADDSUB,
        SIMD_ARITH_CLASS_QADDSUB,
        SIMD_ARITH_CLASS_COMPARE: p.w[0] = simd_narrow;
        SIMD_ARITH_CLASS_DOT: p.w[0] = dot_out;
        default: p = '0;
    endcase
end

endmodule
