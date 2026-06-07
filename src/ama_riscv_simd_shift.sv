`include "ama_riscv_defines.svh"

module ama_riscv_simd_shift (
    input  simd_shift_op_t op,
    input  simd_t a,
    input  simd_t b,
    input  logic [4:0] shamt,
    output simd_d_t s
);

logic is_widen;
assign is_widen = op[3];
simd_shift_el_width_t ew;
assign ew = simd_shift_el_width_t'({is_widen ? op[2] : 1'b0, op[1]});

simd_shift_kind_t all_shifts_kind; // slli/srli/srai
assign all_shifts_kind = simd_shift_kind_t'({op[2], op[0]});
simd_shift_kind_t kind;
assign kind = is_widen ? SIMD_SHIFT_KIND_SLL : all_shifts_kind;

// shifter for slli/srli/srai, or first shifter for widen
barrel_shift_seg #(.R(1)) shifter_rev (.a, .shamt, .ew, .kind, .s(s.w[0]));

// second shifter for widen
/* verilator lint_off PINCONNECTEMPTY */
barrel_shift_seg #(.R(0)) shifter_left (.a(b), .shamt, .ew, .kind(), .s(s.w[1]));
/* verilator lint_on PINCONNECTEMPTY */

endmodule
