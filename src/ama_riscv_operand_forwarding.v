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
//      2021-08-16  AL  0.2.0 - Add DMEM data input forwarding
//                            - Change select signal names
//                            - Add b_op condition to avoid forwarding rs2 for store
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_operand_forwarding (
    // inputs                         
    input   wire        reg_we_ex         ,
    input   wire        store_inst_id     ,
    input   wire [ 5:0] rs1_id            ,
    input   wire [ 5:0] rs2_id            ,
    input   wire [ 5:0] rd_ex             ,
    input   wire        a_op_sel          ,
    input   wire        b_op_sel          ,
    // outputs                            
    output  reg  [ 1:0] a_op_sel_fwd      ,
    output  reg  [ 1:0] b_op_sel_fwd      ,
    output  wire        dmem_din_sel_fwd
);

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// A operand select
always @ (*) begin
    if ((rs1_id != `RF_X0_ZERO) && (rs1_id == rd_ex) && (reg_we_ex))
        a_op_sel_fwd = `ALU_A_SEL_FWD_ALU;      // forward previous ALU result
    else
        a_op_sel_fwd = {1'b0, a_op_sel};        // don't forward
end

//-----------------------------------------------------------------------------
// B operand select
always @ (*) begin
    if ((rs2_id != `RF_X0_ZERO) && (rs2_id == rd_ex) && (reg_we_ex) && (!store_inst_id))
        b_op_sel_fwd = `ALU_B_SEL_FWD_ALU;      // forward previous ALU result
    else
        b_op_sel_fwd = {1'b0, b_op_sel};        // don't forward
end

//-----------------------------------------------------------------------------
// Store DMEM data input forward
assign dmem_din_sel_fwd = (rs2_id != `RF_X0_ZERO) && (rs2_id == rd_ex) && (reg_we_ex) && (store_inst_id);

endmodule