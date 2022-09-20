
integer fd_chk_rst_seq_d;
integer sample_cnt_chk_rst_seq_d = 0;
reg [31:0] chk_rst_seq_d;
initial begin
    fd_chk_rst_seq_d = $fopen({`STIM_PATH, `"/chk_rst_seq_d`", `".txt`"}, "r");
    if (fd_chk_rst_seq_d) begin
        $display("File 'chk_rst_seq_d' opened: %0d", fd_chk_rst_seq_d);
    end
    else begin
        $display("File 'chk_rst_seq_d' could not be opened: %0d. Exiting simulation.", fd_chk_rst_seq_d);
        $finish;
    end
    while (! $feof(fd_chk_rst_seq_d)) begin
        $fscanf(fd_chk_rst_seq_d, "%d\n", chk_rst_seq_d);
        sample_cnt_chk_rst_seq_d = sample_cnt_chk_rst_seq_d + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rst_seq_d' done. Samples read: %0d.", sample_cnt_chk_rst_seq_d);
end

integer fd_chk_pc;
integer sample_cnt_chk_pc = 0;
reg [31:0] chk_pc;
initial begin
    fd_chk_pc = $fopen({`STIM_PATH, `"/chk_pc`", `".txt`"}, "r");
    if (fd_chk_pc) begin
        $display("File 'chk_pc' opened: %0d", fd_chk_pc);
    end
    else begin
        $display("File 'chk_pc' could not be opened: %0d. Exiting simulation.", fd_chk_pc);
        $finish;
    end
    while (! $feof(fd_chk_pc)) begin
        $fscanf(fd_chk_pc, "%d\n", chk_pc);
        sample_cnt_chk_pc = sample_cnt_chk_pc + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_pc' done. Samples read: %0d.", sample_cnt_chk_pc);
end

integer fd_chk_stall_if_id_d;
integer sample_cnt_chk_stall_if_id_d = 0;
reg [31:0] chk_stall_if_id_d;
initial begin
    fd_chk_stall_if_id_d = $fopen({`STIM_PATH, `"/chk_stall_if_id_d`", `".txt`"}, "r");
    if (fd_chk_stall_if_id_d) begin
        $display("File 'chk_stall_if_id_d' opened: %0d", fd_chk_stall_if_id_d);
    end
    else begin
        $display("File 'chk_stall_if_id_d' could not be opened: %0d. Exiting simulation.", fd_chk_stall_if_id_d);
        $finish;
    end
    while (! $feof(fd_chk_stall_if_id_d)) begin
        $fscanf(fd_chk_stall_if_id_d, "%d\n", chk_stall_if_id_d);
        sample_cnt_chk_stall_if_id_d = sample_cnt_chk_stall_if_id_d + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_stall_if_id_d' done. Samples read: %0d.", sample_cnt_chk_stall_if_id_d);
end

integer fd_chk_imem;
integer sample_cnt_chk_imem = 0;
reg [31:0] chk_imem;
initial begin
    fd_chk_imem = $fopen({`STIM_PATH, `"/chk_imem`", `".txt`"}, "r");
    if (fd_chk_imem) begin
        $display("File 'chk_imem' opened: %0d", fd_chk_imem);
    end
    else begin
        $display("File 'chk_imem' could not be opened: %0d. Exiting simulation.", fd_chk_imem);
        $finish;
    end
    while (! $feof(fd_chk_imem)) begin
        $fscanf(fd_chk_imem, "%d\n", chk_imem);
        sample_cnt_chk_imem = sample_cnt_chk_imem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_imem' done. Samples read: %0d.", sample_cnt_chk_imem);
end

integer fd_chk_inst_ex;
integer sample_cnt_chk_inst_ex = 0;
reg [31:0] chk_inst_ex;
initial begin
    fd_chk_inst_ex = $fopen({`STIM_PATH, `"/chk_inst_ex`", `".txt`"}, "r");
    if (fd_chk_inst_ex) begin
        $display("File 'chk_inst_ex' opened: %0d", fd_chk_inst_ex);
    end
    else begin
        $display("File 'chk_inst_ex' could not be opened: %0d. Exiting simulation.", fd_chk_inst_ex);
        $finish;
    end
    while (! $feof(fd_chk_inst_ex)) begin
        $fscanf(fd_chk_inst_ex, "%d\n", chk_inst_ex);
        sample_cnt_chk_inst_ex = sample_cnt_chk_inst_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_inst_ex' done. Samples read: %0d.", sample_cnt_chk_inst_ex);
end

integer fd_chk_pc_ex;
integer sample_cnt_chk_pc_ex = 0;
reg [31:0] chk_pc_ex;
initial begin
    fd_chk_pc_ex = $fopen({`STIM_PATH, `"/chk_pc_ex`", `".txt`"}, "r");
    if (fd_chk_pc_ex) begin
        $display("File 'chk_pc_ex' opened: %0d", fd_chk_pc_ex);
    end
    else begin
        $display("File 'chk_pc_ex' could not be opened: %0d. Exiting simulation.", fd_chk_pc_ex);
        $finish;
    end
    while (! $feof(fd_chk_pc_ex)) begin
        $fscanf(fd_chk_pc_ex, "%d\n", chk_pc_ex);
        sample_cnt_chk_pc_ex = sample_cnt_chk_pc_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_pc_ex' done. Samples read: %0d.", sample_cnt_chk_pc_ex);
end

integer fd_chk_funct3_ex;
integer sample_cnt_chk_funct3_ex = 0;
reg [31:0] chk_funct3_ex;
initial begin
    fd_chk_funct3_ex = $fopen({`STIM_PATH, `"/chk_funct3_ex`", `".txt`"}, "r");
    if (fd_chk_funct3_ex) begin
        $display("File 'chk_funct3_ex' opened: %0d", fd_chk_funct3_ex);
    end
    else begin
        $display("File 'chk_funct3_ex' could not be opened: %0d. Exiting simulation.", fd_chk_funct3_ex);
        $finish;
    end
    while (! $feof(fd_chk_funct3_ex)) begin
        $fscanf(fd_chk_funct3_ex, "%d\n", chk_funct3_ex);
        sample_cnt_chk_funct3_ex = sample_cnt_chk_funct3_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_funct3_ex' done. Samples read: %0d.", sample_cnt_chk_funct3_ex);
end

integer fd_chk_rs1_addr_ex;
integer sample_cnt_chk_rs1_addr_ex = 0;
reg [31:0] chk_rs1_addr_ex;
initial begin
    fd_chk_rs1_addr_ex = $fopen({`STIM_PATH, `"/chk_rs1_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rs1_addr_ex) begin
        $display("File 'chk_rs1_addr_ex' opened: %0d", fd_chk_rs1_addr_ex);
    end
    else begin
        $display("File 'chk_rs1_addr_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rs1_addr_ex);
        $finish;
    end
    while (! $feof(fd_chk_rs1_addr_ex)) begin
        $fscanf(fd_chk_rs1_addr_ex, "%d\n", chk_rs1_addr_ex);
        sample_cnt_chk_rs1_addr_ex = sample_cnt_chk_rs1_addr_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rs1_addr_ex' done. Samples read: %0d.", sample_cnt_chk_rs1_addr_ex);
end

integer fd_chk_rs2_addr_ex;
integer sample_cnt_chk_rs2_addr_ex = 0;
reg [31:0] chk_rs2_addr_ex;
initial begin
    fd_chk_rs2_addr_ex = $fopen({`STIM_PATH, `"/chk_rs2_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rs2_addr_ex) begin
        $display("File 'chk_rs2_addr_ex' opened: %0d", fd_chk_rs2_addr_ex);
    end
    else begin
        $display("File 'chk_rs2_addr_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rs2_addr_ex);
        $finish;
    end
    while (! $feof(fd_chk_rs2_addr_ex)) begin
        $fscanf(fd_chk_rs2_addr_ex, "%d\n", chk_rs2_addr_ex);
        sample_cnt_chk_rs2_addr_ex = sample_cnt_chk_rs2_addr_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rs2_addr_ex' done. Samples read: %0d.", sample_cnt_chk_rs2_addr_ex);
end

integer fd_chk_rf_data_a_ex;
integer sample_cnt_chk_rf_data_a_ex = 0;
reg [31:0] chk_rf_data_a_ex;
initial begin
    fd_chk_rf_data_a_ex = $fopen({`STIM_PATH, `"/chk_rf_data_a_ex`", `".txt`"}, "r");
    if (fd_chk_rf_data_a_ex) begin
        $display("File 'chk_rf_data_a_ex' opened: %0d", fd_chk_rf_data_a_ex);
    end
    else begin
        $display("File 'chk_rf_data_a_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rf_data_a_ex);
        $finish;
    end
    while (! $feof(fd_chk_rf_data_a_ex)) begin
        $fscanf(fd_chk_rf_data_a_ex, "%d\n", chk_rf_data_a_ex);
        sample_cnt_chk_rf_data_a_ex = sample_cnt_chk_rf_data_a_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rf_data_a_ex' done. Samples read: %0d.", sample_cnt_chk_rf_data_a_ex);
end

integer fd_chk_rf_data_b_ex;
integer sample_cnt_chk_rf_data_b_ex = 0;
reg [31:0] chk_rf_data_b_ex;
initial begin
    fd_chk_rf_data_b_ex = $fopen({`STIM_PATH, `"/chk_rf_data_b_ex`", `".txt`"}, "r");
    if (fd_chk_rf_data_b_ex) begin
        $display("File 'chk_rf_data_b_ex' opened: %0d", fd_chk_rf_data_b_ex);
    end
    else begin
        $display("File 'chk_rf_data_b_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rf_data_b_ex);
        $finish;
    end
    while (! $feof(fd_chk_rf_data_b_ex)) begin
        $fscanf(fd_chk_rf_data_b_ex, "%d\n", chk_rf_data_b_ex);
        sample_cnt_chk_rf_data_b_ex = sample_cnt_chk_rf_data_b_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rf_data_b_ex' done. Samples read: %0d.", sample_cnt_chk_rf_data_b_ex);
end

integer fd_chk_rd_we_ex;
integer sample_cnt_chk_rd_we_ex = 0;
reg [31:0] chk_rd_we_ex;
initial begin
    fd_chk_rd_we_ex = $fopen({`STIM_PATH, `"/chk_rd_we_ex`", `".txt`"}, "r");
    if (fd_chk_rd_we_ex) begin
        $display("File 'chk_rd_we_ex' opened: %0d", fd_chk_rd_we_ex);
    end
    else begin
        $display("File 'chk_rd_we_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rd_we_ex);
        $finish;
    end
    while (! $feof(fd_chk_rd_we_ex)) begin
        $fscanf(fd_chk_rd_we_ex, "%d\n", chk_rd_we_ex);
        sample_cnt_chk_rd_we_ex = sample_cnt_chk_rd_we_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rd_we_ex' done. Samples read: %0d.", sample_cnt_chk_rd_we_ex);
end

integer fd_chk_rd_addr_ex;
integer sample_cnt_chk_rd_addr_ex = 0;
reg [31:0] chk_rd_addr_ex;
initial begin
    fd_chk_rd_addr_ex = $fopen({`STIM_PATH, `"/chk_rd_addr_ex`", `".txt`"}, "r");
    if (fd_chk_rd_addr_ex) begin
        $display("File 'chk_rd_addr_ex' opened: %0d", fd_chk_rd_addr_ex);
    end
    else begin
        $display("File 'chk_rd_addr_ex' could not be opened: %0d. Exiting simulation.", fd_chk_rd_addr_ex);
        $finish;
    end
    while (! $feof(fd_chk_rd_addr_ex)) begin
        $fscanf(fd_chk_rd_addr_ex, "%d\n", chk_rd_addr_ex);
        sample_cnt_chk_rd_addr_ex = sample_cnt_chk_rd_addr_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rd_addr_ex' done. Samples read: %0d.", sample_cnt_chk_rd_addr_ex);
end

integer fd_chk_imm_gen_out_ex;
integer sample_cnt_chk_imm_gen_out_ex = 0;
reg [31:0] chk_imm_gen_out_ex;
initial begin
    fd_chk_imm_gen_out_ex = $fopen({`STIM_PATH, `"/chk_imm_gen_out_ex`", `".txt`"}, "r");
    if (fd_chk_imm_gen_out_ex) begin
        $display("File 'chk_imm_gen_out_ex' opened: %0d", fd_chk_imm_gen_out_ex);
    end
    else begin
        $display("File 'chk_imm_gen_out_ex' could not be opened: %0d. Exiting simulation.", fd_chk_imm_gen_out_ex);
        $finish;
    end
    while (! $feof(fd_chk_imm_gen_out_ex)) begin
        $fscanf(fd_chk_imm_gen_out_ex, "%d\n", chk_imm_gen_out_ex);
        sample_cnt_chk_imm_gen_out_ex = sample_cnt_chk_imm_gen_out_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_imm_gen_out_ex' done. Samples read: %0d.", sample_cnt_chk_imm_gen_out_ex);
end

integer fd_chk_csr_we_ex;
integer sample_cnt_chk_csr_we_ex = 0;
reg [31:0] chk_csr_we_ex;
initial begin
    fd_chk_csr_we_ex = $fopen({`STIM_PATH, `"/chk_csr_we_ex`", `".txt`"}, "r");
    if (fd_chk_csr_we_ex) begin
        $display("File 'chk_csr_we_ex' opened: %0d", fd_chk_csr_we_ex);
    end
    else begin
        $display("File 'chk_csr_we_ex' could not be opened: %0d. Exiting simulation.", fd_chk_csr_we_ex);
        $finish;
    end
    while (! $feof(fd_chk_csr_we_ex)) begin
        $fscanf(fd_chk_csr_we_ex, "%d\n", chk_csr_we_ex);
        sample_cnt_chk_csr_we_ex = sample_cnt_chk_csr_we_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_we_ex' done. Samples read: %0d.", sample_cnt_chk_csr_we_ex);
end

integer fd_chk_csr_ui_ex;
integer sample_cnt_chk_csr_ui_ex = 0;
reg [31:0] chk_csr_ui_ex;
initial begin
    fd_chk_csr_ui_ex = $fopen({`STIM_PATH, `"/chk_csr_ui_ex`", `".txt`"}, "r");
    if (fd_chk_csr_ui_ex) begin
        $display("File 'chk_csr_ui_ex' opened: %0d", fd_chk_csr_ui_ex);
    end
    else begin
        $display("File 'chk_csr_ui_ex' could not be opened: %0d. Exiting simulation.", fd_chk_csr_ui_ex);
        $finish;
    end
    while (! $feof(fd_chk_csr_ui_ex)) begin
        $fscanf(fd_chk_csr_ui_ex, "%d\n", chk_csr_ui_ex);
        sample_cnt_chk_csr_ui_ex = sample_cnt_chk_csr_ui_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_ui_ex' done. Samples read: %0d.", sample_cnt_chk_csr_ui_ex);
end

integer fd_chk_csr_uimm_ex;
integer sample_cnt_chk_csr_uimm_ex = 0;
reg [31:0] chk_csr_uimm_ex;
initial begin
    fd_chk_csr_uimm_ex = $fopen({`STIM_PATH, `"/chk_csr_uimm_ex`", `".txt`"}, "r");
    if (fd_chk_csr_uimm_ex) begin
        $display("File 'chk_csr_uimm_ex' opened: %0d", fd_chk_csr_uimm_ex);
    end
    else begin
        $display("File 'chk_csr_uimm_ex' could not be opened: %0d. Exiting simulation.", fd_chk_csr_uimm_ex);
        $finish;
    end
    while (! $feof(fd_chk_csr_uimm_ex)) begin
        $fscanf(fd_chk_csr_uimm_ex, "%d\n", chk_csr_uimm_ex);
        sample_cnt_chk_csr_uimm_ex = sample_cnt_chk_csr_uimm_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_uimm_ex' done. Samples read: %0d.", sample_cnt_chk_csr_uimm_ex);
end

integer fd_chk_csr_dout_ex;
integer sample_cnt_chk_csr_dout_ex = 0;
reg [31:0] chk_csr_dout_ex;
initial begin
    fd_chk_csr_dout_ex = $fopen({`STIM_PATH, `"/chk_csr_dout_ex`", `".txt`"}, "r");
    if (fd_chk_csr_dout_ex) begin
        $display("File 'chk_csr_dout_ex' opened: %0d", fd_chk_csr_dout_ex);
    end
    else begin
        $display("File 'chk_csr_dout_ex' could not be opened: %0d. Exiting simulation.", fd_chk_csr_dout_ex);
        $finish;
    end
    while (! $feof(fd_chk_csr_dout_ex)) begin
        $fscanf(fd_chk_csr_dout_ex, "%d\n", chk_csr_dout_ex);
        sample_cnt_chk_csr_dout_ex = sample_cnt_chk_csr_dout_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_dout_ex' done. Samples read: %0d.", sample_cnt_chk_csr_dout_ex);
end

integer fd_chk_alu_a_sel_ex;
integer sample_cnt_chk_alu_a_sel_ex = 0;
reg [31:0] chk_alu_a_sel_ex;
initial begin
    fd_chk_alu_a_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_a_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_a_sel_ex) begin
        $display("File 'chk_alu_a_sel_ex' opened: %0d", fd_chk_alu_a_sel_ex);
    end
    else begin
        $display("File 'chk_alu_a_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_alu_a_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_alu_a_sel_ex)) begin
        $fscanf(fd_chk_alu_a_sel_ex, "%d\n", chk_alu_a_sel_ex);
        sample_cnt_chk_alu_a_sel_ex = sample_cnt_chk_alu_a_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_a_sel_ex' done. Samples read: %0d.", sample_cnt_chk_alu_a_sel_ex);
end

integer fd_chk_alu_b_sel_ex;
integer sample_cnt_chk_alu_b_sel_ex = 0;
reg [31:0] chk_alu_b_sel_ex;
initial begin
    fd_chk_alu_b_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_b_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_b_sel_ex) begin
        $display("File 'chk_alu_b_sel_ex' opened: %0d", fd_chk_alu_b_sel_ex);
    end
    else begin
        $display("File 'chk_alu_b_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_alu_b_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_alu_b_sel_ex)) begin
        $fscanf(fd_chk_alu_b_sel_ex, "%d\n", chk_alu_b_sel_ex);
        sample_cnt_chk_alu_b_sel_ex = sample_cnt_chk_alu_b_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_b_sel_ex' done. Samples read: %0d.", sample_cnt_chk_alu_b_sel_ex);
end

integer fd_chk_alu_op_sel_ex;
integer sample_cnt_chk_alu_op_sel_ex = 0;
reg [31:0] chk_alu_op_sel_ex;
initial begin
    fd_chk_alu_op_sel_ex = $fopen({`STIM_PATH, `"/chk_alu_op_sel_ex`", `".txt`"}, "r");
    if (fd_chk_alu_op_sel_ex) begin
        $display("File 'chk_alu_op_sel_ex' opened: %0d", fd_chk_alu_op_sel_ex);
    end
    else begin
        $display("File 'chk_alu_op_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_alu_op_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_alu_op_sel_ex)) begin
        $fscanf(fd_chk_alu_op_sel_ex, "%d\n", chk_alu_op_sel_ex);
        sample_cnt_chk_alu_op_sel_ex = sample_cnt_chk_alu_op_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_op_sel_ex' done. Samples read: %0d.", sample_cnt_chk_alu_op_sel_ex);
end

integer fd_chk_bc_a_sel_ex;
integer sample_cnt_chk_bc_a_sel_ex = 0;
reg [31:0] chk_bc_a_sel_ex;
initial begin
    fd_chk_bc_a_sel_ex = $fopen({`STIM_PATH, `"/chk_bc_a_sel_ex`", `".txt`"}, "r");
    if (fd_chk_bc_a_sel_ex) begin
        $display("File 'chk_bc_a_sel_ex' opened: %0d", fd_chk_bc_a_sel_ex);
    end
    else begin
        $display("File 'chk_bc_a_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_bc_a_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_bc_a_sel_ex)) begin
        $fscanf(fd_chk_bc_a_sel_ex, "%d\n", chk_bc_a_sel_ex);
        sample_cnt_chk_bc_a_sel_ex = sample_cnt_chk_bc_a_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_bc_a_sel_ex' done. Samples read: %0d.", sample_cnt_chk_bc_a_sel_ex);
end

integer fd_chk_bcs_b_sel_ex;
integer sample_cnt_chk_bcs_b_sel_ex = 0;
reg [31:0] chk_bcs_b_sel_ex;
initial begin
    fd_chk_bcs_b_sel_ex = $fopen({`STIM_PATH, `"/chk_bcs_b_sel_ex`", `".txt`"}, "r");
    if (fd_chk_bcs_b_sel_ex) begin
        $display("File 'chk_bcs_b_sel_ex' opened: %0d", fd_chk_bcs_b_sel_ex);
    end
    else begin
        $display("File 'chk_bcs_b_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_bcs_b_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_bcs_b_sel_ex)) begin
        $fscanf(fd_chk_bcs_b_sel_ex, "%d\n", chk_bcs_b_sel_ex);
        sample_cnt_chk_bcs_b_sel_ex = sample_cnt_chk_bcs_b_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_bcs_b_sel_ex' done. Samples read: %0d.", sample_cnt_chk_bcs_b_sel_ex);
end

integer fd_chk_bc_uns_ex;
integer sample_cnt_chk_bc_uns_ex = 0;
reg [31:0] chk_bc_uns_ex;
initial begin
    fd_chk_bc_uns_ex = $fopen({`STIM_PATH, `"/chk_bc_uns_ex`", `".txt`"}, "r");
    if (fd_chk_bc_uns_ex) begin
        $display("File 'chk_bc_uns_ex' opened: %0d", fd_chk_bc_uns_ex);
    end
    else begin
        $display("File 'chk_bc_uns_ex' could not be opened: %0d. Exiting simulation.", fd_chk_bc_uns_ex);
        $finish;
    end
    while (! $feof(fd_chk_bc_uns_ex)) begin
        $fscanf(fd_chk_bc_uns_ex, "%d\n", chk_bc_uns_ex);
        sample_cnt_chk_bc_uns_ex = sample_cnt_chk_bc_uns_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_bc_uns_ex' done. Samples read: %0d.", sample_cnt_chk_bc_uns_ex);
end

integer fd_chk_store_inst_ex;
integer sample_cnt_chk_store_inst_ex = 0;
reg [31:0] chk_store_inst_ex;
initial begin
    fd_chk_store_inst_ex = $fopen({`STIM_PATH, `"/chk_store_inst_ex`", `".txt`"}, "r");
    if (fd_chk_store_inst_ex) begin
        $display("File 'chk_store_inst_ex' opened: %0d", fd_chk_store_inst_ex);
    end
    else begin
        $display("File 'chk_store_inst_ex' could not be opened: %0d. Exiting simulation.", fd_chk_store_inst_ex);
        $finish;
    end
    while (! $feof(fd_chk_store_inst_ex)) begin
        $fscanf(fd_chk_store_inst_ex, "%d\n", chk_store_inst_ex);
        sample_cnt_chk_store_inst_ex = sample_cnt_chk_store_inst_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_store_inst_ex' done. Samples read: %0d.", sample_cnt_chk_store_inst_ex);
end

integer fd_chk_branch_inst_ex;
integer sample_cnt_chk_branch_inst_ex = 0;
reg [31:0] chk_branch_inst_ex;
initial begin
    fd_chk_branch_inst_ex = $fopen({`STIM_PATH, `"/chk_branch_inst_ex`", `".txt`"}, "r");
    if (fd_chk_branch_inst_ex) begin
        $display("File 'chk_branch_inst_ex' opened: %0d", fd_chk_branch_inst_ex);
    end
    else begin
        $display("File 'chk_branch_inst_ex' could not be opened: %0d. Exiting simulation.", fd_chk_branch_inst_ex);
        $finish;
    end
    while (! $feof(fd_chk_branch_inst_ex)) begin
        $fscanf(fd_chk_branch_inst_ex, "%d\n", chk_branch_inst_ex);
        sample_cnt_chk_branch_inst_ex = sample_cnt_chk_branch_inst_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_branch_inst_ex' done. Samples read: %0d.", sample_cnt_chk_branch_inst_ex);
end

integer fd_chk_jump_inst_ex;
integer sample_cnt_chk_jump_inst_ex = 0;
reg [31:0] chk_jump_inst_ex;
initial begin
    fd_chk_jump_inst_ex = $fopen({`STIM_PATH, `"/chk_jump_inst_ex`", `".txt`"}, "r");
    if (fd_chk_jump_inst_ex) begin
        $display("File 'chk_jump_inst_ex' opened: %0d", fd_chk_jump_inst_ex);
    end
    else begin
        $display("File 'chk_jump_inst_ex' could not be opened: %0d. Exiting simulation.", fd_chk_jump_inst_ex);
        $finish;
    end
    while (! $feof(fd_chk_jump_inst_ex)) begin
        $fscanf(fd_chk_jump_inst_ex, "%d\n", chk_jump_inst_ex);
        sample_cnt_chk_jump_inst_ex = sample_cnt_chk_jump_inst_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_jump_inst_ex' done. Samples read: %0d.", sample_cnt_chk_jump_inst_ex);
end

integer fd_chk_dmem_en_id;
integer sample_cnt_chk_dmem_en_id = 0;
reg [31:0] chk_dmem_en_id;
initial begin
    fd_chk_dmem_en_id = $fopen({`STIM_PATH, `"/chk_dmem_en_id`", `".txt`"}, "r");
    if (fd_chk_dmem_en_id) begin
        $display("File 'chk_dmem_en_id' opened: %0d", fd_chk_dmem_en_id);
    end
    else begin
        $display("File 'chk_dmem_en_id' could not be opened: %0d. Exiting simulation.", fd_chk_dmem_en_id);
        $finish;
    end
    while (! $feof(fd_chk_dmem_en_id)) begin
        $fscanf(fd_chk_dmem_en_id, "%d\n", chk_dmem_en_id);
        sample_cnt_chk_dmem_en_id = sample_cnt_chk_dmem_en_id + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_dmem_en_id' done. Samples read: %0d.", sample_cnt_chk_dmem_en_id);
end

integer fd_chk_load_sm_en_ex;
integer sample_cnt_chk_load_sm_en_ex = 0;
reg [31:0] chk_load_sm_en_ex;
initial begin
    fd_chk_load_sm_en_ex = $fopen({`STIM_PATH, `"/chk_load_sm_en_ex`", `".txt`"}, "r");
    if (fd_chk_load_sm_en_ex) begin
        $display("File 'chk_load_sm_en_ex' opened: %0d", fd_chk_load_sm_en_ex);
    end
    else begin
        $display("File 'chk_load_sm_en_ex' could not be opened: %0d. Exiting simulation.", fd_chk_load_sm_en_ex);
        $finish;
    end
    while (! $feof(fd_chk_load_sm_en_ex)) begin
        $fscanf(fd_chk_load_sm_en_ex, "%d\n", chk_load_sm_en_ex);
        sample_cnt_chk_load_sm_en_ex = sample_cnt_chk_load_sm_en_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_load_sm_en_ex' done. Samples read: %0d.", sample_cnt_chk_load_sm_en_ex);
end

integer fd_chk_wb_sel_ex;
integer sample_cnt_chk_wb_sel_ex = 0;
reg [31:0] chk_wb_sel_ex;
initial begin
    fd_chk_wb_sel_ex = $fopen({`STIM_PATH, `"/chk_wb_sel_ex`", `".txt`"}, "r");
    if (fd_chk_wb_sel_ex) begin
        $display("File 'chk_wb_sel_ex' opened: %0d", fd_chk_wb_sel_ex);
    end
    else begin
        $display("File 'chk_wb_sel_ex' could not be opened: %0d. Exiting simulation.", fd_chk_wb_sel_ex);
        $finish;
    end
    while (! $feof(fd_chk_wb_sel_ex)) begin
        $fscanf(fd_chk_wb_sel_ex, "%d\n", chk_wb_sel_ex);
        sample_cnt_chk_wb_sel_ex = sample_cnt_chk_wb_sel_ex + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_wb_sel_ex' done. Samples read: %0d.", sample_cnt_chk_wb_sel_ex);
end

integer fd_chk_inst_mem;
integer sample_cnt_chk_inst_mem = 0;
reg [31:0] chk_inst_mem;
initial begin
    fd_chk_inst_mem = $fopen({`STIM_PATH, `"/chk_inst_mem`", `".txt`"}, "r");
    if (fd_chk_inst_mem) begin
        $display("File 'chk_inst_mem' opened: %0d", fd_chk_inst_mem);
    end
    else begin
        $display("File 'chk_inst_mem' could not be opened: %0d. Exiting simulation.", fd_chk_inst_mem);
        $finish;
    end
    while (! $feof(fd_chk_inst_mem)) begin
        $fscanf(fd_chk_inst_mem, "%d\n", chk_inst_mem);
        sample_cnt_chk_inst_mem = sample_cnt_chk_inst_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_inst_mem' done. Samples read: %0d.", sample_cnt_chk_inst_mem);
end

integer fd_chk_pc_mem;
integer sample_cnt_chk_pc_mem = 0;
reg [31:0] chk_pc_mem;
initial begin
    fd_chk_pc_mem = $fopen({`STIM_PATH, `"/chk_pc_mem`", `".txt`"}, "r");
    if (fd_chk_pc_mem) begin
        $display("File 'chk_pc_mem' opened: %0d", fd_chk_pc_mem);
    end
    else begin
        $display("File 'chk_pc_mem' could not be opened: %0d. Exiting simulation.", fd_chk_pc_mem);
        $finish;
    end
    while (! $feof(fd_chk_pc_mem)) begin
        $fscanf(fd_chk_pc_mem, "%d\n", chk_pc_mem);
        sample_cnt_chk_pc_mem = sample_cnt_chk_pc_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_pc_mem' done. Samples read: %0d.", sample_cnt_chk_pc_mem);
end

integer fd_chk_alu_mem;
integer sample_cnt_chk_alu_mem = 0;
reg [31:0] chk_alu_mem;
initial begin
    fd_chk_alu_mem = $fopen({`STIM_PATH, `"/chk_alu_mem`", `".txt`"}, "r");
    if (fd_chk_alu_mem) begin
        $display("File 'chk_alu_mem' opened: %0d", fd_chk_alu_mem);
    end
    else begin
        $display("File 'chk_alu_mem' could not be opened: %0d. Exiting simulation.", fd_chk_alu_mem);
        $finish;
    end
    while (! $feof(fd_chk_alu_mem)) begin
        $fscanf(fd_chk_alu_mem, "%d\n", chk_alu_mem);
        sample_cnt_chk_alu_mem = sample_cnt_chk_alu_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_mem' done. Samples read: %0d.", sample_cnt_chk_alu_mem);
end

integer fd_chk_alu_in_a_mem;
integer sample_cnt_chk_alu_in_a_mem = 0;
reg [31:0] chk_alu_in_a_mem;
initial begin
    fd_chk_alu_in_a_mem = $fopen({`STIM_PATH, `"/chk_alu_in_a_mem`", `".txt`"}, "r");
    if (fd_chk_alu_in_a_mem) begin
        $display("File 'chk_alu_in_a_mem' opened: %0d", fd_chk_alu_in_a_mem);
    end
    else begin
        $display("File 'chk_alu_in_a_mem' could not be opened: %0d. Exiting simulation.", fd_chk_alu_in_a_mem);
        $finish;
    end
    while (! $feof(fd_chk_alu_in_a_mem)) begin
        $fscanf(fd_chk_alu_in_a_mem, "%d\n", chk_alu_in_a_mem);
        sample_cnt_chk_alu_in_a_mem = sample_cnt_chk_alu_in_a_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_in_a_mem' done. Samples read: %0d.", sample_cnt_chk_alu_in_a_mem);
end

integer fd_chk_funct3_mem;
integer sample_cnt_chk_funct3_mem = 0;
reg [31:0] chk_funct3_mem;
initial begin
    fd_chk_funct3_mem = $fopen({`STIM_PATH, `"/chk_funct3_mem`", `".txt`"}, "r");
    if (fd_chk_funct3_mem) begin
        $display("File 'chk_funct3_mem' opened: %0d", fd_chk_funct3_mem);
    end
    else begin
        $display("File 'chk_funct3_mem' could not be opened: %0d. Exiting simulation.", fd_chk_funct3_mem);
        $finish;
    end
    while (! $feof(fd_chk_funct3_mem)) begin
        $fscanf(fd_chk_funct3_mem, "%d\n", chk_funct3_mem);
        sample_cnt_chk_funct3_mem = sample_cnt_chk_funct3_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_funct3_mem' done. Samples read: %0d.", sample_cnt_chk_funct3_mem);
end

integer fd_chk_rs1_addr_mem;
integer sample_cnt_chk_rs1_addr_mem = 0;
reg [31:0] chk_rs1_addr_mem;
initial begin
    fd_chk_rs1_addr_mem = $fopen({`STIM_PATH, `"/chk_rs1_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rs1_addr_mem) begin
        $display("File 'chk_rs1_addr_mem' opened: %0d", fd_chk_rs1_addr_mem);
    end
    else begin
        $display("File 'chk_rs1_addr_mem' could not be opened: %0d. Exiting simulation.", fd_chk_rs1_addr_mem);
        $finish;
    end
    while (! $feof(fd_chk_rs1_addr_mem)) begin
        $fscanf(fd_chk_rs1_addr_mem, "%d\n", chk_rs1_addr_mem);
        sample_cnt_chk_rs1_addr_mem = sample_cnt_chk_rs1_addr_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rs1_addr_mem' done. Samples read: %0d.", sample_cnt_chk_rs1_addr_mem);
end

integer fd_chk_rs2_addr_mem;
integer sample_cnt_chk_rs2_addr_mem = 0;
reg [31:0] chk_rs2_addr_mem;
initial begin
    fd_chk_rs2_addr_mem = $fopen({`STIM_PATH, `"/chk_rs2_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rs2_addr_mem) begin
        $display("File 'chk_rs2_addr_mem' opened: %0d", fd_chk_rs2_addr_mem);
    end
    else begin
        $display("File 'chk_rs2_addr_mem' could not be opened: %0d. Exiting simulation.", fd_chk_rs2_addr_mem);
        $finish;
    end
    while (! $feof(fd_chk_rs2_addr_mem)) begin
        $fscanf(fd_chk_rs2_addr_mem, "%d\n", chk_rs2_addr_mem);
        sample_cnt_chk_rs2_addr_mem = sample_cnt_chk_rs2_addr_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rs2_addr_mem' done. Samples read: %0d.", sample_cnt_chk_rs2_addr_mem);
end

integer fd_chk_rd_addr_mem;
integer sample_cnt_chk_rd_addr_mem = 0;
reg [31:0] chk_rd_addr_mem;
initial begin
    fd_chk_rd_addr_mem = $fopen({`STIM_PATH, `"/chk_rd_addr_mem`", `".txt`"}, "r");
    if (fd_chk_rd_addr_mem) begin
        $display("File 'chk_rd_addr_mem' opened: %0d", fd_chk_rd_addr_mem);
    end
    else begin
        $display("File 'chk_rd_addr_mem' could not be opened: %0d. Exiting simulation.", fd_chk_rd_addr_mem);
        $finish;
    end
    while (! $feof(fd_chk_rd_addr_mem)) begin
        $fscanf(fd_chk_rd_addr_mem, "%d\n", chk_rd_addr_mem);
        sample_cnt_chk_rd_addr_mem = sample_cnt_chk_rd_addr_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rd_addr_mem' done. Samples read: %0d.", sample_cnt_chk_rd_addr_mem);
end

integer fd_chk_rd_we_mem;
integer sample_cnt_chk_rd_we_mem = 0;
reg [31:0] chk_rd_we_mem;
initial begin
    fd_chk_rd_we_mem = $fopen({`STIM_PATH, `"/chk_rd_we_mem`", `".txt`"}, "r");
    if (fd_chk_rd_we_mem) begin
        $display("File 'chk_rd_we_mem' opened: %0d", fd_chk_rd_we_mem);
    end
    else begin
        $display("File 'chk_rd_we_mem' could not be opened: %0d. Exiting simulation.", fd_chk_rd_we_mem);
        $finish;
    end
    while (! $feof(fd_chk_rd_we_mem)) begin
        $fscanf(fd_chk_rd_we_mem, "%d\n", chk_rd_we_mem);
        sample_cnt_chk_rd_we_mem = sample_cnt_chk_rd_we_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_rd_we_mem' done. Samples read: %0d.", sample_cnt_chk_rd_we_mem);
end

integer fd_chk_csr_we_mem;
integer sample_cnt_chk_csr_we_mem = 0;
reg [31:0] chk_csr_we_mem;
initial begin
    fd_chk_csr_we_mem = $fopen({`STIM_PATH, `"/chk_csr_we_mem`", `".txt`"}, "r");
    if (fd_chk_csr_we_mem) begin
        $display("File 'chk_csr_we_mem' opened: %0d", fd_chk_csr_we_mem);
    end
    else begin
        $display("File 'chk_csr_we_mem' could not be opened: %0d. Exiting simulation.", fd_chk_csr_we_mem);
        $finish;
    end
    while (! $feof(fd_chk_csr_we_mem)) begin
        $fscanf(fd_chk_csr_we_mem, "%d\n", chk_csr_we_mem);
        sample_cnt_chk_csr_we_mem = sample_cnt_chk_csr_we_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_we_mem' done. Samples read: %0d.", sample_cnt_chk_csr_we_mem);
end

integer fd_chk_csr_ui_mem;
integer sample_cnt_chk_csr_ui_mem = 0;
reg [31:0] chk_csr_ui_mem;
initial begin
    fd_chk_csr_ui_mem = $fopen({`STIM_PATH, `"/chk_csr_ui_mem`", `".txt`"}, "r");
    if (fd_chk_csr_ui_mem) begin
        $display("File 'chk_csr_ui_mem' opened: %0d", fd_chk_csr_ui_mem);
    end
    else begin
        $display("File 'chk_csr_ui_mem' could not be opened: %0d. Exiting simulation.", fd_chk_csr_ui_mem);
        $finish;
    end
    while (! $feof(fd_chk_csr_ui_mem)) begin
        $fscanf(fd_chk_csr_ui_mem, "%d\n", chk_csr_ui_mem);
        sample_cnt_chk_csr_ui_mem = sample_cnt_chk_csr_ui_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_ui_mem' done. Samples read: %0d.", sample_cnt_chk_csr_ui_mem);
end

integer fd_chk_csr_uimm_mem;
integer sample_cnt_chk_csr_uimm_mem = 0;
reg [31:0] chk_csr_uimm_mem;
initial begin
    fd_chk_csr_uimm_mem = $fopen({`STIM_PATH, `"/chk_csr_uimm_mem`", `".txt`"}, "r");
    if (fd_chk_csr_uimm_mem) begin
        $display("File 'chk_csr_uimm_mem' opened: %0d", fd_chk_csr_uimm_mem);
    end
    else begin
        $display("File 'chk_csr_uimm_mem' could not be opened: %0d. Exiting simulation.", fd_chk_csr_uimm_mem);
        $finish;
    end
    while (! $feof(fd_chk_csr_uimm_mem)) begin
        $fscanf(fd_chk_csr_uimm_mem, "%d\n", chk_csr_uimm_mem);
        sample_cnt_chk_csr_uimm_mem = sample_cnt_chk_csr_uimm_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_uimm_mem' done. Samples read: %0d.", sample_cnt_chk_csr_uimm_mem);
end

integer fd_chk_csr_dout_mem;
integer sample_cnt_chk_csr_dout_mem = 0;
reg [31:0] chk_csr_dout_mem;
initial begin
    fd_chk_csr_dout_mem = $fopen({`STIM_PATH, `"/chk_csr_dout_mem`", `".txt`"}, "r");
    if (fd_chk_csr_dout_mem) begin
        $display("File 'chk_csr_dout_mem' opened: %0d", fd_chk_csr_dout_mem);
    end
    else begin
        $display("File 'chk_csr_dout_mem' could not be opened: %0d. Exiting simulation.", fd_chk_csr_dout_mem);
        $finish;
    end
    while (! $feof(fd_chk_csr_dout_mem)) begin
        $fscanf(fd_chk_csr_dout_mem, "%d\n", chk_csr_dout_mem);
        sample_cnt_chk_csr_dout_mem = sample_cnt_chk_csr_dout_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_csr_dout_mem' done. Samples read: %0d.", sample_cnt_chk_csr_dout_mem);
end

integer fd_chk_dmem_dout;
integer sample_cnt_chk_dmem_dout = 0;
reg [31:0] chk_dmem_dout;
initial begin
    fd_chk_dmem_dout = $fopen({`STIM_PATH, `"/chk_dmem_dout`", `".txt`"}, "r");
    if (fd_chk_dmem_dout) begin
        $display("File 'chk_dmem_dout' opened: %0d", fd_chk_dmem_dout);
    end
    else begin
        $display("File 'chk_dmem_dout' could not be opened: %0d. Exiting simulation.", fd_chk_dmem_dout);
        $finish;
    end
    while (! $feof(fd_chk_dmem_dout)) begin
        $fscanf(fd_chk_dmem_dout, "%d\n", chk_dmem_dout);
        sample_cnt_chk_dmem_dout = sample_cnt_chk_dmem_dout + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_dmem_dout' done. Samples read: %0d.", sample_cnt_chk_dmem_dout);
end

integer fd_chk_load_sm_en_mem;
integer sample_cnt_chk_load_sm_en_mem = 0;
reg [31:0] chk_load_sm_en_mem;
initial begin
    fd_chk_load_sm_en_mem = $fopen({`STIM_PATH, `"/chk_load_sm_en_mem`", `".txt`"}, "r");
    if (fd_chk_load_sm_en_mem) begin
        $display("File 'chk_load_sm_en_mem' opened: %0d", fd_chk_load_sm_en_mem);
    end
    else begin
        $display("File 'chk_load_sm_en_mem' could not be opened: %0d. Exiting simulation.", fd_chk_load_sm_en_mem);
        $finish;
    end
    while (! $feof(fd_chk_load_sm_en_mem)) begin
        $fscanf(fd_chk_load_sm_en_mem, "%d\n", chk_load_sm_en_mem);
        sample_cnt_chk_load_sm_en_mem = sample_cnt_chk_load_sm_en_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_load_sm_en_mem' done. Samples read: %0d.", sample_cnt_chk_load_sm_en_mem);
end

integer fd_chk_wb_sel_mem;
integer sample_cnt_chk_wb_sel_mem = 0;
reg [31:0] chk_wb_sel_mem;
initial begin
    fd_chk_wb_sel_mem = $fopen({`STIM_PATH, `"/chk_wb_sel_mem`", `".txt`"}, "r");
    if (fd_chk_wb_sel_mem) begin
        $display("File 'chk_wb_sel_mem' opened: %0d", fd_chk_wb_sel_mem);
    end
    else begin
        $display("File 'chk_wb_sel_mem' could not be opened: %0d. Exiting simulation.", fd_chk_wb_sel_mem);
        $finish;
    end
    while (! $feof(fd_chk_wb_sel_mem)) begin
        $fscanf(fd_chk_wb_sel_mem, "%d\n", chk_wb_sel_mem);
        sample_cnt_chk_wb_sel_mem = sample_cnt_chk_wb_sel_mem + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_wb_sel_mem' done. Samples read: %0d.", sample_cnt_chk_wb_sel_mem);
end

integer fd_chk_inst_wb;
integer sample_cnt_chk_inst_wb = 0;
reg [31:0] chk_inst_wb;
initial begin
    fd_chk_inst_wb = $fopen({`STIM_PATH, `"/chk_inst_wb`", `".txt`"}, "r");
    if (fd_chk_inst_wb) begin
        $display("File 'chk_inst_wb' opened: %0d", fd_chk_inst_wb);
    end
    else begin
        $display("File 'chk_inst_wb' could not be opened: %0d. Exiting simulation.", fd_chk_inst_wb);
        $finish;
    end
    while (! $feof(fd_chk_inst_wb)) begin
        $fscanf(fd_chk_inst_wb, "%d\n", chk_inst_wb);
        sample_cnt_chk_inst_wb = sample_cnt_chk_inst_wb + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_inst_wb' done. Samples read: %0d.", sample_cnt_chk_inst_wb);
end

integer fd_chk_x1;
integer sample_cnt_chk_x1 = 0;
reg [31:0] chk_x1;
initial begin
    fd_chk_x1 = $fopen({`STIM_PATH, `"/chk_x1`", `".txt`"}, "r");
    if (fd_chk_x1) begin
        $display("File 'chk_x1' opened: %0d", fd_chk_x1);
    end
    else begin
        $display("File 'chk_x1' could not be opened: %0d. Exiting simulation.", fd_chk_x1);
        $finish;
    end
    while (! $feof(fd_chk_x1)) begin
        $fscanf(fd_chk_x1, "%d\n", chk_x1);
        sample_cnt_chk_x1 = sample_cnt_chk_x1 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x1' done. Samples read: %0d.", sample_cnt_chk_x1);
end

integer fd_chk_x2;
integer sample_cnt_chk_x2 = 0;
reg [31:0] chk_x2;
initial begin
    fd_chk_x2 = $fopen({`STIM_PATH, `"/chk_x2`", `".txt`"}, "r");
    if (fd_chk_x2) begin
        $display("File 'chk_x2' opened: %0d", fd_chk_x2);
    end
    else begin
        $display("File 'chk_x2' could not be opened: %0d. Exiting simulation.", fd_chk_x2);
        $finish;
    end
    while (! $feof(fd_chk_x2)) begin
        $fscanf(fd_chk_x2, "%d\n", chk_x2);
        sample_cnt_chk_x2 = sample_cnt_chk_x2 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x2' done. Samples read: %0d.", sample_cnt_chk_x2);
end

integer fd_chk_x3;
integer sample_cnt_chk_x3 = 0;
reg [31:0] chk_x3;
initial begin
    fd_chk_x3 = $fopen({`STIM_PATH, `"/chk_x3`", `".txt`"}, "r");
    if (fd_chk_x3) begin
        $display("File 'chk_x3' opened: %0d", fd_chk_x3);
    end
    else begin
        $display("File 'chk_x3' could not be opened: %0d. Exiting simulation.", fd_chk_x3);
        $finish;
    end
    while (! $feof(fd_chk_x3)) begin
        $fscanf(fd_chk_x3, "%d\n", chk_x3);
        sample_cnt_chk_x3 = sample_cnt_chk_x3 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x3' done. Samples read: %0d.", sample_cnt_chk_x3);
end

integer fd_chk_x4;
integer sample_cnt_chk_x4 = 0;
reg [31:0] chk_x4;
initial begin
    fd_chk_x4 = $fopen({`STIM_PATH, `"/chk_x4`", `".txt`"}, "r");
    if (fd_chk_x4) begin
        $display("File 'chk_x4' opened: %0d", fd_chk_x4);
    end
    else begin
        $display("File 'chk_x4' could not be opened: %0d. Exiting simulation.", fd_chk_x4);
        $finish;
    end
    while (! $feof(fd_chk_x4)) begin
        $fscanf(fd_chk_x4, "%d\n", chk_x4);
        sample_cnt_chk_x4 = sample_cnt_chk_x4 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x4' done. Samples read: %0d.", sample_cnt_chk_x4);
end

integer fd_chk_x5;
integer sample_cnt_chk_x5 = 0;
reg [31:0] chk_x5;
initial begin
    fd_chk_x5 = $fopen({`STIM_PATH, `"/chk_x5`", `".txt`"}, "r");
    if (fd_chk_x5) begin
        $display("File 'chk_x5' opened: %0d", fd_chk_x5);
    end
    else begin
        $display("File 'chk_x5' could not be opened: %0d. Exiting simulation.", fd_chk_x5);
        $finish;
    end
    while (! $feof(fd_chk_x5)) begin
        $fscanf(fd_chk_x5, "%d\n", chk_x5);
        sample_cnt_chk_x5 = sample_cnt_chk_x5 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x5' done. Samples read: %0d.", sample_cnt_chk_x5);
end

integer fd_chk_x6;
integer sample_cnt_chk_x6 = 0;
reg [31:0] chk_x6;
initial begin
    fd_chk_x6 = $fopen({`STIM_PATH, `"/chk_x6`", `".txt`"}, "r");
    if (fd_chk_x6) begin
        $display("File 'chk_x6' opened: %0d", fd_chk_x6);
    end
    else begin
        $display("File 'chk_x6' could not be opened: %0d. Exiting simulation.", fd_chk_x6);
        $finish;
    end
    while (! $feof(fd_chk_x6)) begin
        $fscanf(fd_chk_x6, "%d\n", chk_x6);
        sample_cnt_chk_x6 = sample_cnt_chk_x6 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x6' done. Samples read: %0d.", sample_cnt_chk_x6);
end

integer fd_chk_x7;
integer sample_cnt_chk_x7 = 0;
reg [31:0] chk_x7;
initial begin
    fd_chk_x7 = $fopen({`STIM_PATH, `"/chk_x7`", `".txt`"}, "r");
    if (fd_chk_x7) begin
        $display("File 'chk_x7' opened: %0d", fd_chk_x7);
    end
    else begin
        $display("File 'chk_x7' could not be opened: %0d. Exiting simulation.", fd_chk_x7);
        $finish;
    end
    while (! $feof(fd_chk_x7)) begin
        $fscanf(fd_chk_x7, "%d\n", chk_x7);
        sample_cnt_chk_x7 = sample_cnt_chk_x7 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x7' done. Samples read: %0d.", sample_cnt_chk_x7);
end

integer fd_chk_x8;
integer sample_cnt_chk_x8 = 0;
reg [31:0] chk_x8;
initial begin
    fd_chk_x8 = $fopen({`STIM_PATH, `"/chk_x8`", `".txt`"}, "r");
    if (fd_chk_x8) begin
        $display("File 'chk_x8' opened: %0d", fd_chk_x8);
    end
    else begin
        $display("File 'chk_x8' could not be opened: %0d. Exiting simulation.", fd_chk_x8);
        $finish;
    end
    while (! $feof(fd_chk_x8)) begin
        $fscanf(fd_chk_x8, "%d\n", chk_x8);
        sample_cnt_chk_x8 = sample_cnt_chk_x8 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x8' done. Samples read: %0d.", sample_cnt_chk_x8);
end

integer fd_chk_x9;
integer sample_cnt_chk_x9 = 0;
reg [31:0] chk_x9;
initial begin
    fd_chk_x9 = $fopen({`STIM_PATH, `"/chk_x9`", `".txt`"}, "r");
    if (fd_chk_x9) begin
        $display("File 'chk_x9' opened: %0d", fd_chk_x9);
    end
    else begin
        $display("File 'chk_x9' could not be opened: %0d. Exiting simulation.", fd_chk_x9);
        $finish;
    end
    while (! $feof(fd_chk_x9)) begin
        $fscanf(fd_chk_x9, "%d\n", chk_x9);
        sample_cnt_chk_x9 = sample_cnt_chk_x9 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x9' done. Samples read: %0d.", sample_cnt_chk_x9);
end

integer fd_chk_x10;
integer sample_cnt_chk_x10 = 0;
reg [31:0] chk_x10;
initial begin
    fd_chk_x10 = $fopen({`STIM_PATH, `"/chk_x10`", `".txt`"}, "r");
    if (fd_chk_x10) begin
        $display("File 'chk_x10' opened: %0d", fd_chk_x10);
    end
    else begin
        $display("File 'chk_x10' could not be opened: %0d. Exiting simulation.", fd_chk_x10);
        $finish;
    end
    while (! $feof(fd_chk_x10)) begin
        $fscanf(fd_chk_x10, "%d\n", chk_x10);
        sample_cnt_chk_x10 = sample_cnt_chk_x10 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x10' done. Samples read: %0d.", sample_cnt_chk_x10);
end

integer fd_chk_x11;
integer sample_cnt_chk_x11 = 0;
reg [31:0] chk_x11;
initial begin
    fd_chk_x11 = $fopen({`STIM_PATH, `"/chk_x11`", `".txt`"}, "r");
    if (fd_chk_x11) begin
        $display("File 'chk_x11' opened: %0d", fd_chk_x11);
    end
    else begin
        $display("File 'chk_x11' could not be opened: %0d. Exiting simulation.", fd_chk_x11);
        $finish;
    end
    while (! $feof(fd_chk_x11)) begin
        $fscanf(fd_chk_x11, "%d\n", chk_x11);
        sample_cnt_chk_x11 = sample_cnt_chk_x11 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x11' done. Samples read: %0d.", sample_cnt_chk_x11);
end

integer fd_chk_x12;
integer sample_cnt_chk_x12 = 0;
reg [31:0] chk_x12;
initial begin
    fd_chk_x12 = $fopen({`STIM_PATH, `"/chk_x12`", `".txt`"}, "r");
    if (fd_chk_x12) begin
        $display("File 'chk_x12' opened: %0d", fd_chk_x12);
    end
    else begin
        $display("File 'chk_x12' could not be opened: %0d. Exiting simulation.", fd_chk_x12);
        $finish;
    end
    while (! $feof(fd_chk_x12)) begin
        $fscanf(fd_chk_x12, "%d\n", chk_x12);
        sample_cnt_chk_x12 = sample_cnt_chk_x12 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x12' done. Samples read: %0d.", sample_cnt_chk_x12);
end

integer fd_chk_x13;
integer sample_cnt_chk_x13 = 0;
reg [31:0] chk_x13;
initial begin
    fd_chk_x13 = $fopen({`STIM_PATH, `"/chk_x13`", `".txt`"}, "r");
    if (fd_chk_x13) begin
        $display("File 'chk_x13' opened: %0d", fd_chk_x13);
    end
    else begin
        $display("File 'chk_x13' could not be opened: %0d. Exiting simulation.", fd_chk_x13);
        $finish;
    end
    while (! $feof(fd_chk_x13)) begin
        $fscanf(fd_chk_x13, "%d\n", chk_x13);
        sample_cnt_chk_x13 = sample_cnt_chk_x13 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x13' done. Samples read: %0d.", sample_cnt_chk_x13);
end

integer fd_chk_x14;
integer sample_cnt_chk_x14 = 0;
reg [31:0] chk_x14;
initial begin
    fd_chk_x14 = $fopen({`STIM_PATH, `"/chk_x14`", `".txt`"}, "r");
    if (fd_chk_x14) begin
        $display("File 'chk_x14' opened: %0d", fd_chk_x14);
    end
    else begin
        $display("File 'chk_x14' could not be opened: %0d. Exiting simulation.", fd_chk_x14);
        $finish;
    end
    while (! $feof(fd_chk_x14)) begin
        $fscanf(fd_chk_x14, "%d\n", chk_x14);
        sample_cnt_chk_x14 = sample_cnt_chk_x14 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x14' done. Samples read: %0d.", sample_cnt_chk_x14);
end

integer fd_chk_x15;
integer sample_cnt_chk_x15 = 0;
reg [31:0] chk_x15;
initial begin
    fd_chk_x15 = $fopen({`STIM_PATH, `"/chk_x15`", `".txt`"}, "r");
    if (fd_chk_x15) begin
        $display("File 'chk_x15' opened: %0d", fd_chk_x15);
    end
    else begin
        $display("File 'chk_x15' could not be opened: %0d. Exiting simulation.", fd_chk_x15);
        $finish;
    end
    while (! $feof(fd_chk_x15)) begin
        $fscanf(fd_chk_x15, "%d\n", chk_x15);
        sample_cnt_chk_x15 = sample_cnt_chk_x15 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x15' done. Samples read: %0d.", sample_cnt_chk_x15);
end

integer fd_chk_x16;
integer sample_cnt_chk_x16 = 0;
reg [31:0] chk_x16;
initial begin
    fd_chk_x16 = $fopen({`STIM_PATH, `"/chk_x16`", `".txt`"}, "r");
    if (fd_chk_x16) begin
        $display("File 'chk_x16' opened: %0d", fd_chk_x16);
    end
    else begin
        $display("File 'chk_x16' could not be opened: %0d. Exiting simulation.", fd_chk_x16);
        $finish;
    end
    while (! $feof(fd_chk_x16)) begin
        $fscanf(fd_chk_x16, "%d\n", chk_x16);
        sample_cnt_chk_x16 = sample_cnt_chk_x16 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x16' done. Samples read: %0d.", sample_cnt_chk_x16);
end

integer fd_chk_x17;
integer sample_cnt_chk_x17 = 0;
reg [31:0] chk_x17;
initial begin
    fd_chk_x17 = $fopen({`STIM_PATH, `"/chk_x17`", `".txt`"}, "r");
    if (fd_chk_x17) begin
        $display("File 'chk_x17' opened: %0d", fd_chk_x17);
    end
    else begin
        $display("File 'chk_x17' could not be opened: %0d. Exiting simulation.", fd_chk_x17);
        $finish;
    end
    while (! $feof(fd_chk_x17)) begin
        $fscanf(fd_chk_x17, "%d\n", chk_x17);
        sample_cnt_chk_x17 = sample_cnt_chk_x17 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x17' done. Samples read: %0d.", sample_cnt_chk_x17);
end

integer fd_chk_x18;
integer sample_cnt_chk_x18 = 0;
reg [31:0] chk_x18;
initial begin
    fd_chk_x18 = $fopen({`STIM_PATH, `"/chk_x18`", `".txt`"}, "r");
    if (fd_chk_x18) begin
        $display("File 'chk_x18' opened: %0d", fd_chk_x18);
    end
    else begin
        $display("File 'chk_x18' could not be opened: %0d. Exiting simulation.", fd_chk_x18);
        $finish;
    end
    while (! $feof(fd_chk_x18)) begin
        $fscanf(fd_chk_x18, "%d\n", chk_x18);
        sample_cnt_chk_x18 = sample_cnt_chk_x18 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x18' done. Samples read: %0d.", sample_cnt_chk_x18);
end

integer fd_chk_x19;
integer sample_cnt_chk_x19 = 0;
reg [31:0] chk_x19;
initial begin
    fd_chk_x19 = $fopen({`STIM_PATH, `"/chk_x19`", `".txt`"}, "r");
    if (fd_chk_x19) begin
        $display("File 'chk_x19' opened: %0d", fd_chk_x19);
    end
    else begin
        $display("File 'chk_x19' could not be opened: %0d. Exiting simulation.", fd_chk_x19);
        $finish;
    end
    while (! $feof(fd_chk_x19)) begin
        $fscanf(fd_chk_x19, "%d\n", chk_x19);
        sample_cnt_chk_x19 = sample_cnt_chk_x19 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x19' done. Samples read: %0d.", sample_cnt_chk_x19);
end

integer fd_chk_x20;
integer sample_cnt_chk_x20 = 0;
reg [31:0] chk_x20;
initial begin
    fd_chk_x20 = $fopen({`STIM_PATH, `"/chk_x20`", `".txt`"}, "r");
    if (fd_chk_x20) begin
        $display("File 'chk_x20' opened: %0d", fd_chk_x20);
    end
    else begin
        $display("File 'chk_x20' could not be opened: %0d. Exiting simulation.", fd_chk_x20);
        $finish;
    end
    while (! $feof(fd_chk_x20)) begin
        $fscanf(fd_chk_x20, "%d\n", chk_x20);
        sample_cnt_chk_x20 = sample_cnt_chk_x20 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x20' done. Samples read: %0d.", sample_cnt_chk_x20);
end

integer fd_chk_x21;
integer sample_cnt_chk_x21 = 0;
reg [31:0] chk_x21;
initial begin
    fd_chk_x21 = $fopen({`STIM_PATH, `"/chk_x21`", `".txt`"}, "r");
    if (fd_chk_x21) begin
        $display("File 'chk_x21' opened: %0d", fd_chk_x21);
    end
    else begin
        $display("File 'chk_x21' could not be opened: %0d. Exiting simulation.", fd_chk_x21);
        $finish;
    end
    while (! $feof(fd_chk_x21)) begin
        $fscanf(fd_chk_x21, "%d\n", chk_x21);
        sample_cnt_chk_x21 = sample_cnt_chk_x21 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x21' done. Samples read: %0d.", sample_cnt_chk_x21);
end

integer fd_chk_x22;
integer sample_cnt_chk_x22 = 0;
reg [31:0] chk_x22;
initial begin
    fd_chk_x22 = $fopen({`STIM_PATH, `"/chk_x22`", `".txt`"}, "r");
    if (fd_chk_x22) begin
        $display("File 'chk_x22' opened: %0d", fd_chk_x22);
    end
    else begin
        $display("File 'chk_x22' could not be opened: %0d. Exiting simulation.", fd_chk_x22);
        $finish;
    end
    while (! $feof(fd_chk_x22)) begin
        $fscanf(fd_chk_x22, "%d\n", chk_x22);
        sample_cnt_chk_x22 = sample_cnt_chk_x22 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x22' done. Samples read: %0d.", sample_cnt_chk_x22);
end

integer fd_chk_x23;
integer sample_cnt_chk_x23 = 0;
reg [31:0] chk_x23;
initial begin
    fd_chk_x23 = $fopen({`STIM_PATH, `"/chk_x23`", `".txt`"}, "r");
    if (fd_chk_x23) begin
        $display("File 'chk_x23' opened: %0d", fd_chk_x23);
    end
    else begin
        $display("File 'chk_x23' could not be opened: %0d. Exiting simulation.", fd_chk_x23);
        $finish;
    end
    while (! $feof(fd_chk_x23)) begin
        $fscanf(fd_chk_x23, "%d\n", chk_x23);
        sample_cnt_chk_x23 = sample_cnt_chk_x23 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x23' done. Samples read: %0d.", sample_cnt_chk_x23);
end

integer fd_chk_x24;
integer sample_cnt_chk_x24 = 0;
reg [31:0] chk_x24;
initial begin
    fd_chk_x24 = $fopen({`STIM_PATH, `"/chk_x24`", `".txt`"}, "r");
    if (fd_chk_x24) begin
        $display("File 'chk_x24' opened: %0d", fd_chk_x24);
    end
    else begin
        $display("File 'chk_x24' could not be opened: %0d. Exiting simulation.", fd_chk_x24);
        $finish;
    end
    while (! $feof(fd_chk_x24)) begin
        $fscanf(fd_chk_x24, "%d\n", chk_x24);
        sample_cnt_chk_x24 = sample_cnt_chk_x24 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x24' done. Samples read: %0d.", sample_cnt_chk_x24);
end

integer fd_chk_x25;
integer sample_cnt_chk_x25 = 0;
reg [31:0] chk_x25;
initial begin
    fd_chk_x25 = $fopen({`STIM_PATH, `"/chk_x25`", `".txt`"}, "r");
    if (fd_chk_x25) begin
        $display("File 'chk_x25' opened: %0d", fd_chk_x25);
    end
    else begin
        $display("File 'chk_x25' could not be opened: %0d. Exiting simulation.", fd_chk_x25);
        $finish;
    end
    while (! $feof(fd_chk_x25)) begin
        $fscanf(fd_chk_x25, "%d\n", chk_x25);
        sample_cnt_chk_x25 = sample_cnt_chk_x25 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x25' done. Samples read: %0d.", sample_cnt_chk_x25);
end

integer fd_chk_x26;
integer sample_cnt_chk_x26 = 0;
reg [31:0] chk_x26;
initial begin
    fd_chk_x26 = $fopen({`STIM_PATH, `"/chk_x26`", `".txt`"}, "r");
    if (fd_chk_x26) begin
        $display("File 'chk_x26' opened: %0d", fd_chk_x26);
    end
    else begin
        $display("File 'chk_x26' could not be opened: %0d. Exiting simulation.", fd_chk_x26);
        $finish;
    end
    while (! $feof(fd_chk_x26)) begin
        $fscanf(fd_chk_x26, "%d\n", chk_x26);
        sample_cnt_chk_x26 = sample_cnt_chk_x26 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x26' done. Samples read: %0d.", sample_cnt_chk_x26);
end

integer fd_chk_x27;
integer sample_cnt_chk_x27 = 0;
reg [31:0] chk_x27;
initial begin
    fd_chk_x27 = $fopen({`STIM_PATH, `"/chk_x27`", `".txt`"}, "r");
    if (fd_chk_x27) begin
        $display("File 'chk_x27' opened: %0d", fd_chk_x27);
    end
    else begin
        $display("File 'chk_x27' could not be opened: %0d. Exiting simulation.", fd_chk_x27);
        $finish;
    end
    while (! $feof(fd_chk_x27)) begin
        $fscanf(fd_chk_x27, "%d\n", chk_x27);
        sample_cnt_chk_x27 = sample_cnt_chk_x27 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x27' done. Samples read: %0d.", sample_cnt_chk_x27);
end

integer fd_chk_x28;
integer sample_cnt_chk_x28 = 0;
reg [31:0] chk_x28;
initial begin
    fd_chk_x28 = $fopen({`STIM_PATH, `"/chk_x28`", `".txt`"}, "r");
    if (fd_chk_x28) begin
        $display("File 'chk_x28' opened: %0d", fd_chk_x28);
    end
    else begin
        $display("File 'chk_x28' could not be opened: %0d. Exiting simulation.", fd_chk_x28);
        $finish;
    end
    while (! $feof(fd_chk_x28)) begin
        $fscanf(fd_chk_x28, "%d\n", chk_x28);
        sample_cnt_chk_x28 = sample_cnt_chk_x28 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x28' done. Samples read: %0d.", sample_cnt_chk_x28);
end

integer fd_chk_x29;
integer sample_cnt_chk_x29 = 0;
reg [31:0] chk_x29;
initial begin
    fd_chk_x29 = $fopen({`STIM_PATH, `"/chk_x29`", `".txt`"}, "r");
    if (fd_chk_x29) begin
        $display("File 'chk_x29' opened: %0d", fd_chk_x29);
    end
    else begin
        $display("File 'chk_x29' could not be opened: %0d. Exiting simulation.", fd_chk_x29);
        $finish;
    end
    while (! $feof(fd_chk_x29)) begin
        $fscanf(fd_chk_x29, "%d\n", chk_x29);
        sample_cnt_chk_x29 = sample_cnt_chk_x29 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x29' done. Samples read: %0d.", sample_cnt_chk_x29);
end

integer fd_chk_x30;
integer sample_cnt_chk_x30 = 0;
reg [31:0] chk_x30;
initial begin
    fd_chk_x30 = $fopen({`STIM_PATH, `"/chk_x30`", `".txt`"}, "r");
    if (fd_chk_x30) begin
        $display("File 'chk_x30' opened: %0d", fd_chk_x30);
    end
    else begin
        $display("File 'chk_x30' could not be opened: %0d. Exiting simulation.", fd_chk_x30);
        $finish;
    end
    while (! $feof(fd_chk_x30)) begin
        $fscanf(fd_chk_x30, "%d\n", chk_x30);
        sample_cnt_chk_x30 = sample_cnt_chk_x30 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x30' done. Samples read: %0d.", sample_cnt_chk_x30);
end

integer fd_chk_x31;
integer sample_cnt_chk_x31 = 0;
reg [31:0] chk_x31;
initial begin
    fd_chk_x31 = $fopen({`STIM_PATH, `"/chk_x31`", `".txt`"}, "r");
    if (fd_chk_x31) begin
        $display("File 'chk_x31' opened: %0d", fd_chk_x31);
    end
    else begin
        $display("File 'chk_x31' could not be opened: %0d. Exiting simulation.", fd_chk_x31);
        $finish;
    end
    while (! $feof(fd_chk_x31)) begin
        $fscanf(fd_chk_x31, "%d\n", chk_x31);
        sample_cnt_chk_x31 = sample_cnt_chk_x31 + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_x31' done. Samples read: %0d.", sample_cnt_chk_x31);
end

integer fd_chk_tohost;
integer sample_cnt_chk_tohost = 0;
reg [31:0] chk_tohost;
initial begin
    fd_chk_tohost = $fopen({`STIM_PATH, `"/chk_tohost`", `".txt`"}, "r");
    if (fd_chk_tohost) begin
        $display("File 'chk_tohost' opened: %0d", fd_chk_tohost);
    end
    else begin
        $display("File 'chk_tohost' could not be opened: %0d. Exiting simulation.", fd_chk_tohost);
        $finish;
    end
    while (! $feof(fd_chk_tohost)) begin
        $fscanf(fd_chk_tohost, "%d\n", chk_tohost);
        sample_cnt_chk_tohost = sample_cnt_chk_tohost + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_tohost' done. Samples read: %0d.", sample_cnt_chk_tohost);
end

integer fd_chk_alu_out;
integer sample_cnt_chk_alu_out = 0;
reg [31:0] chk_alu_out;
initial begin
    fd_chk_alu_out = $fopen({`STIM_PATH, `"/chk_alu_out`", `".txt`"}, "r");
    if (fd_chk_alu_out) begin
        $display("File 'chk_alu_out' opened: %0d", fd_chk_alu_out);
    end
    else begin
        $display("File 'chk_alu_out' could not be opened: %0d. Exiting simulation.", fd_chk_alu_out);
        $finish;
    end
    while (! $feof(fd_chk_alu_out)) begin
        $fscanf(fd_chk_alu_out, "%d\n", chk_alu_out);
        sample_cnt_chk_alu_out = sample_cnt_chk_alu_out + 1; 
        @(posedge clk); 
    end
end
initial begin
    @(posedge sim_done); 
    $display("Vector read 'chk_alu_out' done. Samples read: %0d.", sample_cnt_chk_alu_out);
end
