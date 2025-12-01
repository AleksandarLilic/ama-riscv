`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    input  alu_op_t op,
    input  arch_width_t a,
    input  arch_width_t b,
    output arch_width_t s
);

localparam SHAMT_BITS = $clog2(ARCH_WIDTH); // 5 for 32-bit arch

// adder, subtractor, comparator
logic is_sub;
assign is_sub = (
    (op == ALU_OP_SUB) || (op == ALU_OP_SLT) || (op == ALU_OP_SLTU)
);

logic cout, slt_res, sltu_res;
arch_width_t adder_b, adder_out;
assign adder_b = is_sub ? ~b : b;
assign {cout, adder_out} = (a + adder_b + {31'b0, is_sub});

// sltu logic: in (a + ~b + 1), cout=0 indicates a borrow (a < b)
assign sltu_res = ~cout;

// slt logic (signbit xor overflow)
// overflow happens if
//   1. operands have different signs (a vs b)
//   2. result sign matches b
// the *original* b sign is used, not the inverted adder_b
logic v_flag, n_flag; // overflow, negative
assign v_flag = ((a[31] != b[31]) && (adder_out[31] != a[31]));
assign n_flag = adder_out[31];
assign slt_res = n_flag ^ v_flag;

// shift opt (srl and sra) reuse the right shifter
logic sr_fill;
assign sr_fill = (op == ALU_OP_SRA) ? a[31] : 1'b0;

logic [SHAMT_BITS-1:0] shamt;
assign shamt = b[SHAMT_BITS-1:0];

arch_width_t srla_res;
arch_double_width_t sr_temp;
assign sr_temp = ({{32{sr_fill}}, a} >> shamt);
assign srla_res = sr_temp[31:0];

arch_width_t sll_res;
assign sll_res = (a << shamt);

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
        ALU_OP_XOR: s = a ^ b;
        ALU_OP_OR: s = a | b;
        ALU_OP_AND: s = a & b;
        ALU_OP_PASS_B: s = b;
        default: s = 'h0;
    endcase
end

endmodule
