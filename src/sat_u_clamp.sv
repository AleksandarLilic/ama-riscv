`include "ama_riscv_defines.svh"

module sat_u_clamp #(
    parameter unsigned W_IN = 16,
    parameter unsigned W_OUT = 8
)(
    input  logic [W_IN-1:0] a,
    output logic [W_OUT-1:0] q
);

if (W_IN <= W_OUT) begin: check_width
    $error("sat_u_clamp: W_IN must be greater than W_OUT");
end

// clamp-to-max, no underflow direction
logic highs;
assign highs = (|a[W_IN-1:W_OUT]);
assign q = highs ? {W_OUT{1'b1}} : a[W_OUT-1:0];

endmodule
