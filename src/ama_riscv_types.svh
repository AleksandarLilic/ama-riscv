`ifndef AMA_RISCV_TYPES
`define AMA_RISCV_TYPES

parameter unsigned ARCH_WIDTH = 32;
parameter unsigned ARCH_WIDTH_H = ARCH_WIDTH/2;
parameter unsigned ARCH_WIDTH_D = ARCH_WIDTH*2;
parameter unsigned INST_WIDTH = 32;
parameter unsigned DMEM_ADDR_OFFSET_WIDTH = 12; // inst immediate bits in offset

typedef logic [ARCH_WIDTH-1:0] arch_width_t;
typedef logic [ARCH_WIDTH_D-1:0] arch_double_width_t;
typedef logic signed [ARCH_WIDTH_D-1:0] arch_double_width_s_t;
typedef logic [INST_WIDTH-1:0] inst_width_t;

typedef union packed {
    logic [ARCH_WIDTH-1:0] w; // word
    logic [1:0] [(ARCH_WIDTH/2)-1:0] h; // half
    logic [3:0] [(ARCH_WIDTH/4)-1:0] b; // byte
    logic [7:0] [(ARCH_WIDTH/8)-1:0] n; // nibble
    logic [15:0] [(ARCH_WIDTH/16)-1:0] c; // crumb
} simd_t;

typedef union packed {
    logic [ARCH_WIDTH_D-1:0] d;
    logic [1:0] [(ARCH_WIDTH_D/2)-1:0] w;
    logic [3:0] [(ARCH_WIDTH_D/4)-1:0] h;
    logic [7:0] [(ARCH_WIDTH_D/8)-1:0] b;
    logic [15:0] [(ARCH_WIDTH_D/16)-1:0] n;
    logic [31:0] [(ARCH_WIDTH_D/32)-1:0] c;
} simd_d_t;

parameter unsigned RF_NUM = 32;
parameter unsigned RF_BANKED = 1;

// Memory parameters (what is being counted)
// no suffix - number of bits, or if specified in the parameter name eg 'offset'
// *_B - byte,       8-bit
// *_H - half,       16-bit
// *_W - word,       32-bit
// *_D - doubleword, 64-bit
// *_Q - quadword,   128-bit
// *_L - line (module-specific)

/* verilator lint_off UNUSEDPARAM */
parameter unsigned MEM_SIZE_B = 65536;
parameter unsigned MEM_SIZE_W = MEM_SIZE_B >> 2;
parameter unsigned MEM_SIZE_Q = MEM_SIZE_W >> 2;
parameter unsigned CORE_WORD_ADDR_BUS = $clog2(MEM_SIZE_W); // 14
parameter unsigned CORE_BYTE_ADDR_BUS = CORE_WORD_ADDR_BUS + 2; // 16

parameter unsigned MEM_DATA_BUS = 128;
parameter unsigned MEM_DATA_BUS_B = MEM_DATA_BUS >> 3; // 16
parameter unsigned CORE_DATA_BUS_B = 4;
parameter unsigned CACHE_LINE_SIZE_B = 64;
parameter unsigned CACHE_LINE_B_MASK = CACHE_LINE_SIZE_B - 1; // 63 aka 0x3F
parameter unsigned CACHE_LINE_SIZE = CACHE_LINE_SIZE_B << 3; // 512
parameter unsigned MEM_TRANSFERS_PER_CL = CACHE_LINE_SIZE/MEM_DATA_BUS; // 4

parameter unsigned CACHE_LINE_BYTE_ADDR = $clog2(CACHE_LINE_SIZE_B); // 6
parameter unsigned CACHE_TO_MEM_OFFSET = $clog2(MEM_DATA_BUS_B); // 4 bits less -> 128 (mem) vs 32 bits ($)
parameter unsigned MEM_ADDR_BUS = CORE_BYTE_ADDR_BUS - CACHE_TO_MEM_OFFSET; // 16 - 4 = 12
/* verilator lint_on UNUSEDPARAM */

parameter unsigned ICACHE_SETS = 4;
parameter unsigned ICACHE_WAYS = 4;
parameter unsigned DCACHE_SETS = 8;
parameter unsigned DCACHE_WAYS = 4;

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
    OPC7_CUSTOM = 7'b000_1011,
    OPC7_SYSTEM = 7'b111_0011
} opc7_t;

typedef enum logic [6:0] {
    CUSTOM_ISA_FN7_SIMD_DOT = 7'h03,
    CUSTOM_ISA_FN7_SIMD_WIDEN = 7'h20
} custom_isa_fn7_t;

typedef enum logic [1:0] {
    CSR_OP_NONE = 2'b00,
    CSR_OP_RW = 2'b01, // Atomic Read/Write CSR
    CSR_OP_RS = 2'b10, // Atomic Read and Set Bits in CSR
    CSR_OP_RC = 2'b11 // Atomic Read and Clear Bits in CSR
} csr_op_t;

typedef enum logic {
    B_NT = 1'b0,
    B_T = 1'b1
} branch_t;

// PC mux
typedef enum logic [2:0] {
    PC_SEL_PC = 3'd0, // PC
    PC_SEL_INC4 = 3'd1, // PC = PC + 4
    PC_SEL_ALU = 3'd2, // ALU output, used for jalr & branch resolution
    PC_SEL_JAL_BP = 3'd3 // PC = Branch prediction PC / JAL (direct jump dest.)
} pc_sel_t;

// operand muxes in decode
typedef enum logic [1:0] {
    A_SEL_RS1 = 2'd0, // A = Reg[rs1]
    A_SEL_PC = 2'd1, // A = PC
    A_SEL_FWD = 2'd2 // forward A from backend
} a_sel_t;

typedef enum logic [1:0] {
    B_SEL_RS2 = 2'd0, // B = Reg[rs2]
    B_SEL_IMM = 2'd1, // B = Immediate value; from Imm Gen
    B_SEL_FWD = 2'd2 // forward B from backend
} b_sel_t;

// forwarding muxes
typedef enum logic [1:0] {
    FWD_BE_MEM = 2'd0, // result from mem stage
    FWD_BE_WBK = 2'd1, // from wbk
    FWD_BE_MEM_P = 2'd2, // paired from mem
    FWD_BE_WBK_P = 2'd3 // paired from wbk
} fwd_be_t;

// result muxes
typedef enum logic [2:0] {
    EWB_SEL_ALU = 3'd0,
    EWB_SEL_IMM_U = 3'd1,
    EWB_SEL_PC_INC4 = 3'd2,
    EWB_SEL_CSR = 3'd3,
    EWB_SEL_DATA_FMT = 3'd4
} ewb_sel_t;

typedef enum logic [1:0] {
    WB_SEL_EWB = 2'd0,
    WB_SEL_DMEM = 2'd1,
    WB_SEL_SIMD = 2'd2
} wb_sel_t;

// module operation muxes
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

typedef enum logic {
    DMEM_READ = 1'b0,
    DMEM_WRITE = 1'b1
} dmem_rtype_t;

typedef enum logic [4:0] {
    //               b7    b2   fn3
    // rv32i
    ALU_OP_ADD =  {1'b0, 1'b0, 3'h0},
    ALU_OP_SUB =  {1'b1, 1'b0, 3'h0},
    ALU_OP_SLL =  {1'b0, 1'b0, 3'h1},
    ALU_OP_SRL =  {1'b0, 1'b0, 3'h5},
    ALU_OP_SRA =  {1'b1, 1'b0, 3'h5},
    ALU_OP_SLT =  {1'b0, 1'b0, 3'h2},
    ALU_OP_SLTU = {1'b0, 1'b0, 3'h3},
    ALU_OP_XOR =  {1'b0, 1'b0, 3'h4},
    ALU_OP_OR =   {1'b0, 1'b0, 3'h6},
    ALU_OP_AND =  {1'b0, 1'b0, 3'h7},
    // zbb partial
    ALU_OP_MIN =  {1'b0, 1'b1, 3'h4},
    ALU_OP_MINU = {1'b0, 1'b1, 3'h5},
    ALU_OP_MAX =  {1'b0, 1'b1, 3'h6},
    ALU_OP_MAXU = {1'b0, 1'b1, 3'h7},
    ALU_OP_OFF =  {5{1'b1}}
} alu_op_t;

typedef enum logic [3:0] {
    SIMD_ARITH_OP_MUL = 4'h0,
    SIMD_ARITH_OP_MULH = 4'h1,
    SIMD_ARITH_OP_MULHSU = 4'h2,
    SIMD_ARITH_OP_MULHU = 4'h3,
    SIMD_ARITH_OP_DOT16 = (4'h8 + 4'h0),
    SIMD_ARITH_OP_DOT8 = (4'h8 + 4'h2)
    // SIMD_ARITH_OP_DOT4 = (4'h8 + 4'h4),
    // SIMD_ARITH_OP_DOT2 = (4'h8 + 4'h6),
} simd_arith_op_t;

typedef enum logic [2:0] {
    SIMD_WIDEN_OP_16 = 3'h0,
    SIMD_WIDEN_OP_16U = 3'h1,
    SIMD_WIDEN_OP_8 = 3'h2,
    SIMD_WIDEN_OP_8U = 3'h3,
    SIMD_WIDEN_OP_4 = 3'h4,
    SIMD_WIDEN_OP_4U = 3'h5,
    SIMD_WIDEN_OP_2 = 3'h6,
    SIMD_WIDEN_OP_2U = 3'h7
} simd_widen_op_t;

typedef enum logic [2:0] {
    IG_OFF = 3'd0,
    IG_I_TYPE = 3'd1,
    IG_S_TYPE = 3'd2,
    IG_B_TYPE = 3'd3,
    //IG_J_TYPE = 3'd4,
    IG_U_TYPE = 3'd5
} ig_sel_t;

// RF addresses
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

typedef struct packed {
    logic rd;
    logic rdp;
} rf_we_t;

// Core signal bundles
typedef struct packed {
    logic en;
    logic re;
    logic we;
    logic ui;
    csr_op_t op;
} csr_ctrl_t;

typedef struct packed {
    logic mult;
    logic simd_dot;
    logic simd_data_fmt;
    logic load;
    logic store;
    logic branch;
    logic jal;
    logic jalr;
} inst_type_t; // only types that backend cares about, add as needed

typedef struct packed {
    logic rd;
    logic rdp;
    logic rs1;
    logic rs2;
    logic rs3;
} has_reg_t;

typedef struct packed {
    pc_sel_t pc_sel;
    logic pc_we;
    logic bubble_dec;
    logic bubble_exe;
    logic use_cp;
} fe_ctrl_t;

typedef struct packed {
    inst_type_t itype;
    has_reg_t has_reg;
    csr_ctrl_t csr_ctrl;
    alu_op_t alu_op;
    simd_arith_op_t simd_arith_op;
    simd_widen_op_t simd_widen_op;
    a_sel_t a_sel;
    b_sel_t b_sel;
    ig_sel_t ig_sel;
    logic branch_u;
    logic dmem_en;
    ewb_sel_t ewb_sel;
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
    //logic to_dec;
    logic to_exe;
} hazard_t;

typedef struct packed {
    dmem_rtype_t rtype;
    dmem_dtype_t dtype;
    logic [CORE_BYTE_ADDR_BUS-1:0] addr;
    logic [ARCH_WIDTH-1:0] wdata;
    logic en;
} dmem_req_side_t;

typedef struct packed {
    logic bad_spec;
    logic fe;
    logic fe_ic;
    logic be;
    logic be_dc;
    logic ret_simd;
} perf_event_t;

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
    arch_width_t pc_mem;
    spec_exec_t spec;
    branch_t br_res;
} bp_pipe_t; // pipeline signals to branch predictor

parameter bp_static_t BP_STATIC_TYPE = BP_STATIC_BTFN;
parameter bp_t BP_1_TYPE = BP_BIMODAL;
parameter unsigned BP_1_PC_BITS = 5;
parameter unsigned BP_1_CNT_BITS = 3;
parameter bp_t BP_2_TYPE = BP_GLOBAL;
parameter unsigned BP_2_GHR_BITS = 9;
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

typedef union packed {
    logic [MEM_DATA_BUS-1:0] q; // mem bus
    logic [MEM_DATA_BUS/INST_WIDTH-1:0] [INST_WIDTH-1:0] w; // inst 32
} cache_line_short_data_t;

// CSRs
typedef enum logic [11:0] {
    CSR_TOHOST = 12'h51E,
    CSR_MCYCLE = 12'hB00,
    CSR_MINSTRET = 12'hB02,
    CSR_MCYCLEH = 12'hB80,
    CSR_MINSTRETH = 12'hB82,
    CSR_MSCRATCH = 12'h340,
    CSR_MHPMCOUNTER3 = 12'hB03,
    CSR_MHPMCOUNTER4 = 12'hB04,
    CSR_MHPMCOUNTER5 = 12'hB05,
    CSR_MHPMCOUNTER6 = 12'hB06,
    CSR_MHPMCOUNTER7 = 12'hB07,
    CSR_MHPMCOUNTER8 = 12'hB08,
    CSR_MHPMCOUNTER3H = 12'hB83,
    CSR_MHPMCOUNTER4H = 12'hB84,
    CSR_MHPMCOUNTER5H = 12'hB85,
    CSR_MHPMCOUNTER6H = 12'hB86,
    CSR_MHPMCOUNTER7H = 12'hB87,
    CSR_MHPMCOUNTER8H = 12'hB88,
    CSR_MHPMEVENT3 = 12'h323,
    CSR_MHPMEVENT4 = 12'h324,
    CSR_MHPMEVENT5 = 12'h325,
    CSR_MHPMEVENT6 = 12'h326,
    CSR_MHPMEVENT7 = 12'h327,
    CSR_MHPMEVENT8 = 12'h328,
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

parameter unsigned MHPM_IDX_L = 3; // index low, starts at idx 3
parameter unsigned MHPMCOUNTERS = 6;
parameter unsigned MHPMEVENTS = 6;
parameter unsigned MHPMCOUNTER_WIDTH = 48; // min 32 bits

parameter unsigned MHPMCOUNTER_PAD_WIDTH = (ARCH_WIDTH_D - MHPMCOUNTER_WIDTH);
parameter logic [MHPMCOUNTER_PAD_WIDTH-1:0] MHPMCOUNTER_PAD = 'h0;

`define MHPM_RANGE_C MHPM_IDX_L:(MHPMCOUNTERS + MHPM_IDX_L - 1)
`define MHPM_RANGE_E MHPM_IDX_L:(MHPMEVENTS + MHPM_IDX_L - 1)

// Machine Hardware Performance Monitor (MHPM) counters & events
typedef enum logic [MHPMEVENTS-1:0] {
    MHPMEVENT_NONE = 0,
    MHPMEVENT_BAD_SPEC = (1 << 0),
    MHPMEVENT_BE = (1 << 1),
    MHPMEVENT_BE_DC = (1 << 2),
    MHPMEVENT_FE = (1 << 3),
    MHPMEVENT_FE_IC = (1 << 4),
    MHPMEVENT_RET_SIMD = (1 << 5)
} mhpmevent_t;

typedef struct packed {
    logic [MHPMCOUNTER_WIDTH-1:32] hi;
    logic [31:0] lo;
} csr_mhpm_fields_t;

typedef union packed {
    logic [MHPMCOUNTER_WIDTH-1:0] r;
    csr_mhpm_fields_t f;
} csr_mhpm_t;

typedef struct {
    arch_width_t tohost;
    arch_width_t mscratch;
    csr_dw_t mcycle;
    csr_dw_t minstret;
    csr_dw_t mtime;
    mhpmevent_t mhpmevent[`MHPM_RANGE_E];
    csr_mhpm_t mhpmcounter[`MHPM_RANGE_C];
} csr_t;

// peripherals
typedef struct packed {
    logic rx_valid;
    logic tx_ready;
} uart_rv_ctrl_t;

typedef enum logic [1:0] {
    UART_CTRL = 2'd0,
    UART_RX = 2'd1,
    UART_TX = 2'd2
} uart_addr_t;

typedef struct packed {
    logic en;
    logic we;
    logic load_signed;
    uart_addr_t addr;
} uart_ctrl_t;


typedef struct packed {
    uart_ctrl_t ctrl;
    logic [7:0] send;
} uart_ch_side_t;

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
    //modport TX_RV (output valid, input  ready); // producer
    //modport RX_RV (input  valid, output ready); // consumer
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

// rv ctrl only
interface rv_ctrl_if ();
    logic valid;
    logic ready;
    modport TX (output valid, input  ready); // producer
    modport RX (input  valid, output ready); // consumer
endinterface

interface uart_if ();
    uart_ctrl_t ctrl;
    logic [7:0] send;
    logic [31:0] recv;
    modport TX (output ctrl, output send, input recv); // core
    modport RX (input ctrl, input send, output recv); // uart
endinterface

// not all stages will be used by every instatiation
/* verilator lint_off UNUSEDSIGNAL */

interface pipeline_if #(parameter unsigned W = ARCH_WIDTH);
    logic [W-1:0] fet, dec, exe, mem, wbk, ret;
    modport IN (input fet, dec, exe, mem, wbk, ret);
    modport OUT (output fet, dec, exe, mem, wbk, ret);
endinterface

interface pipeline_if_s; // scalar version, easier on the wave, no diff to W=1
    logic fet, dec, exe, mem, wbk, ret;
    modport IN (input fet, dec, exe, mem, wbk, ret);
    modport OUT (output fet, dec, exe, mem, wbk, ret);
endinterface

interface pipeline_if_typed #(parameter type T = arch_width_t);
    T fet, dec, exe, mem, wbk, ret;
    modport IN  (input  fet, dec, exe, mem, wbk, ret);
    modport OUT (output fet, dec, exe, mem, wbk, ret);
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

function automatic logic get_fn7_b0(input inst_width_t inst);
    get_fn7_b0 = inst[25];
endfunction

function automatic logic get_fn7_b2(input inst_width_t inst);
    get_fn7_b2 = inst[27];
endfunction

function automatic logic get_fn7_b5(input inst_width_t inst);
    get_fn7_b5 = inst[30];
endfunction

function automatic logic get_fn7_b6(input inst_width_t inst);
    get_fn7_b6 = inst[31];
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

function automatic rf_addr_t get_rdp (input rf_addr_t rd);
    get_rdp = rf_addr_t'((rd + 5'h1) & 5'h1f);
endfunction

function automatic logic[31:0] e_16_32(input logic sign, input logic [15:0] a);
    e_16_32 = {{16{sign}}, a};
endfunction

function automatic logic[15:0] e_8_16(input logic sign, input logic [7:0] a);
    e_8_16 = {{8{sign}}, a};
endfunction

function automatic logic[7:0] e_4_8(input logic sign, input logic [3:0] a);
    e_4_8 = {{4{sign}}, a};
endfunction

function automatic logic[3:0] e_2_4(input logic sign, input logic [1:0] a);
    e_2_4 = {{2{sign}}, a};
endfunction

/* verilator lint_on UNUSEDPARAM */

`endif // AMA_RISCV_TYPES
