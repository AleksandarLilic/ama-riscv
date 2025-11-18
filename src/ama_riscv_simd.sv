`include "ama_riscv_defines.svh"

module ama_riscv_simd (
    input  mult_op_t op,
    input  simd_t a,
    input  simd_t b,
    output simd_t p
);

localparam int unsigned W = 32;

// set up masks
localparam int unsigned TILE_8 = 8; // 8x8 blocks
simd_t [W-1:0] mask_8;
always_comb begin
    for (int y = 0; y < W; y++) begin
        for (int x = 0; x < W; x++) begin
            // select which 8x8 tile (y,x) belongs to
            // set ones only on diagonal tile blocks (ty == tx)
            mask_8[y][x] = ((y / TILE_8) == (x / TILE_8));
        end
    end
end

localparam int unsigned TILE_16 = 16; // 16x16 blocks
simd_t [W-1:0] mask_16;

always_comb begin
    for (int y = 0; y < W; y++) begin
        for (int x = 0; x < W; x++) begin
            // select which 16x16 tile (y,x) belongs to
            // set ones only on diagonal tile blocks (ty == tx)
            mask_16[y][x] = ((y / TILE_16) == (x / TILE_16));
        end
    end
end

logic op_dot16, op_dot8, op_simd;
assign op_dot16 = (op == MULT_OP_DOT16);
assign op_dot8 = (op == MULT_OP_DOT8);
assign op_simd = op[2];

// AND matrix for signed multiply using lane-aware Baugh–Wooley
simd_t [W-1:0] pp; // partial products matrix
always_comb begin
    int lane_sz;
    if (op_dot8) lane_sz = 8;
    else if (op_dot16) lane_sz = 16;
    else lane_sz = W; // plain 32x32 signed

    for (int i = 0; i < W; i++) begin
        for (int j = 0; j < W; j++) begin
            logic y, flip;
            int li, lj; // lane-local indices

            // lane-local positions
            li = i % lane_sz;
            lj = j % lane_sz;

            // Baugh–Wooley rule per lane:
            // flip last row / last col, except 'sign × sign' intersection
            flip = 1'b0;
            if (op != MULT_OP_MULHU) begin // the only unsigned multiplication
                flip = (
                    ((li == lane_sz-1) && (lj != lane_sz-1)) || // "row sign"
                    ((lj == lane_sz-1) && (li != lane_sz-1)) // "col sign"
                );
            end
            y = a[i] & b[j];
            pp[i][j] = flip ? ~y : y;
        end
    end
end

simd_d_t [W-1:0] ppv; // double-wide pp view
always_comb begin
    for (int i = 0; i < W; i++) begin
        simd_d_t x;
        x = {32'h0, pp[i]};
        ppv[i] = x; // idk whatever
        if (!op_simd) begin // MULT 32x32
            ppv[i] = (x << i);
        end else if (op_dot16) begin // DOT16
            ppv[i] = (((x & mask_16[i]) << (i % 16)) >> ((i / 16) * 16));
        end else if (op_dot8) begin // DOT8
            ppv[i] = (((x & mask_8[i]) << (i % 8)) >> ((i / 8) * 8));
        end
    end
end

simd_d_t corr; // correction for modified BW
always_comb begin
    corr = '0;
    if (!op_simd) begin
        // 32x32 signed MBW
        corr[32] = 1'b1;
        corr[63] = 1'b1;
    end else if (op_dot16) begin
        // 2 lanes of 16x16 signed
        corr[17] = 1'b1; // idx [16] set twice (1x per lane)
    end else if (op_dot8) begin
        // 4 lanes of 8x8 signed
        corr[10] = 1'b1; // idx [8] set four times (1x per lane)
    end
end

// first four trees in parallel
simd_d_t [1:0] o_tree_0, o_tree_1, o_tree_2, o_tree_3;
csa_tree_8 #(.W(64)) csa_tree_8_i0 (.a (ppv[7:0]), .o (o_tree_0));
csa_tree_8 #(.W(64)) csa_tree_8_i1 (.a (ppv[15:8]), .o (o_tree_1));
csa_tree_8 #(.W(64)) csa_tree_8_i2 (.a (ppv[23:16]), .o (o_tree_2));
csa_tree_8 #(.W(64)) csa_tree_8_i3 (.a (ppv[31:24]), .o (o_tree_3));

simd_d_t [7:0] i_tree_f, i_tree_f_d; // inputs to the final tree
assign i_tree_f = {o_tree_3, o_tree_2, o_tree_1, o_tree_0};

// TODO: provisional pipeline
assign i_tree_f_d = i_tree_f;

// final tree
simd_d_t [1:0] o_tree_f;
csa_tree_8 #(.W(64)) csa_tree_8_f_i (.a (i_tree_f_d), .o(o_tree_f));

simd_d_t tree_sum;
assign tree_sum = o_tree_f[0] + o_tree_f[1];

// wrap up multiplication
simd_d_t mul_u, mul_s;
assign mul_u = tree_sum;
assign mul_s = tree_sum + corr;

logic b_sign_bit;
assign b_sign_bit = b[ARCH_WIDTH-1]; // b MSB
simd_t mul_su;
assign mul_su = b_sign_bit ? (mul_s.w[1] + a) : mul_s.w[1];

// wrap up simd
simd_d_t dot16, dot8;
assign dot16 = mul_s; // same operations, input matrix & corr were different
assign dot8 = mul_s; // same as above, but input & corr different yet again

localparam unsigned DOT8_W = ARCH_WIDTH_H + 1; // dot8 result width, 17 bits
localparam unsigned DOT8_SIGN = ARCH_WIDTH - DOT8_W; // sign pad, 15 bits

// output assignment based on the operation
always_comb begin
    p = 'h0;
    unique case (op)
        MULT_OP_MUL: p = mul_s[ARCH_WIDTH-1:0];
        MULT_OP_MULH: p = mul_s[ARCH_WIDTH_D-1:ARCH_WIDTH];
        MULT_OP_MULHSU: p = mul_su;
        MULT_OP_MULHU: p = mul_u[ARCH_WIDTH_D-1:ARCH_WIDTH];
        MULT_OP_DOT16: p = dot16[ARCH_WIDTH-1:0];
        MULT_OP_DOT8: p = {{DOT8_SIGN{dot8[DOT8_W-1]}}, dot8[DOT8_W-1:0]};
    endcase
end

endmodule
