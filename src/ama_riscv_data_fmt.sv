`include "ama_riscv_defines.svh"

module ama_riscv_data_fmt (
    input  widen_op_t op,
    input  simd_t a,
    output simd_d_t s
);

always_comb begin
    s = 'h0;
    unique case (op)
        WIDEN_OP_16: `IT(2) s.w[i] = e_16_32(a.h[i][15], a.h[i]);
        WIDEN_OP_16U: `IT(2) s.w[i] = e_16_32(1'b0, a.h[i]);
        WIDEN_OP_8: `IT(4) s.h[i] = e_8_16(a.b[i][7], a.b[i]);
        WIDEN_OP_8U: `IT(4) s.h[i] = e_8_16(1'b0, a.b[i]);
        WIDEN_OP_4: `IT(8) s.b[i] = e_4_8(a.n[i][3], a.n[i]);
        WIDEN_OP_4U: `IT(8) s.b[i] = e_4_8(1'b0, a.n[i]);
        WIDEN_OP_2: `IT(16) s.n[i] = e_2_4(a.c[i][1], a.c[i]);
        WIDEN_OP_2U: `IT(16) s.n[i] = e_2_4(1'b0, a.c[i]);
    endcase
end

endmodule
