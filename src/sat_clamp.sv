`include "ama_riscv_defines.svh"

module sat_clamp #(
    parameter unsigned W_IN = 16,
    parameter unsigned W_OUT = 8
)(
    input  logic [W_IN-1:0] a,
    input  logic u, // 1 = unsigned
    output logic [W_OUT-1:0] q
);

logic any_hi, all_hi;
assign any_hi = (|a[W_IN-1:W_OUT]);
assign all_hi = (&a[W_IN-1:W_OUT]);

logic ovf, ovf_s;
// signed ovf has to take into account one more bit
assign ovf_s = ((any_hi | a[W_OUT-1]) && !(all_hi & a[W_OUT-1]));
assign ovf = u ? any_hi : ovf_s;

logic [W_OUT-1:0] clamp_val, clamp_val_s;
// for signed, saturate toward the true sign a[W_OUT]:
// a[W_OUT]=0 -> +max = 0_11..1 (e.g. 0x7F / +127)
// a[W_OUT]=1 -> -min = 1_00..0 (e.g. 0x80 / -128)
assign clamp_val_s = {a[W_IN-1], {(W_OUT-1){~a[W_IN-1]}}};

assign clamp_val = u ? {W_OUT{1'b1}} : clamp_val_s;

assign q = ovf ? clamp_val : a[W_OUT-1:0];

endmodule
