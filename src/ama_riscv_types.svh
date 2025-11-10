`ifndef AMA_RISCV_TYPES
`define AMA_RISCV_TYPES

parameter unsigned ARCH_WIDTH = 32;
parameter unsigned ARCH_DOUBLE_WIDTH = ARCH_WIDTH*2;
parameter unsigned INST_WIDTH = 32;
typedef logic [ARCH_WIDTH-1:0] arch_width_t;
typedef logic [ARCH_DOUBLE_WIDTH-1:0] arch_double_width_t;
typedef logic signed [ARCH_DOUBLE_WIDTH-1:0] arch_double_width_s_t;
typedef logic [INST_WIDTH-1:0] inst_width_t;

parameter unsigned RF_NUM = 32;

// Memory parameters (what is being counted)
// no suffix - number of bits, or if specified in the parameter name eg 'offset'
// *_B - byte,       8-bit
// *_H - half,       16-bit
// *_W - word,       32-bit
// *_D - doubleword, 64-bit
// *_Q - quadword,   128-bit
// *_L - line (module-specific)

parameter unsigned MEM_SIZE_W = 16384; // words, 64KB
parameter unsigned MEM_SIZE_Q = MEM_SIZE_W >> 2;
parameter unsigned CORE_WORD_ADDR_BUS = $clog2(MEM_SIZE_W); // 14
parameter unsigned CORE_BYTE_ADDR_BUS = CORE_WORD_ADDR_BUS + 2; // 16

parameter unsigned MEM_DATA_BUS = 128;
parameter unsigned MEM_DATA_BUS_B = MEM_DATA_BUS >> 3; // 16
parameter unsigned CACHE_LINE_SIZE_B = 64;
parameter unsigned CACHE_LINE_B_MASK = CACHE_LINE_SIZE_B - 1; // 63 aka 0x3F
parameter unsigned CACHE_LINE_SIZE = CACHE_LINE_SIZE_B << 3; // 512
parameter unsigned MEM_TRANSFERS_PER_CL = CACHE_LINE_SIZE/MEM_DATA_BUS; // 4

parameter unsigned CACHE_LINE_BYTE_ADDR = $clog2(CACHE_LINE_SIZE_B); // 6
parameter unsigned CACHE_TO_MEM_OFFSET = $clog2(MEM_DATA_BUS_B); // 4 bits less -> 128 (mem) vs 32 bits ($)
parameter unsigned MEM_ADDR_BUS = CORE_BYTE_ADDR_BUS - CACHE_TO_MEM_OFFSET; // 16 - 4 = 12

parameter unsigned ICACHE_SETS = 4;
parameter unsigned ICACHE_WAYS = 2;
parameter unsigned DCACHE_SETS = 8;
parameter unsigned DCACHE_WAYS = 2;

// Core enums
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

typedef enum logic [1:0] {
    CSR_OP_SEL_NONE = 2'b00,
    CSR_OP_SEL_ASSIGN = 2'b01,
    CSR_OP_SEL_SET_BITS = 2'b10,
    CSR_OP_SEL_CLR_BITS = 2'b11
} csr_op_sel_t;

typedef enum logic {
    B_NT = 1'b0,
    B_T = 1'b1
} branch_t;

typedef enum logic [1:0] {
    PC_SEL_PC = 2'd0, // PC
    PC_SEL_INC4 = 2'd1, // PC = PC + 4
    PC_SEL_ALU = 2'd2, // ALU output, used for jump/branch
    PC_SEL_BP = 2'd3 // PC = Branch prediction output
} pc_sel_t;

typedef enum logic [1:0] {
    ALU_A_SEL_RS1 = 2'd0, // A = Reg[rs1]
    ALU_A_SEL_PC = 2'd1, // A = PC
    ALU_A_SEL_FWD = 2'd2 // forward A from backend
} alu_a_sel_t;

typedef enum logic [1:0] {
    ALU_B_SEL_RS2 = 2'd0, // B = Reg[rs2]
    ALU_B_SEL_IMM = 2'd1, // B = Immediate value; from Imm Gen
    ALU_B_SEL_FWD = 2'd2 // forward B from backend
} alu_b_sel_t;

typedef enum logic {
    FWD_BE_EWBK = 1'b0, // early writeback
    FWD_BE_WBK = 1'b1 // writeback
} fwd_be_t;

typedef enum logic [1:0] {
    WB_SEL_DMEM = 2'd0, // Reg[rd] = DMEM[ALU]
    WB_SEL_ALU = 2'd1, // Reg[rd] = ALU
    WB_SEL_INC4 = 2'd2, // Reg[rd] = PC + 4
    WB_SEL_CSR = 2'd3 // Reg[rd] = CSR data
} wb_sel_t;

typedef enum logic [1:0] {
    BRANCH_SEL_BEQ = 2'd0, // Branch Equal
    BRANCH_SEL_BNE = 2'd1, // Branch Not Equal
    BRANCH_SEL_BLT = 2'd2, // Branch Less Than
    BRANCH_SEL_BGE = 2'd3  // Branch Greater Than
} branch_sel_t;

typedef enum logic [2:0] {
    DMEM_DTYPE_BYTE = 3'b000,
    DMEM_DTYPE_HALF = 3'b001,
    DMEM_DTYPE_WORD = 3'b010,
    DMEM_DTYPE_UBYTE = 3'b100,
    DMEM_DTYPE_UHALF = 3'b101
} dmem_dtype_t;

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

typedef enum logic [1:0] {
    MULT_OP_MUL = 2'b00,
    MULT_OP_MULH = 2'b01,
    MULT_OP_MULHSU = 2'b10,
    MULT_OP_MULHU = 2'b11
} mult_op_t;

typedef enum logic [2:0] {
    IG_DISABLED = 3'b000,
    IG_I_TYPE = 3'b001,
    IG_S_TYPE = 3'b010,
    IG_B_TYPE = 3'b011,
    IG_J_TYPE = 3'b100,
    IG_U_TYPE = 3'b101
} ig_sel_t;

typedef enum logic [4:0] {
    RF_X0_ZERO = 5'd0, // hard-wired zero
    RF_X1_RA = 5'd1, // return address
    RF_X2_SP = 5'd2, // stack pointer
    RF_X3_GP = 5'd3, // global pointer
    RF_X4_TP = 5'd4, // thread pointer
    RF_X5_T0 = 5'd5, // temporary/alternate link register
    RF_X6_T1 = 5'd6, // temporary
    RF_X7_T2 = 5'd7, // temporary
    RF_X8_S0 = 5'd8, // saved register/frame pointer
    RF_X9_S1 = 5'd9, // saved register
    RF_X10_A0 = 5'd10, // function argument/return value
    RF_X11_A1 = 5'd11, // function argument/return value
    RF_X12_A2 = 5'd12, // function argument
    RF_X13_A3 = 5'd13, // function argument
    RF_X14_A4 = 5'd14, // function argument
    RF_X15_A5 = 5'd15, // function argument
    RF_X16_A6 = 5'd16, // function argument
    RF_X17_A7 = 5'd17, // function argument
    RF_X18_S2 = 5'd18, // saved register
    RF_X19_S3 = 5'd19, // saved register
    RF_X20_S4 = 5'd20, // saved register
    RF_X21_S5 = 5'd21, // saved register
    RF_X22_S6 = 5'd22, // saved register
    RF_X23_S7 = 5'd23, // saved register
    RF_X24_S8 = 5'd24, // saved register
    RF_X25_S9 = 5'd25, // saved register
    RF_X26_S10 = 5'd26, // saved register
    RF_X27_S11 = 5'd27, // saved register
    RF_X28_T3 = 5'd28, // temporary
    RF_X29_T4 = 5'd29, // temporary
    RF_X30_T5 = 5'd30, // temporary
    RF_X31_T6 = 5'd31 // temporary
} rf_addr_t;

typedef enum logic {
    DMEM_READ = 0,
    DMEM_WRITE = 1
} dmem_rtype_t;

// Core signal bundles
typedef struct packed {
    logic en;
    logic we;
    logic ui;
    csr_op_sel_t op_sel;
} csr_ctrl_t;

typedef struct packed {
    logic mult;
    logic load;
    logic store;
    logic branch;
    logic jump;
} inst_type_t; // only types that backend cares about, add as needed

typedef struct packed {
    logic rd;
    logic rs1;
    logic rs2;
} has_reg_t;

typedef struct packed {
    pc_sel_t pc_sel;
    logic pc_we;
    logic bubble_dec;
    logic use_cp;
} fe_ctrl_t;

typedef struct packed {
    inst_type_t itype;
    has_reg_t has_reg;
    csr_ctrl_t csr_ctrl;
    alu_op_t alu_op_sel;
    mult_op_t mult_op_sel;
    alu_a_sel_t alu_a_sel;
    alu_b_sel_t alu_b_sel;
    ig_sel_t ig_sel;
    logic bc_uns;
    logic dmem_en;
    wb_sel_t wb_sel;
    logic rd_we;
} decoder_t;

typedef struct packed {
    logic enter;
    logic resolve;
    logic wrong;
} spec_exec_t; // speculative execution

typedef struct packed {
    logic flush;
    logic en;
    logic bubble;
} stage_ctrl_t; // pipeline stage control

typedef struct packed {
    logic to_dec;
    logic to_exe;
} hazard_be_t;

// branch predictor
typedef enum logic [2:0] {
    BP_STATIC,
    BP_BIMODAL,
    //BP_LOCAL,
    BP_GLOBAL,
    BP_GSELECT,
    BP_GSHARE,
    BP_COMBINED
} bp_t;

typedef enum logic [2:0] {
    BP_STATIC_AT,
    BP_STATIC_ANT,
    BP_STATIC_BTFN
} bp_static_t;

typedef struct packed {
    branch_t bp_1_p;
    branch_t bp_2_p;
} bp_comp_t;

typedef struct packed {
    arch_width_t pc_dec;
    arch_width_t pc_exe;
    spec_exec_t spec;
    branch_t br_res;
} bp_pipe_t; // pipeline signals to branch predictor

parameter bp_static_t BP_STATIC_TYPE = BP_STATIC_BTFN;
parameter bp_t BP_1_TYPE = BP_BIMODAL;
parameter unsigned BP_1_PC_BITS = 5;
parameter unsigned BP_1_CNT_BITS = 3;
parameter bp_t BP_2_TYPE = BP_GLOBAL;
parameter unsigned BP_2_GR_BITS = 9;
parameter unsigned BP_2_CNT_BITS = 1;
parameter unsigned BP_C_PC_BITS = 4;
parameter unsigned BP_C_CNT_BITS = 4;

//parameter bp_t BP_TYPE = BP_STATIC; // static
parameter bp_t BP_TYPE = BP_COMBINED; // or combined
//parameter bp_t BP_TYPE = BP_1_TYPE; // reuse bp_1 param otherwise

// common cache types
typedef union packed {
    logic [CACHE_LINE_SIZE-1:0] f; // flat view
    logic [CACHE_LINE_SIZE/MEM_DATA_BUS-1:0] [MEM_DATA_BUS-1:0] q; // mem bus
    logic [CACHE_LINE_SIZE/INST_WIDTH-1:0] [INST_WIDTH-1:0] w; // inst 32
} cache_line_data_t;

// CSRs
typedef enum logic [11:0] {
    CSR_TOHOST = 12'h51E,
    CSR_MCYCLE = 12'hB00,
    CSR_MINSTRET = 12'hB02,
    CSR_MCYCLEH = 12'hB80,
    CSR_MINSTRETH = 12'hB82,
    CSR_MSCRATCH = 12'h340,
    CSR_TIME = 12'hC01, // URO
    CSR_TIMEH = 12'hC81 // URO
} csr_addr_t;

typedef enum logic {
    CSR_LOW = 1'b0,
    CSR_HIGH = 1'b1
} csr_lh_t;

typedef union packed {
    arch_double_width_t rdw; // reg double width
    arch_width_t [1:0] r; // reg
} csr_dw_t;

typedef struct {
    arch_width_t tohost;
    csr_dw_t mcycle;
    csr_dw_t minstret;
    csr_dw_t mtime;
    arch_width_t mscratch;
} csr_t;

// peripherals
typedef struct packed {
    logic rx_valid;
    logic tx_ready;
} uart_ctrl_t;

typedef enum logic [1:0] {
    UART_CTRL = 2'd0,
    UART_RX = 2'd1,
    UART_TX = 2'd2
} uart_addr_t;

typedef enum int unsigned {
    BR_9600 = 9600,
    BR_19200 = 19200,
    BR_38400 = 38400,
    BR_57600 = 57600,
    BR_115200 = 115200,
    BR_230400 = 230400,
    BR_460800 = 460800,
    BR_576000 = 576000,
    BR_921600 = 921600
} uart_baud_rate_t;

// interfaces
/* verilator lint_off DECLFILENAME */

// generic rv interface
interface rv_if #(parameter DW = ARCH_WIDTH) (/* input logic clk */);
    logic valid;
    // some modules are always ready and don't use the signal
    /* verilator lint_off UNUSEDSIGNAL */
    logic ready;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [DW-1:0] data;
    modport TX (output valid, output data, input  ready); // producer
    modport RX (input  valid, input  data, output ready); // consumer
endinterface

// rv interface with data and address (da) bus
interface rv_if_da #(parameter AW = ARCH_WIDTH, parameter DW = ARCH_WIDTH) ();
    logic valid;
    /* verilator lint_off UNUSEDSIGNAL */
    logic ready;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [AW-1:0] addr;
    logic [DW-1:0] wdata;
    modport TX (output valid, output addr, output wdata, input  ready); // prod
    modport RX (input  valid, input  addr, input  wdata, output ready); // cons
endinterface

// rv interface for dcache
interface rv_if_dc #(parameter AW = ARCH_WIDTH, parameter DW = ARCH_WIDTH) ();
    logic valid;
    logic ready;
    dmem_rtype_t rtype;
    dmem_dtype_t dtype;
    logic [AW-1:0] addr;
    logic [DW-1:0] wdata;
    modport TX (
        output valid,
        output addr,
        output wdata,
        output dtype,
        output rtype,
        input  ready
    );
    modport RX (
        input  valid,
        input  addr,
        input  wdata,
        input  dtype,
        input  rtype,
        output ready
    );
endinterface

// not all stages will be used by every instatiation
/* verilator lint_off UNUSEDSIGNAL */

interface pipeline_if #(parameter unsigned W = ARCH_WIDTH);
    logic [W-1:0] fet, dec, exe, mem, wbk;
    modport IN (input fet, dec, exe, mem, wbk);
    modport OUT (output fet, dec, exe, mem, wbk);
endinterface

interface pipeline_if_s; // scalar version, easier on the wave, no diff to W=1
    logic fet, dec, exe, mem, wbk;
    modport IN (input fet, dec, exe, mem, wbk);
    modport OUT (output fet, dec, exe, mem, wbk);
endinterface

interface pipeline_if_typed #(parameter type T = arch_width_t);
    T fet, dec, exe, mem, wbk;
    modport IN  (input  fet, dec, exe, mem, wbk);
    modport OUT (output fet, dec, exe, mem, wbk);
endinterface

/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on DECLFILENAME */

/* verilator lint_off UNUSEDSIGNAL */

// helper build-time functions
function automatic bit is_pow2 (int x);
    return (x > 0) && ((x & (x - 1)) == 0);
endfunction

// let max(a,b) = (a > b) ? a : b; // not supported by xsim... sv-2012 was 13 yrs ago
`define MAX(a,b) (a > b) ? a : b

// helpers synthesizable
function automatic opc7_t get_opc7(input inst_width_t inst);
    get_opc7 = opc7_t'(inst[6:0]);
endfunction

function automatic logic [2:0] get_fn3(input inst_width_t inst);
    get_fn3 = inst[14:12];
endfunction

function automatic branch_sel_t get_branch_sel(input inst_width_t inst);
    get_branch_sel = branch_sel_t'({inst[14], inst[12]});
endfunction

function automatic logic [6:0] get_fn7(input inst_width_t inst);
    get_fn7 = inst[31:25];
endfunction

function automatic logic get_fn7_b5(input inst_width_t inst);
    get_fn7_b5 = inst[30];
endfunction

function automatic logic get_fn7_b0(input inst_width_t inst);
    get_fn7_b0 = inst[25];
endfunction

function automatic rf_addr_t get_rs1(input inst_width_t inst, input logic has);
    get_rs1 = rf_addr_t'(inst[19:15] & {5{has}});
endfunction

function automatic rf_addr_t get_rs2(input inst_width_t inst, input logic has);
    get_rs2 = rf_addr_t'(inst[24:20] & {5{has}});
endfunction

function automatic rf_addr_t get_rd(input inst_width_t inst, input logic has);
    get_rd = rf_addr_t'(inst[11:7] & {5{has}});
endfunction

/* verilator lint_on UNUSEDPARAM */

`endif // AMA_RISCV_TYPES
