`include "ama_riscv_defines.svh"

module ama_riscv_mult (
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  stage_ctrl_t ctrl_exe_mem,
    input  stage_ctrl_t ctrl_mem_wbk,
    input  logic [1:0] op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] p
);

//------------------------------------------------------------------------------
// stage 1 (EXE) - operand extension + partial products

logic signed [32:0] ext_a, ext_b;
always_comb begin
    unique case (op)
        SIMD_ARITH_OP_MUL[1:0],
        SIMD_ARITH_OP_MULH[1:0]: begin
            ext_a = {a[31], a};
            ext_b = {b[31], b};
        end
        SIMD_ARITH_OP_MULHSU[1:0]: begin
            ext_a = {a[31], a};
            ext_b = {1'b0, b};
        end
        SIMD_ARITH_OP_MULHU[1:0]: begin
            ext_a = {1'b0, a};
            ext_b = {1'b0, b};
        end
        default: begin
            ext_a = '0;
            ext_b = '0;
        end
    endcase
end

logic signed [16:0] a_hi, b_hi;
logic [15:0] a_lo, b_lo;
assign a_hi = ext_a[32:16];
assign a_lo = ext_a[15:0];
assign b_hi = ext_b[32:16];
assign b_lo = ext_b[15:0];

(* use_dsp = "no" *) logic signed [33:0] pp0;
(* use_dsp = "no" *) logic signed [33:0] pp1;
(* use_dsp = "no" *) logic signed [33:0] pp2;
(* use_dsp = "no" *) logic signed [33:0] pp3;
assign pp0 = ($signed({1'b0, a_lo}) * $signed({1'b0, b_lo}));
assign pp1 = (a_hi * $signed({1'b0, b_lo}));
assign pp2 = ($signed({1'b0, a_lo}) * b_hi);
assign pp3 = (a_hi * b_hi);

//------------------------------------------------------------------------------
// pipeline: EXE_MEM

logic signed [33:0] pp0_d, pp1_d, pp2_d, pp3_d;
logic [1:0] op_d;
logic en_d;
`STAGE_E_M(en, pp0, pp0_d, 'h0)
`STAGE_E_M(en, pp1, pp1_d, 'h0)
`STAGE_E_M(en, pp2, pp2_d, 'h0)
`STAGE_E_M(en, pp3, pp3_d, 'h0)
`STAGE_E_M(en, op, op_d, 'h0)
`STAGE_E_M(1'b1, en, en_d, 'h0)

//------------------------------------------------------------------------------
// stage 2 (MEM) - accumulation + output select

logic [63:0] prod;
assign prod = (
    {{32{1'b0}}, pp0_d[31:0]} +
    {{14{pp1_d[33]}}, pp1_d, 16'b0} +
    {{14{pp2_d[33]}}, pp2_d, 16'b0} +
    {pp3_d[31:0], 32'b0}
);

logic [31:0] p_mem;
assign p_mem = (op_d == SIMD_ARITH_OP_MUL[1:0]) ? prod[31:0] : prod[63:32];

//------------------------------------------------------------------------------
// pipeline: MEM_WBK

`STAGE_M_W(en_d, p_mem, p, 'h0)

endmodule
