`include "ama_riscv_defines.svh"

module ama_riscv_control (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] inst_id,
    input  logic        bc_a_eq_b,
    input  logic        bc_a_lt_b,
 /* input  logic        bp_taken,
    input  logic        bp_clear, */
    input  logic [ 1:0] store_mask_offset,
    input  logic [31:0] inst_ex,
    input  logic        reg_we_ex,
    input  logic        reg_we_mem,
    input  logic [ 4:0] rd_ex,
    input  logic [ 4:0] rd_mem,
    input  logic        store_inst_ex,
    output logic        stall_if,
    output logic        clear_if,
    output logic        clear_id,
    output logic        clear_ex,
    output logic        clear_mem,
    output logic [ 1:0] pc_sel,
    output logic        pc_we,
    output logic        load_inst,
    output logic        store_inst,
    output logic        branch_inst,
    output logic        jump_inst,
    output logic        csr_en,
    output logic        csr_we,
    output logic        csr_ui,
    output logic [ 1:0] csr_op_sel,
    output logic [ 3:0] alu_op_sel,
    output logic [ 2:0] ig_sel,
    output logic        bc_uns,
    output logic        dmem_en,
    output logic        load_sm_en,
    output logic [ 1:0] wb_sel,
    output logic        reg_we,
    output logic [ 1:0] alu_a_sel_fwd,
    output logic [ 1:0] alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd,
    output logic [ 3:0] dmem_we
);

// Signals
logic        alu_a_sel;
logic        alu_b_sel;
logic [ 4:0] rs1_id;
logic [ 4:0] rs2_id;
logic [ 2:0] funct3_ex;
assign rs1_id = inst_id[19:15];
assign rs2_id = inst_id[24:20];
assign funct3_ex = inst_ex[14:12];

ama_riscv_decoder ama_riscv_decoder_i (
    .clk (clk),
    .rst (rst),
    .inst_id (inst_id),
    .inst_ex (inst_ex),
    .bc_a_eq_b (bc_a_eq_b),
    .bc_a_lt_b (bc_a_lt_b),
 /* .bp_taken (bp_taken),
    .bp_clear (bp_clear), */
    .stall_if (stall_if),
    .clear_if (clear_if),
    .clear_id (clear_id),
    .clear_ex (clear_ex),
    .clear_mem (clear_mem),
    .pc_sel (pc_sel),
    .pc_we (pc_we),
    .load_inst (load_inst),
    .store_inst (store_inst),
    .branch_inst (branch_inst),
    .jump_inst (jump_inst),
    .csr_en (csr_en),
    .csr_we (csr_we),
    .csr_ui (csr_ui),
    .csr_op_sel (csr_op_sel),
    .alu_op_sel (alu_op_sel),
    .alu_a_sel (alu_a_sel),
    .alu_b_sel (alu_b_sel),
    .ig_sel (ig_sel),
    .bc_uns (bc_uns),
    .dmem_en (dmem_en),
    .load_sm_en (load_sm_en),
    .wb_sel (wb_sel),
    .reg_we (reg_we)
);

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    .reg_we_ex (reg_we_ex),
    .reg_we_mem (reg_we_mem),
    .store_inst_id (store_inst),
    .branch_inst_id (branch_inst),
    .rs1_id (rs1_id),
    .rs2_id (rs2_id),
    .rd_ex (rd_ex),
    .rd_mem (rd_mem),
    .alu_a_sel (alu_a_sel),
    .alu_b_sel (alu_b_sel),
    .alu_a_sel_fwd (alu_a_sel_fwd),
    .alu_b_sel_fwd (alu_b_sel_fwd),
    .bc_a_sel_fwd (bc_a_sel_fwd),
    .bcs_b_sel_fwd (bcs_b_sel_fwd),
    .rf_a_sel_fwd (rf_a_sel_fwd),
    .rf_b_sel_fwd (rf_b_sel_fwd)
);

ama_riscv_store_mask ama_riscv_store_mask_i (
    .en (store_inst_ex),
    .offset (store_mask_offset),
    .width (funct3_ex[1:0]),
    .mask (dmem_we)
);

endmodule
