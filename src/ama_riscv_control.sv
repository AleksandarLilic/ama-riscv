`include "ama_riscv_defines.svh"

module ama_riscv_control (
    input  logic        clk,
    input  logic        rst,
    pipeline_if.IN      inst,
    rv_if.TX            imem_req,
    rv_if.RX            imem_rsp,
    input  logic        bc_a_eq_b,
    input  logic        bc_a_lt_b,
 /* input  logic        bp_taken,
    input  logic        bp_clear, */
    input  logic [ 1:0] store_mask_offset,
    pipeline_if.IN      rd_we,
    input  logic [ 4:0] rd_exe,
    input  logic [ 4:0] rd_mem,
    input  logic        store_inst_exe,
    output logic        bubble_dec,
    output pc_sel_t     pc_sel,
    output logic        pc_we,
    output logic        load_inst,
    output logic        store_inst,
    //output logic        branch_inst,
    //output logic        jump_inst,
    output csr_ctrl_t   csr_ctrl,
    output alu_op_t     alu_op_sel,
    output logic [ 2:0] ig_sel,
    output logic        bc_uns,
    output logic        dmem_en,
    output logic        load_sm_en,
    output logic [ 1:0] wb_sel,
    output logic        rd_we_dec,
    output logic [ 1:0] alu_a_sel_fwd,
    output logic [ 1:0] alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd,
    output logic [ 3:0] dmem_we
);

// Signals
logic        branch_inst;
logic        alu_a_sel;
logic        alu_b_sel;
logic [ 4:0] rs1_dec;
logic [ 4:0] rs2_dec;
logic [ 2:0] fn3_exe;
assign rs1_dec = inst.p.dec[19:15];
assign rs2_dec = inst.p.dec[24:20];
assign fn3_exe = inst.p.exe[14:12];

ama_riscv_decoder ama_riscv_decoder_i (
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req),
    .imem_rsp (imem_rsp),
    .inst (inst),
    .bc_a_eq_b (bc_a_eq_b),
    .bc_a_lt_b (bc_a_lt_b),
 /* .bp_taken (bp_taken),
    .bp_clear (bp_clear), */
    .bubble_dec (bubble_dec),
    .pc_sel (pc_sel),
    .pc_we (pc_we),
    .load_inst (load_inst),
    .store_inst (store_inst),
    .branch_inst (branch_inst),
    //.jump_inst (jump_inst),
    .csr_ctrl (csr_ctrl),
    .alu_op_sel (alu_op_sel),
    .alu_a_sel (alu_a_sel),
    .alu_b_sel (alu_b_sel),
    .ig_sel (ig_sel),
    .bc_uns (bc_uns),
    .dmem_en (dmem_en),
    .load_sm_en (load_sm_en),
    .wb_sel (wb_sel),
    .rd_we (rd_we_dec)
);

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    .rd_we (rd_we),
    .store_inst_dec (store_inst),
    .branch_inst_dec (branch_inst),
    .rs1_dec (rs1_dec),
    .rs2_dec (rs2_dec),
    .rd_exe (rd_exe),
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
    .en (store_inst_exe),
    .offset (store_mask_offset),
    .width (fn3_exe[1:0]),
    .mask (dmem_we)
);

endmodule
