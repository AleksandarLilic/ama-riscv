`ifndef AMA_RISCV_TB_DEFINES
`define AMA_RISCV_TB_DEFINES

// profiling from isa sim
// enum class hw_status_t { miss, hit, none };
typedef enum logic [1:0] {
    hw_status_t_miss = 2'b00,
    hw_status_t_hit = 2'b01,
    hw_status_t_none = 2'b10
} hw_status_t;

`endif // AMA_RISCV_TB_DEFINES
