`ifndef AMA_RISCV_TB_DEFINES
`define AMA_RISCV_TB_DEFINES

`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_types.svh"

`define LOG_UART
`define UART_SHORTCUT

`define CLK_HALF_PERIOD 5 // ns
parameter unsigned CLK_PERIOD = (`CLK_HALF_PERIOD * 2);
parameter unsigned CLOCK_FREQ = (1_000 / CLK_PERIOD) * 1_000_000; // Hz

// TB
`define TOHOST_PASS 32'd1
`define DEFAULT_TIMEOUT_CLOCKS 5_000_000
`define RST_PULSES 2
`define CHK_ACT 1'b1

// path defines
`define TB ama_riscv_tb

`define DUT DUT_ama_riscv_top_i
`define TOP `DUT

`define CORE_TOP `TOP.ama_riscv_core_top_i
`define CORE `CORE_TOP.ama_riscv_core_i
`define CORE_VIEW `CORE.ama_riscv_core_view_i
`define DEC `CORE.ama_riscv_decoder_i
`define FE_CTRL `CORE.ama_riscv_fe_ctrl_i
`define RF `CORE.ama_riscv_reg_file_i
`define ALU `CORE.ama_riscv_alu_i
`define CSR `CORE.ama_riscv_csr_i

`define ICACHE `CORE_TOP.ama_riscv_icache_i
`define DCACHE `CORE_TOP.ama_riscv_dcache_i
`define MEM `TOP.ama_riscv_mem_i
`define MEM_ARRAY `MEM.mem

//`define LOG_V(x) $fwrite(log_fd, "%0t: %0s\n", $time, x)
//`define LOGNT(x) $fwrite(log_fd, "%0s\n", x)

`define LOG(x) $display("%12t: %0s", $time, x)
`define LOGNT(x) $display("%0s", x)

`define LOGNT_W(x, w) \
    `TB.warnings += w; \
    if (`TB.args.log_level >= LOG_WARN) `LOGNT($sformatf("WARNING: %0s", x))

`define LOG_E(x, e) \
    `TB.errors += e; \
    if (`TB.args.log_level >= LOG_ERROR) `LOG($sformatf("ERROR: %0s", x))

`define LOG_W(x, w) \
    `TB.warnings += w; \
    if (`TB.args.log_level >= LOG_WARN) `LOG($sformatf("WARNING: %0s", x))

`define LOG_I(x) \
    if (`TB.args.log_level >= LOG_INFO) `LOG($sformatf("INFO: %0s", x))

`define LOG_V(x) \
    if (`TB.args.log_level >= LOG_VERBOSE) `LOG($sformatf("VERBOSE: %0s", x))

`define LOG_D(x) \
    if (`TB.args.log_level >= LOG_DEBUG) `LOG($sformatf("DEBUG: %0s", x))

`endif // AMA_RISCV_TB_DEFINES
