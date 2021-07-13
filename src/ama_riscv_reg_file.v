//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Register File
// File:            ama_riscv_reg_file.v
// Date created:    2021-07-09
// Author:          Aleksandar Lilic
// Description:     RV32I Register File with sync write back and async read
//
// Version history:
//      2021-07-09  AL  0.1.0 - Initial
//      2021-07-09  AL  0.2.0 - Add write enable
//      2021-07-09  AL  1.0.0 - Release
//      2021-07-13  AL  1.1.0 - Add defines
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_reg_file (
    input   wire        clk,
    input   wire        rst,
    // inputs
    input   wire        we,
    input   wire [ 4:0] addr_a,
    input   wire [ 4:0] addr_b,
    input   wire [ 4:0] addr_d,
    input   wire [31:0] data_d,
    // outputs
    output  reg  [31:0] data_a,
    output  reg  [31:0] data_b
);

//-----------------------------------------------------------------------------
// Signals
// Registers
reg [31:0] reg_r1;
reg [31:0] reg_r2;
reg [31:0] reg_r3;
reg [31:0] reg_r4;
reg [31:0] reg_r5;
reg [31:0] reg_r6;
reg [31:0] reg_r7;
reg [31:0] reg_r8;
reg [31:0] reg_r9;
reg [31:0] reg_r10;
reg [31:0] reg_r11;
reg [31:0] reg_r12;
reg [31:0] reg_r13;
reg [31:0] reg_r14;
reg [31:0] reg_r15;
reg [31:0] reg_r16;
reg [31:0] reg_r17;
reg [31:0] reg_r18;
reg [31:0] reg_r19;
reg [31:0] reg_r20;
reg [31:0] reg_r21;
reg [31:0] reg_r22;
reg [31:0] reg_r23;
reg [31:0] reg_r24;
reg [31:0] reg_r25;
reg [31:0] reg_r26;
reg [31:0] reg_r27;
reg [31:0] reg_r28;
reg [31:0] reg_r29;
reg [31:0] reg_r30;
reg [31:0] reg_r31;

// Alternative names
// name: register_abi-name      // Description
wire [31:0] x0_zero = 32'b0;    // hard-wired zero
wire [31:0] x1_ra   = reg_r1;   // return address
wire [31:0] x2_sp   = reg_r2;   // stack pointer 
wire [31:0] x3_gp   = reg_r3;   // global pointer
wire [31:0] x4_tp   = reg_r4;   // thread pointer
wire [31:0] x5_t0   = reg_r5;   // temporary/alternate link register
wire [31:0] x6_t1   = reg_r6;   // temporary
wire [31:0] x7_t2   = reg_r7;   // temporary
wire [31:0] x8_s0   = reg_r8;   // saved register/frame pointer
wire [31:0] x9_s1   = reg_r9;   // saved register
wire [31:0] x10_a0  = reg_r10;  // function argument/return value
wire [31:0] x11_a1  = reg_r11;  // function argument/return value
wire [31:0] x12_a2  = reg_r12;  // function argument
wire [31:0] x13_a3  = reg_r13;  // function argument
wire [31:0] x14_a4  = reg_r14;  // function argument
wire [31:0] x15_a5  = reg_r15;  // function argument
wire [31:0] x16_a6  = reg_r16;  // function argument
wire [31:0] x17_a7  = reg_r17;  // function argument
wire [31:0] x18_s2  = reg_r18;  // saved register
wire [31:0] x19_s3  = reg_r19;  // saved register
wire [31:0] x20_s4  = reg_r20;  // saved register
wire [31:0] x21_s5  = reg_r21;  // saved register
wire [31:0] x22_s6  = reg_r22;  // saved register
wire [31:0] x23_s7  = reg_r23;  // saved register
wire [31:0] x24_s8  = reg_r24;  // saved register
wire [31:0] x25_s9  = reg_r25;  // saved register
wire [31:0] x26_s10 = reg_r26;  // saved register
wire [31:0] x27_s11 = reg_r27;  // saved register
wire [31:0] x28_t3  = reg_r28;  // temporary
wire [31:0] x29_t4  = reg_r29;  // temporary
wire [31:0] x30_t5  = reg_r30;  // temporary
wire [31:0] x31_t6  = reg_r31;  // temporary
    
//-----------------------------------------------------------------------------
// synchronous register write back
always @ (posedge clk) begin
    if (rst) begin
        reg_r1       <= 32'h00000000;
        reg_r2       <= 32'h00000000;
        reg_r3       <= 32'h00000000;
        reg_r4       <= 32'h00000000;
        reg_r5       <= 32'h00000000;
        reg_r6       <= 32'h00000000;
        reg_r7       <= 32'h00000000;
        reg_r8       <= 32'h00000000;
        reg_r9       <= 32'h00000000;
        reg_r10      <= 32'h00000000;
        reg_r11      <= 32'h00000000;
        reg_r12      <= 32'h00000000;
        reg_r13      <= 32'h00000000;
        reg_r14      <= 32'h00000000;
        reg_r15      <= 32'h00000000;
        reg_r16      <= 32'h00000000;
        reg_r17      <= 32'h00000000;
        reg_r18      <= 32'h00000000;
        reg_r19      <= 32'h00000000;
        reg_r20      <= 32'h00000000;
        reg_r21      <= 32'h00000000;
        reg_r22      <= 32'h00000000;
        reg_r23      <= 32'h00000000;
        reg_r24      <= 32'h00000000;
        reg_r25      <= 32'h00000000;
        reg_r26      <= 32'h00000000;
        reg_r27      <= 32'h00000000;
        reg_r28      <= 32'h00000000;
        reg_r29      <= 32'h00000000;
        reg_r30      <= 32'h00000000;
        reg_r31      <= 32'h00000000;
    end
    else if (we == 1'b1) begin
        if      (addr_d == `RF_X1_RA  ) reg_r1  <= data_d;
        if      (addr_d == `RF_X2_SP  ) reg_r2  <= data_d;
        if      (addr_d == `RF_X3_GP  ) reg_r3  <= data_d;
        if      (addr_d == `RF_X4_TP  ) reg_r4  <= data_d;
        if      (addr_d == `RF_X5_T0  ) reg_r5  <= data_d;
        if      (addr_d == `RF_X6_T1  ) reg_r6  <= data_d;
        if      (addr_d == `RF_X7_T2  ) reg_r7  <= data_d;
        if      (addr_d == `RF_X8_S0  ) reg_r8  <= data_d;
        if      (addr_d == `RF_X9_S1  ) reg_r9  <= data_d;
        if      (addr_d == `RF_X10_A0 ) reg_r10 <= data_d;
        if      (addr_d == `RF_X11_A1 ) reg_r11 <= data_d;
        if      (addr_d == `RF_X12_A2 ) reg_r12 <= data_d;
        if      (addr_d == `RF_X13_A3 ) reg_r13 <= data_d;
        if      (addr_d == `RF_X14_A4 ) reg_r14 <= data_d;
        if      (addr_d == `RF_X15_A5 ) reg_r15 <= data_d;
        if      (addr_d == `RF_X16_A6 ) reg_r16 <= data_d;
        if      (addr_d == `RF_X17_A7 ) reg_r17 <= data_d;
        if      (addr_d == `RF_X18_S2 ) reg_r18 <= data_d;
        if      (addr_d == `RF_X19_S3 ) reg_r19 <= data_d;
        if      (addr_d == `RF_X20_S4 ) reg_r20 <= data_d;
        if      (addr_d == `RF_X21_S5 ) reg_r21 <= data_d;
        if      (addr_d == `RF_X22_S6 ) reg_r22 <= data_d;
        if      (addr_d == `RF_X23_S7 ) reg_r23 <= data_d;
        if      (addr_d == `RF_X24_S8 ) reg_r24 <= data_d;
        if      (addr_d == `RF_X25_S9 ) reg_r25 <= data_d;
        if      (addr_d == `RF_X26_S10) reg_r26 <= data_d;
        if      (addr_d == `RF_X27_S11) reg_r27 <= data_d;
        if      (addr_d == `RF_X28_T3 ) reg_r28 <= data_d;
        if      (addr_d == `RF_X29_T4 ) reg_r29 <= data_d;
        if      (addr_d == `RF_X30_T5 ) reg_r30 <= data_d;
        if      (addr_d == `RF_X31_T6 ) reg_r31 <= data_d;
    end
end // synchronous register write back

//-----------------------------------------------------------------------------
// asynchronous register read
always @ (*) begin
    // port A
    case (addr_a)
        `RF_X1_RA  :   data_a = reg_r1;
        `RF_X2_SP  :   data_a = reg_r2;
        `RF_X3_GP  :   data_a = reg_r3;
        `RF_X4_TP  :   data_a = reg_r4;
        `RF_X5_T0  :   data_a = reg_r5;
        `RF_X6_T1  :   data_a = reg_r6;
        `RF_X7_T2  :   data_a = reg_r7;
        `RF_X8_S0  :   data_a = reg_r8;
        `RF_X9_S1  :   data_a = reg_r9;
        `RF_X10_A0 :   data_a = reg_r10;
        `RF_X11_A1 :   data_a = reg_r11;
        `RF_X12_A2 :   data_a = reg_r12;
        `RF_X13_A3 :   data_a = reg_r13;
        `RF_X14_A4 :   data_a = reg_r14;
        `RF_X15_A5 :   data_a = reg_r15;
        `RF_X16_A6 :   data_a = reg_r16;
        `RF_X17_A7 :   data_a = reg_r17;
        `RF_X18_S2 :   data_a = reg_r18;
        `RF_X19_S3 :   data_a = reg_r19;
        `RF_X20_S4 :   data_a = reg_r20;
        `RF_X21_S5 :   data_a = reg_r21;
        `RF_X22_S6 :   data_a = reg_r22;
        `RF_X23_S7 :   data_a = reg_r23;
        `RF_X24_S8 :   data_a = reg_r24;
        `RF_X25_S9 :   data_a = reg_r25;
        `RF_X26_S10:   data_a = reg_r26;
        `RF_X27_S11:   data_a = reg_r27;
        `RF_X28_T3 :   data_a = reg_r28;
        `RF_X29_T4 :   data_a = reg_r29;
        `RF_X30_T5 :   data_a = reg_r30;
        `RF_X31_T6 :   data_a = reg_r31;
        default:       data_a = 32'h00000000;
    endcase
    
    // port B
    case (addr_b)
        `RF_X1_RA  :   data_b = reg_r1;
        `RF_X2_SP  :   data_b = reg_r2;
        `RF_X3_GP  :   data_b = reg_r3;
        `RF_X4_TP  :   data_b = reg_r4;
        `RF_X5_T0  :   data_b = reg_r5;
        `RF_X6_T1  :   data_b = reg_r6;
        `RF_X7_T2  :   data_b = reg_r7;
        `RF_X8_S0  :   data_b = reg_r8;
        `RF_X9_S1  :   data_b = reg_r9;
        `RF_X10_A0 :   data_b = reg_r10;
        `RF_X11_A1 :   data_b = reg_r11;
        `RF_X12_A2 :   data_b = reg_r12;
        `RF_X13_A3 :   data_b = reg_r13;
        `RF_X14_A4 :   data_b = reg_r14;
        `RF_X15_A5 :   data_b = reg_r15;
        `RF_X16_A6 :   data_b = reg_r16;
        `RF_X17_A7 :   data_b = reg_r17;
        `RF_X18_S2 :   data_b = reg_r18;
        `RF_X19_S3 :   data_b = reg_r19;
        `RF_X20_S4 :   data_b = reg_r20;
        `RF_X21_S5 :   data_b = reg_r21;
        `RF_X22_S6 :   data_b = reg_r22;
        `RF_X23_S7 :   data_b = reg_r23;
        `RF_X24_S8 :   data_b = reg_r24;
        `RF_X25_S9 :   data_b = reg_r25;
        `RF_X26_S10:   data_b = reg_r26;
        `RF_X27_S11:   data_b = reg_r27;
        `RF_X28_T3 :   data_b = reg_r28;
        `RF_X29_T4 :   data_b = reg_r29;
        `RF_X30_T5 :   data_b = reg_r30;
        `RF_X31_T6 :   data_b = reg_r31;
        default:       data_b = 32'h00000000;
    endcase
end // asynchronous register read

endmodule