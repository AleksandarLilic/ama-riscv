`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    // alu side
    input  alu_op_t op,
    input  arch_width_t a,
    input  arch_width_t b,
    output arch_width_t s,
    // branch side
    input  logic is_branch,
    input  logic branch_u,
    input  branch_sel_t branch_sel,
    output branch_t branch_res
);

localparam SHAMT_BITS = $clog2(ARCH_WIDTH); // 5 for 32-bit arch

// adder, subtractor, comparator
logic is_min, is_max, is_unsigned_zbb;
assign is_min = ((op == ALU_OP_MIN) || (op == ALU_OP_MINU));
assign is_max = ((op == ALU_OP_MAX) || (op == ALU_OP_MAXU));
assign is_unsigned_zbb = ((op == ALU_OP_MINU) || (op == ALU_OP_MAXU));

logic is_sub;
assign is_sub = (
    (op == ALU_OP_SUB) ||
    (op == ALU_OP_SLT) || (op == ALU_OP_SLTU) ||
    is_min || is_max ||
    is_branch
);

logic cout, slt_res, sltu_res;
arch_width_t adder_b, adder_out;
assign adder_b = is_sub ? ~b : b;
assign {cout, adder_out} = (a + adder_b + {31'b0, is_sub});

// --- sltu logic: in (a + ~b + 1), cout=0 indicates a borrow (a < b)
assign sltu_res = ~cout;

// --- slt logic (signbit xor overflow)
// overflow happens if
//   1. operands have different signs (a vs b)
//   2. result sign matches b
// the *original* b sign is used, not the inverted adder_b
logic v_flag, n_flag; // overflow, negative
assign v_flag = ((a[31] != b[31]) && (adder_out[31] != a[31]));
assign n_flag = adder_out[31];
assign slt_res = (n_flag ^ v_flag);

// --- min/max selection logic
// determine if doing signed or unsigned comparison
logic cmp_lt;
assign cmp_lt = ((op == ALU_OP_SLTU) || is_unsigned_zbb) ? sltu_res : slt_res;

logic pick_a;
// MIN: keep A if A < B. MAX: keep A if A >= B (which is !cmp_lt)
assign pick_a = is_min ? cmp_lt : !cmp_lt;

arch_width_t minmax_res;
assign minmax_res = pick_a ? a : b;

// --- shift opt (srl and sra) reuse the right shifter
logic sr_fill;
assign sr_fill = (op == ALU_OP_SRA) ? a[31] : 1'b0;

logic [SHAMT_BITS-1:0] shamt;
assign shamt = b[SHAMT_BITS-1:0];

arch_width_t srla_res;
assign srla_res = arch_width_t'({{32{sr_fill}}, a} >> shamt); // low 32bits only

arch_width_t sll_res;
assign sll_res = (a << shamt);

arch_width_t a_xor_b;
assign a_xor_b = (a ^ b);

// outputs
always_comb begin
    unique case (op)
        // add, sub, compares
        ALU_OP_ADD,
        ALU_OP_SUB: s = adder_out;
        ALU_OP_SLT: s = {31'b0, slt_res};
        ALU_OP_SLTU: s = {31'b0, sltu_res};
        // shifts
        ALU_OP_SLL: s = sll_res;
        ALU_OP_SRL,
        ALU_OP_SRA: s = srla_res;
        // logic
        ALU_OP_XOR: s = a_xor_b;
        ALU_OP_OR: s = (a | b);
        ALU_OP_AND: s = (a & b);
        ALU_OP_MIN,
        ALU_OP_MINU,
        ALU_OP_MAX,
        ALU_OP_MAXU: s = minmax_res;
        ALU_OP_OFF: s = 'h0;
        default: s = 'h0;
    endcase
end

// branch compare & resolution
logic bc_a_lts_b, bc_a_ltu_b;
assign bc_a_lts_b = slt_res;
assign bc_a_ltu_b = sltu_res;

logic bc_a_ne_b, bc_a_eq_b, bc_a_lt_b, bc_a_ge_b;
assign bc_a_ne_b = (|a_xor_b);
assign bc_a_eq_b = (!bc_a_ne_b);
assign bc_a_lt_b = (branch_u) ? bc_a_ltu_b : bc_a_lts_b;
assign bc_a_ge_b = (bc_a_eq_b || !bc_a_lt_b);

always_comb begin
    unique case (branch_sel)
        BRANCH_SEL_BEQ: branch_res = branch_t'(bc_a_eq_b);
        BRANCH_SEL_BNE: branch_res = branch_t'(bc_a_ne_b);
        BRANCH_SEL_BLT: branch_res = branch_t'(bc_a_lt_b);
        BRANCH_SEL_BGE: branch_res = branch_t'(bc_a_ge_b);
    endcase
end

endmodule
