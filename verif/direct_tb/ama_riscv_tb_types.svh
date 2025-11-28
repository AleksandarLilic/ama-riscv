`ifndef AMA_RISCV_TB_TYPES
`define AMA_RISCV_TB_TYPES

`include "ama_riscv_defines.svh"

typedef enum int {
    LOG_NONE = 0,
    LOG_ERROR = 1,
    LOG_WARN = 2,
    LOG_INFO = 3,
    LOG_VERBOSE = 4,
    LOG_DEBUG = 5
} log_level_e;

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

typedef struct {
    string test_path;
    bit tohost_chk_en;
    bit cosim_en;
    bit cosim_chk_en;
    bit stop_on_cosim_error;
    int unsigned timeout_clocks;
    int unsigned log_level;
    int unsigned prof_pc_start;
    int unsigned prof_pc_stop;
    int unsigned prof_pc_single_match;
    bit prof_trace;
    bit log_isa_sim;
} plusargs_t;

// cosim
localparam int SLEN = 32; // number of characters in the string

typedef struct {
    int unsigned pc;
    int unsigned inst;
    int unsigned tohost;
    int unsigned rf[RF_NUM];
    logic [8*SLEN-1:0] stack_top_str_wave;
    logic [8*SLEN-1:0] inst_asm_str_wave;
} cosim_t;

typedef struct {
    string inst_asm;
    string stack_top;
} cosim_str_t;

typedef struct {
    longint unsigned mtime;
    longint unsigned mhpmcounter[MHPMCOUNTERS+MHPM_OFFSET];
} csr_sync_t;

// profiling from isa sim
// enum class hw_status_t { miss, hit, none };
typedef enum logic [1:0] {
    hw_status_t_miss = 2'b00,
    hw_status_t_hit = 2'b01,
    hw_status_t_none = 2'b10
} hw_status_t;

// perf
typedef struct {
    byte aref = 'h0; // because 'ref' is a keyword
    byte hit = 'h0;
    byte miss = 'h0;
    byte wb = 'h0; // writeback (only caches)
    byte load = 'h0; // access type load (only caches)
    byte size = 'h0; // number of bytes (only caches)
    // byte handle_pending_req = 'h0;
    byte hm = 'h0;
} hw_events_t;

typedef struct {
    int unsigned aref = 'h0;
    int unsigned hit = 'h0;
    int unsigned miss = 'h0;
    int unsigned wb = 'h0;
} hw_counters_t;

typedef struct {
    byte bad_spec = 'h0;
    byte fe = 'h0;
    byte fe_ic = 'h0;
    byte be = 'h0;
    byte be_dc = 'h0;
    byte ret_simd = 'h0;
} core_events_t;

typedef struct {
    int unsigned cycles;
    int unsigned bad_spec;
    int unsigned be;
    int unsigned be_dc;
    int unsigned be_core;
    int unsigned fe;
    int unsigned fe_ic;
    int unsigned fe_core;
    int unsigned ret_simd;
    int unsigned ret_int;
    int unsigned ret;
} core_events_counters_t;

// views
typedef struct packed {
    logic [6:0] fn7;
    rf_addr_t rs2;
    rf_addr_t rs1;
    logic [2:0] fn3;
    rf_addr_t rd;
    opc7_t opc;
} inst_r_t;

typedef struct packed {
    logic [11:0] imm;
    rf_addr_t rs1;
    logic [2:0] fn3;
    rf_addr_t rd;
    opc7_t opc;
} inst_i_t;

typedef struct packed {
    logic [11:5] imm_h;
    rf_addr_t rs2;
    rf_addr_t rs1;
    logic [2:0] fn3;
    logic [4:0] imm_l;
    opc7_t opc;
} inst_s_t;

typedef struct packed {
    logic [11:5] imm_h_unord; // unordered value, bits don't correspond to 11:5
    rf_addr_t rs2;
    rf_addr_t rs1;
    logic [2:0] fn3;
    logic [4:0] imm_l_unord;
    opc7_t opc;
} inst_b_t;

typedef struct packed {
    logic [31:12] imm_unord;
    rf_addr_t rd;
    opc7_t opc;
} inst_j_t;

typedef struct packed {
    logic [31:12] imm;
    rf_addr_t rd;
    opc7_t opc;
} inst_u_t;

typedef union packed {
    inst_width_t i;
    inst_r_t r_type;
    inst_i_t i_type;
    inst_s_t s_type;
    inst_b_t b_type;
    inst_j_t j_type;
    inst_u_t u_type;
} inst_shadow_t;

typedef struct packed {
    inst_r_t r_type;
    inst_i_t i_type;
    inst_s_t s_type;
    inst_b_t b_type;
    inst_j_t j_type;
    inst_u_t u_type;
} inst_t;

`endif // AMA_RISCV_TB_TYPES
