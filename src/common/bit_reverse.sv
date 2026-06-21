`include "ama_riscv_defines.svh"

module bit_reverse #(
    parameter unsigned W = 8
)(
    input logic [W-1:0] a,
    output logic [W-1:0] s
);

for (genvar i = 0; i < W; i++) begin : g_br
    assign s[W-1-i] = a[i];
end

endmodule
