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
    logic op_rem, op_uns, quot_neg, rem_neg;
    logic div_by_zero, overflow;
} setup_t;

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
} div_buf_t;

//------------------------------------------------------------------------------
// start conditions
logic in_op_rem, in_op_uns, in_a_neg, in_b_neg;
arch_width_t in_abs_a, in_abs_b;
assign {in_op_rem, in_op_uns} = op;
assign in_a_neg = (!in_op_uns && a[W-1]);
assign in_b_neg = (!in_op_uns && b[W-1]);
assign in_abs_a = in_a_neg ? (~a + 1'b1) : a;
assign in_abs_b = in_b_neg ? (~b + 1'b1) : b;

logic in_overflow;
assign in_overflow = (!in_op_uns && (a == 32'h8000_0000) && (b == {W{1'b1}}));

logic op_rem, start_a_neg, start_neg;
arch_width_t start_abs_a, start_abs_b;
setup_t setup;
assign op_rem = setup.op_rem;
assign start_a_neg = setup.rem_neg;
assign start_abs_a = setup.abs_a;
assign start_abs_b = setup.abs_b;
assign start_neg = setup.quot_neg;

// count leading zeros
logic start_clz_a_empty, start_clz_b_empty;
logic [CLZ_WIDTH-1:0] start_clz_a, start_clz_b;
lzc #(.WIDTH (W), .MODE (1'b1))
lzc_dividend_i (
    .in_i (start_abs_a), .cnt_o (start_clz_a), .empty_o (start_clz_a_empty)
);

lzc #(.WIDTH (W), .MODE (1'b1))
lzc_divisor_i (
    .in_i (start_abs_b), .cnt_o (start_clz_b), .empty_o (start_clz_b_empty)
);

logic [COUNT_WIDTH-1:0] start_clz_skip, start_iter_count;
arch_width_t start_dividend_norm;
assign start_clz_skip = {1'b0, start_clz_a};
assign start_iter_count = (COUNT_WIDTH'(W) - start_clz_skip);
assign start_dividend_norm = (start_abs_a << start_clz_skip);

//------------------------------------------------------------------------------
// special case?
logic start_div_by_zero, start_overflow, start_less_than_divisor, start_pow2;
logic [CLZ_WIDTH-1:0] start_pow2_shift;
arch_width_t start_abs_b_m1;
arch_width_t start_pow2_quot_mag, start_pow2_rem_mag;
arch_width_t start_pow2_quot, start_pow2_rem;

assign start_div_by_zero = setup.div_by_zero;
assign start_overflow = setup.overflow;
assign start_less_than_divisor = (
    !start_div_by_zero && (start_clz_a_empty || (start_abs_a < start_abs_b))
);
assign start_abs_b_m1 = (start_abs_b - 1'b1);
assign start_pow2 = (
    !start_less_than_divisor &&
    !start_clz_b_empty &&
    ((start_abs_b & start_abs_b_m1) == '0)
);
assign start_pow2_shift = (CLZ_WIDTH'(W - 1) - start_clz_b);
assign start_pow2_quot_mag = (start_abs_a >> start_pow2_shift);
assign start_pow2_rem_mag = (start_abs_a & start_abs_b_m1);
assign start_pow2_quot = start_neg ?
        (~start_pow2_quot_mag + 1'b1) : start_pow2_quot_mag;
assign start_pow2_rem = start_a_neg ?
    (~start_pow2_rem_mag + 1'b1) : start_pow2_rem_mag;

logic start_special;
assign start_special = (
    start_div_by_zero ||
    start_overflow ||
    start_less_than_divisor ||
    start_pow2
);

arch_width_t special_quot, special_rem, special_result;
always_comb begin
    special_quot = '0;
    special_rem = '0;
    priority case (1'b1)
        start_div_by_zero: begin
            special_quot = {W{1'b1}};
            special_rem = setup.a;
        end

        start_overflow: begin
            special_quot = setup.a;
            special_rem = '0;
        end

        start_less_than_divisor: begin
            special_quot = '0;
            special_rem = setup.a;
        end

        start_pow2: begin
            special_quot = start_pow2_quot;
            special_rem = start_pow2_rem;
        end

        default: begin
        end
    endcase
end
assign special_result = op_rem ? special_rem : special_quot;

//------------------------------------------------------------------------------
// common case
state_t state, nx_state;
div_state_t ds;
div_buf_t db;
logic db_valid;
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

logic start_buf_hit;
arch_width_t buf_result;
assign start_buf_hit = (
    (state == IDLE) &&
    start &&
    db_valid &&
    (a == db.a) &&
    (b == db.b) &&
    (in_op_uns == db.op_uns)
);
assign buf_result = in_op_rem ? db.rem : db.quot;

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
            if (start && !start_buf_hit) nx_state = SETUP;
        end

        SETUP: begin
            nx_state = start_special ? IDLE : ITER;
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
        db_valid <= 1'b0;
    end else if (flush) begin
    end else begin
        unique case (state)
            IDLE: begin
                if (start) begin
                    if (start_buf_hit) begin
                        // mirror the hit result into the holding register so
                        // `result` does not fall back to an older value once
                        // the combinational hit condition goes away
                        ds.result <= buf_result;
                    end else begin
                        // miss: flop the request, invalidate the old buffer
                        // entry, and let SETUP classify the operation
                        setup.a <= a;
                        setup.b <= b;
                        setup.abs_a <= in_abs_a;
                        setup.abs_b <= in_abs_b;
                        setup.op_rem <= in_op_rem;
                        setup.op_uns <= in_op_uns;
                        setup.quot_neg <= (in_a_neg ^ in_b_neg);
                        setup.rem_neg <= in_a_neg;
                        setup.div_by_zero <= (b == '0);
                        setup.overflow <= in_overflow;
                        db.a <= a;
                        db.b <= b;
                        db.op_uns <= in_op_uns;
                        db_valid <= 1'b0;
                    end
                end
            end

            SETUP: begin
                if (start_special) begin
                    // special-case completion: produce both outputs without
                    // entering the iterative datapath and repopulate the buffer
                    ds.result <= special_result;
                    db.quot <= special_quot;
                    db.rem <= special_rem;
                    db_valid <= 1'b1;
                end else begin
                    // regular divide: initialize the restoring datapath state
                    // and enter the iteration loop on the next cycle
                    ds.dividend <= start_dividend_norm;
                    ds.divisor <= start_abs_b;
                    ds.quot <= '0;
                    ds.rem <= '0;
                    ds.iter_count <= start_iter_count;
                    ds.op_rem <= op_rem;
                    ds.quot_neg <= start_neg;
                    ds.rem_neg <= start_a_neg;
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
                // commit the final quotient/remainder, then mark the buffered
                // entry as valid again for future combinational hits
                ds.result <= ds.op_rem ? rem_fixed : quot_fixed;
                db.quot <= quot_fixed;
                db.rem <= rem_fixed;
                db_valid <= 1'b1;
            end

            default: begin
                // no state updates
            end
        endcase
    end
end

// hits bypass the FSM combinationally; otherwise hold the last completed result
assign result = start_buf_hit ? buf_result : ds.result;
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
    (state == FIXUP) |-> ((ds.quot * ds.divisor + ds.rem) == start_abs_a)
);
`endif

endmodule
