`include "ama_riscv_defines.v"

module ama_riscv_reg_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [ 4:0] addr_a,
    input  wire [ 4:0] addr_b,
    input  wire [ 4:0] addr_d,
    input  wire [31:0] data_d,
    output reg  [31:0] data_a,
    output reg  [31:0] data_b
);

// Registers
reg  [31:0] reg_x1_ra; // return address
reg  [31:0] reg_x2_sp; // stack pointer 
reg  [31:0] reg_x3_gp; // global pointer
reg  [31:0] reg_x4_tp; // thread pointer
reg  [31:0] reg_x5_t0; // temporary/alternate link register
reg  [31:0] reg_x6_t1; // temporary
reg  [31:0] reg_x7_t2; // temporary
reg  [31:0] reg_x8_s0; // saved register/frame pointer
reg  [31:0] reg_x9_s1; // saved register
reg  [31:0] reg_x10_a0; // function argument/return value
reg  [31:0] reg_x11_a1; // function argument/return value
reg  [31:0] reg_x12_a2; // function argument
reg  [31:0] reg_x13_a3; // function argument
reg  [31:0] reg_x14_a4; // function argument
reg  [31:0] reg_x15_a5; // function argument
reg  [31:0] reg_x16_a6; // function argument
reg  [31:0] reg_x17_a7; // function argument
reg  [31:0] reg_x18_s2; // saved register
reg  [31:0] reg_x19_s3; // saved register
reg  [31:0] reg_x20_s4; // saved register
reg  [31:0] reg_x21_s5; // saved register
reg  [31:0] reg_x22_s6; // saved register
reg  [31:0] reg_x23_s7; // saved register
reg  [31:0] reg_x24_s8; // saved register
reg  [31:0] reg_x25_s9; // saved register
reg  [31:0] reg_x26_s10; // saved register
reg  [31:0] reg_x27_s11; // saved register
reg  [31:0] reg_x28_t3; // temporary
reg  [31:0] reg_x29_t4; // temporary
reg  [31:0] reg_x30_t5; // temporary
reg  [31:0] reg_x31_t6; // temporary

// synchronous register write back
always @ (posedge clk) begin
    if (rst) begin
        reg_x1_ra <= 32'h00000000;
        reg_x2_sp <= 32'h00000000;
        reg_x3_gp <= 32'h00000000;
        reg_x4_tp <= 32'h00000000;
        reg_x5_t0 <= 32'h00000000;
        reg_x6_t1 <= 32'h00000000;
        reg_x7_t2 <= 32'h00000000;
        reg_x8_s0 <= 32'h00000000;
        reg_x9_s1 <= 32'h00000000;
        reg_x10_a0 <= 32'h00000000;
        reg_x11_a1 <= 32'h00000000;
        reg_x12_a2 <= 32'h00000000;
        reg_x13_a3 <= 32'h00000000;
        reg_x14_a4 <= 32'h00000000;
        reg_x15_a5 <= 32'h00000000;
        reg_x16_a6 <= 32'h00000000;
        reg_x17_a7 <= 32'h00000000;
        reg_x18_s2 <= 32'h00000000;
        reg_x19_s3 <= 32'h00000000;
        reg_x20_s4 <= 32'h00000000;
        reg_x21_s5 <= 32'h00000000;
        reg_x22_s6 <= 32'h00000000;
        reg_x23_s7 <= 32'h00000000;
        reg_x24_s8 <= 32'h00000000;
        reg_x25_s9 <= 32'h00000000;
        reg_x26_s10 <= 32'h00000000;
        reg_x27_s11 <= 32'h00000000;
        reg_x28_t3 <= 32'h00000000;
        reg_x29_t4 <= 32'h00000000;
        reg_x30_t5 <= 32'h00000000;
        reg_x31_t6 <= 32'h00000000;
    end
    else if (we == 1'b1) begin
        case (addr_d)
            `RF_X1_RA  : reg_x1_ra   <= data_d;
            `RF_X2_SP  : reg_x2_sp   <= data_d;
            `RF_X3_GP  : reg_x3_gp   <= data_d;
            `RF_X4_TP  : reg_x4_tp   <= data_d;
            `RF_X5_T0  : reg_x5_t0   <= data_d;
            `RF_X6_T1  : reg_x6_t1   <= data_d;
            `RF_X7_T2  : reg_x7_t2   <= data_d;
            `RF_X8_S0  : reg_x8_s0   <= data_d;
            `RF_X9_S1  : reg_x9_s1   <= data_d;
            `RF_X10_A0 : reg_x10_a0  <= data_d;
            `RF_X11_A1 : reg_x11_a1  <= data_d;
            `RF_X12_A2 : reg_x12_a2  <= data_d;
            `RF_X13_A3 : reg_x13_a3  <= data_d;
            `RF_X14_A4 : reg_x14_a4  <= data_d;
            `RF_X15_A5 : reg_x15_a5  <= data_d;
            `RF_X16_A6 : reg_x16_a6  <= data_d;
            `RF_X17_A7 : reg_x17_a7  <= data_d;
            `RF_X18_S2 : reg_x18_s2  <= data_d;
            `RF_X19_S3 : reg_x19_s3  <= data_d;
            `RF_X20_S4 : reg_x20_s4  <= data_d;
            `RF_X21_S5 : reg_x21_s5  <= data_d;
            `RF_X22_S6 : reg_x22_s6  <= data_d;
            `RF_X23_S7 : reg_x23_s7  <= data_d;
            `RF_X24_S8 : reg_x24_s8  <= data_d;
            `RF_X25_S9 : reg_x25_s9  <= data_d;
            `RF_X26_S10: reg_x26_s10 <= data_d;
            `RF_X27_S11: reg_x27_s11 <= data_d;
            `RF_X28_T3 : reg_x28_t3  <= data_d;
            `RF_X29_T4 : reg_x29_t4  <= data_d;
            `RF_X30_T5 : reg_x30_t5  <= data_d;
            `RF_X31_T6 : reg_x31_t6  <= data_d;
        endcase
    end
end

// asynchronous register read
always @ (*) begin
    // port A
    case (addr_a)
        `RF_X1_RA  : data_a = reg_x1_ra;
        `RF_X2_SP  : data_a = reg_x2_sp;
        `RF_X3_GP  : data_a = reg_x3_gp;
        `RF_X4_TP  : data_a = reg_x4_tp;
        `RF_X5_T0  : data_a = reg_x5_t0;
        `RF_X6_T1  : data_a = reg_x6_t1;
        `RF_X7_T2  : data_a = reg_x7_t2;
        `RF_X8_S0  : data_a = reg_x8_s0;
        `RF_X9_S1  : data_a = reg_x9_s1;
        `RF_X10_A0 : data_a = reg_x10_a0;
        `RF_X11_A1 : data_a = reg_x11_a1;
        `RF_X12_A2 : data_a = reg_x12_a2;
        `RF_X13_A3 : data_a = reg_x13_a3;
        `RF_X14_A4 : data_a = reg_x14_a4;
        `RF_X15_A5 : data_a = reg_x15_a5;
        `RF_X16_A6 : data_a = reg_x16_a6;
        `RF_X17_A7 : data_a = reg_x17_a7;
        `RF_X18_S2 : data_a = reg_x18_s2;
        `RF_X19_S3 : data_a = reg_x19_s3;
        `RF_X20_S4 : data_a = reg_x20_s4;
        `RF_X21_S5 : data_a = reg_x21_s5;
        `RF_X22_S6 : data_a = reg_x22_s6;
        `RF_X23_S7 : data_a = reg_x23_s7;
        `RF_X24_S8 : data_a = reg_x24_s8;
        `RF_X25_S9 : data_a = reg_x25_s9;
        `RF_X26_S10: data_a = reg_x26_s10;
        `RF_X27_S11: data_a = reg_x27_s11;
        `RF_X28_T3 : data_a = reg_x28_t3;
        `RF_X29_T4 : data_a = reg_x29_t4;
        `RF_X30_T5 : data_a = reg_x30_t5;
        `RF_X31_T6 : data_a = reg_x31_t6;
        default:     data_a = 32'h00000000;
    endcase
    
    // port B
    case (addr_b)
        `RF_X1_RA  : data_b = reg_x1_ra;
        `RF_X2_SP  : data_b = reg_x2_sp;
        `RF_X3_GP  : data_b = reg_x3_gp;
        `RF_X4_TP  : data_b = reg_x4_tp;
        `RF_X5_T0  : data_b = reg_x5_t0;
        `RF_X6_T1  : data_b = reg_x6_t1;
        `RF_X7_T2  : data_b = reg_x7_t2;
        `RF_X8_S0  : data_b = reg_x8_s0;
        `RF_X9_S1  : data_b = reg_x9_s1;
        `RF_X10_A0 : data_b = reg_x10_a0;
        `RF_X11_A1 : data_b = reg_x11_a1;
        `RF_X12_A2 : data_b = reg_x12_a2;
        `RF_X13_A3 : data_b = reg_x13_a3;
        `RF_X14_A4 : data_b = reg_x14_a4;
        `RF_X15_A5 : data_b = reg_x15_a5;
        `RF_X16_A6 : data_b = reg_x16_a6;
        `RF_X17_A7 : data_b = reg_x17_a7;
        `RF_X18_S2 : data_b = reg_x18_s2;
        `RF_X19_S3 : data_b = reg_x19_s3;
        `RF_X20_S4 : data_b = reg_x20_s4;
        `RF_X21_S5 : data_b = reg_x21_s5;
        `RF_X22_S6 : data_b = reg_x22_s6;
        `RF_X23_S7 : data_b = reg_x23_s7;
        `RF_X24_S8 : data_b = reg_x24_s8;
        `RF_X25_S9 : data_b = reg_x25_s9;
        `RF_X26_S10: data_b = reg_x26_s10;
        `RF_X27_S11: data_b = reg_x27_s11;
        `RF_X28_T3 : data_b = reg_x28_t3;
        `RF_X29_T4 : data_b = reg_x29_t4;
        `RF_X30_T5 : data_b = reg_x30_t5;
        `RF_X31_T6 : data_b = reg_x31_t6;
        default:     data_b = 32'h00000000;
    endcase
end

endmodule
