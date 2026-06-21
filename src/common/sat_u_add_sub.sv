`include "ama_riscv_defines.svh"

module sat_u_add_sub #(
    parameter unsigned W_OUT = 8 // data out width
)(
    input  logic [W_OUT:0] a, // W_OUT result bits + 1 carry/borrow guard bit
    input  logic op_sub,
    output logic [W_OUT-1:0] q
);

// a[W_OUT] -> the op's carry (add) or borrow (sub); high only on over/underflow
// {W_OUT{!op_sub}} = all-ones on add, all-zeros on sub
assign q = a[W_OUT] ? {W_OUT{!op_sub}} : a[W_OUT-1:0];

endmodule
