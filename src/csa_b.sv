`include "ama_riscv_defines.svh"

module csa_b (
    input logic x,
    input logic y,
    input logic z,
    output logic s,
    output logic c
);

// if you insist
assign s = (x ^ y ^ z);
assign c = ((x & y) | (x & z) | (y & z));

// assign {c, s} = x + y + z;

endmodule
