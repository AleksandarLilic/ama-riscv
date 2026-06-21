`include "ama_riscv_defines.svh"

module csa #(
    parameter unsigned W = 8, // data witdth
    parameter bit A = 0, // align output
    parameter bit CKL = 0 // carry kill
)(
    input logic [W-1:0] x,
    input logic [W-1:0] y,
    input logic [W-1:0] z,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic ckl, // carry kill, active high
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [W-1:0] s,
    output logic [W-1:0] c
);

logic [W-1:0] ct;
always_comb begin
    `IT(W) {ct[i], s[i]} = (x[i] + y[i] + z[i]);
    // csa_b csa_b_i (.x (x[i]), .y (y[i]), .z (z[i]), .s (s[i]), .c (ct[i]));
end

logic [W-1:0] ctk;
if (CKL) begin: gen_carry_kill
assign ctk = (ct & {W{!ckl}});
end else begin: gen_carry_keep
assign ctk = ct;
end

if (A) begin: gen_align
assign c = (ctk << 1);
end else begin: gen_pass
assign c = ctk;
end

endmodule
