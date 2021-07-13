//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Defines
// File:            ama_riscv_defines.v
// Date created:    2021-07-11
// Author:          Aleksandar Lilic
// Description:     Macro defines
//
// Version history:
//      2021-07-11  AL  0.1.0 - Add ALU defines
//      2021-07-11  AL  0.2.0 - Add Imm Gen defines
//      2021-07-13  AL  0.3.0 - Add Imm Gen Disabled define, shift others
//
//-----------------------------------------------------------------------------
// ALU
`define ALU_ADD     4'b0000
`define ALU_SUB     4'b1000
`define ALU_SLL     4'b0001
`define ALU_SRL     4'b0101
`define ALU_SRA     4'b1101
`define ALU_SLT     4'b0010
`define ALU_SLTU    4'b0011
`define ALU_XOR     4'b0100
`define ALU_OR      4'b0110
`define ALU_AND     4'b0111
`define ALU_PASS_B  4'b1111

// Imm Gen
`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

//-----------------------------------------------------------------------------
// End of defines