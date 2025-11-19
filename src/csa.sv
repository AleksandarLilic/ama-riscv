`include "ama_riscv_defines.svh"

module csa #(
    parameter unsigned W = 8
)(
    input logic [W-1:0] x,
    input logic [W-1:0] y,
    input logic [W-1:0] z,
    output logic [W-1:0] s,
    output logic [W-1:0] c
);

always_comb begin
    `IT(W) {c[i], s[i]} = (x[i] + y[i] + z[i]);
    // csa_b csa_b_i (.x (x[i]), .y (y[i]), .z (z[i]), .s (s[i]), .c (c[i]));
end

endmodule
