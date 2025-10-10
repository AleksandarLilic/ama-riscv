`include "ama_riscv_defines.svh"

module ama_riscv_operand_forwarding (
    // inputs
    pipeline_if.IN      rd_we,
    input  logic        store_inst_dec,
    input  logic        branch_inst_dec,
    input  rf_addr_t    rs1_dec,
    input  rf_addr_t    rs2_dec,
    input  rf_addr_t    rd_exe,
    input  rf_addr_t    rd_mem,
    input  alu_a_sel_t  alu_a_sel_dec,
    input  alu_b_sel_t  alu_b_sel_dec,
    // outputs
    output alu_a_sel_t  alu_a_sel_fwd,
    output alu_b_sel_t  alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd
);

logic rs1_nz;
logic rs2_nz;
logic op_a_wr_valid_exe;
logic op_b_wr_valid_exe;
logic rf_a_wr_valid_mem;
logic rf_b_wr_valid_mem;

assign rs1_nz = (rs1_dec != RF_X0_ZERO);
assign rs2_nz = (rs2_dec != RF_X0_ZERO);
assign op_a_wr_valid_exe = (rs1_nz && (rs1_dec == rd_exe) && rd_we.exe);
assign op_b_wr_valid_exe = (rs2_nz && (rs2_dec == rd_exe) && rd_we.exe);
assign rf_a_wr_valid_mem = (rs1_nz && (rs1_dec == rd_mem) && rd_we.mem);
assign rf_b_wr_valid_mem = (rs2_nz && (rs2_dec == rd_mem) && rd_we.mem);

// ALU A operand forwarding
always_comb begin
    if (op_a_wr_valid_exe && (alu_a_sel_dec == ALU_A_SEL_RS1)) begin
        alu_a_sel_fwd = ALU_A_SEL_FWD_ALU;
    end else begin
        alu_a_sel_fwd = alu_a_sel_t'({1'b0, alu_a_sel_dec});
    end
end

// ALU B operand forwarding
always_comb begin
    if (op_b_wr_valid_exe && (alu_b_sel_dec == ALU_B_SEL_RS2)) begin
        alu_b_sel_fwd = ALU_B_SEL_FWD_ALU;
    end else begin
        alu_b_sel_fwd = alu_b_sel_t'({1'b0, alu_b_sel_dec});
    end
end

// Branch Compare A operand forwarding
assign bc_a_sel_fwd = (
    op_a_wr_valid_exe && branch_inst_dec);
// Branch Compare B operand and Store DMEM data input forwarding
assign bcs_b_sel_fwd = (
    op_b_wr_valid_exe && (store_inst_dec || branch_inst_dec));
// RF A operand forwarding
assign rf_a_sel_fwd = (
    rf_a_wr_valid_mem &&
    ((alu_a_sel_dec == ALU_A_SEL_RS1) || branch_inst_dec)
);
// RF B operand forwarding
assign rf_b_sel_fwd = (
    rf_b_wr_valid_mem &&
    ((alu_b_sel_dec == ALU_B_SEL_RS2) || branch_inst_dec || store_inst_dec)
);

endmodule
