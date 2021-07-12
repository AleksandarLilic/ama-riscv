//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Immediate Generation
// File:            ama_riscv_ig_out_gen.v
// Date created:    2021-07-11
// Author:          Aleksandar Lilic
// Description:     RISC-V ig_outediate values are less than 32-bit wide when 
//                  stored as a part of the ig_inruction, while ig_out value can
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
//      2021-07-12  AL  0.1.1 - Add checks and fix compares
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_ig_out_gen (
    // inputs
    input   wire        en    ,
    input   wire [ 3:0] ig_sel,
    input   wire [31:7] ig_in ,
    // outputs
    output  wire [31:0] ig_out
);

//-----------------------------------------------------------------------------
// Signals
wire i_type = (ig_sel == `IG_I_TYPE);
wire s_type = (ig_sel == `IG_S_TYPE);
wire b_type = (ig_sel == `IG_B_TYPE);
wire j_type = (ig_sel == `IG_J_TYPE);
wire u_type = (ig_sel == `IG_U_TYPE);

//-----------------------------------------------------------------------------
// MUXes

assign ig_out[31:20] = (i_type) ?      ig_in[31:20]    : 
                     /* others */  {12{ig_in[31   ]}};                      // sign ext

assign ig_out[19:12] = (i_type || s_type || b_type) ? {8{ig_in[31   ]}} :   // sign ext 
                     /*(j_type || u_type) */             ig_in[19:12];

assign ig_out[   11] = (i_type || s_type)  ? ig_in[31] :                    // sign ext
                       (b_type)            ? ig_in[ 7] : 
                       (j_type)            ? ig_in[20] : 
                     /*(u_type) */                1'b0;

assign ig_out[10: 5] = (u_type)   ? 6'b0 : 
                     /* others  */  ig_in[30:25];

assign ig_out[ 4: 1] = (i_type || j_type) ? ig_in[24:21] : 
                       (s_type || b_type) ? ig_in[11: 7] : 
                     /*(u_type) */                  4'b0;

assign ig_out[    0] = (i_type) ? ig_in[20] : 
                       (s_type) ? ig_in[ 7] : 
                     /*(b_type || j_type || u_type)*/ 1'b0;

endmodule
