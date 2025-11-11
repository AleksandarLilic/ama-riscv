`include "ama_riscv_defines.svh"

module ama_riscv_mult (
    input  mult_op_t op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] p
);

arch_double_width_s_t a_s, b_s;
assign a_s = {{ARCH_WIDTH{a[ARCH_WIDTH-1]}}, a};
assign b_s = {{ARCH_WIDTH{b[ARCH_WIDTH-1]}}, b};

arch_double_width_t a_u, b_u;
assign a_u = {{ARCH_WIDTH{1'b0}}, a};
assign b_u = {{ARCH_WIDTH{1'b0}}, b};

arch_double_width_s_t mul_p, mul_a, mul_b;
assign mul_p = mul_a * mul_b;

always_comb begin
    mul_a = a_s;
    mul_b = b_s;
    p = 'h0;
    unique case (op)
        MULT_OP_MUL: begin
            mul_a = a_s;
            mul_b = b_s;
            p = mul_p[ARCH_WIDTH-1:0];
        end
        MULT_OP_MULH: begin
            mul_a = a_s;
            mul_b = b_s;
            p = mul_p[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH];
        end
        MULT_OP_MULHSU: begin
            mul_a = a_s;
            mul_b = $signed(b_u);
            p = mul_p[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH];
        end
        MULT_OP_MULHU: begin
            mul_a = $signed(a_u);
            mul_b = $signed(b_u);
            p = mul_p[ARCH_DOUBLE_WIDTH-1:ARCH_WIDTH];
        end
    endcase
end

endmodule
