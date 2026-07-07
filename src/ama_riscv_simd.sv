`include "ama_riscv_defines.svh"

module ama_riscv_simd #(
    parameter bit RV32M_ONLY = 0
)(
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  stage_ctrl_t ctrl_exe_mem,
    input  stage_ctrl_t ctrl_mem_wbk,
    input  simd_arith_op_t op,
    input  simd_t a,
    input  simd_t b,
    /* verilator lint_off UNUSEDSIGNAL */
    input  arch_width_t c_late, // unused on RV32M mode
    /* verilator lint_on UNUSEDSIGNAL */
    output simd_d_t p
);

localparam int unsigned W = 32;

//------------------------------------------------------------------------------

logic op_simd, op_simd_dot;
logic op_lane_arith; // add/sub, qadd/qsub, min/max -> lane uses a/b operands
simd_arith_el_width_t ew;
logic op_unsigned;

if (RV32M_ONLY) begin: gen_ctrl_rv32m
assign {op_simd, op_simd_dot, op_lane_arith} = 3'h0;
assign ew.b32 = 1'b1;
assign {ew.b16, ew.b8, ew.b4, ew.b2} = 4'h0;
assign op_unsigned = (op == SIMD_ARITH_OP_MULHU);

end else begin: gen_ctrl_simd
logic op_rv32_mul;
assign op_rv32_mul = (op[6:3] == SIMD_ARITH_CLASS_RV32M);
assign op_simd = (op[6:3] != SIMD_ARITH_CLASS_RV32M);
assign op_simd_dot = (op[6:3] == SIMD_ARITH_CLASS_DOT);
assign op_lane_arith = (
    (op[6:3] == SIMD_ARITH_CLASS_ADDSUB) ||
    (op[6:3] == SIMD_ARITH_CLASS_QADDSUB) ||
    (op[6:3] == SIMD_ARITH_CLASS_COMPARE)
);
assign ew.b2 = (op_simd_dot && (op[2:1] == 2'b11));
assign ew.b4 = (op_simd_dot && (op[2:1] == 2'b10));
assign ew.b8 = (op_simd && (op[1] == 1'b1) && !ew.b2);
assign ew.b16 = (op_simd && (op[1] == 1'b0) && !ew.b4);
assign ew.b32 = op_rv32_mul;
assign op_unsigned = ((op == SIMD_ARITH_OP_MULHU) || (op_simd && op[0]));

end
logic [3:0] aenc; // element alignment, one-hot encoded
assign aenc = {ew.b16, ew.b8, ew.b4, ew.b2};

//------------------------------------------------------------------------------
// get pp matrix and correction value

simd_d_t [W-1:0] ppv; // double-wide pp view
simd_d_t corr; // correction for modified BW for signed operations
ama_riscv_simd_ppgen #(.RV32M_ONLY(RV32M_ONLY)) ppgen_i (
    .op_unsigned, .op_simd_dot, .ew, .a, .b, .ppv, .corr
);

//------------------------------------------------------------------------------
// first four trees in parallel
logic s1a_e2, s2a_e4;
assign s1a_e2 = (|aenc && (aenc == 4'h1));
assign s2a_e4 = (|aenc && (aenc <= 4'h2));

simd_d_t [1:0] o_tree_0, o_tree_1, o_tree_2, o_tree_3;
/* verilator lint_off PINCONNECTEMPTY */
ama_riscv_simd_csa_tree_8 #(.W(64), .S1A(2*2), .S2A(4*2))
csa_tree_8_i0 (
    .a(ppv[7:0]), .s1a(s1a_e2), .s2a(s2a_e4), .o(o_tree_0), .taps()
);
ama_riscv_simd_csa_tree_8 #(.W(64), .S1A(2*2), .S2A(4*2))
csa_tree_8_i1 (
    .a(ppv[15:8]), .s1a(s1a_e2), .s2a(s2a_e4), .o(o_tree_1), .taps()
);
ama_riscv_simd_csa_tree_8 #(.W(64), .S1A(2*2), .S2A(4*2))
csa_tree_8_i2 (
    .a(ppv[23:16]), .s1a(s1a_e2), .s2a(s2a_e4), .o(o_tree_2), .taps()
);
ama_riscv_simd_csa_tree_8 #(.W(64), .S1A(2*2), .S2A(4*2))
csa_tree_8_i3 (
    .a(ppv[31:24]), .s1a(s1a_e2), .s2a(s2a_e4), .o(o_tree_3), .taps()
);
/* verilator lint_on PINCONNECTEMPTY */

//------------------------------------------------------------------------------
// pipeline: EXE_MEM

logic s1a_e8, s2a_e16;
assign s1a_e8 = (|aenc && (aenc <= 4'h4));
assign s2a_e16 = (|aenc && (aenc <= 4'h8));
logic s1a_e8_d, s2a_e16_d;

simd_t a_d;
logic en_d;
/* verilator lint_off UNUSEDSIGNAL */
simd_arith_op_t op_d; // some bits unused on RV32M mode
/* verilator lint_on UNUSEDSIGNAL */
simd_d_t corr_d;
simd_d_t [1:0] o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d;
logic b_sign_bit, b_sign_bit_d;
assign b_sign_bit = b[ARCH_WIDTH-1]; // b MSB

// in general case, simple FFs are fine, e.g.
//`DFF_CI_RI_RV(SIMD_ARITH_OP_MUL, op, op_d)

// but, in CPU, make sure it's aligned with stage its using
`STAGE_E_M(1'b1, en, en_d, 'h0)
`STAGE_E_M(en, {s1a_e8, s2a_e16}, {s1a_e8_d, s2a_e16_d}, 'h0)
`STAGE_E_M(en, o_tree_0, o_tree_0_d, 'h0)
`STAGE_E_M(en, o_tree_1, o_tree_1_d, 'h0)
`STAGE_E_M(en, o_tree_2, o_tree_2_d, 'h0)
`STAGE_E_M(en, o_tree_3, o_tree_3_d, 'h0)
`STAGE_E_M(en, op, op_d, SIMD_ARITH_OP_MUL)
`STAGE_E_M(en, corr, corr_d, 'h0)
`STAGE_E_M((en && !op_simd), b_sign_bit, b_sign_bit_d, 1'b0)
`STAGE_E_M((en && (!op_simd || op_lane_arith)), a, a_d, 'h0)

//------------------------------------------------------------------------------
// final tree rv32m mul & simd dot
simd_d_t [7:0] i_tree_f;
simd_d_t [1:0] o_tree_f;
/* verilator lint_off UNUSEDSIGNAL */
simd_d_t [3:0] mul16_taps; // unused on RV32M mode
/* verilator lint_on UNUSEDSIGNAL */
assign i_tree_f = {o_tree_3_d, o_tree_2_d, o_tree_1_d, o_tree_0_d};
ama_riscv_simd_csa_tree_8 #(.W(64), .S1A(8*2), .S2A(16*2))
csa_tree_8_f_i (
    .a(i_tree_f), .s1a(s1a_e8_d), .s2a(s2a_e16_d),
    .o(o_tree_f), .taps(mul16_taps)
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
simd_d_t p_mem;

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
// SIMD back-end: dot + lanes + output (gated when RV32M_ONLY)
if (!RV32M_ONLY) begin: gen_backend_simd

simd_t b_d;
`STAGE(ctrl_exe_mem, (en && op_lane_arith), b, b_d, 'h0)

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

for (genvar k = 0; k < 4; k++) begin: gen_lane_b
    ama_riscv_simd_lane_wrapup #(.W(8)) lane_b_i (
        .op_d(op_d),
        .a_lane(a_d.b[k]),
        .b_lane(b_d.b[k]),
        // instead of '>> (8*2*k)', just take the .h on the k index
        .t0(i_tree_f[2*k].h[k]),
        .t1(i_tree_f[2*k+1].h[k]),
        .corr(corr_d.h[0]),
        .y(lane_b_y[k])
    );
end

for (genvar k = 0; k < 2; k++) begin: gen_lane_h
    ama_riscv_simd_lane_wrapup #(.W(16)) lane_h_i (
        .op_d(op_d),
        .a_lane(a_d.h[k]),
        .b_lane(b_d.h[k]),
        // instead of '>> (16*2*k)', just take the .w on the k index
        .t0(mul16_taps[2*k].w[k]),
        .t1(mul16_taps[2*k+1].w[k]),
        .corr(corr_d.w[0]),
        .y(lane_h_y[k])
    );
end

// assemble packed results (narrow ops take [W-1:0] per lane, wmul full 2W)
arch_width_t res_narrow_b, res_narrow_h;
assign res_narrow_b = {
    lane_b_y[3][7:0], lane_b_y[2][7:0], lane_b_y[1][7:0], lane_b_y[0][7:0]
};
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
    p_mem = '0;
    unique case (op_d[6:3])
        SIMD_ARITH_CLASS_RV32M: p_mem.w[0] = mul_res;
        SIMD_ARITH_CLASS_WMUL: p_mem = simd_wmul;
        SIMD_ARITH_CLASS_MUL,
        SIMD_ARITH_CLASS_ADDSUB,
        SIMD_ARITH_CLASS_QADDSUB,
        SIMD_ARITH_CLASS_COMPARE: p_mem.w[0] = simd_narrow;
        SIMD_ARITH_CLASS_DOT: p_mem.w[0] = dot_out;
        default: p_mem = '0;
    endcase
end

end else begin: gen_backend_rv32m

always_comb begin
    p_mem = '0;
    p_mem.w[0] = mul_res;
end

end // gen_simd_be/gen_rv32m_out

//------------------------------------------------------------------------------
// pipeline: MEM_WBK

`STAGE_M_W(en_d, p_mem, p, 'h0)

endmodule
