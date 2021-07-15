//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Branch Compare
// File:            ama_riscv_branch_compare.v
// Date created:    2021-07-15
// Author:          Aleksandar Lilic
// Description:     Comparing two 32-bit values as either signed or unsigned
//                  Two possible outcomes:
//                  1. Operands are equal
//                  2. Operand A is smaller than operand B
//                  * Other comparisons can be inferred by combining these two
//
// Version history:
//      2021-07-15  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------

module ama_riscv_branch_compare (
    // inputs
    input   wire        op_uns  ,
    input   wire [31:0] in_a    ,
    input   wire [31:0] in_b    ,
    // outputs
    output  wire        op_eq   ,
    output  wire        op_lt   
);

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// Compare

// Operands equal
assign op_eq = (op_uns) ? (in_a == in_b) : ($signed(in_a) == $signed(in_b));

// Operand A less than operand B
assign op_lt = (op_uns) ? (in_a <  in_b) : ($signed(in_a) <  $signed(in_b));

endmodule