`ifndef AMA_RISCV_FPGA_DEFINES
`define AMA_RISCV_FPGA_DEFINES

`define SYNT
`define FPGA

`ifndef CPU_TARGET_FREQ_MHZ
`define CPU_TARGET_FREQ_MHZ 50
`endif

`ifndef BOARD_ARTY_A7
`ifndef BOARD_CMOD_A7
`define BOARD_ARTY_A7 // default to arty
`endif
`endif

`endif // AMA_RISCV_FPGA_DEFINES
