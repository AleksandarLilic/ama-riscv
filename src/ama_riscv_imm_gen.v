//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Immediate Generation
// File:            ama_riscv_ig_out_gen.v
// Date created:    2021-07-11
// Author:          Aleksandar Lilic
// Description:     RISC-V ig_outediate values are less than 32-bit wide when 
//                  stored as a part of the instruction, while ig_out value can
//                  also be segmented. This module puts all parts in correct
//                  places and pads value to 32 bits
//                  Different paddings for:
//                  - i_type
//                  - s_type
//                  - b_type
//                  - j_type
//                  - u_type
//
// Version history:
//      2021-07-11  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_ig_out_gen (
    // inputs
    input   wire        en    ,
    input   wire [ 3:0] ig_sel,
    input   wire [31:7] ig_in ,
    // outputs
    output  reg  [31:0] ig_out
);

//-----------------------------------------------------------------------------
// Signals

assign ig_out[31:20] = (IG_U_TYPE) ?      ig_in[31:20]    : 
                     /* others */     {12{ig_in[31   ]}};       // sign ext

assign ig_out[19:12] = (IG_I_TYPE || IG_S_TYPE || IG_B_TYPE) ? {8{ig_in[31   ]}} : // sign ext 
                     /*(IG_J_TYPE || IG_U_TYPE) */                ig_in[19:12];

assign ig_out[   11] = (IG_I_TYPE || IG_S_TYPE)  ? inst[31] :    // sign ext
                       (IG_B_TYPE)               ? inst[ 7] : 
                       (IG_J_TYPE)               ? inst[20] : 
                     /*(IG_U_TYPE) */                  1’b0;

assign ig_out[10: 5] = (IG_U_TYPE)   ? 6’b0 : 
                     /* others  */  inst[30:25];

assign ig_out[ 4: 1] = (IG_I_TYPE || IG_J_TYPE) ? inst[24:21] : 
                       (IG_S_TYPE || IG_B_TYPE) ? inst[11: 7] : 
                     /*(IG_U_TYPE) */                    4’b0;

assign ig_out[    0] = (IG_I_TYPE) ? inst[20] : 
                       (IG_S_TYPE) ? inst[ 7] : 
                     /*(IG_B_TYPE || IG_J_TYPE || IG_U_TYPE)*/ 1’b0;

endmodule
