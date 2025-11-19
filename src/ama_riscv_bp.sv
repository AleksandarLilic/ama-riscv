`include "ama_riscv_defines.svh"

module ama_riscv_bp #(
    parameter unsigned PC_BITS = 5,
    parameter unsigned CNT_BITS = 3,
    parameter unsigned GR_BITS = 5,
    parameter bp_t BP_TYPE_SEL = BP_BIMODAL
)(
    input  logic clk,
    input  logic rst,
    input  bp_pipe_t pipe_in,
    input  bp_comp_t bp_comp_pred,
    output branch_t pred
);

localparam unsigned IDX_BITS =
    ((BP_TYPE_SEL == BP_BIMODAL) || (BP_TYPE_SEL == BP_COMBINED)) ? PC_BITS :
    (BP_TYPE_SEL == BP_GLOBAL) ? GR_BITS :
    (BP_TYPE_SEL == BP_GSELECT) ? (GR_BITS + PC_BITS) :
    (BP_TYPE_SEL == BP_GSHARE) ? `MAX(GR_BITS, PC_BITS) : 'h0;

localparam unsigned CNT_ENTRIES = 2**IDX_BITS;
localparam unsigned CNT_MAX = (2**CNT_BITS) - 1;
localparam unsigned CNT_THR = (CNT_MAX == 1) ? CNT_MAX : (CNT_MAX >> 1);

logic taken;
assign taken = (pipe_in.br_res == B_T);

logic [PC_BITS-1:0] pc_dec_part, pc_exe_part;
assign pc_dec_part = pipe_in.pc_dec[PC_BITS-1:0];
assign pc_exe_part = pipe_in.pc_exe[PC_BITS-1:0];

logic [GR_BITS-1:0] gr;
always_ff @(posedge clk) begin
    if (rst) gr <= 'h0;
    else if (pipe_in.spec.resolve) gr <= {gr[GR_BITS-2:0], taken};
end

logic [IDX_BITS-1:0] cnt_idx, cnt_idx_up;
if ((BP_TYPE_SEL == BP_BIMODAL) || (BP_TYPE_SEL == BP_COMBINED))
begin: gen_bimodal_idx
assign cnt_idx = pc_dec_part;
assign cnt_idx_up = pc_exe_part;
end

if (BP_TYPE_SEL == BP_GLOBAL) begin: gen_global_idx
assign cnt_idx = gr;
assign cnt_idx_up = gr; // gr updated in the same clk as cnt, so this is correct
end

if (BP_TYPE_SEL == BP_GSELECT) begin: gen_gselect_idx
assign cnt_idx = {pc_dec_part, gr};
assign cnt_idx_up = {pc_exe_part, gr};
end

if (BP_TYPE_SEL == BP_GSHARE) begin: gen_gshare_idx
localparam GR_OFF = PC_BITS > GR_BITS ? PC_BITS - GR_BITS : 0;
assign cnt_idx = (pc_dec_part ^ (gr << GR_OFF));
assign cnt_idx_up = (pc_exe_part ^ (gr << GR_OFF));
end

logic [CNT_BITS-1:0] cnt [CNT_ENTRIES];
logic [CNT_BITS-1:0] inc, dec;

if (CNT_BITS == 1) begin: gen_cnt_toggle_id
assign inc = (cnt[cnt_idx_up] != 'h1);
assign dec = (cnt[cnt_idx_up] != 'h0);
end else begin: gen_cnt_wide_id
assign inc = {{CNT_BITS-1{1'b0}}, cnt[cnt_idx_up] != CNT_MAX};
assign dec = {{CNT_BITS-1{1'b0}}, cnt[cnt_idx_up] != 'h0};
end

if (BP_TYPE_SEL != BP_COMBINED) begin: gen_cnt_up_1

always_ff @(posedge clk) begin
    if (rst) begin
        // initialize to weakly taken
        /* verilator lint_off WIDTHTRUNC */
        `IT_P(c, CNT_ENTRIES) cnt[c] <= CNT_THR;
        /* verilator lint_on WIDTHTRUNC */
    end else if (pipe_in.spec.resolve) begin
        if (taken) cnt[cnt_idx_up] <= cnt[cnt_idx_up] + inc;
        else cnt[cnt_idx_up] <= cnt[cnt_idx_up] - dec;
    end
end
/* verilator lint_off WIDTHEXPAND */
assign pred = branch_t'(cnt[cnt_idx] >= CNT_THR);
/* verilator lint_on WIDTHEXPAND */

end else begin: gen_cnt_up_comb

bp_comp_t pred_made;
always_ff @(posedge clk) begin
    if (rst) pred_made <= '{B_NT, B_NT};
    else if (pipe_in.spec.enter) pred_made <= bp_comp_pred;
    // TODO: no need to clear?
end

logic bp_comp_diff, bp_1_hit;
assign bp_comp_diff = (pred_made.bp_1_p != pred_made.bp_2_p);
assign bp_1_hit = (pred_made.bp_1_p == pipe_in.br_res);

// inc on bp1 hit, dec on bp2 hit, no change if both predict the same
always_ff @(posedge clk) begin
    if (rst) begin
        // initialize to slight bp1 prediction bias
        /* verilator lint_off WIDTHTRUNC */
        `IT_P(c, CNT_ENTRIES) cnt[c] <= CNT_THR;
        /* verilator lint_on WIDTHTRUNC */
    end else if (pipe_in.spec.resolve) begin
        if (bp_comp_diff) begin
            if (bp_1_hit) cnt[cnt_idx_up] <= cnt[cnt_idx_up] + inc;
            else cnt[cnt_idx_up] <= cnt[cnt_idx_up] - dec;
        end
    end
end

logic meta;
/* verilator lint_off WIDTHEXPAND */
assign meta = (cnt[cnt_idx] >= CNT_THR);
/* verilator lint_on WIDTHEXPAND */
assign pred = meta ? bp_comp_pred.bp_1_p : bp_comp_pred.bp_2_p;

end

endmodule
