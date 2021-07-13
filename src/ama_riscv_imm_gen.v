//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Immediate Generation
// File:            ama_riscv_imm_gen.v
// Date created:    2021-07-11
// Author:          Aleksandar Lilic
// Description:     RISC-V ig_outediate values are less than 32-bit wide when 
//                  stored as a part of the ig_instruction, while ig_out value can
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
//      2021-07-12  AL  0.1.2 - Fix naming
//      2021-07-12  AL  0.1.3 - Fix ig_out[31:20] mux check
//      2021-07-12  AL  0.1.4 - Fix ig_out[ 4: 1] for b and s types
//      2021-07-13  AL  0.2.0 - Merge en to ig_sel as 3'b000, shift other defs by 1
//                              Add 'keep previous' if disabled, add clk and rst
//      2021-07-13  AL  1.0.0 - Release
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_imm_gen (
    input   wire        clk   ,
    input   wire        rst   ,
    // inputs
    input   wire [ 2:0] ig_sel,
    input   wire [31:7] ig_in ,
    // outputs
    output  wire [31:0] ig_out
);

//-----------------------------------------------------------------------------
// Signals
reg   [31:0] ig_out_prev;
wire  [31:0] ig_out_w;

wire disabled = (ig_sel == `IG_DISABLED);
wire i_type   = (ig_sel == `IG_I_TYPE  );
wire s_type   = (ig_sel == `IG_S_TYPE  );
wire b_type   = (ig_sel == `IG_B_TYPE  );
wire j_type   = (ig_sel == `IG_J_TYPE  );
wire u_type   = (ig_sel == `IG_U_TYPE  );

//-----------------------------------------------------------------------------
// MUXes
assign ig_out_w[31:20] = (u_type)                        ?     ig_in[31:20] : 
                       /* others */                        {12{ig_in[31   ]}};   // sign ext

assign ig_out_w[19:12] = (j_type || u_type)              ?     ig_in[19:12] :   
                       /*(i_type || s_type || b_type)*/    { 8{ig_in[31   ]}};   // sign ext

assign ig_out_w[   11] = (u_type)                        ?             1'b0 :    // zero pad
                         (b_type)                        ?     ig_in[ 7   ] : 
                         (j_type)                        ?     ig_in[20   ] : 
                       /*(i_type || s_type) */                 ig_in[31   ]  ;   // sign ext

assign ig_out_w[10: 5] = (u_type)                        ?             6'b0 :    // zero pad
                       /* others  */                           ig_in[30:25]  ;

assign ig_out_w[ 4: 1] = (u_type)                        ?             4'b0 :    // zero pad 
                         (s_type || b_type)              ?     ig_in[11: 8] : 
                       /*(i_type || j_type) */                 ig_in[24:21]  ;

assign ig_out_w[    0] = (i_type)                        ?     ig_in[   20] : 
                         (s_type)                        ?     ig_in[    7] : 
                       /*(b_type || j_type || u_type)*/                1'b0  ;   // zero pad

//-----------------------------------------------------------------------------
// Assign output
assign ig_out = (disabled) ? ig_out_prev : ig_out_w;

//-----------------------------------------------------------------------------
// Store previous value
always @ (posedge clk) begin
    if (rst)
        ig_out_prev <= 32'h0000;
    else
        ig_out_prev <= ig_out;
end

endmodule
