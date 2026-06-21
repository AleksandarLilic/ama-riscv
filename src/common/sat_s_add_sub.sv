`include "ama_riscv_defines.svh"

module sat_s_add_sub #(
    parameter unsigned W_OUT = 8 // data out width
)(
    input  logic [W_OUT:0] a, // W_OUT result bits + 1 sign guard bit
    output logic [W_OUT-1:0] q
);

// overflow when guard bit isn't a faithful sign-extension of the output MSB
logic ovf;
assign ovf = (a[W_OUT] ^ a[W_OUT-1]);

// saturate toward the true sign a[W_OUT]:
// a[W_OUT]=0 -> +max = 0_11..1 (e.g. 0x7F / +127)
// a[W_OUT]=1 -> -min = 1_00..0 (e.g. 0x80 / -128)
assign q = ovf ? {a[W_OUT], {(W_OUT-1){~a[W_OUT]}}} : a[W_OUT-1:0];

endmodule
