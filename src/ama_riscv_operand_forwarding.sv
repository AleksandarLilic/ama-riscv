`include "ama_riscv_defines.svh"

module ama_riscv_operand_forwarding (
    // inputs
    input  logic        store_inst_dec,
    input  logic        branch_inst_dec,
    input  logic        store_inst_exe,
    input  logic        branch_inst_exe,
    input  logic        load_inst_mem,
    input  logic        dc_stalled,
    input  rf_addr_t    rs1_dec,
    input  rf_addr_t    rs2_dec,
    input  rf_addr_t    rs1_exe,
    input  rf_addr_t    rs2_exe,
    input  rf_addr_t    rd_mem,
    input  logic        rd_we_mem,
    input  alu_a_sel_t  alu_a_sel_dec,
    input  alu_b_sel_t  alu_b_sel_dec,
    input  alu_a_sel_t  alu_a_sel_exe,
    input  alu_b_sel_t  alu_b_sel_exe,
    // outputs
    output alu_a_sel_t  alu_a_sel_fwd,
    output alu_b_sel_t  alu_b_sel_fwd,
    output logic        bc_a_sel_fwd,
    output logic        bcs_b_sel_fwd,
    output logic        rf_a_sel_fwd,
    output logic        rf_b_sel_fwd,
    output logic        load_hazard_stall
);

logic rs1_dec_in_mem;
logic rs2_dec_in_mem;
logic rs1_exe_in_mem;
logic rs2_exe_in_mem;

assign rs1_dec_in_mem = (
    (rs1_dec != RF_X0_ZERO) && (rs1_dec == rd_mem) && rd_we_mem);
assign rs2_dec_in_mem = (
    (rs2_dec != RF_X0_ZERO) && (rs2_dec == rd_mem) && rd_we_mem);
assign rs1_exe_in_mem = (
    (rs1_exe != RF_X0_ZERO) && (rs1_exe == rd_mem) && rd_we_mem);
assign rs2_exe_in_mem = (
    (rs2_exe != RF_X0_ZERO) && (rs2_exe == rd_mem) && rd_we_mem);

assign load_hazard_stall =
    load_inst_mem && dc_stalled && (rs1_exe_in_mem || rs2_exe_in_mem);

// ALU operand forwarding
always_comb begin
    if (rs1_exe_in_mem && (alu_a_sel_exe == ALU_A_SEL_RS1)) begin
        alu_a_sel_fwd = ALU_A_SEL_FWD_ALU;
    end else begin
        alu_a_sel_fwd = alu_a_sel_t'({1'b0, alu_a_sel_exe});
    end
end

always_comb begin
    if (rs2_exe_in_mem && (alu_b_sel_exe == ALU_B_SEL_RS2)) begin
        alu_b_sel_fwd = ALU_B_SEL_FWD_ALU;
    end else begin
        alu_b_sel_fwd = alu_b_sel_t'({1'b0, alu_b_sel_exe});
    end
end

// Branch Compare amd store dmem operand forwarding
assign bc_a_sel_fwd = (rs1_exe_in_mem && branch_inst_exe);
assign bcs_b_sel_fwd = (rs2_exe_in_mem && (store_inst_exe || branch_inst_exe));

// RF read operand forwarding
assign rf_a_sel_fwd = (
    rs1_dec_in_mem &&
    ((alu_a_sel_dec == ALU_A_SEL_RS1) || branch_inst_dec)
);
assign rf_b_sel_fwd = (
    rs2_dec_in_mem &&
    ((alu_b_sel_dec == ALU_B_SEL_RS2) || branch_inst_dec || store_inst_dec)
);

endmodule
