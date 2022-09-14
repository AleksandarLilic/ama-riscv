
integer fd_chk_rst_seq_d;
reg [31:0] chk_rst_seq_d;
initial begin    
    fd_chk_rst_seq_d = $fopen({`STIM_PATH, `"/chk_rst_seq_d`", `".txt`"}, "r");
    if (fd_chk_rst_seq_d) $display("File chk_rst_seq_d opened: %0d", fd_chk_rst_seq_d);
    else $display("File 'chk_rst_seq_d' could not be opened: %0d", fd_chk_rst_seq_d);
    
    while (! $feof(fd_chk_rst_seq_d)) begin
        $fscanf(fd_chk_rst_seq_d, "%d\n", chk_rst_seq_d);
        @(posedge clk); 
    end
end

integer fd_chk_pc;
reg [31:0] chk_pc;
initial begin    
    fd_chk_pc = $fopen({`STIM_PATH, `"/chk_pc`", `".txt`"}, "r");
    if (fd_chk_pc) $display("File chk_pc opened: %0d", fd_chk_pc);
    else $display("File 'chk_pc' could not be opened: %0d", fd_chk_pc);
    
    while (! $feof(fd_chk_pc)) begin
        $fscanf(fd_chk_pc, "%d\n", chk_pc);
        @(posedge clk); 
    end
end

integer fd_chk_stall_if_id_d;
reg [31:0] chk_stall_if_id_d;
initial begin    
    fd_chk_stall_if_id_d = $fopen({`STIM_PATH, `"/chk_stall_if_id_d`", `".txt`"}, "r");
    if (fd_chk_stall_if_id_d) $display("File chk_stall_if_id_d opened: %0d", fd_chk_stall_if_id_d);
    else $display("File 'chk_stall_if_id_d' could not be opened: %0d", fd_chk_stall_if_id_d);
    
    while (! $feof(fd_chk_stall_if_id_d)) begin
        $fscanf(fd_chk_stall_if_id_d, "%d\n", chk_stall_if_id_d);
        @(posedge clk); 
    end
end

integer fd_chk_imem;
reg [31:0] chk_imem;
initial begin    
    fd_chk_imem = $fopen({`STIM_PATH, `"/chk_imem`", `".txt`"}, "r");
    if (fd_chk_imem) $display("File chk_imem opened: %0d", fd_chk_imem);
    else $display("File 'chk_imem' could not be opened: %0d", fd_chk_imem);
    
    while (! $feof(fd_chk_imem)) begin
        $fscanf(fd_chk_imem, "%d\n", chk_imem);
        @(posedge clk); 
    end
end

integer fd_chk_inst_ex;
reg [31:0] chk_inst_ex;
initial begin    
    fd_chk_inst_ex = $fopen({`STIM_PATH, `"/chk_inst_ex`", `".txt`"}, "r");
    if (fd_chk_inst_ex) $display("File chk_inst_ex opened: %0d", fd_chk_inst_ex);
    else $display("File 'chk_inst_ex' could not be opened: %0d", fd_chk_inst_ex);
    
    while (! $feof(fd_chk_inst_ex)) begin
        $fscanf(fd_chk_inst_ex, "%d\n", chk_inst_ex);
        @(posedge clk); 
    end
end

integer fd_chk_pc_ex;
reg [31:0] chk_pc_ex;
initial begin    
    fd_chk_pc_ex = $fopen({`STIM_PATH, `"/chk_pc_ex`", `".txt`"}, "r");
    if (fd_chk_pc_ex) $display("File chk_pc_ex opened: %0d", fd_chk_pc_ex);
    else $display("File 'chk_pc_ex' could not be opened: %0d", fd_chk_pc_ex);
    
    while (! $feof(fd_chk_pc_ex)) begin
        $fscanf(fd_chk_pc_ex, "%d\n", chk_pc_ex);
        @(posedge clk); 
    end
end

integer fd_chk_funct3_ex;
reg [31:0] chk_funct3_ex;
initial begin    
    fd_chk_funct3_ex = $fopen({`STIM_PATH, `"/chk_funct3_ex`", `".txt`"}, "r");
    if (fd_chk_funct3_ex) $display("File chk_funct3_ex opened: %0d", fd_chk_funct3_ex);
    else $display("File 'chk_funct3_ex' could not be opened: %0d", fd_chk_funct3_ex);
    
    while (! $feof(fd_chk_funct3_ex)) begin
        $fscanf(fd_chk_funct3_ex, "%d\n", chk_funct3_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rs1_addr_ex;
reg [31:0] chk_rs1_addr_ex;
initial begin    
    fd_chk_rs1_addr_ex = $fopen({`STIM_PATH, `"/chk_rs1_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rs1_addr_ex) $display("File chk_rs1_addr_ex opened: %0d", fd_chk_rs1_addr_ex);
    else $display("File 'chk_rs1_addr_ex' could not be opened: %0d", fd_chk_rs1_addr_ex);
    
    while (! $feof(fd_chk_rs1_addr_ex)) begin
        $fscanf(fd_chk_rs1_addr_ex, "%d\n", chk_rs1_addr_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rs2_addr_ex;
reg [31:0] chk_rs2_addr_ex;
initial begin    
    fd_chk_rs2_addr_ex = $fopen({`STIM_PATH, `"/chk_rs2_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rs2_addr_ex) $display("File chk_rs2_addr_ex opened: %0d", fd_chk_rs2_addr_ex);
    else $display("File 'chk_rs2_addr_ex' could not be opened: %0d", fd_chk_rs2_addr_ex);
    
    while (! $feof(fd_chk_rs2_addr_ex)) begin
        $fscanf(fd_chk_rs2_addr_ex, "%d\n", chk_rs2_addr_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rf_data_a_ex;
reg [31:0] chk_rf_data_a_ex;
initial begin    
    fd_chk_rf_data_a_ex = $fopen({`STIM_PATH, `"/chk_rf_data_a_ex`", `".txt`"}, "r");
    if (fd_chk_rf_data_a_ex) $display("File chk_rf_data_a_ex opened: %0d", fd_chk_rf_data_a_ex);
    else $display("File 'chk_rf_data_a_ex' could not be opened: %0d", fd_chk_rf_data_a_ex);
    
    while (! $feof(fd_chk_rf_data_a_ex)) begin
        $fscanf(fd_chk_rf_data_a_ex, "%d\n", chk_rf_data_a_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rf_data_b_ex;
reg [31:0] chk_rf_data_b_ex;
initial begin    
    fd_chk_rf_data_b_ex = $fopen({`STIM_PATH, `"/chk_rf_data_b_ex`", `".txt`"}, "r");
    if (fd_chk_rf_data_b_ex) $display("File chk_rf_data_b_ex opened: %0d", fd_chk_rf_data_b_ex);
    else $display("File 'chk_rf_data_b_ex' could not be opened: %0d", fd_chk_rf_data_b_ex);
    
    while (! $feof(fd_chk_rf_data_b_ex)) begin
        $fscanf(fd_chk_rf_data_b_ex, "%d\n", chk_rf_data_b_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rd_we_ex;
reg [31:0] chk_rd_we_ex;
initial begin    
    fd_chk_rd_we_ex = $fopen({`STIM_PATH, `"/chk_rd_we_ex`", `".txt`"}, "r");
    if (fd_chk_rd_we_ex) $display("File chk_rd_we_ex opened: %0d", fd_chk_rd_we_ex);
    else $display("File 'chk_rd_we_ex' could not be opened: %0d", fd_chk_rd_we_ex);
    
    while (! $feof(fd_chk_rd_we_ex)) begin
        $fscanf(fd_chk_rd_we_ex, "%d\n", chk_rd_we_ex);
        @(posedge clk); 
    end
end

integer fd_chk_rd_addr_ex;
reg [31:0] chk_rd_addr_ex;
initial begin    
    fd_chk_rd_addr_ex = $fopen({`STIM_PATH, `"/chk_rd_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rd_addr_ex) $display("File chk_rd_addr_ex opened: %0d", fd_chk_rd_addr_ex);
    else $display("File 'chk_rd_addr_ex' could not be opened: %0d", fd_chk_rd_addr_ex);
    
    while (! $feof(fd_chk_rd_addr_ex)) begin
        $fscanf(fd_chk_rd_addr_ex, "%d\n", chk_rd_addr_ex);
        @(posedge clk); 
    end
end

integer fd_chk_imm_gen_out_ex;
reg [31:0] chk_imm_gen_out_ex;
initial begin    
    fd_chk_imm_gen_out_ex = $fopen({`STIM_PATH, `"/chk_imm_gen_out_ex`", `".txt`"}, "r");
    if (fd_chk_imm_gen_out_ex) $display("File chk_imm_gen_out_ex opened: %0d", fd_chk_imm_gen_out_ex);
    else $display("File 'chk_imm_gen_out_ex' could not be opened: %0d", fd_chk_imm_gen_out_ex);
    
    while (! $feof(fd_chk_imm_gen_out_ex)) begin
        $fscanf(fd_chk_imm_gen_out_ex, "%d\n", chk_imm_gen_out_ex);
        @(posedge clk); 
    end
end

integer fd_chk_csr_we_ex;
reg [31:0] chk_csr_we_ex;
initial begin    
    fd_chk_csr_we_ex = $fopen({`STIM_PATH, `"/chk_csr_we_ex`", `".txt`"}, "r");
    if (fd_chk_csr_we_ex) $display("File chk_csr_we_ex opened: %0d", fd_chk_csr_we_ex);
    else $display("File 'chk_csr_we_ex' could not be opened: %0d", fd_chk_csr_we_ex);
    
    while (! $feof(fd_chk_csr_we_ex)) begin
        $fscanf(fd_chk_csr_we_ex, "%d\n", chk_csr_we_ex);
        @(posedge clk); 
    end
end

integer fd_chk_csr_ui_ex;
reg [31:0] chk_csr_ui_ex;
initial begin    
    fd_chk_csr_ui_ex = $fopen({`STIM_PATH, `"/chk_csr_ui_ex`", `".txt`"}, "r");
    if (fd_chk_csr_ui_ex) $display("File chk_csr_ui_ex opened: %0d", fd_chk_csr_ui_ex);
    else $display("File 'chk_csr_ui_ex' could not be opened: %0d", fd_chk_csr_ui_ex);
    
    while (! $feof(fd_chk_csr_ui_ex)) begin
        $fscanf(fd_chk_csr_ui_ex, "%d\n", chk_csr_ui_ex);
        @(posedge clk); 
    end
end

integer fd_chk_csr_uimm_ex;
reg [31:0] chk_csr_uimm_ex;
initial begin    
    fd_chk_csr_uimm_ex = $fopen({`STIM_PATH, `"/chk_csr_uimm_ex`", `".txt`"}, "r");
    if (fd_chk_csr_uimm_ex) $display("File chk_csr_uimm_ex opened: %0d", fd_chk_csr_uimm_ex);
    else $display("File 'chk_csr_uimm_ex' could not be opened: %0d", fd_chk_csr_uimm_ex);
    
    while (! $feof(fd_chk_csr_uimm_ex)) begin
        $fscanf(fd_chk_csr_uimm_ex, "%d\n", chk_csr_uimm_ex);
        @(posedge clk); 
    end
end

integer fd_chk_csr_dout_ex;
reg [31:0] chk_csr_dout_ex;
initial begin    
    fd_chk_csr_dout_ex = $fopen({`STIM_PATH, `"/chk_csr_dout_ex`", `".txt`"}, "r");
    if (fd_chk_csr_dout_ex) $display("File chk_csr_dout_ex opened: %0d", fd_chk_csr_dout_ex);
    else $display("File 'chk_csr_dout_ex' could not be opened: %0d", fd_chk_csr_dout_ex);
    
    while (! $feof(fd_chk_csr_dout_ex)) begin
        $fscanf(fd_chk_csr_dout_ex, "%d\n", chk_csr_dout_ex);
        @(posedge clk); 
    end
end

integer fd_chk_alu_a_sel_ex;
reg [31:0] chk_alu_a_sel_ex;
initial begin    
    fd_chk_alu_a_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_a_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_a_sel_ex) $display("File chk_alu_a_sel_ex opened: %0d", fd_chk_alu_a_sel_ex);
    else $display("File 'chk_alu_a_sel_ex' could not be opened: %0d", fd_chk_alu_a_sel_ex);
    
    while (! $feof(fd_chk_alu_a_sel_ex)) begin
        $fscanf(fd_chk_alu_a_sel_ex, "%d\n", chk_alu_a_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_alu_b_sel_ex;
reg [31:0] chk_alu_b_sel_ex;
initial begin    
    fd_chk_alu_b_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_b_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_b_sel_ex) $display("File chk_alu_b_sel_ex opened: %0d", fd_chk_alu_b_sel_ex);
    else $display("File 'chk_alu_b_sel_ex' could not be opened: %0d", fd_chk_alu_b_sel_ex);
    
    while (! $feof(fd_chk_alu_b_sel_ex)) begin
        $fscanf(fd_chk_alu_b_sel_ex, "%d\n", chk_alu_b_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_alu_op_sel_ex;
reg [31:0] chk_alu_op_sel_ex;
initial begin    
    fd_chk_alu_op_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_op_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_op_sel_ex) $display("File chk_alu_op_sel_ex opened: %0d", fd_chk_alu_op_sel_ex);
    else $display("File 'chk_alu_op_sel_ex' could not be opened: %0d", fd_chk_alu_op_sel_ex);
    
    while (! $feof(fd_chk_alu_op_sel_ex)) begin
        $fscanf(fd_chk_alu_op_sel_ex, "%d\n", chk_alu_op_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_bc_a_sel_ex;
reg [31:0] chk_bc_a_sel_ex;
initial begin    
    fd_chk_bc_a_sel_ex = $fopen({`STIM_PATH, `"/chk_bc_a_sel_ex`", `".txt`"}, "r");
    if (fd_chk_bc_a_sel_ex) $display("File chk_bc_a_sel_ex opened: %0d", fd_chk_bc_a_sel_ex);
    else $display("File 'chk_bc_a_sel_ex' could not be opened: %0d", fd_chk_bc_a_sel_ex);
    
    while (! $feof(fd_chk_bc_a_sel_ex)) begin
        $fscanf(fd_chk_bc_a_sel_ex, "%d\n", chk_bc_a_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_bcs_b_sel_ex;
reg [31:0] chk_bcs_b_sel_ex;
initial begin    
    fd_chk_bcs_b_sel_ex = $fopen({`STIM_PATH, `"/chk_bcs_b_sel_ex`", `".txt`"}, "r");
    if (fd_chk_bcs_b_sel_ex) $display("File chk_bcs_b_sel_ex opened: %0d", fd_chk_bcs_b_sel_ex);
    else $display("File 'chk_bcs_b_sel_ex' could not be opened: %0d", fd_chk_bcs_b_sel_ex);
    
    while (! $feof(fd_chk_bcs_b_sel_ex)) begin
        $fscanf(fd_chk_bcs_b_sel_ex, "%d\n", chk_bcs_b_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_bc_uns_ex;
reg [31:0] chk_bc_uns_ex;
initial begin    
    fd_chk_bc_uns_ex = $fopen({`STIM_PATH, `"/chk_bc_uns_ex`", `".txt`"}, "r");
    if (fd_chk_bc_uns_ex) $display("File chk_bc_uns_ex opened: %0d", fd_chk_bc_uns_ex);
    else $display("File 'chk_bc_uns_ex' could not be opened: %0d", fd_chk_bc_uns_ex);
    
    while (! $feof(fd_chk_bc_uns_ex)) begin
        $fscanf(fd_chk_bc_uns_ex, "%d\n", chk_bc_uns_ex);
        @(posedge clk); 
    end
end

integer fd_chk_store_inst_ex;
reg [31:0] chk_store_inst_ex;
initial begin    
    fd_chk_store_inst_ex = $fopen({`STIM_PATH, `"/chk_store_inst_ex`", `".txt`"}, "r");
    if (fd_chk_store_inst_ex) $display("File chk_store_inst_ex opened: %0d", fd_chk_store_inst_ex);
    else $display("File 'chk_store_inst_ex' could not be opened: %0d", fd_chk_store_inst_ex);
    
    while (! $feof(fd_chk_store_inst_ex)) begin
        $fscanf(fd_chk_store_inst_ex, "%d\n", chk_store_inst_ex);
        @(posedge clk); 
    end
end

integer fd_chk_branch_inst_ex;
reg [31:0] chk_branch_inst_ex;
initial begin    
    fd_chk_branch_inst_ex = $fopen({`STIM_PATH, `"/chk_branch_inst_ex`", `".txt`"}, "r");
    if (fd_chk_branch_inst_ex) $display("File chk_branch_inst_ex opened: %0d", fd_chk_branch_inst_ex);
    else $display("File 'chk_branch_inst_ex' could not be opened: %0d", fd_chk_branch_inst_ex);
    
    while (! $feof(fd_chk_branch_inst_ex)) begin
        $fscanf(fd_chk_branch_inst_ex, "%d\n", chk_branch_inst_ex);
        @(posedge clk); 
    end
end

integer fd_chk_jump_inst_ex;
reg [31:0] chk_jump_inst_ex;
initial begin    
    fd_chk_jump_inst_ex = $fopen({`STIM_PATH, `"/chk_jump_inst_ex`", `".txt`"}, "r");
    if (fd_chk_jump_inst_ex) $display("File chk_jump_inst_ex opened: %0d", fd_chk_jump_inst_ex);
    else $display("File 'chk_jump_inst_ex' could not be opened: %0d", fd_chk_jump_inst_ex);
    
    while (! $feof(fd_chk_jump_inst_ex)) begin
        $fscanf(fd_chk_jump_inst_ex, "%d\n", chk_jump_inst_ex);
        @(posedge clk); 
    end
end

integer fd_chk_dmem_en_id;
reg [31:0] chk_dmem_en_id;
initial begin    
    fd_chk_dmem_en_id = $fopen({`STIM_PATH, `"/chk_dmem_en_id`", `".txt`"}, "r");
    if (fd_chk_dmem_en_id) $display("File chk_dmem_en_id opened: %0d", fd_chk_dmem_en_id);
    else $display("File 'chk_dmem_en_id' could not be opened: %0d", fd_chk_dmem_en_id);
    
    while (! $feof(fd_chk_dmem_en_id)) begin
        $fscanf(fd_chk_dmem_en_id, "%d\n", chk_dmem_en_id);
        @(posedge clk); 
    end
end

integer fd_chk_load_sm_en_ex;
reg [31:0] chk_load_sm_en_ex;
initial begin    
    fd_chk_load_sm_en_ex = $fopen({`STIM_PATH, `"/chk_load_sm_en_ex`", `".txt`"}, "r");
    if (fd_chk_load_sm_en_ex) $display("File chk_load_sm_en_ex opened: %0d", fd_chk_load_sm_en_ex);
    else $display("File 'chk_load_sm_en_ex' could not be opened: %0d", fd_chk_load_sm_en_ex);
    
    while (! $feof(fd_chk_load_sm_en_ex)) begin
        $fscanf(fd_chk_load_sm_en_ex, "%d\n", chk_load_sm_en_ex);
        @(posedge clk); 
    end
end

integer fd_chk_wb_sel_ex;
reg [31:0] chk_wb_sel_ex;
initial begin    
    fd_chk_wb_sel_ex = $fopen({`STIM_PATH, `"/chk_wb_sel_ex`", `".txt`"}, "r");
    if (fd_chk_wb_sel_ex) $display("File chk_wb_sel_ex opened: %0d", fd_chk_wb_sel_ex);
    else $display("File 'chk_wb_sel_ex' could not be opened: %0d", fd_chk_wb_sel_ex);
    
    while (! $feof(fd_chk_wb_sel_ex)) begin
        $fscanf(fd_chk_wb_sel_ex, "%d\n", chk_wb_sel_ex);
        @(posedge clk); 
    end
end

integer fd_chk_inst_mem;
reg [31:0] chk_inst_mem;
initial begin    
    fd_chk_inst_mem = $fopen({`STIM_PATH, `"/chk_inst_mem`", `".txt`"}, "r");
    if (fd_chk_inst_mem) $display("File chk_inst_mem opened: %0d", fd_chk_inst_mem);
    else $display("File 'chk_inst_mem' could not be opened: %0d", fd_chk_inst_mem);
    
    while (! $feof(fd_chk_inst_mem)) begin
        $fscanf(fd_chk_inst_mem, "%d\n", chk_inst_mem);
        @(posedge clk); 
    end
end

integer fd_chk_pc_mem;
reg [31:0] chk_pc_mem;
initial begin    
    fd_chk_pc_mem = $fopen({`STIM_PATH, `"/chk_pc_mem`", `".txt`"}, "r");
    if (fd_chk_pc_mem) $display("File chk_pc_mem opened: %0d", fd_chk_pc_mem);
    else $display("File 'chk_pc_mem' could not be opened: %0d", fd_chk_pc_mem);
    
    while (! $feof(fd_chk_pc_mem)) begin
        $fscanf(fd_chk_pc_mem, "%d\n", chk_pc_mem);
        @(posedge clk); 
    end
end

integer fd_chk_alu_mem;
reg [31:0] chk_alu_mem;
initial begin    
    fd_chk_alu_mem = $fopen({`STIM_PATH, `"/chk_alu_mem`", `".txt`"}, "r");
    if (fd_chk_alu_mem) $display("File chk_alu_mem opened: %0d", fd_chk_alu_mem);
    else $display("File 'chk_alu_mem' could not be opened: %0d", fd_chk_alu_mem);
    
    while (! $feof(fd_chk_alu_mem)) begin
        $fscanf(fd_chk_alu_mem, "%d\n", chk_alu_mem);
        @(posedge clk); 
    end
end

integer fd_chk_funct3_mem;
reg [31:0] chk_funct3_mem;
initial begin    
    fd_chk_funct3_mem = $fopen({`STIM_PATH, `"/chk_funct3_mem`", `".txt`"}, "r");
    if (fd_chk_funct3_mem) $display("File chk_funct3_mem opened: %0d", fd_chk_funct3_mem);
    else $display("File 'chk_funct3_mem' could not be opened: %0d", fd_chk_funct3_mem);
    
    while (! $feof(fd_chk_funct3_mem)) begin
        $fscanf(fd_chk_funct3_mem, "%d\n", chk_funct3_mem);
        @(posedge clk); 
    end
end

integer fd_chk_rs1_addr_mem;
reg [31:0] chk_rs1_addr_mem;
initial begin    
    fd_chk_rs1_addr_mem = $fopen({`STIM_PATH, `"/chk_rs1_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rs1_addr_mem) $display("File chk_rs1_addr_mem opened: %0d", fd_chk_rs1_addr_mem);
    else $display("File 'chk_rs1_addr_mem' could not be opened: %0d", fd_chk_rs1_addr_mem);
    
    while (! $feof(fd_chk_rs1_addr_mem)) begin
        $fscanf(fd_chk_rs1_addr_mem, "%d\n", chk_rs1_addr_mem);
        @(posedge clk); 
    end
end

integer fd_chk_rs2_addr_mem;
reg [31:0] chk_rs2_addr_mem;
initial begin    
    fd_chk_rs2_addr_mem = $fopen({`STIM_PATH, `"/chk_rs2_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rs2_addr_mem) $display("File chk_rs2_addr_mem opened: %0d", fd_chk_rs2_addr_mem);
    else $display("File 'chk_rs2_addr_mem' could not be opened: %0d", fd_chk_rs2_addr_mem);
    
    while (! $feof(fd_chk_rs2_addr_mem)) begin
        $fscanf(fd_chk_rs2_addr_mem, "%d\n", chk_rs2_addr_mem);
        @(posedge clk); 
    end
end

integer fd_chk_rd_addr_mem;
reg [31:0] chk_rd_addr_mem;
initial begin    
    fd_chk_rd_addr_mem = $fopen({`STIM_PATH, `"/chk_rd_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rd_addr_mem) $display("File chk_rd_addr_mem opened: %0d", fd_chk_rd_addr_mem);
    else $display("File 'chk_rd_addr_mem' could not be opened: %0d", fd_chk_rd_addr_mem);
    
    while (! $feof(fd_chk_rd_addr_mem)) begin
        $fscanf(fd_chk_rd_addr_mem, "%d\n", chk_rd_addr_mem);
        @(posedge clk); 
    end
end

integer fd_chk_rd_we_mem;
reg [31:0] chk_rd_we_mem;
initial begin    
    fd_chk_rd_we_mem = $fopen({`STIM_PATH, `"/chk_rd_we_mem`", `".txt`"}, "r");
    if (fd_chk_rd_we_mem) $display("File chk_rd_we_mem opened: %0d", fd_chk_rd_we_mem);
    else $display("File 'chk_rd_we_mem' could not be opened: %0d", fd_chk_rd_we_mem);
    
    while (! $feof(fd_chk_rd_we_mem)) begin
        $fscanf(fd_chk_rd_we_mem, "%d\n", chk_rd_we_mem);
        @(posedge clk); 
    end
end

integer fd_chk_csr_we_mem;
reg [31:0] chk_csr_we_mem;
initial begin    
    fd_chk_csr_we_mem = $fopen({`STIM_PATH, `"/chk_csr_we_mem`", `".txt`"}, "r");
    if (fd_chk_csr_we_mem) $display("File chk_csr_we_mem opened: %0d", fd_chk_csr_we_mem);
    else $display("File 'chk_csr_we_mem' could not be opened: %0d", fd_chk_csr_we_mem);
    
    while (! $feof(fd_chk_csr_we_mem)) begin
        $fscanf(fd_chk_csr_we_mem, "%d\n", chk_csr_we_mem);
        @(posedge clk); 
    end
end

integer fd_chk_csr_ui_mem;
reg [31:0] chk_csr_ui_mem;
initial begin    
    fd_chk_csr_ui_mem = $fopen({`STIM_PATH, `"/chk_csr_ui_mem`", `".txt`"}, "r");
    if (fd_chk_csr_ui_mem) $display("File chk_csr_ui_mem opened: %0d", fd_chk_csr_ui_mem);
    else $display("File 'chk_csr_ui_mem' could not be opened: %0d", fd_chk_csr_ui_mem);
    
    while (! $feof(fd_chk_csr_ui_mem)) begin
        $fscanf(fd_chk_csr_ui_mem, "%d\n", chk_csr_ui_mem);
        @(posedge clk); 
    end
end

integer fd_chk_csr_uimm_mem;
reg [31:0] chk_csr_uimm_mem;
initial begin    
    fd_chk_csr_uimm_mem = $fopen({`STIM_PATH, `"/chk_csr_uimm_mem`", `".txt`"}, "r");
    if (fd_chk_csr_uimm_mem) $display("File chk_csr_uimm_mem opened: %0d", fd_chk_csr_uimm_mem);
    else $display("File 'chk_csr_uimm_mem' could not be opened: %0d", fd_chk_csr_uimm_mem);
    
    while (! $feof(fd_chk_csr_uimm_mem)) begin
        $fscanf(fd_chk_csr_uimm_mem, "%d\n", chk_csr_uimm_mem);
        @(posedge clk); 
    end
end

integer fd_chk_csr_dout_mem;
reg [31:0] chk_csr_dout_mem;
initial begin    
    fd_chk_csr_dout_mem = $fopen({`STIM_PATH, `"/chk_csr_dout_mem`", `".txt`"}, "r");
    if (fd_chk_csr_dout_mem) $display("File chk_csr_dout_mem opened: %0d", fd_chk_csr_dout_mem);
    else $display("File 'chk_csr_dout_mem' could not be opened: %0d", fd_chk_csr_dout_mem);
    
    while (! $feof(fd_chk_csr_dout_mem)) begin
        $fscanf(fd_chk_csr_dout_mem, "%d\n", chk_csr_dout_mem);
        @(posedge clk); 
    end
end

integer fd_chk_dmem_dout;
reg [31:0] chk_dmem_dout;
initial begin    
    fd_chk_dmem_dout = $fopen({`STIM_PATH, `"/chk_dmem_dout`", `".txt`"}, "r");
    if (fd_chk_dmem_dout) $display("File chk_dmem_dout opened: %0d", fd_chk_dmem_dout);
    else $display("File 'chk_dmem_dout' could not be opened: %0d", fd_chk_dmem_dout);
    
    while (! $feof(fd_chk_dmem_dout)) begin
        $fscanf(fd_chk_dmem_dout, "%d\n", chk_dmem_dout);
        @(posedge clk); 
    end
end

integer fd_chk_load_sm_en_mem;
reg [31:0] chk_load_sm_en_mem;
initial begin    
    fd_chk_load_sm_en_mem = $fopen({`STIM_PATH, `"/chk_load_sm_en_mem`", `".txt`"}, "r");
    if (fd_chk_load_sm_en_mem) $display("File chk_load_sm_en_mem opened: %0d", fd_chk_load_sm_en_mem);
    else $display("File 'chk_load_sm_en_mem' could not be opened: %0d", fd_chk_load_sm_en_mem);
    
    while (! $feof(fd_chk_load_sm_en_mem)) begin
        $fscanf(fd_chk_load_sm_en_mem, "%d\n", chk_load_sm_en_mem);
        @(posedge clk); 
    end
end

integer fd_chk_wb_sel_mem;
reg [31:0] chk_wb_sel_mem;
initial begin    
    fd_chk_wb_sel_mem = $fopen({`STIM_PATH, `"/chk_wb_sel_mem`", `".txt`"}, "r");
    if (fd_chk_wb_sel_mem) $display("File chk_wb_sel_mem opened: %0d", fd_chk_wb_sel_mem);
    else $display("File 'chk_wb_sel_mem' could not be opened: %0d", fd_chk_wb_sel_mem);
    
    while (! $feof(fd_chk_wb_sel_mem)) begin
        $fscanf(fd_chk_wb_sel_mem, "%d\n", chk_wb_sel_mem);
        @(posedge clk); 
    end
end

integer fd_chk_inst_wb;
reg [31:0] chk_inst_wb;
initial begin    
    fd_chk_inst_wb = $fopen({`STIM_PATH, `"/chk_inst_wb`", `".txt`"}, "r");
    if (fd_chk_inst_wb) $display("File chk_inst_wb opened: %0d", fd_chk_inst_wb);
    else $display("File 'chk_inst_wb' could not be opened: %0d", fd_chk_inst_wb);
    
    while (! $feof(fd_chk_inst_wb)) begin
        $fscanf(fd_chk_inst_wb, "%d\n", chk_inst_wb);
        @(posedge clk); 
    end
end

integer fd_chk_x1;
reg [31:0] chk_x1;
initial begin    
    fd_chk_x1 = $fopen({`STIM_PATH, `"/chk_x1`", `".txt`"}, "r");
    if (fd_chk_x1) $display("File chk_x1 opened: %0d", fd_chk_x1);
    else $display("File 'chk_x1' could not be opened: %0d", fd_chk_x1);
    
    while (! $feof(fd_chk_x1)) begin
        $fscanf(fd_chk_x1, "%d\n", chk_x1);
        @(posedge clk); 
    end
end

integer fd_chk_x2;
reg [31:0] chk_x2;
initial begin    
    fd_chk_x2 = $fopen({`STIM_PATH, `"/chk_x2`", `".txt`"}, "r");
    if (fd_chk_x2) $display("File chk_x2 opened: %0d", fd_chk_x2);
    else $display("File 'chk_x2' could not be opened: %0d", fd_chk_x2);
    
    while (! $feof(fd_chk_x2)) begin
        $fscanf(fd_chk_x2, "%d\n", chk_x2);
        @(posedge clk); 
    end
end

integer fd_chk_x3;
reg [31:0] chk_x3;
initial begin    
    fd_chk_x3 = $fopen({`STIM_PATH, `"/chk_x3`", `".txt`"}, "r");
    if (fd_chk_x3) $display("File chk_x3 opened: %0d", fd_chk_x3);
    else $display("File 'chk_x3' could not be opened: %0d", fd_chk_x3);
    
    while (! $feof(fd_chk_x3)) begin
        $fscanf(fd_chk_x3, "%d\n", chk_x3);
        @(posedge clk); 
    end
end

integer fd_chk_x4;
reg [31:0] chk_x4;
initial begin    
    fd_chk_x4 = $fopen({`STIM_PATH, `"/chk_x4`", `".txt`"}, "r");
    if (fd_chk_x4) $display("File chk_x4 opened: %0d", fd_chk_x4);
    else $display("File 'chk_x4' could not be opened: %0d", fd_chk_x4);
    
    while (! $feof(fd_chk_x4)) begin
        $fscanf(fd_chk_x4, "%d\n", chk_x4);
        @(posedge clk); 
    end
end

integer fd_chk_x5;
reg [31:0] chk_x5;
initial begin    
    fd_chk_x5 = $fopen({`STIM_PATH, `"/chk_x5`", `".txt`"}, "r");
    if (fd_chk_x5) $display("File chk_x5 opened: %0d", fd_chk_x5);
    else $display("File 'chk_x5' could not be opened: %0d", fd_chk_x5);
    
    while (! $feof(fd_chk_x5)) begin
        $fscanf(fd_chk_x5, "%d\n", chk_x5);
        @(posedge clk); 
    end
end

integer fd_chk_x6;
reg [31:0] chk_x6;
initial begin    
    fd_chk_x6 = $fopen({`STIM_PATH, `"/chk_x6`", `".txt`"}, "r");
    if (fd_chk_x6) $display("File chk_x6 opened: %0d", fd_chk_x6);
    else $display("File 'chk_x6' could not be opened: %0d", fd_chk_x6);
    
    while (! $feof(fd_chk_x6)) begin
        $fscanf(fd_chk_x6, "%d\n", chk_x6);
        @(posedge clk); 
    end
end

integer fd_chk_x7;
reg [31:0] chk_x7;
initial begin    
    fd_chk_x7 = $fopen({`STIM_PATH, `"/chk_x7`", `".txt`"}, "r");
    if (fd_chk_x7) $display("File chk_x7 opened: %0d", fd_chk_x7);
    else $display("File 'chk_x7' could not be opened: %0d", fd_chk_x7);
    
    while (! $feof(fd_chk_x7)) begin
        $fscanf(fd_chk_x7, "%d\n", chk_x7);
        @(posedge clk); 
    end
end

integer fd_chk_x8;
reg [31:0] chk_x8;
initial begin    
    fd_chk_x8 = $fopen({`STIM_PATH, `"/chk_x8`", `".txt`"}, "r");
    if (fd_chk_x8) $display("File chk_x8 opened: %0d", fd_chk_x8);
    else $display("File 'chk_x8' could not be opened: %0d", fd_chk_x8);
    
    while (! $feof(fd_chk_x8)) begin
        $fscanf(fd_chk_x8, "%d\n", chk_x8);
        @(posedge clk); 
    end
end

integer fd_chk_x9;
reg [31:0] chk_x9;
initial begin    
    fd_chk_x9 = $fopen({`STIM_PATH, `"/chk_x9`", `".txt`"}, "r");
    if (fd_chk_x9) $display("File chk_x9 opened: %0d", fd_chk_x9);
    else $display("File 'chk_x9' could not be opened: %0d", fd_chk_x9);
    
    while (! $feof(fd_chk_x9)) begin
        $fscanf(fd_chk_x9, "%d\n", chk_x9);
        @(posedge clk); 
    end
end

integer fd_chk_x10;
reg [31:0] chk_x10;
initial begin    
    fd_chk_x10 = $fopen({`STIM_PATH, `"/chk_x10`", `".txt`"}, "r");
    if (fd_chk_x10) $display("File chk_x10 opened: %0d", fd_chk_x10);
    else $display("File 'chk_x10' could not be opened: %0d", fd_chk_x10);
    
    while (! $feof(fd_chk_x10)) begin
        $fscanf(fd_chk_x10, "%d\n", chk_x10);
        @(posedge clk); 
    end
end

integer fd_chk_x11;
reg [31:0] chk_x11;
initial begin    
    fd_chk_x11 = $fopen({`STIM_PATH, `"/chk_x11`", `".txt`"}, "r");
    if (fd_chk_x11) $display("File chk_x11 opened: %0d", fd_chk_x11);
    else $display("File 'chk_x11' could not be opened: %0d", fd_chk_x11);
    
    while (! $feof(fd_chk_x11)) begin
        $fscanf(fd_chk_x11, "%d\n", chk_x11);
        @(posedge clk); 
    end
end

integer fd_chk_x12;
reg [31:0] chk_x12;
initial begin    
    fd_chk_x12 = $fopen({`STIM_PATH, `"/chk_x12`", `".txt`"}, "r");
    if (fd_chk_x12) $display("File chk_x12 opened: %0d", fd_chk_x12);
    else $display("File 'chk_x12' could not be opened: %0d", fd_chk_x12);
    
    while (! $feof(fd_chk_x12)) begin
        $fscanf(fd_chk_x12, "%d\n", chk_x12);
        @(posedge clk); 
    end
end

integer fd_chk_x13;
reg [31:0] chk_x13;
initial begin    
    fd_chk_x13 = $fopen({`STIM_PATH, `"/chk_x13`", `".txt`"}, "r");
    if (fd_chk_x13) $display("File chk_x13 opened: %0d", fd_chk_x13);
    else $display("File 'chk_x13' could not be opened: %0d", fd_chk_x13);
    
    while (! $feof(fd_chk_x13)) begin
        $fscanf(fd_chk_x13, "%d\n", chk_x13);
        @(posedge clk); 
    end
end

integer fd_chk_x14;
reg [31:0] chk_x14;
initial begin    
    fd_chk_x14 = $fopen({`STIM_PATH, `"/chk_x14`", `".txt`"}, "r");
    if (fd_chk_x14) $display("File chk_x14 opened: %0d", fd_chk_x14);
    else $display("File 'chk_x14' could not be opened: %0d", fd_chk_x14);
    
    while (! $feof(fd_chk_x14)) begin
        $fscanf(fd_chk_x14, "%d\n", chk_x14);
        @(posedge clk); 
    end
end

integer fd_chk_x15;
reg [31:0] chk_x15;
initial begin    
    fd_chk_x15 = $fopen({`STIM_PATH, `"/chk_x15`", `".txt`"}, "r");
    if (fd_chk_x15) $display("File chk_x15 opened: %0d", fd_chk_x15);
    else $display("File 'chk_x15' could not be opened: %0d", fd_chk_x15);
    
    while (! $feof(fd_chk_x15)) begin
        $fscanf(fd_chk_x15, "%d\n", chk_x15);
        @(posedge clk); 
    end
end

integer fd_chk_x16;
reg [31:0] chk_x16;
initial begin    
    fd_chk_x16 = $fopen({`STIM_PATH, `"/chk_x16`", `".txt`"}, "r");
    if (fd_chk_x16) $display("File chk_x16 opened: %0d", fd_chk_x16);
    else $display("File 'chk_x16' could not be opened: %0d", fd_chk_x16);
    
    while (! $feof(fd_chk_x16)) begin
        $fscanf(fd_chk_x16, "%d\n", chk_x16);
        @(posedge clk); 
    end
end

integer fd_chk_x17;
reg [31:0] chk_x17;
initial begin    
    fd_chk_x17 = $fopen({`STIM_PATH, `"/chk_x17`", `".txt`"}, "r");
    if (fd_chk_x17) $display("File chk_x17 opened: %0d", fd_chk_x17);
    else $display("File 'chk_x17' could not be opened: %0d", fd_chk_x17);
    
    while (! $feof(fd_chk_x17)) begin
        $fscanf(fd_chk_x17, "%d\n", chk_x17);
        @(posedge clk); 
    end
end

integer fd_chk_x18;
reg [31:0] chk_x18;
initial begin    
    fd_chk_x18 = $fopen({`STIM_PATH, `"/chk_x18`", `".txt`"}, "r");
    if (fd_chk_x18) $display("File chk_x18 opened: %0d", fd_chk_x18);
    else $display("File 'chk_x18' could not be opened: %0d", fd_chk_x18);
    
    while (! $feof(fd_chk_x18)) begin
        $fscanf(fd_chk_x18, "%d\n", chk_x18);
        @(posedge clk); 
    end
end

integer fd_chk_x19;
reg [31:0] chk_x19;
initial begin    
    fd_chk_x19 = $fopen({`STIM_PATH, `"/chk_x19`", `".txt`"}, "r");
    if (fd_chk_x19) $display("File chk_x19 opened: %0d", fd_chk_x19);
    else $display("File 'chk_x19' could not be opened: %0d", fd_chk_x19);
    
    while (! $feof(fd_chk_x19)) begin
        $fscanf(fd_chk_x19, "%d\n", chk_x19);
        @(posedge clk); 
    end
end

integer fd_chk_x20;
reg [31:0] chk_x20;
initial begin    
    fd_chk_x20 = $fopen({`STIM_PATH, `"/chk_x20`", `".txt`"}, "r");
    if (fd_chk_x20) $display("File chk_x20 opened: %0d", fd_chk_x20);
    else $display("File 'chk_x20' could not be opened: %0d", fd_chk_x20);
    
    while (! $feof(fd_chk_x20)) begin
        $fscanf(fd_chk_x20, "%d\n", chk_x20);
        @(posedge clk); 
    end
end

integer fd_chk_x21;
reg [31:0] chk_x21;
initial begin    
    fd_chk_x21 = $fopen({`STIM_PATH, `"/chk_x21`", `".txt`"}, "r");
    if (fd_chk_x21) $display("File chk_x21 opened: %0d", fd_chk_x21);
    else $display("File 'chk_x21' could not be opened: %0d", fd_chk_x21);
    
    while (! $feof(fd_chk_x21)) begin
        $fscanf(fd_chk_x21, "%d\n", chk_x21);
        @(posedge clk); 
    end
end

integer fd_chk_x22;
reg [31:0] chk_x22;
initial begin    
    fd_chk_x22 = $fopen({`STIM_PATH, `"/chk_x22`", `".txt`"}, "r");
    if (fd_chk_x22) $display("File chk_x22 opened: %0d", fd_chk_x22);
    else $display("File 'chk_x22' could not be opened: %0d", fd_chk_x22);
    
    while (! $feof(fd_chk_x22)) begin
        $fscanf(fd_chk_x22, "%d\n", chk_x22);
        @(posedge clk); 
    end
end

integer fd_chk_x23;
reg [31:0] chk_x23;
initial begin    
    fd_chk_x23 = $fopen({`STIM_PATH, `"/chk_x23`", `".txt`"}, "r");
    if (fd_chk_x23) $display("File chk_x23 opened: %0d", fd_chk_x23);
    else $display("File 'chk_x23' could not be opened: %0d", fd_chk_x23);
    
    while (! $feof(fd_chk_x23)) begin
        $fscanf(fd_chk_x23, "%d\n", chk_x23);
        @(posedge clk); 
    end
end

integer fd_chk_x24;
reg [31:0] chk_x24;
initial begin    
    fd_chk_x24 = $fopen({`STIM_PATH, `"/chk_x24`", `".txt`"}, "r");
    if (fd_chk_x24) $display("File chk_x24 opened: %0d", fd_chk_x24);
    else $display("File 'chk_x24' could not be opened: %0d", fd_chk_x24);
    
    while (! $feof(fd_chk_x24)) begin
        $fscanf(fd_chk_x24, "%d\n", chk_x24);
        @(posedge clk); 
    end
end

integer fd_chk_x25;
reg [31:0] chk_x25;
initial begin    
    fd_chk_x25 = $fopen({`STIM_PATH, `"/chk_x25`", `".txt`"}, "r");
    if (fd_chk_x25) $display("File chk_x25 opened: %0d", fd_chk_x25);
    else $display("File 'chk_x25' could not be opened: %0d", fd_chk_x25);
    
    while (! $feof(fd_chk_x25)) begin
        $fscanf(fd_chk_x25, "%d\n", chk_x25);
        @(posedge clk); 
    end
end

integer fd_chk_x26;
reg [31:0] chk_x26;
initial begin    
    fd_chk_x26 = $fopen({`STIM_PATH, `"/chk_x26`", `".txt`"}, "r");
    if (fd_chk_x26) $display("File chk_x26 opened: %0d", fd_chk_x26);
    else $display("File 'chk_x26' could not be opened: %0d", fd_chk_x26);
    
    while (! $feof(fd_chk_x26)) begin
        $fscanf(fd_chk_x26, "%d\n", chk_x26);
        @(posedge clk); 
    end
end

integer fd_chk_x27;
reg [31:0] chk_x27;
initial begin    
    fd_chk_x27 = $fopen({`STIM_PATH, `"/chk_x27`", `".txt`"}, "r");
    if (fd_chk_x27) $display("File chk_x27 opened: %0d", fd_chk_x27);
    else $display("File 'chk_x27' could not be opened: %0d", fd_chk_x27);
    
    while (! $feof(fd_chk_x27)) begin
        $fscanf(fd_chk_x27, "%d\n", chk_x27);
        @(posedge clk); 
    end
end

integer fd_chk_x28;
reg [31:0] chk_x28;
initial begin    
    fd_chk_x28 = $fopen({`STIM_PATH, `"/chk_x28`", `".txt`"}, "r");
    if (fd_chk_x28) $display("File chk_x28 opened: %0d", fd_chk_x28);
    else $display("File 'chk_x28' could not be opened: %0d", fd_chk_x28);
    
    while (! $feof(fd_chk_x28)) begin
        $fscanf(fd_chk_x28, "%d\n", chk_x28);
        @(posedge clk); 
    end
end

integer fd_chk_x29;
reg [31:0] chk_x29;
initial begin    
    fd_chk_x29 = $fopen({`STIM_PATH, `"/chk_x29`", `".txt`"}, "r");
    if (fd_chk_x29) $display("File chk_x29 opened: %0d", fd_chk_x29);
    else $display("File 'chk_x29' could not be opened: %0d", fd_chk_x29);
    
    while (! $feof(fd_chk_x29)) begin
        $fscanf(fd_chk_x29, "%d\n", chk_x29);
        @(posedge clk); 
    end
end

integer fd_chk_x30;
reg [31:0] chk_x30;
initial begin    
    fd_chk_x30 = $fopen({`STIM_PATH, `"/chk_x30`", `".txt`"}, "r");
    if (fd_chk_x30) $display("File chk_x30 opened: %0d", fd_chk_x30);
    else $display("File 'chk_x30' could not be opened: %0d", fd_chk_x30);
    
    while (! $feof(fd_chk_x30)) begin
        $fscanf(fd_chk_x30, "%d\n", chk_x30);
        @(posedge clk); 
    end
end

integer fd_chk_x31;
reg [31:0] chk_x31;
initial begin    
    fd_chk_x31 = $fopen({`STIM_PATH, `"/chk_x31`", `".txt`"}, "r");
    if (fd_chk_x31) $display("File chk_x31 opened: %0d", fd_chk_x31);
    else $display("File 'chk_x31' could not be opened: %0d", fd_chk_x31);
    
    while (! $feof(fd_chk_x31)) begin
        $fscanf(fd_chk_x31, "%d\n", chk_x31);
        @(posedge clk); 
    end
end

integer fd_chk_tohost;
reg [31:0] chk_tohost;
initial begin    
    fd_chk_tohost = $fopen({`STIM_PATH, `"/chk_tohost`", `".txt`"}, "r");
    if (fd_chk_tohost) $display("File chk_tohost opened: %0d", fd_chk_tohost);
    else $display("File 'chk_tohost' could not be opened: %0d", fd_chk_tohost);
    
    while (! $feof(fd_chk_tohost)) begin
        $fscanf(fd_chk_tohost, "%d\n", chk_tohost);
        @(posedge clk); 
    end
end
