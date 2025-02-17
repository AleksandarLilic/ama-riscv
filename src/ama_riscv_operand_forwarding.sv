`include "ama_riscv_defines.svh"

module ama_riscv_operand_forwarding (
    // inputs
    input  logic        reg_we_ex,
    input  logic        reg_we_mem,
    input  logic        store_inst_id,
    input  logic        branch_inst_id,
    input  logic [ 4:0] rs1_id,
    input  logic [ 4:0] rs2_id,
    input  logic [ 4:0] rd_ex,
    input  logic [ 4:0] rd_mem,
    input  logic        alu_a_sel,
    input  logic        alu_b_sel,
    // outputs
    output logic [ 1:0] alu_a_sel_fwd,
    output logic [ 1:0] alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd
);

logic rs1_wr_valid;
logic rs2_wr_valid;
logic op_a_wr_valid_ex;
logic op_b_wr_valid_ex;
logic rf_a_wr_valid_mem;
logic rf_b_wr_valid_mem;

assign rs1_wr_valid = (rs1_id != `RF_X0_ZERO);
assign rs2_wr_valid = (rs2_id != `RF_X0_ZERO);
assign op_a_wr_valid_ex = (rs1_wr_valid && (rs1_id == rd_ex) && (reg_we_ex));
assign op_b_wr_valid_ex = (rs2_wr_valid && (rs2_id == rd_ex) && (reg_we_ex));
assign rf_a_wr_valid_mem = (rs1_wr_valid && (rs1_id == rd_mem) && (reg_we_mem));
assign rf_b_wr_valid_mem = (rs2_wr_valid && (rs2_id == rd_mem) && (reg_we_mem));

// ALU A operand forwarding
always_comb begin
    if (op_a_wr_valid_ex && alu_a_sel == `ALU_A_SEL_RS1) begin
        alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;
    end else begin
        alu_a_sel_fwd = {1'b0, alu_a_sel}; // don't forward
    end
end

// ALU B operand forwarding
always_comb begin
    if (op_b_wr_valid_ex && alu_b_sel == `ALU_B_SEL_RS2) begin
        alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;
    end else begin
        alu_b_sel_fwd = {1'b0, alu_b_sel}; // don't forward
    end
end

// Branch Compare A operand forwarding
assign bc_a_sel_fwd  = (op_a_wr_valid_ex && branch_inst_id);
// Branch Compare B operand and Store DMEM data input forwarding
assign bcs_b_sel_fwd = (op_b_wr_valid_ex && (store_inst_id || branch_inst_id));
// RF A operand forwarding
assign rf_a_sel_fwd  =
    (rf_a_wr_valid_mem && ((alu_a_sel == `ALU_A_SEL_RS1) || (branch_inst_id)));
// RF B operand forwarding
assign rf_b_sel_fwd  =
    (rf_b_wr_valid_mem &&
        ((alu_b_sel == `ALU_B_SEL_RS2) || branch_inst_id || store_inst_id)
    );

endmodule
