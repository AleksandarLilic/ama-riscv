`include "ama_riscv_defines.svh"

module ama_riscv_bp #(
    parameter unsigned PC_BITS = 5,
    parameter unsigned CNT_BITS = 3,
    parameter unsigned GHR_BITS = 5,
    parameter bp_t BP_TYPE_SEL = BP_BIMODAL
)(
    input  logic clk,
    input  logic rst,
    input  bp_pipe_t pipe_in,
    /* verilator lint_off UNUSEDSIGNAL */
    input  bp_comp_t bp_comp_pred, // component predictors, only for combined
    /* verilator lint_on UNUSEDSIGNAL */
    output branch_t pred
);

//------------------------------------------------------------------------------
// params
localparam unsigned IDX_BITS =
    ((BP_TYPE_SEL == BP_BIMODAL) || (BP_TYPE_SEL == BP_COMBINED)) ? PC_BITS :
    (BP_TYPE_SEL == BP_GLOBAL) ? GHR_BITS :
    (BP_TYPE_SEL == BP_GSELECT) ? (GHR_BITS + PC_BITS) :
    (BP_TYPE_SEL == BP_GSHARE) ? `MAX(GHR_BITS, PC_BITS) : 'h0;
localparam unsigned CNT_MAX = ((1 << CNT_BITS) - 1);
localparam unsigned CNT_THR = (CNT_MAX == 1) ? CNT_MAX : (CNT_MAX >> 1);

//------------------------------------------------------------------------------
// PHT indexing (per BP type)
logic taken;
assign taken = (pipe_in.br_res == B_T);

// due to parametrization, pc or ghr might not be used for a given config
/* verilator lint_off UNUSEDSIGNAL */
logic [PC_BITS-1:0] pc_dec_part, pc_mem_part;
logic [GHR_BITS-1:0] ghr;
/* verilator lint_on UNUSEDSIGNAL */

assign pc_dec_part = pipe_in.pc_dec[PC_BITS-1:0];
assign pc_mem_part = pipe_in.pc_mem[PC_BITS-1:0];

always_ff @(posedge clk) begin
    if (rst) ghr <= 'h0;
    else if (pipe_in.spec.resolve) ghr <= {ghr[GHR_BITS-2:0], taken};
end

logic [IDX_BITS-1:0] pht_idx, pht_idx_up;
if ((BP_TYPE_SEL == BP_BIMODAL) || (BP_TYPE_SEL == BP_COMBINED))
begin: gen_bimodal_idx
assign pht_idx = pc_dec_part;
assign pht_idx_up = pc_mem_part;
end

if (BP_TYPE_SEL == BP_GLOBAL) begin: gen_global_idx
assign pht_idx = ghr;
assign pht_idx_up = ghr; // ghr updated in the same clk as pht

/*
// FIXME: perf bug
// back to back branches update late, but this adds logic on critical path
assign pht_idx = pipe_in.spec.resolve ? {ghr[GHR_BITS-2:0], taken} : ghr;
always_ff @(posedge clk) begin
    if (rst) pht_idx_up <= 'h0;
    else if (pipe_in.spec.enter) pht_idx_up <= pht_idx;
end
*/

end

if (BP_TYPE_SEL == BP_GSELECT) begin: gen_gselect_idx
assign pht_idx = {pc_dec_part, ghr};
assign pht_idx_up = {pc_mem_part, ghr};
end

if (BP_TYPE_SEL == BP_GSHARE) begin: gen_gshare_idx
localparam GHR_OFF = (PC_BITS > GHR_BITS) ? (PC_BITS - GHR_BITS) : 0;
assign pht_idx = (pc_dec_part ^ (ghr << GHR_OFF));
assign pht_idx_up = (pc_mem_part ^ (ghr << GHR_OFF));
end

//------------------------------------------------------------------------------
// PHT structure & update
logic [CNT_BITS-1:0] inc, dec;
logic [CNT_BITS-1:0] pht_read, pht_read_up, pht_update_val;
logic pht_update_en;

ama_riscv_pht #(
    .IDX_BITS (IDX_BITS),
    .CNT_BITS (CNT_BITS),
    .CNT_THR (CNT_THR)
) ama_riscv_pht_i(
    .clk (clk),
    .rst (rst),
    // inputs
    .idx (pht_idx),
    .idx_up (pht_idx_up),
    .update_en (pht_update_en),
    .update_val (pht_update_val),
    // outputs
    .read (pht_read),
    .read_up (pht_read_up)
);

if (CNT_BITS == 1) begin: gen_cnt_toggle_id
assign inc = (!pht_read_up); // inc if 0
assign dec = pht_read_up; // dec if 1
end else begin: gen_cnt_wide_id
assign inc = {{CNT_BITS-1{1'b0}}, (pht_read_up != CNT_MAX)};
assign dec = {{CNT_BITS-1{1'b0}}, (pht_read_up != 'h0)};
end

if (BP_TYPE_SEL != BP_COMBINED) begin: gen_pht_up

assign pht_update_val = taken ? (pht_read_up + inc) : (pht_read_up - dec);
assign pht_update_en = pipe_in.spec.resolve;
assign pred = branch_t'(pht_read >= CNT_THR);

end else begin: gen_pht_up_comb

bp_comp_t pred_made;
always_ff @(posedge clk) begin
    if (rst) pred_made <= '{B_NT, B_NT};
    else if (pipe_in.spec.enter) pred_made <= bp_comp_pred;
    else if (pipe_in.spec.resolve) pred_made <= '{B_NT, B_NT};
end

logic bp_comp_1_hit, bp_comp_diff;
assign bp_comp_1_hit = (pred_made.bp_1_p == pipe_in.br_res);
assign bp_comp_diff = (pred_made.bp_1_p != pred_made.bp_2_p);
// inc on bp1 hit, dec on bp2 hit, no change if both predict the same
assign pht_update_val = bp_comp_1_hit ? (pht_read_up+inc) : (pht_read_up-dec);
assign pht_update_en = (pipe_in.spec.resolve && bp_comp_diff);

logic meta;
assign meta = (pht_read >= CNT_THR);
assign pred = meta ? bp_comp_pred.bp_1_p : bp_comp_pred.bp_2_p;

end

endmodule
