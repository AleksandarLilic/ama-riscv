`include "ama_riscv_defines.svh"

module ama_riscv_simd_ppgen #(
    parameter bit RV32M_ONLY = 0
)(
    input  logic op_unsigned,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic op_simd_dot,
    input  simd_arith_el_width_t ew,
    /* verilator lint_on UNUSEDSIGNAL */
    input  simd_t a,
    input  simd_t b,
    output simd_d_t [31:0] ppv, // double-wide pp view
    output simd_d_t corr // correction for modified BW for signed operations
);

localparam int unsigned W = 32;

//------------------------------------------------------------------------------
// AND matrix for signed multiply using lane-aware Baugh–Wooley

logic [W-1:0] sign_mask;

if (RV32M_ONLY) begin: gen_sign_mask_rv32m
assign sign_mask = (!op_unsigned) ? 'h8000_0000 : 'h0;

end else begin: gen_sign_mask_simd
always_comb begin
    sign_mask = '0;
    if (!op_unsigned) begin
        unique case (1'b1)
            ew.b2: sign_mask = 'hAAAA_AAAA;
            ew.b4: sign_mask = 'h8888_8888;
            ew.b8: sign_mask = 'h8080_8080;
            ew.b16: sign_mask = 'h8000_8000;
            ew.b32: sign_mask = 'h8000_0000;
            default: sign_mask = '0;
        endcase
    end
end

end // gen_sign_mask_rv32m/simd

simd_t [W-1:0] pp; // partial products matrix
logic [W-1:0][W-1:0] y;
logic [W-1:0][W-1:0] flip;
for (genvar r = 0; r < W; r++) begin: gen_pp_rows
    for (genvar c = 0; c < W; c++) begin: gen_pp_columns
        assign y[r][c] = (b[r] & a[c]);
        assign flip[r][c] = (sign_mask[r] ^ sign_mask[c]);
        assign pp[r][c] = flip[r][c] ? ~y[r][c] : y[r][c];
    end
end

if (RV32M_ONLY) begin: gen_ppv_rv32m
always_comb begin
    `IT_P(i, W) begin
        simd_d_t x;
        x = {32'h0, pp[i]};
        ppv[i] = (x << i);
    end
end

end else begin: gen_ppv_simd

// set up masks
// select which 16x16/8x8/4x4/2x2 tile (j,i) belongs to
// set ones only on diagonal tile blocks (j == i)

localparam int unsigned TILE_16 = 16; // 16x16 blocks
simd_t [W-1:0] mask_16;
always_comb begin
    `IT_P(j, W) `IT_P(i, W) mask_16[j][i] = ((j / TILE_16) == (i / TILE_16));
end

localparam int unsigned TILE_8 = 8; // 8x8 blocks
simd_t [W-1:0] mask_8;
always_comb begin
    `IT_P(j, W) `IT_P(i, W) mask_8[j][i] = ((j / TILE_8) == (i / TILE_8));
end

localparam int unsigned TILE_4 = 4; // 4x4 blocks
simd_t [W-1:0] mask_4;
always_comb begin
    `IT_P(j, W) `IT_P(i, W) mask_4[j][i] = ((j / TILE_4) == (i / TILE_4));
end

localparam int unsigned TILE_2 = 2; // 2x2 blocks
simd_t [W-1:0] mask_2;
always_comb begin
    `IT_P(j, W) `IT_P(i, W) mask_2[j][i] = ((j / TILE_2) == (i / TILE_2));
end

always_comb begin
    `IT_P(i, W) begin
        simd_d_t x;
        unique case (1'b1)
            ew.b32: x = {32'h0, pp[i]};
            ew.b16: x = {32'h0, (pp[i] & mask_16[i])};
            ew.b8: x = {32'h0, (pp[i] & mask_8[i])};
            ew.b4: x = {32'h0, (pp[i] & mask_4[i])};
            ew.b2: x = {32'h0, (pp[i] & mask_2[i])};
            default: x = '0;
        endcase
        ppv[i] = (x << i);
    end
end

end // gen_ppv_rv32m/simd

if (RV32M_ONLY) begin: gen_corr_rv32m
always_comb begin
    corr = '0;
    if (!op_unsigned) begin corr[32] = 1'b1; corr[63] = 1'b1; end
end

end else begin: gen_corr_simd
always_comb begin
    corr = '0;
    if (!op_unsigned) begin
        unique case (1'b1)
            ew.b32: begin corr[32] = 1'b1; corr[63] = 1'b1; end
            (ew.b16 && op_simd_dot): begin corr[17] = 1'b1; end
            (ew.b16 && !op_simd_dot): begin corr[16] = 1'b1; corr[31] = 1'b1;end
            (ew.b8 && op_simd_dot): begin corr[10] = 1'b1; end
            (ew.b8 && !op_simd_dot): begin corr[8] = 1'b1; corr[15] = 1'b1;end
            ew.b4: begin corr[7] = 1'b1; end // idx [4] set 8 times
            ew.b2: begin corr[6] = 1'b1; end // idx [2] set 16 times
        endcase
    end
end

end // gen_corr_rv32m/simd

endmodule
