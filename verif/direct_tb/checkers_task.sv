task run_checkers;
    int checker_errors_prev;
    int dummy = 0;
    begin
        checker_errors_prev = errors;
        checker_t("rst_seq_d", `CHECKER_INACTIVE, dummy, sig_chk_rst_seq_d);
        checker_t("pc", `CHECKER_ACTIVE, `DUT_CORE.pc, sig_chk_pc);
        checker_t("stall_if_id_d", `CHECKER_INACTIVE, dummy, sig_chk_stall_if_id_d);
        checker_t("imem", `CHECKER_INACTIVE, dummy, sig_chk_imem);
        checker_t("inst_ex", `CHECKER_ACTIVE, `DUT_CORE.inst_ex, sig_chk_inst_ex);
        checker_t("pc_ex", `CHECKER_ACTIVE, `DUT_CORE.pc_ex, sig_chk_pc_ex);
        checker_t("funct3_ex", `CHECKER_INACTIVE, dummy, sig_chk_funct3_ex);
        checker_t("rs1_addr_ex", `CHECKER_INACTIVE, dummy, sig_chk_rs1_addr_ex);
        checker_t("rs2_addr_ex", `CHECKER_INACTIVE, dummy, sig_chk_rs2_addr_ex);
        checker_t("rf_data_a_ex", `CHECKER_ACTIVE, `DUT_CORE.rs1_data_ex, sig_chk_rf_data_a_ex);
        checker_t("rf_data_b_ex", `CHECKER_ACTIVE, `DUT_CORE.rs2_data_ex, sig_chk_rf_data_b_ex);
        checker_t("rd_we_ex", `CHECKER_ACTIVE, `DUT_CORE.reg_we_ex, sig_chk_rd_we_ex);
        checker_t("rd_addr_ex", `CHECKER_ACTIVE, `DUT_CORE.rd_addr_ex, sig_chk_rd_addr_ex);
        checker_t("imm_gen_out_ex", `CHECKER_ACTIVE, `DUT_CORE.imm_gen_out_ex, sig_chk_imm_gen_out_ex);
        checker_t("csr_we_ex", `CHECKER_INACTIVE, dummy, sig_chk_csr_we_ex);
        checker_t("csr_ui_ex", `CHECKER_INACTIVE, dummy, sig_chk_csr_ui_ex);
        checker_t("csr_uimm_ex", `CHECKER_INACTIVE, dummy, sig_chk_csr_uimm_ex);
        checker_t("csr_dout_ex", `CHECKER_INACTIVE, dummy, sig_chk_csr_dout_ex);
        checker_t("alu_a_sel_ex", `CHECKER_INACTIVE, dummy, sig_chk_alu_a_sel_ex);
        checker_t("alu_b_sel_ex", `CHECKER_INACTIVE, dummy, sig_chk_alu_b_sel_ex);
        checker_t("alu_op_sel_ex", `CHECKER_ACTIVE, `DUT_CORE.alu_op_sel_ex, sig_chk_alu_op_sel_ex);
        checker_t("bc_a_sel_ex", `CHECKER_INACTIVE, dummy, sig_chk_bc_a_sel_ex);
        checker_t("bcs_b_sel_ex", `CHECKER_INACTIVE, dummy, sig_chk_bcs_b_sel_ex);
        checker_t("bc_uns_ex", `CHECKER_INACTIVE, dummy, sig_chk_bc_uns_ex);
        checker_t("store_inst_ex", `CHECKER_INACTIVE, dummy, sig_chk_store_inst_ex);
        checker_t("branch_inst_ex", `CHECKER_INACTIVE, dummy, sig_chk_branch_inst_ex);
        checker_t("jump_inst_ex", `CHECKER_INACTIVE, dummy, sig_chk_jump_inst_ex);
        checker_t("dmem_en_id", `CHECKER_INACTIVE, dummy, sig_chk_dmem_en_id);
        checker_t("load_sm_en_ex", `CHECKER_INACTIVE, dummy, sig_chk_load_sm_en_ex);
        checker_t("wb_sel_ex", `CHECKER_INACTIVE, dummy, sig_chk_wb_sel_ex);
        checker_t("inst_mem", `CHECKER_INACTIVE, dummy, sig_chk_inst_mem);
        checker_t("pc_mem", `CHECKER_INACTIVE, dummy, sig_chk_pc_mem);
        checker_t("alu_mem", `CHECKER_ACTIVE, `DUT_CORE.alu_out_mem, sig_chk_alu_mem);
        checker_t("alu_in_a_mem", `CHECKER_INACTIVE, dummy, sig_chk_alu_in_a_mem);
        checker_t("funct3_mem", `CHECKER_INACTIVE, dummy, sig_chk_funct3_mem);
        checker_t("rs1_addr_mem", `CHECKER_INACTIVE, dummy, sig_chk_rs1_addr_mem);
        checker_t("rs2_addr_mem", `CHECKER_INACTIVE, dummy, sig_chk_rs2_addr_mem);
        checker_t("rd_addr_mem", `CHECKER_INACTIVE, dummy, sig_chk_rd_addr_mem);
        checker_t("rd_we_mem", `CHECKER_ACTIVE, `DUT_CORE.reg_we_mem, sig_chk_rd_we_mem);
        checker_t("csr_we_mem", `CHECKER_INACTIVE, dummy, sig_chk_csr_we_mem);
        checker_t("csr_ui_mem", `CHECKER_INACTIVE, dummy, sig_chk_csr_ui_mem);
        checker_t("csr_uimm_mem", `CHECKER_INACTIVE, dummy, sig_chk_csr_uimm_mem);
        checker_t("csr_dout_mem", `CHECKER_INACTIVE, dummy, sig_chk_csr_dout_mem);
        checker_t("dmem_dout", `CHECKER_INACTIVE, dummy, sig_chk_dmem_dout);
        checker_t("load_sm_en_mem", `CHECKER_INACTIVE, dummy, sig_chk_load_sm_en_mem);
        checker_t("wb_sel_mem", `CHECKER_INACTIVE, dummy, sig_chk_wb_sel_mem);
        checker_t("inst_wb", `CHECKER_ACTIVE, `DUT_CORE.inst_wb, sig_chk_inst_wb);
        checker_t("x1", `CHECKER_ACTIVE, `DUT_RF.x1_ra, sig_chk_x1);
        checker_t("x2", `CHECKER_ACTIVE, `DUT_RF.x2_sp, sig_chk_x2);
        checker_t("x3", `CHECKER_ACTIVE, `DUT_RF.x3_gp, sig_chk_x3);
        checker_t("x4", `CHECKER_ACTIVE, `DUT_RF.x4_tp, sig_chk_x4);
        checker_t("x5", `CHECKER_ACTIVE, `DUT_RF.x5_t0, sig_chk_x5);
        checker_t("x6", `CHECKER_ACTIVE, `DUT_RF.x6_t1, sig_chk_x6);
        checker_t("x7", `CHECKER_ACTIVE, `DUT_RF.x7_t2, sig_chk_x7);
        checker_t("x8", `CHECKER_ACTIVE, `DUT_RF.x8_s0, sig_chk_x8);
        checker_t("x9", `CHECKER_ACTIVE, `DUT_RF.x9_s1, sig_chk_x9);
        checker_t("x10", `CHECKER_ACTIVE, `DUT_RF.x10_a0, sig_chk_x10);
        checker_t("x11", `CHECKER_ACTIVE, `DUT_RF.x11_a1, sig_chk_x11);
        checker_t("x12", `CHECKER_ACTIVE, `DUT_RF.x12_a2, sig_chk_x12);
        checker_t("x13", `CHECKER_ACTIVE, `DUT_RF.x13_a3, sig_chk_x13);
        checker_t("x14", `CHECKER_ACTIVE, `DUT_RF.x14_a4, sig_chk_x14);
        checker_t("x15", `CHECKER_ACTIVE, `DUT_RF.x15_a5, sig_chk_x15);
        checker_t("x16", `CHECKER_ACTIVE, `DUT_RF.x16_a6, sig_chk_x16);
        checker_t("x17", `CHECKER_ACTIVE, `DUT_RF.x17_a7, sig_chk_x17);
        checker_t("x18", `CHECKER_ACTIVE, `DUT_RF.x18_s2, sig_chk_x18);
        checker_t("x19", `CHECKER_ACTIVE, `DUT_RF.x19_s3, sig_chk_x19);
        checker_t("x20", `CHECKER_ACTIVE, `DUT_RF.x20_s4, sig_chk_x20);
        checker_t("x21", `CHECKER_ACTIVE, `DUT_RF.x21_s5, sig_chk_x21);
        checker_t("x22", `CHECKER_ACTIVE, `DUT_RF.x22_s6, sig_chk_x22);
        checker_t("x23", `CHECKER_ACTIVE, `DUT_RF.x23_s7, sig_chk_x23);
        checker_t("x24", `CHECKER_ACTIVE, `DUT_RF.x24_s8, sig_chk_x24);
        checker_t("x25", `CHECKER_ACTIVE, `DUT_RF.x25_s9, sig_chk_x25);
        checker_t("x26", `CHECKER_ACTIVE, `DUT_RF.x26_s10, sig_chk_x26);
        checker_t("x27", `CHECKER_ACTIVE, `DUT_RF.x27_s11, sig_chk_x27);
        checker_t("x28", `CHECKER_ACTIVE, `DUT_RF.x28_t3, sig_chk_x28);
        checker_t("x29", `CHECKER_ACTIVE, `DUT_RF.x29_t4, sig_chk_x29);
        checker_t("x30", `CHECKER_ACTIVE, `DUT_RF.x30_t5, sig_chk_x30);
        checker_t("x31", `CHECKER_ACTIVE, `DUT_RF.x31_t6, sig_chk_x31);
        checker_t("tohost", `CHECKER_ACTIVE, `DUT_CORE.tohost, sig_chk_tohost);
        checker_t("imem_addr", `CHECKER_ACTIVE, `DUT_CORE.imem_addr, sig_chk_imem_addr);
        checker_t("inst_id", `CHECKER_ACTIVE, `DUT_CORE.inst_id, sig_chk_inst_id);
        checker_t("alu_out", `CHECKER_ACTIVE, `DUT_CORE.alu_out, sig_chk_alu_out);
        errors_for_wave = (errors != checker_errors_prev);
    end // main task body
endtask // run_checkers
