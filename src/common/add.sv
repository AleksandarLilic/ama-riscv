`include "ama_riscv_defines.svh"

module add #(
    parameter unsigned W = 8 // data witdth
)(
    input logic [W-1:0] a,
    input logic [W-1:0] b,
    input ci,
    output logic [W-1:0] s,
    output co
);

logic [W-1:0] ci_w;
assign ci_w = {{(W-1){1'b0}}, ci};

assign {co, s} = (a + b + ci_w);

endmodule
