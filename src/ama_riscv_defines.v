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
//
//-----------------------------------------------------------------------------
// Register File
`define RF_X0_ZERO 5'd0 // hard-wired zero
`define RF_X1_RA   5'd1  // return address
`define RF_X2_SP   5'd2  // stack pointer 
`define RF_X3_GP   5'd3  // global pointer
`define RF_X4_TP   5'd4  // thread pointer
`define RF_X5_T0   5'd5  // temporary/alternate link register
`define RF_X6_T1   5'd6  // temporary
`define RF_X7_T2   5'd7  // temporary
`define RF_X8_S0   5'd8  // saved register/frame pointer
`define RF_X9_S1   5'd9  // saved register
`define RF_X10_A0  5'd10 // function argument/return value
`define RF_X11_A1  5'd11 // function argument/return value
`define RF_X12_A2  5'd12 // function argument
`define RF_X13_A3  5'd13 // function argument
`define RF_X14_A4  5'd14 // function argument
`define RF_X15_A5  5'd15 // function argument
`define RF_X16_A6  5'd16 // function argument
`define RF_X17_A7  5'd17 // function argument
`define RF_X18_S2  5'd18 // saved register
`define RF_X19_S3  5'd19 // saved register
`define RF_X20_S4  5'd20 // saved register
`define RF_X21_S5  5'd21 // saved register
`define RF_X22_S6  5'd22 // saved register
`define RF_X23_S7  5'd23 // saved register
`define RF_X24_S8  5'd24 // saved register
`define RF_X25_S9  5'd25 // saved register
`define RF_X26_S10 5'd26 // saved register
`define RF_X27_S11 5'd27 // saved register
`define RF_X28_T3  5'd28 // temporary
`define RF_X29_T4  5'd29 // temporary
`define RF_X30_T5  5'd30 // temporary
`define RF_X31_T6  5'd31 // temporary


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