`include "ama_riscv_defines.svh"

module ama_riscv_bp #(
    parameter unsigned PC_BITS = 5,
    parameter unsigned CNT_BITS = 3
)(
    input  logic clk,
    input  logic rst,
    input  bp_t  pipe_in,
    output branch_t pred
);

localparam unsigned CNT_MAX = (2**CNT_BITS) - 1;
localparam unsigned CNT_THR = (CNT_MAX >> 1);
localparam unsigned CNT_INIT = (CNT_THR + 1); // weakly taken bias
localparam unsigned CNT_ENTRIES = 2**PC_BITS;

logic [PC_BITS-1:0] cnt_idx, cnt_idx_up;
logic [CNT_BITS-1:0] cnt [CNT_ENTRIES];

assign cnt_idx = pipe_in.pc_dec[PC_BITS-1:0];
assign cnt_idx_up = pipe_in.pc_exe[PC_BITS-1:0];

always_ff @(posedge clk) begin
    if (rst) begin
        for (int unsigned c = 0; c < CNT_ENTRIES; c++) cnt[c] <= CNT_INIT;
    end else if (pipe_in.spec.resolve) begin
        if (pipe_in.br_res == B_T) begin
            cnt[cnt_idx_up] <= cnt[cnt_idx_up] + (cnt[cnt_idx_up] != CNT_MAX);
        end else begin
            cnt[cnt_idx_up] <= cnt[cnt_idx_up] - (cnt[cnt_idx_up] != 'h0);
        end
    end
end

assign pred = branch_t'(cnt[cnt_idx] > CNT_THR);

endmodule
