`ifndef AMA_RISCV_DEFINES
`define AMA_RISCV_DEFINES

// Memory map
`define RESET_VECTOR 32'h4_0000
`define DMEM_RANGE 2'b00
`define MMIO_RANGE 2'b01

// Opcodes
typedef enum logic [6:0] {
    OPC7_R_TYPE = 7'b011_0011,
    OPC7_I_TYPE = 7'b001_0011,
    OPC7_LOAD = 7'b000_0011,
    OPC7_STORE = 7'b010_0011,
    OPC7_BRANCH = 7'b110_0011,
    OPC7_JALR = 7'b110_0111,
    OPC7_JAL = 7'b110_1111,
    OPC7_LUI = 7'b011_0111,
    OPC7_AUIPC = 7'b001_0111,
    OPC7_SYSTEM = 7'b111_0011
} opc7_t;

// NOP inst
`define NOP 32'h13 // addi x0 x0 0

// CSR addresses
`define CSR_TOHOST 12'h51E
`define CSR_MSCRATCH 12'h340

`define CSR_OP_SEL_ASSIGN 2'b01
`define CSR_OP_SEL_SET_BITS 2'b10
`define CSR_OP_SEL_CLR_BITS 2'b11

// MUX select signals
// PC select
typedef enum logic[1:0] {
    PC_SEL_INC4 = 2'd0, // PC = PC + 4
    PC_SEL_ALU = 2'd1, // ALU output, used for jump/branch
    PC_SEL_BP = 2'd2, // PC = Branch prediction output
    PC_SEL_PC = 2'd3 // PC = Hardwired start address
} pc_sel_t;

// ALU A operand select
`define ALU_A_SEL_RS1 1'd0 // A = Reg[rs1]
`define ALU_A_SEL_PC 1'd1 // A = PC
`define ALU_A_SEL_FWD_ALU 2'd2 // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_RS2 1'd0 // B = Reg[rs2]
`define ALU_B_SEL_IMM 1'd1 // B = Immediate value; from Imm Gen
`define ALU_B_SEL_FWD_ALU 2'd2 // B = ALU; forwarding from MEM stage

// Write back select
`define WB_SEL_DMEM 2'd0 // Reg[rd] = DMEM[ALU]
`define WB_SEL_ALU 2'd1 // Reg[rd] = ALU
`define WB_SEL_INC4 2'd2 // Reg[rd] = PC + 4
`define WB_SEL_CSR 2'd3 // Reg[rd] = CSR data

// Branch Resolution
`define BR_SEL_BEQ 2'd0 // Branch Equal
`define BR_SEL_BNE 2'd1 // Branch Not Equal
`define BR_SEL_BLT 2'd2 // Branch Less Than
`define BR_SEL_BGE 2'd3 // Branch Greater Than

// Register File
`define RF_X0_ZERO 5'd0 // hard-wired zero
`define RF_X1_RA 5'd1 // return address
`define RF_X2_SP 5'd2 // stack pointer
`define RF_X3_GP 5'd3 // global pointer
`define RF_X4_TP 5'd4 // thread pointer
`define RF_X5_T0 5'd5 // temporary/alternate link register
`define RF_X6_T1 5'd6 // temporary
`define RF_X7_T2 5'd7 // temporary
`define RF_X8_S0 5'd8 // saved register/frame pointer
`define RF_X9_S1 5'd9 // saved register
`define RF_X10_A0 5'd10 // function argument/return value
`define RF_X11_A1 5'd11 // function argument/return value
`define RF_X12_A2 5'd12 // function argument
`define RF_X13_A3 5'd13 // function argument
`define RF_X14_A4 5'd14 // function argument
`define RF_X15_A5 5'd15 // function argument
`define RF_X16_A6 5'd16 // function argument
`define RF_X17_A7 5'd17 // function argument
`define RF_X18_S2 5'd18 // saved register
`define RF_X19_S3 5'd19 // saved register
`define RF_X20_S4 5'd20 // saved register
`define RF_X21_S5 5'd21 // saved register
`define RF_X22_S6 5'd22 // saved register
`define RF_X23_S7 5'd23 // saved register
`define RF_X24_S8 5'd24 // saved register
`define RF_X25_S9 5'd25 // saved register
`define RF_X26_S10 5'd26 // saved register
`define RF_X27_S11 5'd27 // saved register
`define RF_X28_T3 5'd28 // temporary
`define RF_X29_T4 5'd29 // temporary
`define RF_X30_T5 5'd30 // temporary
`define RF_X31_T6 5'd31 // temporary

// DMEM access
typedef enum logic [2:0] {
    DMEM_DTYPE_BYTE = 3'b000,
    DMEM_DTYPE_HALF = 3'b001,
    DMEM_DTYPE_WORD = 3'b010,
    DMEM_DTYPE_UBYTE = 3'b100,
    DMEM_DTYPE_UHALF = 3'b101
} dmem_dtype_t;

// DMEM Offset
`define DMEM_BYTE_OFF_0  2'd0
`define DMEM_BYTE_OFF_1  2'd1
`define DMEM_BYTE_OFF_2  2'd2
`define DMEM_BYTE_OFF_3  2'd3

// ALU
typedef enum logic [3:0] {
    ALU_OP_ADD = 4'b0000,
    ALU_OP_SUB = 4'b1000,
    ALU_OP_SLL = 4'b0001,
    ALU_OP_SRL = 4'b0101,
    ALU_OP_SRA = 4'b1101,
    ALU_OP_SLT = 4'b0010,
    ALU_OP_SLTU = 4'b0011,
    ALU_OP_XOR = 4'b0100,
    ALU_OP_OR = 4'b0110,
    ALU_OP_AND = 4'b0111,
    ALU_OP_PASS_B = 4'b1111
} alu_op_t;

// Imm Gen
`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

// Memory parameters
// *_B - byte
// *_H - half
// *_W - word
// *_D - doubleword
// *_Q - quadword
// *_L - line (module-specific)
// no suffix - number of bits, or if otherwise specified in the parameter name (eg 'offset')

parameter unsigned MEM_SIZE_W = 16384; // words, 64KB
parameter unsigned CORE_ADDR_BUS_W = $clog2(MEM_SIZE_W); // 14
parameter unsigned CORE_ADDR_BUS_B = CORE_ADDR_BUS_W + 2; // 16
parameter unsigned CORE_DATA_BUS = 32;

`ifdef IMEM_DELAY
`define IMEM_DELAY_CLK 2
`else
`define IMEM_DELAY_CLK 1
`endif

// interfaces
/* verilator lint_off DECLFILENAME */
// generic rv interface
interface rv_if #(parameter DW = 32) (/* input logic clk */);
    //localparam unsigned W = DW;
    logic valid;
    logic ready;
    logic [DW-1:0] data;
    modport TX (output valid, output data, input  ready); // producer
    modport RX (input  valid, input  data, output ready); // consumer
endinterface

// rv interface with data and address (da) bus
interface rv_if_da #(parameter AW = 32, parameter DW = 32) ();
    //localparam unsigned W = DW;
    logic valid;
    logic ready;
    logic [AW-1:0] addr;
    logic [DW-1:0] wdata;
    modport TX (output valid, output addr, output wdata, input  ready); // prod
    modport RX (input  valid, input  addr, input  wdata, output ready); // cons
endinterface

interface pipeline_if #(parameter unsigned W = 32);
    typedef struct packed {
        logic [W-1:0] fet;
        logic [W-1:0] dec;
        logic [W-1:0] exe;
        logic [W-1:0] mem;
        logic [W-1:0] wbk;
    } pipeline_t;

    pipeline_t p;

    modport IN (input p);
    modport OUT (output p);

endinterface
/* verilator lint_on DECLFILENAME */

typedef struct packed {
    logic en;
    logic we;
    logic ui;
    logic [1:0] op_sel;
} csr_ctrl_t;

// DFF macros
`define DFF_CI_RI_RVI_CLR_CLRVI(_clr, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else if (_clr) _q <= 'h0; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RV_CLR_CLRVI(_rstv, _clr, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else if (_clr) _q <= _rstv; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RVI_CLR_CLRVI_EN(_clr, _en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else if (_clr) _q <= 'h0; \
        else if (_en) _q <= _d; \
    end

`define DFF_CI_RI_RV_CLR_CLRVI_EN(_rstv, _clr, _en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else if (_clr) _q <= _rstv; \
        else if (_en) _q <= _d; \
    end

`define STAGE(_clr, _d, _q) \
    `DFF_CI_RI_RVI_CLR_CLRVI(_clr, _d, _q)

`define STAGE_EN(_clr, _en, _d, _q) \
    `DFF_CI_RI_RVI_CLR_CLRVI_EN(_clr, _en, _d, _q)

// explicit reset value for enum types
// _rstv moved to middle to align visually with STAGE_EN macro
`define STAGE_RV(_clr, _rstv, _d, _q) \
    `DFF_CI_RI_RV_CLR_CLRVI(_rstv, _clr, _d, _q)

`define STAGE_EN_RV(_clr, _en, _rstv, _d, _q) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN(_rstv, _clr, _en, _d, _q)

`define DFF_CI_RI_RV(_rstv, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RVI(_d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RVI_EN(en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else if (en) _q <= _d; \
    end

`define DFF_CI_EN(en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (en) _q <= _d; \
    end

`define DFF_CI_RI_RV_EN(_rstv, en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else if (en) _q <= _d; \
    end

`endif // AMA_RISCV_DEFINES
