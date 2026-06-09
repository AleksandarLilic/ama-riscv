`include "ama_riscv_defines.svh"

module ama_riscv_simd_sat_clamp (
    input  simd_d_t a,
    input  logic [2:0] op,
    output simd_t q
);

simd_t ql[4];
// per-width generate loops over output elements
`GIT(2)  begin: gen_SC32 sat_clamp #(32,16) sc_i (.a(a.w[i]), .u(op[0]), .q(ql[0].h[i])); end
`GIT(4)  begin: gen_SC16 sat_clamp #(16, 8) sc_i (.a(a.h[i]), .u(op[0]), .q(ql[1].b[i])); end
`GIT(8)  begin: gen_SC8  sat_clamp #( 8, 4) sc_i (.a(a.b[i]), .u(op[0]), .q(ql[2].n[i])); end
`GIT(16) begin: gen_SC4  sat_clamp #( 4, 2) sc_i (.a(a.n[i]), .u(op[0]), .q(ql[3].c[i])); end

always_comb begin
    q = 'h0;
    unique case (op[2:1])
        SIMD_DATA_FMT_OP_QNARROW_32[2:1]: q = ql[0];
        SIMD_DATA_FMT_OP_QNARROW_16[2:1]: q = ql[1];
        SIMD_DATA_FMT_OP_QNARROW_8[2:1]: q = ql[2];
        SIMD_DATA_FMT_OP_QNARROW_4[2:1]: q = ql[3];
    endcase
end

endmodule
