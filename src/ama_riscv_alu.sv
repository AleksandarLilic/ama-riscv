`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    input  alu_op_t     op_sel,
    input  logic [31:0] in_a,
    input  logic [31:0] in_b,
    output logic [31:0] out_s
);

arch_double_width_t in_a_double_sll;
arch_double_width_t in_a_double_srl;
arch_double_width_t in_a_double_sra;
logic [5:0] shamt; // TODO: one more bit for 64-bit arch
assign in_a_double_sll = {in_a, {ARCH_WIDTH{1'b0}}};
assign in_a_double_srl = {{ARCH_WIDTH{1'b0}}, in_a};
assign in_a_double_sra = {{ARCH_WIDTH{in_a[ARCH_WIDTH-1]}}, in_a};
assign shamt = {1'b0, in_b[4:0]};

always_comb begin
    case (op_sel)
        ALU_OP_ADD: out_s = in_a + in_b;
        ALU_OP_SUB: out_s = in_a - in_b;
        ALU_OP_SLL: out_s = in_a_double_sll[(ARCH_DOUBLE_WIDTH-1-shamt) -: ARCH_WIDTH];
        ALU_OP_SRL: out_s = in_a_double_srl[shamt +: ARCH_WIDTH];
        ALU_OP_SRA: out_s = in_a_double_sra[shamt +: ARCH_WIDTH];
        ALU_OP_SLT: out_s = ($signed(in_a) < $signed(in_b)) ? 'h1 : 'h0;
        ALU_OP_SLTU: out_s = (in_a < in_b) ? 'h1 : 'h0;
        ALU_OP_XOR: out_s = in_a ^ in_b;
        ALU_OP_OR: out_s = in_a | in_b;
        ALU_OP_AND: out_s = in_a & in_b;
        ALU_OP_PASS_B: out_s = in_b;
        default: out_s = 'h0; // invalid operation
    endcase
end

endmodule
