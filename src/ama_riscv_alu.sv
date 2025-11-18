`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    input  alu_op_t op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] s
);

localparam SHAMT_BITS = $clog2(ARCH_WIDTH); // 5 for 32-bit arch
logic [SHAMT_BITS:0] shamt;
arch_double_width_t a_d_sll, a_d_srl, a_d_sra;

assign a_d_sll = {a, {ARCH_WIDTH{1'b0}}};
assign a_d_srl = {{ARCH_WIDTH{1'b0}}, a};
assign a_d_sra = {{ARCH_WIDTH{a[ARCH_WIDTH-1]}}, a};
assign shamt = {1'b0, b[SHAMT_BITS-1:0]};

always_comb begin
    s = 'h0; // invalid operation
    unique case (op)
        ALU_OP_ADD: s = a + b;
        ALU_OP_SUB: s = a - b;
        ALU_OP_SLL: s = a_d_sll[(ARCH_WIDTH_D-1-shamt) -: ARCH_WIDTH];
        ALU_OP_SRL: s = a_d_srl[shamt +: ARCH_WIDTH];
        ALU_OP_SRA: s = a_d_sra[shamt +: ARCH_WIDTH];
        ALU_OP_SLT: s = ($signed(a) < $signed(b)) ? 'h1 : 'h0;
        ALU_OP_SLTU: s = (a < b) ? 'h1 : 'h0;
        ALU_OP_XOR: s = a ^ b;
        ALU_OP_OR: s = a | b;
        ALU_OP_AND: s = a & b;
        ALU_OP_PASS_B: s = b;
    endcase
end

endmodule
