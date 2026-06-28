`include "ama_riscv_defines.svh"

module ama_riscv_simd_data_fmt (
    input  simd_data_fmt_op_t op,
    input  simd_t a,
    input  simd_t b,
    input  simd_t c,
    output simd_d_t s,
    output simd_d_t s_widen
);

//------------------------------------------------------------------------------
// widening op
simd_d_t wo;
always_comb begin
    wo = 'h0;
    unique case (op[2:0])
        SIMD_DATA_FMT_OP_WIDEN_16[2:0]: `IT(2) wo.w[i] = e_16_32(a.h[i][15], a.h[i]);
        SIMD_DATA_FMT_OP_WIDEN_16U[2:0]: `IT(2) wo.w[i] = e_16_32(1'b0, a.h[i]);
        SIMD_DATA_FMT_OP_WIDEN_8[2:0]: `IT(4) wo.h[i] = e_8_16(a.b[i][7], a.b[i]);
        SIMD_DATA_FMT_OP_WIDEN_8U[2:0]: `IT(4) wo.h[i] = e_8_16(1'b0, a.b[i]);
        SIMD_DATA_FMT_OP_WIDEN_4[2:0]: `IT(8) wo.b[i] = e_4_8(a.n[i][3], a.n[i]);
        SIMD_DATA_FMT_OP_WIDEN_4U[2:0]: `IT(8) wo.b[i] = e_4_8(1'b0, a.n[i]);
        SIMD_DATA_FMT_OP_WIDEN_2[2:0]: `IT(16) wo.n[i] = e_2_4(a.c[i][1], a.c[i]);
        SIMD_DATA_FMT_OP_WIDEN_2U[2:0]: `IT(16) wo.n[i] = e_2_4(1'b0, a.c[i]);
    endcase
end

assign s_widen = wo; // widen result for shifter

//------------------------------------------------------------------------------
// (q)narrowing op
simd_d_t n_in;
assign n_in = {b, a};

simd_t no;
always_comb begin
    no = 'h0;
    unique case (op[2:1])
        SIMD_DATA_FMT_OP_NARROW_32[2:1]: `IT(2) no.h[i] = t_32_16(n_in.w[i]);
        SIMD_DATA_FMT_OP_NARROW_16[2:1]: `IT(4) no.b[i] = t_16_8(n_in.h[i]);
        SIMD_DATA_FMT_OP_NARROW_8[2:1]: `IT(8) no.n[i] = t_8_4(n_in.b[i]);
        SIMD_DATA_FMT_OP_NARROW_4[2:1]: `IT(16) no.c[i] = t_4_2(n_in.n[i]);
    endcase
end

// qnarrowing op
simd_t qno;
ama_riscv_simd_sat_clamp sat_clamp_i(
    .a(n_in), .op(op[2:0]), .q(qno)
);

//------------------------------------------------------------------------------
// txp op
simd_t txp_a, txp_b;
always_comb begin
    txp_a = 'h0;
    txp_b = 'h0;
    unique case (op[2:1])
        SIMD_DATA_FMT_OP_TXP_16[2:1]: begin
            txp_a.h[0] = a.h[0];
            txp_a.h[1] = b.h[0];
            txp_b.h[0] = a.h[1];
            txp_b.h[1] = b.h[1];
        end
        SIMD_DATA_FMT_OP_TXP_8[2:1]: begin
            `IT(2) begin
                txp_a.b[i*2 + 0] = a.b[i*2 + 0];
                txp_a.b[i*2 + 1] = b.b[i*2 + 0];
                txp_b.b[i*2 + 0] = a.b[i*2 + 1];
                txp_b.b[i*2 + 1] = b.b[i*2 + 1];
            end
        end
        SIMD_DATA_FMT_OP_TXP_4[2:1]: begin
            `IT(4) begin
                txp_a.n[i*2 + 0] = a.n[i*2 + 0];
                txp_a.n[i*2 + 1] = b.n[i*2 + 0];
                txp_b.n[i*2 + 0] = a.n[i*2 + 1];
                txp_b.n[i*2 + 1] = b.n[i*2 + 1];
            end
        end
        SIMD_DATA_FMT_OP_TXP_2[2:1]: begin
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
// scalar-vector ops

// dup
simd_t dup;
always_comb begin
    dup = 'h0;
    unique case (op[2:1])
        SIMD_DATA_FMT_OP_DUP_16[2:1]: `IT(2) dup.h[i] = a.h[0];
        SIMD_DATA_FMT_OP_DUP_8[2:1]: `IT(4) dup.b[i] = a.b[0];
        SIMD_DATA_FMT_OP_DUP_4[2:1]: `IT(8) dup.n[i] = a.n[0];
        SIMD_DATA_FMT_OP_DUP_2[2:1]: `IT(16) dup.c[i] = a.c[0];
    endcase
end

// vins
logic idx_h;
logic [1:0] idx_b;
logic [2:0] idx_n;
logic [3:0] idx_c;
assign idx_h = b[0];
assign idx_b = b[1:0];
assign idx_n = b[2:0];
assign idx_c = b[3:0];

simd_t vins;
always_comb begin
    vins = c;
    unique case (op[2:1])
        SIMD_DATA_FMT_OP_VINS_16[2:1]: vins.h[idx_h] = a.h[0];
        SIMD_DATA_FMT_OP_VINS_8[2:1]: vins.b[idx_b] = a.b[0];
        SIMD_DATA_FMT_OP_VINS_4[2:1]: vins.n[idx_n] = a.n[0];
        SIMD_DATA_FMT_OP_VINS_2[2:1]: vins.c[idx_c] = a.c[0];
    endcase
end

simd_t dup_vins;
assign dup_vins = op[0] ? vins : dup;

// vext
simd_t vext;
always_comb begin
    vext = 'h0;
    unique case (op[2:0])
        SIMD_DATA_FMT_OP_VEXT16[2:0]: vext = e_16_32(a.h[idx_h][15], a.h[idx_h]);
        SIMD_DATA_FMT_OP_VEXT16U[2:0]: vext = e_16_32(1'b0, a.h[idx_h]);
        SIMD_DATA_FMT_OP_VEXT8[2:0]: vext = e_8_32(a.b[idx_b][7], a.b[idx_b]);
        SIMD_DATA_FMT_OP_VEXT8U[2:0]: vext = e_8_32(1'b0, a.b[idx_b]);
        SIMD_DATA_FMT_OP_VEXT4[2:0]: vext = e_4_32(a.n[idx_n][3], a.n[idx_n]);
        SIMD_DATA_FMT_OP_VEXT4U[2:0]: vext = e_4_32(1'b0, a.n[idx_n]);
        SIMD_DATA_FMT_OP_VEXT2[2:0]: vext = e_2_32(a.c[idx_c][1], a.c[idx_c]);
        SIMD_DATA_FMT_OP_VEXT2U[2:0]: vext = e_2_32(1'b0, a.c[idx_c]);
    endcase
end

//------------------------------------------------------------------------------
// output

always_comb begin
    s = 'h0;
    unique case (op[7:3])
        SIMD_DATA_FMT_CLASS_NARROW: s.w[0] = no;
        SIMD_DATA_FMT_CLASS_QNARROW: s.w[0] = qno;
        SIMD_DATA_FMT_CLASS_TXP: s = {txp_b, txp_a}; // w1 = txp_b, w0 = txp_a
        SIMD_DATA_FMT_CLASS_DUP_VINS: s.w[0] = dup_vins;
        SIMD_DATA_FMT_CLASS_VEXT: s.w[0] = vext;
        default: s = 'h0;
    endcase
end

endmodule
