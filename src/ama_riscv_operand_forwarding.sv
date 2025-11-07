`include "ama_riscv_defines.svh"

module ama_riscv_operand_forwarding (
    // inputs
    input  logic        store_inst_dec,
    input  logic        branch_inst_dec,
    input  logic        store_inst_exe,
    input  logic        branch_inst_exe,
    input  logic        load_inst_mem,
    input  rf_addr_t    rs1_dec,
    input  rf_addr_t    rs2_dec,
    input  rf_addr_t    rs1_exe,
    input  rf_addr_t    rs2_exe,
    input  rf_addr_t    rd_mem,
    input  rf_addr_t    rd_wbk,
    input  logic        rd_we_mem,
    input  logic        rd_we_wbk,
    input  alu_a_sel_t  alu_a_sel_dec,
    input  alu_b_sel_t  alu_b_sel_dec,
    input  alu_a_sel_t  alu_a_sel_exe,
    input  alu_b_sel_t  alu_b_sel_exe,
    // outputs
    output fwd_be_t     fwd_be_rs1_dec,
    output fwd_be_t     fwd_be_rs2_dec,
    output fwd_be_t     fwd_be_rs1_exe,
    output fwd_be_t     fwd_be_rs2_exe,
    output alu_a_sel_t  alu_a_sel_fwd,
    output alu_b_sel_t  alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd,
    output hazard_be_t  hazard_be
);

// is any source reg anywhere in the backend?
logic rs1_dec_nz, rs2_dec_nz, rs1_exe_nz, rs2_exe_nz;
assign rs1_dec_nz = (rs1_dec != RF_X0_ZERO);
assign rs2_dec_nz = (rs2_dec != RF_X0_ZERO);
assign rs1_exe_nz = (rs1_exe != RF_X0_ZERO);
assign rs2_exe_nz = (rs2_exe != RF_X0_ZERO);

// anywhere in the mem stage?
logic rs1_dec_in_mem, rs2_dec_in_mem, rs1_exe_in_mem, rs2_exe_in_mem;
assign rs1_dec_in_mem = (rs1_dec_nz && (rs1_dec == rd_mem) && rd_we_mem);
assign rs2_dec_in_mem = (rs2_dec_nz && (rs2_dec == rd_mem) && rd_we_mem);
assign rs1_exe_in_mem = (rs1_exe_nz && (rs1_exe == rd_mem) && rd_we_mem);
assign rs2_exe_in_mem = (rs2_exe_nz && (rs2_exe == rd_mem) && rd_we_mem);

// anywhere in the writeback stage?
logic rs1_dec_in_wbk, rs2_dec_in_wbk, rs1_exe_in_wbk, rs2_exe_in_wbk;
assign rs1_dec_in_wbk = (rs1_dec_nz && (rs1_dec == rd_wbk) && rd_we_wbk);
assign rs2_dec_in_wbk = (rs2_dec_nz && (rs2_dec == rd_wbk) && rd_we_wbk);
assign rs1_exe_in_wbk = (rs1_exe_nz && (rs1_exe == rd_wbk) && rd_we_wbk);
assign rs2_exe_in_wbk = (rs2_exe_nz && (rs2_exe == rd_wbk) && rd_we_wbk);

// combine to anywhere in the backend
logic rs1_dec_in_be, rs2_dec_in_be, rs1_exe_in_be, rs2_exe_in_be;
assign rs1_dec_in_be = (rs1_dec_in_mem || rs1_dec_in_wbk);
assign rs2_dec_in_be = (rs2_dec_in_mem || rs2_dec_in_wbk);
assign rs1_exe_in_be = (rs1_exe_in_mem || rs1_exe_in_wbk);
assign rs2_exe_in_be = (rs2_exe_in_mem || rs2_exe_in_wbk);

// if it is, where to get the data from?
// if it's found in both mem and wbk, prioritize mem as a later update to the rd
assign fwd_be_rs1_dec = rs1_dec_in_mem ? FWD_BE_EWBK : FWD_BE_WBK;
assign fwd_be_rs2_dec = rs2_dec_in_mem ? FWD_BE_EWBK : FWD_BE_WBK;
assign fwd_be_rs1_exe = rs1_exe_in_mem ? FWD_BE_EWBK : FWD_BE_WBK;
assign fwd_be_rs2_exe = rs2_exe_in_mem ? FWD_BE_EWBK : FWD_BE_WBK;

// ALU operand forwarding
assign alu_a_sel_fwd = (rs1_exe_in_be && (alu_a_sel_exe == ALU_A_SEL_RS1)) ?
    ALU_A_SEL_FWD : alu_a_sel_exe;

assign alu_b_sel_fwd = (rs2_exe_in_be && (alu_b_sel_exe == ALU_B_SEL_RS2)) ?
    ALU_B_SEL_FWD : alu_b_sel_exe;

// Branch Compare amd store dmem operand forwarding
assign bc_a_sel_fwd = (rs1_exe_in_be && branch_inst_exe);
assign bcs_b_sel_fwd = (rs2_exe_in_be && (store_inst_exe || branch_inst_exe));

// RF read operand forwarding
assign rf_a_sel_fwd = (
    rs1_dec_in_be &&
    ((alu_a_sel_dec == ALU_A_SEL_RS1) || branch_inst_dec)
);
assign rf_b_sel_fwd = (
    rs2_dec_in_be &&
    ((alu_b_sel_dec == ALU_B_SEL_RS2) || branch_inst_dec || store_inst_dec)
);

assign hazard_be.to_dec = load_inst_mem && (rs1_dec_in_mem || rs2_dec_in_mem);
assign hazard_be.to_exe = load_inst_mem && (rs1_exe_in_mem || rs2_exe_in_mem);

endmodule
