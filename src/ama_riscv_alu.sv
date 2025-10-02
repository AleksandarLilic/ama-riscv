`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    input  alu_op_t     op_sel,
    input  logic [31:0] in_a,
    input  logic [31:0] in_b,
    output logic [31:0] out_s
);

logic [63:0] in_a_double_sll;
logic [63:0] in_a_double_srl;
logic [63:0] in_a_double_sra;
logic [ 5:0] shamt;
assign in_a_double_sll = {in_a, 32'h0};
assign in_a_double_srl = {32'h0, in_a};
assign in_a_double_sra = {{32{in_a[31]}}, in_a};
assign shamt = {1'b0,in_b[4:0]};

always_comb begin
    case (op_sel)
        ALU_OP_ADD: out_s = in_a + in_b;
        ALU_OP_SUB: out_s = in_a - in_b;
        ALU_OP_SLL: out_s = in_a_double_sll[(63-shamt) -: 32];
        ALU_OP_SRL: out_s = in_a_double_srl[shamt +: 32];
        ALU_OP_SRA: out_s = in_a_double_sra[shamt +: 32];
        ALU_OP_SLT: out_s = ($signed(in_a) < $signed(in_b)) ? 32'h1 : 32'h0;
        ALU_OP_SLTU: out_s = (in_a < in_b) ? 32'h1 : 32'h0;
        ALU_OP_XOR: out_s = in_a ^ in_b;
        ALU_OP_OR: out_s = in_a | in_b;
        ALU_OP_AND: out_s = in_a & in_b;
        ALU_OP_PASS_B: out_s = in_b;
        default: out_s = 32'h0; // invalid operation
    endcase
end

endmodule
