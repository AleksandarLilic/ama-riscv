`include "ama_riscv_defines.svh"

module ama_riscv_simd_lane_wrapup #(
    parameter unsigned W = 8 // bits
)(
    /* verilator lint_off UNUSEDSIGNAL */
    input  simd_arith_op_t op_d, // op[1] (width bit) not used
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [W-1:0] a_lane,
    input  logic [W-1:0] b_lane,
    input  logic [2*W-1:0] t0,
    input  logic [2*W-1:0] t1,
    input  logic [2*W-1:0] corr,
    output logic [2*W-1:0] y // wmul: full 2W; narrow ops: result in [W-1:0]
);

if (W != 8 && W != 16) begin: check_width
    $error("simd_lane_wrapup: supports only 8 and 16-bit width");
end

//------------------------------------------------------------------------------
// decode op class
// controls (op_d = {fn7[3:0], fn3}; fn3 = {op, width, uns})
logic [3:0] op_class;
assign op_class = op_d[6:3];

logic is_mul, is_wmul, is_addsub, is_qaddsub, is_compare;
assign is_mul = (op_class == SIMD_ARITH_CLASS_MUL);
assign is_wmul = (op_class == SIMD_ARITH_CLASS_WMUL);
assign is_addsub = (op_class == SIMD_ARITH_CLASS_ADDSUB);
assign is_qaddsub = (op_class == SIMD_ARITH_CLASS_QADDSUB);
assign is_compare = (op_class == SIMD_ARITH_CLASS_COMPARE);

// adder consumes raw operands (vs the mul CSA taps) for these groups
logic use_operands;
assign use_operands = (is_addsub || is_qaddsub || is_compare);

logic op_uns; // fn3[0]; selects ext + saturation/compare direction
assign op_uns = op_d[0];

logic is_sub; // actual subtract (sub / qsub); fn3[2] = 1
assign is_sub = ((is_addsub || is_qaddsub) && op_d[2]);

logic adder_sub_mode; // adder in subtract mode (compare subtracts to compare)
assign adder_sub_mode = (is_sub || is_compare);

logic is_min; // compare: fn3[2] = 0 min, 1 max
assign is_min = (is_compare && !op_d[2]);

//------------------------------------------------------------------------------
// compress the two tree taps + BW correction
logic [1:0] [2*W-1:0] csa_out;
csa #(.W(2*W), .A(1)) csa_i (
    .x(t0), .y(t1), .z(corr), .ckl(1'b0), .s(csa_out[0]), .c(csa_out[1])
);

//------------------------------------------------------------------------------
// add/sub/compare front-end: extend operands to 2W (sign or zero by op_uns),
// invert b for subtract at *full* width, then share the mul final adder
logic [2*W-1:0] a_ext, b_ext, b_adder;
assign a_ext = op_uns ? {{W{1'b0}}, a_lane} : {{W{a_lane[W-1]}}, a_lane};
assign b_ext = op_uns ? {{W{1'b0}}, b_lane} : {{W{b_lane[W-1]}}, b_lane};
assign b_adder = (b_ext ^ {(2*W){adder_sub_mode}}); // ~b_ext when subtracting

logic [2*W-1:0] add_x, add_y;
logic add_cin;
assign add_x = use_operands ? a_ext : csa_out[0];
assign add_y = use_operands ? b_adder : csa_out[1];
assign add_cin = (use_operands && adder_sub_mode);

logic [2*W-1:0] sum; // mul: the 2W product; add/sub/compare: a +/- b
/* verilator lint_off PINCONNECTEMPTY */
add #(.W(2*W)) add_i (.a(add_x), .b(add_y), .ci(add_cin), .s(sum), .co());
/* verilator lint_on PINCONNECTEMPTY */

//------------------------------------------------------------------------------
// saturating add/sub: feed result + 1 guard bit (sum[W:0])
logic [W-1:0] qs_out, qu_out;
sat_s_add_sub #(.W_OUT(W)) qs_i (.a(sum[W:0]), .q(qs_out));
sat_u_add_sub #(.W_OUT(W)) qu_i (.a(sum[W:0]), .op_sub(is_sub), .q(qu_out));

logic [W-1:0] qsum;
assign qsum = (op_uns ? qu_out : qs_out);

//------------------------------------------------------------------------------
// compare: signed less-than via cmp_slt, unsigned via the borrow guard (sum[W])
// min/max returns the *raw* operand (bypasses saturation)
logic slt, cmp_lt, pick_a;
logic [W-1:0] minmax_out;
cmp_s_lt cmp_i (
    .a_sign(a_lane[W-1]), .b_sign(b_lane[W-1]), .s_sign(sum[W-1]), .lt(slt)
);
assign cmp_lt = op_uns ? sum[W] : slt;
assign pick_a = is_min ? cmp_lt : ~cmp_lt; // min: keep a if a<b; max: if a>=b
assign minmax_out = pick_a ? a_lane : b_lane;

//------------------------------------------------------------------------------
// mul(h)
logic is_mulh;
assign is_mulh = op_d[2];
logic [2*W-1:0] mul_out;
assign mul_out = is_mulh ? {{W{1'b0}}, sum[2*W-1:W]} : {{W{1'b0}}, sum[W-1:0]};

//------------------------------------------------------------------------------
// output select
always_comb begin
    y = '0;
    unique case (1'b1)
        is_wmul: y = sum;
        is_mul: y = mul_out;
        is_addsub: y = {{W{1'b0}}, sum[W-1:0]}; // wrapping add/sub
        is_qaddsub: y = {{W{1'b0}}, qsum};
        is_compare: y = {{W{1'b0}}, minmax_out};
        default: y = '0;
    endcase
end

endmodule
