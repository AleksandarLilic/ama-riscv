`include "ama_riscv_defines.svh"

module cmp_s_lt (
    input  logic a_sign, // operand a sign
    input  logic b_sign, // operand b sign
    input  logic s_sign, // subtract out sign
    output logic lt
);

// 'compare signed less than' logic (signbit xor overflow)
// overflow happens if
//   1. operands have different signs (a vs b)
//   2. result sign matches b
// the *original* b sign is used, not the inverted adder_b
logic v_flag, n_flag; // overflow, negative
assign v_flag = ((a_sign != b_sign) && (s_sign == b_sign));
assign n_flag = s_sign;
assign lt = (n_flag ^ v_flag);

endmodule
