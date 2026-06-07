`include "ama_riscv_defines.svh"

module sat_s_clamp #(
    parameter unsigned W_IN = 16,
    parameter unsigned W_OUT = 8
)(
    input  logic [W_IN-1:0] a,
    output logic [W_OUT-1:0] q
);

if (W_IN <= W_OUT) begin: check_width
    $error("sat_s_clamp: W_IN must be greater than W_OUT");
end

// fits in W_OUT-bit signed iff a[W_IN-1:W_OUT-1] are all identical
logic ovf_p, ovf_n, ovf;
assign ovf_p = (|a[W_IN-1:W_OUT-1]); // at least one high-part high bit
assign ovf_n = !(&a[W_IN-1:W_OUT-1]); // at least one high-part low bit
assign ovf = (ovf_p && ovf_n);

// saturate toward the true sign a[W_OUT]:
// a[W_OUT]=0 -> +max = 0_11..1 (e.g. 0x7F / +127)
// a[W_OUT]=1 -> -min = 1_00..0 (e.g. 0x80 / -128)
assign q = ovf ? {a[W_IN-1], {(W_OUT-1){~a[W_IN-1]}}} : a[W_OUT-1:0];

endmodule
