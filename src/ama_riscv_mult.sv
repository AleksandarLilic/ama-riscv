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

typedef struct packed {
    logic signed [25:0] e0_l, e0_h;
    logic signed [25:0] e1_l, e1_h;
    logic signed [25:0] e2_l, e2_h;
    logic signed [25:0] e3_l, e3_h;
} partials_t;

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

logic signed [16:0] a_lo, a_hi, b_lo, b_hi;
assign a_hi = ext_a[32:16];
assign a_lo = {1'b0, ext_a[15:0]};
assign b_hi = ext_b[32:16];
assign b_lo = {1'b0, ext_b[15:0]};

// split the b-side halves into bytes
// each pp becomes two narrow products (sharing the a-side operand)
logic signed [8:0] b_lo_l, b_lo_h, b_hi_l, b_hi_h;
assign b_lo_l = {1'b0, b_lo[7:0]};
assign b_lo_h = b_lo[16:8];
assign b_hi_l = {1'b0, b_hi[7:0]};
assign b_hi_h = b_hi[16:8];

(* use_dsp = "no" *) partials_t pp;
// pp.e0 = a_lo * b_lo (u*u)
assign pp.e0_l = (a_lo * b_lo_l);
assign pp.e0_h = (a_lo * b_lo_h);
// pp.e1 = a_hi * b_lo (s*u)
assign pp.e1_l = (a_hi * b_lo_l);
assign pp.e1_h = (a_hi * b_lo_h);
// pp.e2 = a_lo * b_hi (u*s)
assign pp.e2_l = (a_lo * b_hi_l);
assign pp.e2_h = (a_lo * b_hi_h);
// pp.e3 = a_hi * b_hi (s*s)
assign pp.e3_l = (a_hi * b_hi_l);
assign pp.e3_h = (a_hi * b_hi_h);

//------------------------------------------------------------------------------
// pipeline: EXE_MEM

logic en_d;
logic [1:0] op_d;
partials_t pp_d;
`STAGE_E_M(en, pp, pp_d, 'h0)
`STAGE_E_M(en, op, op_d, 'h0)
`STAGE_E_M(1'b1, en, en_d, 'h0)

//------------------------------------------------------------------------------
// stage 2 (MEM)
// recombine b-side bytes, accumulate, output select

/* verilator lint_off UNUSEDSIGNAL */
logic signed [33:0] pp0_d, pp1_d, pp2_d, pp3_d; // [33:32] of pp0 and pp3 unused
/* verilator lint_on UNUSEDSIGNAL */
assign pp0_d = ({{8{pp_d.e0_l[25]}}, pp_d.e0_l} + {pp_d.e0_h, 8'b0});
assign pp1_d = ({{8{pp_d.e1_l[25]}}, pp_d.e1_l} + {pp_d.e1_h, 8'b0});
assign pp2_d = ({{8{pp_d.e2_l[25]}}, pp_d.e2_l} + {pp_d.e2_h, 8'b0});
assign pp3_d = ({{8{pp_d.e3_l[25]}}, pp_d.e3_l} + {pp_d.e3_h, 8'b0});

logic signed [34:0] mid;
assign mid = (pp1_d + pp2_d);

logic [63:0] prod;
assign prod = ({pp3_d[31:0], pp0_d[31:0]} + {{13{mid[34]}}, mid, 16'b0});

logic [31:0] p_mem;
assign p_mem = (op_d == SIMD_ARITH_OP_MUL[1:0]) ? prod[31:0] : prod[63:32];

//------------------------------------------------------------------------------
// pipeline: MEM_WBK

`STAGE_M_W(en_d, p_mem, p, 'h0)

endmodule
