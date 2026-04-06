`include "ama_riscv_defines.svh"

module csa #(
    parameter unsigned W = 8, // data witdth
    parameter unsigned A = 0 // align output
)(
    input logic [W-1:0] x,
    input logic [W-1:0] y,
    input logic [W-1:0] z,
    output logic [W-1:0] s,
    output logic [W-1:0] c
);

if (A > 1) begin: check_csa
    $error("csa A > 1 - only 0 or 1 supported");
end

logic [W-1:0] ct;
always_comb begin
    `IT(W) {ct[i], s[i]} = (x[i] + y[i] + z[i]);
    // csa_b csa_b_i (.x (x[i]), .y (y[i]), .z (z[i]), .s (s[i]), .c (ct[i]));
end

if (A) begin: gen_align
assign c = (ct << 1);
end else begin: gen_pass
assign c = ct;
end

endmodule
