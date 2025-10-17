`ifndef AMA_RISCV_TB_DEFINES
`define AMA_RISCV_TB_DEFINES

`define DEFAULT_HALF_PERIOD 5 // ns

// TB
`define TOHOST_CHECK 1'b1
`define DEFAULT_TIMEOUT_CLOCKS 5_000_000
`define RST_PULSES 2
// per checker enable defines
`define CHECKER_ACTIVE 1'b1
`define CHECKER_INACTIVE 1'b0

// DUT define
`define DUT DUT_ama_riscv_core_top_i

// DUT core defines
`define DUT_CORE `DUT.ama_riscv_core_i
`define DUT_DEC `DUT_CORE.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF `DUT_CORE.ama_riscv_reg_file_i

// DUT memory defines
`define DUT_IC `DUT.ama_riscv_icache_i
`define DUT_DC `DUT.ama_riscv_dcache_i
`define DUT_MEM `DUT.ama_riscv_mem_i
`define DUT_MEM_ARRAY `DUT_MEM.mem

`define TOHOST_PASS 32'd1

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
    errors += 1; \
    if (ama_riscv_core_top_tb.log_level >= LOG_ERROR) \
    `LOG($sformatf("ERROR: %0s", x))

`define LOG_W(x) \
    warnings += 1; \
    if (ama_riscv_core_top_tb.log_level >= LOG_WARN) \
    `LOG($sformatf("WARNING: %0s", x))

`define LOG_I(x) \
    if (ama_riscv_core_top_tb.log_level >= LOG_INFO) \
    `LOG($sformatf("INFO: %0s", x))

`define LOG_V(x) \
    if (ama_riscv_core_top_tb.log_level >= LOG_VERBOSE) \
    `LOG($sformatf("VERBOSE: %0s", x))

`define LOG_D(x) \
    if (ama_riscv_core_top_tb.log_level >= LOG_DEBUG) \
    `LOG($sformatf("DEBUG: %0s", x))

// profiling from isa sim
// enum class hw_status_t { miss, hit, none };
typedef enum logic [1:0] {
    hw_status_t_miss = 2'b00,
    hw_status_t_hit = 2'b01,
    hw_status_t_none = 2'b10
} hw_status_t;

`endif // AMA_RISCV_TB_DEFINES
