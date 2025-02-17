`include "ama_riscv_defines.svh"

module ama_riscv_alu (
    input  wire [ 3:0] op_sel,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output reg  [31:0] out_s
);

wire [63:0] in_a_double_sll = {in_a, 32'h0};
wire [63:0] in_a_double_srl = {32'h0, in_a};
wire [63:0] in_a_double_sra = {{32{in_a[31]}}, in_a};
wire [ 4:0] shamt = in_b[4:0];

always @ (*) begin
    case (op_sel)
        `ALU_ADD: out_s = in_a + in_b;
        `ALU_SUB: out_s = in_a - in_b;
        `ALU_SLL: out_s = in_a_double_sll[(63-shamt) -: 32];
        `ALU_SRL: out_s = in_a_double_srl[shamt +: 32];
        `ALU_SRA: out_s = in_a_double_sra[shamt +: 32];
        `ALU_SLT: out_s = ($signed(in_a) < $signed(in_b)) ? 32'h1 : 32'h0;
        `ALU_SLTU: out_s = (in_a < in_b) ? 32'h1 : 32'h0;
        `ALU_XOR: out_s = in_a ^ in_b;
        `ALU_OR: out_s = in_a | in_b;
        `ALU_AND: out_s = in_a & in_b;
        `ALU_PASS_B: out_s = in_b;
        default: out_s = 32'h0; // invalid operation        
    endcase
end

endmodule
