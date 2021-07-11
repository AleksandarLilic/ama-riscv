//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          ALU
// File:            ama_riscv_alu.v
// Date created:    2021-07-11
// Author:          Aleksandar Lilic
// Description:     Arithmetic and Logic Unit
//                  Supported operations:
//                  - addition
//                  - subtraction
//                  - shift left logical
//                  - shift right logical
//                  - shift right arithmetic
//                  - set less than
//                  - set less than unsigned
//                  - xor
//                  - or
//                  - and
//
// Version history:
//      2021-07-11  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_alu (
    // inputs
    input   wire [ 3:0] op_sel,
    input   wire [31:0] in_a  ,
    input   wire [31:0] in_b  ,
    // outputs
    output  reg  [31:0] out_s
);

//-----------------------------------------------------------------------------
// Signals
wire  [63:0] in_a_double_sll = {          in_a, 32'h0000};
wire  [63:0] in_a_double_srl = {      32'h0000,     in_a};
wire  [63:0] in_a_double_sra = {{32{in_a[31]}},     in_a};
wire  [ 4:0] shamt           = in_b[4:0];

//-----------------------------------------------------------------------------
// ALU
always @ (*) begin
    case (op_sel)
        `ALU_ADD: begin
            out_s = in_a + in_b;
        end
        
        `ALU_SUB: begin
            out_s = in_a - in_b;
        end
        
        `ALU_SLL: begin
            out_s = in_a_double_sll[(63-shamt) -: 32];
        end
        
        `ALU_SRL: begin
            out_s = in_a_double_srl[     shamt +: 32];
        end
        
        `ALU_SRA: begin
            out_s = in_a_double_sra[     shamt +: 32];
        end
        
        `ALU_SLT: begin
            out_s = ($signed(in_a) < $signed(in_b)) ? 32'h0001 : 32'h0000;
        end
        
        `ALU_SLTU: begin
            out_s = (in_a < in_b) ? 32'h0001 : 32'h0000;
        end
        
        `ALU_XOR: begin
            out_s = in_a ^ in_b;
        end
        
        `ALU_OR: begin
            out_s = in_a | in_b;
        end
        
        `ALU_AND: begin
            out_s = in_a & in_b;
        end
        
        `ALU_PASS_B: begin
            out_s = in_b;
        end
        
        default: begin  // invalid operation
            out_s = 32'h0000;
        end        
        
    endcase
end

endmodule