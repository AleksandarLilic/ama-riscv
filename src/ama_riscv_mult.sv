`include "ama_riscv_defines.svh"

module ama_riscv_mult (
    input  mult_op_t op_sel,
    input  logic [31:0] in_a,
    input  logic [31:0] in_b,
    output logic [31:0] out_s
);

arch_double_width_s_t a_s, b_s;
assign a_s = {{ARCH_WIDTH{in_a[ARCH_WIDTH-1]}}, in_a};
assign b_s = {{ARCH_WIDTH{in_b[ARCH_WIDTH-1]}}, in_b};
arch_double_width_t a_u, b_u;
assign a_u = {{ARCH_WIDTH{1'b0}}, in_a};
assign b_u = {{ARCH_WIDTH{1'b0}}, in_b};

arch_double_width_s_t mul_a, mul_b, res;
assign res = mul_a * mul_b;

always_comb begin
    mul_a = a_s;
    mul_b = b_s;
    out_s = 'h0;
    unique case (op_sel)
        MULT_OP_MUL: begin
            mul_a = a_s;
            mul_b = b_s;
            out_s = res[ARCH_WIDTH-1:0]; end
        MULT_OP_MULH: begin
            mul_a = a_s;
            mul_b = b_s;
            out_s = res[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH]; end
        MULT_OP_MULHSU: begin
            mul_a = a_s;
            mul_b = $signed(b_u);
            out_s = res[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH]; end
        MULT_OP_MULHU: begin
            mul_a = $signed(a_u);
            mul_b = $signed(b_u);
            out_s = res[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH]; end
    endcase
end
endmodule
