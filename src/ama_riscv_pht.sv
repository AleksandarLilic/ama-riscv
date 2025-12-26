`include "ama_riscv_defines.svh"

module ama_riscv_pht #(
    parameter unsigned IDX_BITS = 2,
    parameter unsigned CNT_BITS = 2,
    parameter unsigned CNT_THR = 1 // used for init, e.g. weakly taken
)(
    input  logic clk,
    input  logic rst,
    input  logic [IDX_BITS-1:0] idx,
    input  logic [IDX_BITS-1:0] idx_up,
    input  logic [CNT_BITS-1:0] update_val,
    input  logic update_en,
    output logic [CNT_BITS-1:0] read,
    output logic [CNT_BITS-1:0] read_up
);

localparam unsigned PHT_ENTRIES = (1 << IDX_BITS);
typedef logic [CNT_BITS-1:0] pht_e_t;

pht_e_t pht [PHT_ENTRIES];

always_ff @(posedge clk) begin
    if (rst) `IT_P(c, PHT_ENTRIES) pht[c] <= pht_e_t'(CNT_THR);
    else if (update_en) pht[idx_up] <= update_val;
end

always_comb begin
    read = pht[idx];
    read_up = pht[idx_up];
end

endmodule
