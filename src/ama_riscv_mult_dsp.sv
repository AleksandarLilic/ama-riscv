`include "ama_riscv_defines.svh"

// module that simply allows FPGA synthesis tools to infer DSP blocks
// but doesn't enforce it
// inputs are flopped so A/B regs on DSPs can be inferred

module ama_riscv_mult_dsp (
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

typedef struct packed {
    logic [1:0] op;
    arch_double_width_s_t mul_a, mul_b;
} data_t;

//------------------------------------------------------------------------------
// stage 1 (EXE) - operand extension

arch_double_width_s_t a_s, b_s;
assign a_s = {{ARCH_WIDTH{a[ARCH_WIDTH-1]}}, a};
assign b_s = {{ARCH_WIDTH{b[ARCH_WIDTH-1]}}, b};

arch_double_width_t a_u, b_u;
assign a_u = {{ARCH_WIDTH{1'b0}}, a};
assign b_u = {{ARCH_WIDTH{1'b0}}, b};

data_t din;
always_comb begin
    din.mul_a = a_s;
    din.mul_b = b_s;
    din.op = op;
    unique case (op)
        SIMD_ARITH_OP_MUL[1:0],
        SIMD_ARITH_OP_MULH[1:0]: begin
            din.mul_a = a_s;
            din.mul_b = b_s;
        end
        SIMD_ARITH_OP_MULHSU[1:0]: begin
            din.mul_a = a_s;
            din.mul_b = $signed(b_u);
        end
        SIMD_ARITH_OP_MULHU[1:0]: begin
            din.mul_a = $signed(a_u);
            din.mul_b = $signed(b_u);
        end
    endcase
end

//------------------------------------------------------------------------------
// pipeline: EXE_MEM

logic en_d;
data_t din_d;
`STAGE_E_M(en, din, din_d, 'h0)
`STAGE_E_M(1'b1, en, en_d, 'h0)

//------------------------------------------------------------------------------
// stage 2 (MEM) - multiply and output select

arch_double_width_s_t prod;
assign prod = (din_d.mul_a * din_d.mul_b);

logic [31:0] p_mem;
assign p_mem = (din_d.op == SIMD_ARITH_OP_MUL[1:0]) ? prod[31:0] : prod[63:32];

//------------------------------------------------------------------------------
// pipeline: MEM_WBK

`STAGE_M_W(en_d, p_mem, p, 'h0)

endmodule
