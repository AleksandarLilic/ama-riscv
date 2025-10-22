`ifndef AMA_RISCV_TB_DEFINES
`define AMA_RISCV_TB_DEFINES

`include "ama_riscv_defines.svh"

`define LOG_UART
`define UART_SHORTCUT

`define CLK_HALF_PERIOD 5 // ns
parameter unsigned CLK_PERIOD = (`CLK_HALF_PERIOD * 2);
parameter unsigned CLOCK_FREQ = (1_000 / CLK_PERIOD) * 1_000_000; // Hz

// TB
`define TOHOST_CHECK 1'b1
`define TOHOST_PASS 32'd1
`define DEFAULT_TIMEOUT_CLOCKS 5_000_000
`define RST_PULSES 2
`define CHECKER_ACTIVE 1'b1
`define CHECKER_INACTIVE 1'b0

// path defines
`define TB ama_riscv_tb

`define DUT DUT_ama_riscv_top_i
`define TOP `DUT

`define CORE_TOP `TOP.ama_riscv_core_top_i
`define CORE `CORE_TOP.ama_riscv_core_i
`define DEC `CORE.ama_riscv_decoder_i
`define RF `CORE.ama_riscv_reg_file_i

`define ICACHE `CORE_TOP.ama_riscv_icache_i
`define DCACHE `CORE_TOP.ama_riscv_dcache_i
`define MEM `TOP.ama_riscv_mem_i
`define MEM_ARRAY `MEM.mem

`define TO_STRING(x) `"x`"

//`define LOG_V(x) $fwrite(log_fd, "%0t: %0s\n", $time, x)
//`define LOGNT(x) $fwrite(log_fd, "%0s\n", x)

int log_level;
typedef enum int {
    LOG_NONE = 0,
    LOG_ERROR = 1,
    LOG_WARN = 2,
    LOG_INFO = 3,
    LOG_VERBOSE = 4,
    LOG_DEBUG = 5
} log_level_e;

`define LOG(x) $display("%12t: %0s", $time, x)
`define LOGNT(x) $display("%0s", x)

`define LOG_E(x) \
    `TB.errors += 1; \
    if (`TB.log_level >= LOG_ERROR) `LOG($sformatf("ERROR: %0s", x))

`define LOG_W(x) \
    `TB.warnings += 1; \
    if (`TB.log_level >= LOG_WARN) `LOG($sformatf("WARNING: %0s", x))

`define LOG_I(x) \
    if (`TB.log_level >= LOG_INFO) `LOG($sformatf("INFO: %0s", x))

`define LOG_V(x) \
    if (`TB.log_level >= LOG_VERBOSE) `LOG($sformatf("VERBOSE: %0s", x))

`define LOG_D(x) \
    if (`TB.log_level >= LOG_DEBUG) `LOG($sformatf("DEBUG: %0s", x))

// tb-only types
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

// profiling from isa sim
// enum class hw_status_t { miss, hit, none };
typedef enum logic [1:0] {
    hw_status_t_miss = 2'b00,
    hw_status_t_hit = 2'b01,
    hw_status_t_none = 2'b10
} hw_status_t;

`endif // AMA_RISCV_TB_DEFINES
