`include "ama_riscv_defines.svh"

module ama_riscv_data_fmt (
    input  simd_data_fmt_op_t op,
    input  simd_data_fmt_type_t op_t,
    input  simd_t a,
    input  simd_t b,
    output simd_d_t s
);

//------------------------------------------------------------------------------
// widening op
simd_d_t wo;
always_comb begin
    wo = 'h0;
    unique case (simd_widen_op_t'(op))
        SIMD_WIDEN_OP_16: `IT(2) wo.w[i] = e_16_32(a.h[i][15], a.h[i]);
        SIMD_WIDEN_OP_16U: `IT(2) wo.w[i] = e_16_32(1'b0, a.h[i]);
        SIMD_WIDEN_OP_8: `IT(4) wo.h[i] = e_8_16(a.b[i][7], a.b[i]);
        SIMD_WIDEN_OP_8U: `IT(4) wo.h[i] = e_8_16(1'b0, a.b[i]);
        SIMD_WIDEN_OP_4: `IT(8) wo.b[i] = e_4_8(a.n[i][3], a.n[i]);
        SIMD_WIDEN_OP_4U: `IT(8) wo.b[i] = e_4_8(1'b0, a.n[i]);
        SIMD_WIDEN_OP_2: `IT(16) wo.n[i] = e_2_4(a.c[i][1], a.c[i]);
        SIMD_WIDEN_OP_2U: `IT(16) wo.n[i] = e_2_4(1'b0, a.c[i]);
    endcase
end

//------------------------------------------------------------------------------
// txp op
simd_t txp_a, txp_b;
always_comb begin
    txp_a = 'h0;
    txp_b = 'h0;
    unique case (simd_widen_op_t'(op[2:1]))
        SIMD_TXP_OP_16: begin
            txp_a.h[0] = a.h[0];
            txp_a.h[1] = b.h[0];
            txp_b.h[0] = a.h[1];
            txp_b.h[1] = b.h[1];
        end
        SIMD_TXP_OP_8: begin
            `IT(2) begin
                txp_a.b[i*2 + 0] = a.b[i*2 + 0];
                txp_a.b[i*2 + 1] = b.b[i*2 + 0];
                txp_b.b[i*2 + 0] = a.b[i*2 + 1];
                txp_b.b[i*2 + 1] = b.b[i*2 + 1];
            end
        end
        SIMD_TXP_OP_4: begin
            `IT(4) begin
                txp_a.n[i*2 + 0] = a.n[i*2 + 0];
                txp_a.n[i*2 + 1] = b.n[i*2 + 0];
                txp_b.n[i*2 + 0] = a.n[i*2 + 1];
                txp_b.n[i*2 + 1] = b.n[i*2 + 1];
            end
        end
        SIMD_TXP_OP_2: begin
            `IT(8) begin
                txp_a.c[i*2 + 0] = a.c[i*2 + 0];
                txp_a.c[i*2 + 1] = b.c[i*2 + 0];
                txp_b.c[i*2 + 0] = a.c[i*2 + 1];
                txp_b.c[i*2 + 1] = b.c[i*2 + 1];
            end
        end
    endcase
end

//------------------------------------------------------------------------------
// output
always_comb begin
    unique case (op_t)
        SIMD_DATA_FMT_TYPE_NONE: s = 'h0;
        SIMD_DATA_FMT_TYPE_WIDEN: s = wo;
        SIMD_DATA_FMT_TYPE_TXP: s = {txp_b, txp_a}; // w1 = txp_b, w0 = txp_a
    endcase
end


endmodule
