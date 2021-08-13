//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Operand Forwarding
// File:            ama_riscv_operand_forwarding.v
// Date created:    2021-08-12
// Author:          Aleksandar Lilic
// Description:     Operand Forwarding in case of data dependency in pipeline
//
// Version history:
//      2021-08-12  AL  0.1.0 - Initial - Add forwarding
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_operand_forwarding (
    // inputs                         
    input   wire        reg_we_ex     ,
    input   wire [ 5:0] rs1_id        ,
    input   wire [ 5:0] rs2_id        ,
    input   wire [ 5:0] rd_ex         ,
    input   wire        alu_a_sel     ,
    input   wire        alu_b_sel     ,
    // outputs
    output  reg  [ 1:0] alu_a_sel_fwd ,
    output  reg  [ 1:0] alu_b_sel_fwd
);

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// A operand select
always @ (*) begin
    if ((rs1_id != `RF_X0_ZERO) && (rs1_id == rd_ex) && (reg_we_ex))
        alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;     // forward previous ALU result
    else
        alu_a_sel_fwd = {1'b0, alu_a_sel};      // don't forward
end

//-----------------------------------------------------------------------------
// B operand select
always @ (*) begin
    if ((rs2_id != `RF_X0_ZERO) && (rs2_id == rd_ex) && (reg_we_ex))
        alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;     // forward previous ALU result
    else
        alu_b_sel_fwd = {1'b0, alu_b_sel};      // don't forward
end


endmodule