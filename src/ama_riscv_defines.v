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
//      2021-07-13  AL  0.4.0 - Add Register File defines
//      2021-07-13  AL  0.5.0 - Add DMEM access defines
//      2021-07-16  AL  0.6.0 - Add Opcode 5-bit defines
//      2021-07-16  AL  0.7.0 - Add MUX select defines (PC, ALU_A op, ALU_B op, WB)
//
//-----------------------------------------------------------------------------
// Opcodes
// Only top 5 bits of a 7-bit opcode is needed
// All RV32I instructions have format of {OPC5,2'b11}
`define OPC5_ARI_R_TYPE  5'b0_1100      // R-type
`define OPC5_ARI_I_TYPE  5'b0_0100      // I-type
`define OPC5_LOAD        5'b0_0000      // I-type
`define OPC5_STORE       5'b0_1000      // S-type
`define OPC5_BRANCH      5'b1_1000      // B-type
`define OPC5_JALR        5'b1_1001      // J-type, I-format
`define OPC5_JAL         5'b1_1011      // J-type
`define OPC5_LUI         5'b0_1101      // U-type
`define OPC5_AUIPC       5'b0_0101      // U-type

//-----------------------------------------------------------------------------
// MUX select signals
// PC select
`define PC_SEL_INC4         2'd0  // PC = PC + 4
`define PC_SEL_ALU          2'd1  // ALU output, used for jump/branch
`define PC_SEL_BP           2'd2  // PC = Branch prediction output
`define PC_SEL_START_ADDR   2'd3  // PC = Hardwired start address

// ALU A operand select
`define ALU_A_SEL_RS1       2'd0  // A = Reg[rs1]
`define ALU_A_SEL_PC        2'd1  // A = PC
`define ALU_A_SEL_FW_ALU    2'd2  // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_RS2       2'd0  // B = Reg[rs2]
`define ALU_B_SEL_IMM       2'd1  // B = Immediate value; from Imm Gen
`define ALU_B_SEL_FW_ALU    2'd2  // B = ALU; forwarding from MEM stage

// Write back select
`define WB_SEL_DMEM         2'd0  // Reg[rd] = DMEM[ALU]
`define WB_SEL_ALU          2'd1  // Reg[rd] = ALU
`define WB_SEL_INC4         2'd2  // Reg[rd] = PC + 4

//-----------------------------------------------------------------------------
// Register File
`define RF_X0_ZERO  5'd0  // hard-wired zero
`define RF_X1_RA    5'd1  // return address
`define RF_X2_SP    5'd2  // stack pointer 
`define RF_X3_GP    5'd3  // global pointer
`define RF_X4_TP    5'd4  // thread pointer
`define RF_X5_T0    5'd5  // temporary/alternate link register
`define RF_X6_T1    5'd6  // temporary
`define RF_X7_T2    5'd7  // temporary
`define RF_X8_S0    5'd8  // saved register/frame pointer
`define RF_X9_S1    5'd9  // saved register
`define RF_X10_A0   5'd10 // function argument/return value
`define RF_X11_A1   5'd11 // function argument/return value
`define RF_X12_A2   5'd12 // function argument
`define RF_X13_A3   5'd13 // function argument
`define RF_X14_A4   5'd14 // function argument
`define RF_X15_A5   5'd15 // function argument
`define RF_X16_A6   5'd16 // function argument
`define RF_X17_A7   5'd17 // function argument
`define RF_X18_S2   5'd18 // saved register
`define RF_X19_S3   5'd19 // saved register
`define RF_X20_S4   5'd20 // saved register
`define RF_X21_S5   5'd21 // saved register
`define RF_X22_S6   5'd22 // saved register
`define RF_X23_S7   5'd23 // saved register
`define RF_X24_S8   5'd24 // saved register
`define RF_X25_S9   5'd25 // saved register
`define RF_X26_S10  5'd26 // saved register
`define RF_X27_S11  5'd27 // saved register
`define RF_X28_T3   5'd28 // temporary
`define RF_X29_T4   5'd29 // temporary
`define RF_X30_T5   5'd30 // temporary
`define RF_X31_T6   5'd31 // temporary

//-----------------------------------------------------------------------------
// DMEM access
// DMEM Width
`define DMEM_BYTE   2'd0
`define DMEM_HALF   2'd1
`define DMEM_WORD   2'd2

// DMEM Offset
`define DMEM_OFF_0  2'd0
`define DMEM_OFF_1  2'd1
`define DMEM_OFF_2  2'd2
`define DMEM_OFF_3  2'd3

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

//-----------------------------------------------------------------------------
// Imm Gen
`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

//-----------------------------------------------------------------------------
// End of defines