`include "ama_riscv_defines.svh"

module ama_riscv_div (
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic flush,
    input  div_op_t op,
    input  arch_width_t a, // dividend
    input  arch_width_t b, // divisor
    output arch_width_t result,
    output logic busy
);

// params
localparam int unsigned W = ARCH_WIDTH;
localparam int unsigned COUNT_WIDTH = $clog2(W + 1);
localparam int unsigned CLZ_WIDTH = $clog2(W);

// custom types
typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ITER,
    FIXUP
} state_t;

typedef struct packed {
    arch_width_t a, b, abs_a, abs_b;
    logic op_rem, op_uns;
    logic a_neg, b_neg, quot_neg, rem_neg;
    logic div_by_zero, overflow;
} data_in_t;

typedef struct packed {
    logic [CLZ_WIDTH-1:0] cnt_a, cnt_b;
    logic empty_a, empty_b;
    logic [COUNT_WIDTH-1:0] skip, iter_count;
    arch_width_t dividend_norm;
} setup_clz_t;

typedef struct packed {
    logic div_by_zero, overflow, less_than_divisor, pow2;
    logic [CLZ_WIDTH-1:0] pow2_shift;
    arch_width_t abs_b_m1;
    arch_width_t pow2_quot_mag, pow2_rem_mag;
    arch_width_t pow2_quot, pow2_rem;
    logic start;
} setup_special_t;

typedef struct packed {
    logic subtract;
    logic [W:0] rem_shift, divisor_ext;
    arch_width_t rem_sub, rem_next, quot_next, dividend_next;
} iter_t;

typedef struct packed {
    arch_width_t result;
    arch_width_t dividend, divisor, quot, rem;
    logic [COUNT_WIDTH-1:0] iter_count;
    logic op_rem, quot_neg, rem_neg;
} div_state_t;

typedef struct packed {
    arch_width_t a, b, quot, rem;
    logic op_uns;
} div_result_cache_t;

//------------------------------------------------------------------------------
// start conditions
data_in_t in;
assign in.a = a;
assign in.b = b;
assign {in.op_rem, in.op_uns} = op;
assign in.a_neg = (!in.op_uns && a[W-1]);
assign in.b_neg = (!in.op_uns && b[W-1]);
assign in.abs_a = in.a_neg ? (~a + 1'b1) : a;
assign in.abs_b = in.b_neg ? (~b + 1'b1) : b;
assign in.quot_neg = (in.a_neg ^ in.b_neg);
assign in.rem_neg = in.a_neg;
assign in.div_by_zero = (b == '0);
assign in.overflow = (!in.op_uns && (a == 32'h8000_0000) && (b == {W{1'b1}}));

//------------------------------------------------------------------------------
// setup
data_in_t setup;
setup_clz_t setup_clz;

// count leading zeros
lzc #(.WIDTH (W), .MODE (1'b1))
lzc_dividend_i (
    .in_i (setup.abs_a), .cnt_o (setup_clz.cnt_a), .empty_o (setup_clz.empty_a)
);

lzc #(.WIDTH (W), .MODE (1'b1))
lzc_divisor_i (
    .in_i (setup.abs_b), .cnt_o (setup_clz.cnt_b), .empty_o (setup_clz.empty_b)
);

assign setup_clz.skip = {1'b0, setup_clz.cnt_a};
assign setup_clz.iter_count = (COUNT_WIDTH'(W) - setup_clz.skip);
assign setup_clz.dividend_norm = (setup.abs_a << setup_clz.skip);

//------------------------------------------------------------------------------
// special case?
setup_special_t setup_sc;

assign setup_sc.div_by_zero = setup.div_by_zero;
assign setup_sc.overflow = setup.overflow;
assign setup_sc.less_than_divisor = (
    !setup_sc.div_by_zero && (setup_clz.empty_a || (setup.abs_a < setup.abs_b))
);
assign setup_sc.abs_b_m1 = (setup.abs_b - 1'b1);
assign setup_sc.pow2 = (
    !setup_sc.less_than_divisor &&
    !setup_clz.empty_b &&
    ((setup.abs_b & setup_sc.abs_b_m1) == '0)
);
assign setup_sc.pow2_shift = (CLZ_WIDTH'(W - 1) - setup_clz.cnt_b);
assign setup_sc.pow2_quot_mag = (setup.abs_a >> setup_sc.pow2_shift);
assign setup_sc.pow2_rem_mag = (setup.abs_a & setup_sc.abs_b_m1);
assign setup_sc.pow2_quot = setup.quot_neg ?
    (~setup_sc.pow2_quot_mag + 1'b1) : setup_sc.pow2_quot_mag;
assign setup_sc.pow2_rem = setup.rem_neg ?
    (~setup_sc.pow2_rem_mag + 1'b1) : setup_sc.pow2_rem_mag;

assign setup_sc.start = (
    setup_sc.div_by_zero ||
    setup_sc.overflow ||
    setup_sc.less_than_divisor ||
    setup_sc.pow2
);

arch_width_t special_quot, special_rem, special_result;
always_comb begin
    special_quot = '0;
    special_rem = '0;
    priority case (1'b1)
        setup_sc.div_by_zero: begin
            special_quot = {W{1'b1}};
            special_rem = setup.a;
        end

        setup_sc.overflow: begin
            special_quot = setup.a;
            special_rem = '0;
        end

        setup_sc.less_than_divisor: begin
            special_quot = '0;
            special_rem = setup.a;
        end

        setup_sc.pow2: begin
            special_quot = setup_sc.pow2_quot;
            special_rem = setup_sc.pow2_rem;
        end

        default: begin
        end
    endcase
end
assign special_result = setup.op_rem ? special_rem : special_quot;

//------------------------------------------------------------------------------
// common case
state_t state, nx_state;
div_state_t ds;
iter_t iter;

assign iter.rem_shift = {ds.rem, ds.dividend[W-1]};
assign iter.divisor_ext = {1'b0, ds.divisor};
assign iter.subtract = (iter.rem_shift >= iter.divisor_ext);
assign iter.rem_sub = arch_width_t'(iter.rem_shift - iter.divisor_ext);
assign iter.rem_next = iter.subtract ? iter.rem_sub : iter.rem_shift[W-1:0];
assign iter.quot_next = {ds.quot[W-2:0], iter.subtract};
assign iter.dividend_next = {ds.dividend[W-2:0], 1'b0};

// fixup at the end
arch_width_t quot_fixed, rem_mag, rem_fixed;
assign quot_fixed = ds.quot_neg ? (~ds.quot + 1'b1) : ds.quot;
assign rem_mag = ds.rem;
assign rem_fixed = ds.rem_neg ? (~rem_mag + 1'b1) : rem_mag;

//------------------------------------------------------------------------------
// divider cache
div_result_cache_t div_cache;
logic div_cache_valid, start_div_cache_hit;

assign start_div_cache_hit = (
    (state == IDLE) &&
    start &&
    div_cache_valid &&
    (a == div_cache.a) &&
    (b == div_cache.b) &&
    (in.op_uns == div_cache.op_uns)
);

arch_width_t div_cache_result;
assign div_cache_result = in.op_rem ? div_cache.rem : div_cache.quot;

//------------------------------------------------------------------------------
// state transition
always_ff @(posedge clk) begin
    if (rst) state <= IDLE;
    else if (flush) state <= IDLE;
    else state <= nx_state;
end

// next state
always_comb begin
    nx_state = state;
    unique case (state)
        IDLE: begin
            if (start && !start_div_cache_hit) nx_state = SETUP;
        end

        SETUP: begin
            nx_state = setup_sc.start ? IDLE : ITER;
        end

        ITER: begin
            if (ds.iter_count == COUNT_WIDTH'(1)) nx_state = FIXUP;
        end

        FIXUP: begin
            nx_state = IDLE;
        end

        default: begin
            nx_state = IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        ds <= '0;
        setup <= '0;
        div_cache_valid <= 1'b0;
    end else if (flush) begin
    end else begin
        unique case (state)
            IDLE: begin
                if (start) begin
                    if (start_div_cache_hit) begin
                        // mirror the hit result into the holding register so
                        // 'result' does not fall back to an older value once
                        // the combinational hit condition goes away
                        ds.result <= div_cache_result;
                    end else begin
                        // miss: flop the request and let SETUP decide whether
                        // this is a special case or real iterative work
                        setup <= in;
                    end
                end
            end

            SETUP: begin
                if (setup_sc.start) begin
                    // special-case completion: produce the result without
                    // entering the iterative datapath; do not refill the
                    // single-entry div_cache with cheap one-cycle operations
                    ds.result <= special_result;
                end else begin
                    // regular divide: initialize the restoring datapath state,
                    // invalidate the old div_cache entry, and enter ITER next
                    ds.dividend <= setup_clz.dividend_norm;
                    ds.divisor <= setup.abs_b;
                    ds.quot <= '0;
                    ds.rem <= '0;
                    ds.iter_count <= setup_clz.iter_count;
                    ds.op_rem <= setup.op_rem;
                    ds.quot_neg <= setup.quot_neg;
                    ds.rem_neg <= setup.rem_neg;
                    div_cache.a <= setup.a;
                    div_cache.b <= setup.b;
                    div_cache.op_uns <= setup.op_uns;
                    div_cache_valid <= 1'b0;
                end
            end

            ITER: begin
                // iterate one restoring-division step
                ds.dividend <= iter.dividend_next;
                ds.quot <= iter.quot_next;
                ds.rem <= iter.rem_next;
                ds.iter_count <= (ds.iter_count - 1'b1);
            end

            FIXUP: begin
                // commit the final quotient/remainder, then mark the cached
                // entry as valid again for future combinational hits
                ds.result <= ds.op_rem ? rem_fixed : quot_fixed;
                div_cache.quot <= quot_fixed;
                div_cache.rem <= rem_fixed;
                div_cache_valid <= 1'b1;
            end

            default: begin
                // no state updates
            end
        endcase
    end
end

// hits bypass the FSM combinationally; otherwise hold the last completed result
assign result = start_div_cache_hit ? div_cache_result : ds.result;
assign busy = (!flush && (state != IDLE));

`ifndef SYNT
// during normal iteration, divisor should be nonzero
assert property (@(posedge clk) disable iff (rst)
    (state == ITER) |-> (ds.divisor != '0)
);

// iteration count should not underflow
assert property (@(posedge clk) disable iff (rst)
    (state == ITER) |-> (ds.iter_count >= 1 && ds.iter_count <= W)
);

// restoring invariant after updates
assert property (@(posedge clk) disable iff (rst)
    (state == ITER && ds.divisor != '0) |-> (ds.rem < ds.divisor)
);

// at FIXUP entry, quotient * divisor + rem == |dividend| (unsigned magnitudes)
assert property (@(posedge clk) disable iff (rst)
    (state == FIXUP) |-> ((ds.quot * ds.divisor + ds.rem) == setup.abs_a)
);
`endif

endmodule
