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
//
//-----------------------------------------------------------------------------

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
    output  wire [31:0] data_a,
    output  wire [31:0] data_b
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
    if (rst_i) begin
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
    else begin
        if      (addr_d == 5'd1)  reg_r1  <= data_d;
        if      (addr_d == 5'd2)  reg_r2  <= data_d;
        if      (addr_d == 5'd3)  reg_r3  <= data_d;
        if      (addr_d == 5'd4)  reg_r4  <= data_d;
        if      (addr_d == 5'd5)  reg_r5  <= data_d;
        if      (addr_d == 5'd6)  reg_r6  <= data_d;
        if      (addr_d == 5'd7)  reg_r7  <= data_d;
        if      (addr_d == 5'd8)  reg_r8  <= data_d;
        if      (addr_d == 5'd9)  reg_r9  <= data_d;
        if      (addr_d == 5'd10) reg_r10 <= data_d;
        if      (addr_d == 5'd11) reg_r11 <= data_d;
        if      (addr_d == 5'd12) reg_r12 <= data_d;
        if      (addr_d == 5'd13) reg_r13 <= data_d;
        if      (addr_d == 5'd14) reg_r14 <= data_d;
        if      (addr_d == 5'd15) reg_r15 <= data_d;
        if      (addr_d == 5'd16) reg_r16 <= data_d;
        if      (addr_d == 5'd17) reg_r17 <= data_d;
        if      (addr_d == 5'd18) reg_r18 <= data_d;
        if      (addr_d == 5'd19) reg_r19 <= data_d;
        if      (addr_d == 5'd20) reg_r20 <= data_d;
        if      (addr_d == 5'd21) reg_r21 <= data_d;
        if      (addr_d == 5'd22) reg_r22 <= data_d;
        if      (addr_d == 5'd23) reg_r23 <= data_d;
        if      (addr_d == 5'd24) reg_r24 <= data_d;
        if      (addr_d == 5'd25) reg_r25 <= data_d;
        if      (addr_d == 5'd26) reg_r26 <= data_d;
        if      (addr_d == 5'd27) reg_r27 <= data_d;
        if      (addr_d == 5'd28) reg_r28 <= data_d;
        if      (addr_d == 5'd29) reg_r29 <= data_d;
        if      (addr_d == 5'd30) reg_r30 <= data_d;
        if      (addr_d == 5'd31) reg_r31 <= data_d;
    end
end // synchronous register write back

// asynchronous register read
always @ (*) begin
    // port A
    case (addr_a)
        5'd1:    data_a = reg_r1;
        5'd2:    data_a = reg_r2;
        5'd3:    data_a = reg_r3;
        5'd4:    data_a = reg_r4;
        5'd5:    data_a = reg_r5;
        5'd6:    data_a = reg_r6;
        5'd7:    data_a = reg_r7;
        5'd8:    data_a = reg_r8;
        5'd9:    data_a = reg_r9;
        5'd10:   data_a = reg_r10;
        5'd11:   data_a = reg_r11;
        5'd12:   data_a = reg_r12;
        5'd13:   data_a = reg_r13;
        5'd14:   data_a = reg_r14;
        5'd15:   data_a = reg_r15;
        5'd16:   data_a = reg_r16;
        5'd17:   data_a = reg_r17;
        5'd18:   data_a = reg_r18;
        5'd19:   data_a = reg_r19;
        5'd20:   data_a = reg_r20;
        5'd21:   data_a = reg_r21;
        5'd22:   data_a = reg_r22;
        5'd23:   data_a = reg_r23;
        5'd24:   data_a = reg_r24;
        5'd25:   data_a = reg_r25;
        5'd26:   data_a = reg_r26;
        5'd27:   data_a = reg_r27;
        5'd28:   data_a = reg_r28;
        5'd29:   data_a = reg_r29;
        5'd30:   data_a = reg_r30;
        5'd31:   data_a = reg_r31;
        default: data_a = 32'h00000000;
    endcase
    
    // port B
    case (addr_b)
        5'd1:    addr_b = reg_r1;
        5'd2:    addr_b = reg_r2;
        5'd3:    addr_b = reg_r3;
        5'd4:    addr_b = reg_r4;
        5'd5:    addr_b = reg_r5;
        5'd6:    addr_b = reg_r6;
        5'd7:    addr_b = reg_r7;
        5'd8:    addr_b = reg_r8;
        5'd9:    addr_b = reg_r9;
        5'd10:   addr_b = reg_r10;
        5'd11:   addr_b = reg_r11;
        5'd12:   addr_b = reg_r12;
        5'd13:   addr_b = reg_r13;
        5'd14:   addr_b = reg_r14;
        5'd15:   addr_b = reg_r15;
        5'd16:   addr_b = reg_r16;
        5'd17:   addr_b = reg_r17;
        5'd18:   addr_b = reg_r18;
        5'd19:   addr_b = reg_r19;
        5'd20:   addr_b = reg_r20;
        5'd21:   addr_b = reg_r21;
        5'd22:   addr_b = reg_r22;
        5'd23:   addr_b = reg_r23;
        5'd24:   addr_b = reg_r24;
        5'd25:   addr_b = reg_r25;
        5'd26:   addr_b = reg_r26;
        5'd27:   addr_b = reg_r27;
        5'd28:   addr_b = reg_r28;
        5'd29:   addr_b = reg_r29;
        5'd30:   addr_b = reg_r30;
        5'd31:   addr_b = reg_r31;
        default: addr_b = 32'h00000000;
    endcase
end // asynchronous register read

endmodule