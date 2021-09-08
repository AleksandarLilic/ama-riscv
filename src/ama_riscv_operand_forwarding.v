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
//      2021-08-17  AL  0.2.1 - Fix forwarding when imm/pc was selected
//      2021-08-18  AL  0.2.2 - Add muxes for branch compare/dmem din
//      2021-08-19  AL  0.2.3 - Remove store inst check for B select
//      2021-09-08  AL  0.2.4 - Fix register address signal width
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_operand_forwarding (
    // inputs                         
    input   wire        reg_we_ex       ,
    input   wire        store_inst_id   ,
    input   wire        branch_inst_id  ,
    input   wire [ 4:0] rs1_id          ,
    input   wire [ 4:0] rs2_id          ,
    input   wire [ 4:0] rd_ex           ,
    input   wire        alu_a_sel       ,
    input   wire        alu_b_sel       ,
    // outputs                          
    output  reg  [ 1:0] alu_a_sel_fwd   ,
    output  reg  [ 1:0] alu_b_sel_fwd   ,
    output  wire        bc_a_sel_fwd    ,
    output  wire        bcs_b_sel_fwd 
);

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// A operand select
always @ (*) begin
    if ((rs1_id != `RF_X0_ZERO) && (rs1_id == rd_ex) && (reg_we_ex) && (!alu_a_sel))
        alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;     // forward previous ALU result
    else
        alu_a_sel_fwd = {1'b0, alu_a_sel};      // don't forward
end

//-----------------------------------------------------------------------------
// B operand select
always @ (*) begin
    if ((rs2_id != `RF_X0_ZERO) && (rs2_id == rd_ex) && (reg_we_ex) && (!alu_b_sel))
        alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;     // forward previous ALU result
    else
        alu_b_sel_fwd = {1'b0, alu_b_sel};      // don't forward
end

//-----------------------------------------------------------------------------
// Branch Compare A operand forward
assign bc_a_sel_fwd = ((rs1_id != `RF_X0_ZERO) && (rs1_id == rd_ex) && (reg_we_ex) && (branch_inst_id));

//-----------------------------------------------------------------------------
// Branch Compare A operand and Store DMEM data input forward
assign bcs_b_sel_fwd = ((rs2_id != `RF_X0_ZERO) && (rs2_id == rd_ex) && (reg_we_ex) && (store_inst_id || branch_inst_id));

endmodule