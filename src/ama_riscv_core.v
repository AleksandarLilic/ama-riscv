//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Core
// File:            ama_riscv_core.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     CPU Core - Control & Datapath
//
// Version history:
//      2021-09-11  AL  0.1.0 - Initial - IF stage
//      2021-09-13  AL  0.1.1 - Fix IMEM address signal
//      2021-09-14  AL  0.2.0 - Add ID stage
//      2021-09-18  AL  0.3.0 - Finish ID/EX pipeline
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_core (
    input   wire        clk  ,
    input   wire        rst
);

//-----------------------------------------------------------------------------
// Signals

// Pipeline control inputs
wire        stall_if                ;
wire        clear_if                ;
wire        clear_id                ;
wire        clear_ex                ;
wire        clear_mem               ;
    
// Signals - MEM stage  
    
// Signals - EX stage   
reg  [31:0] inst_ex                 ;
reg         reg_we_ex               ;
reg  [ 4:0] rd_addr_ex              ;
reg         store_inst_ex           ;
// from datapath
wire        bc_a_eq_b               ;
wire        bc_a_lt_b               ;
wire [ 1:0] store_mask_offset       ;

// Signals - ID stage
wire [31:0] inst_id                 ;
// wire        bp_taken               ;
// wire        bp_clear               ;
wire        store_inst_id           ;
wire        branch_inst_id          ;
wire        jump_inst_id            ;
wire [ 2:0] imm_gen_sel_id          ;
wire [ 3:0] alu_op_sel_id           ;
wire [ 1:0] alu_a_sel_fwd_id        ;
wire [ 1:0] alu_b_sel_fwd_id        ;
wire        bc_a_sel_fwd_id         ;
wire        bcs_b_sel_fwd_id        ;
wire        bc_uns_id               ;
wire [ 3:0] dmem_we_id              ;
wire        dmem_en_id              ;
wire        load_sm_en_id           ;
wire [ 1:0] wb_sel_id               ;
wire        reg_we_id               ;

// Signals - IF stage            
wire [ 1:0] pc_sel_if               ;
wire        pc_we_if                ;

//-----------------------------------------------------------------------------
// Control
ama_riscv_control ama_riscv_control_i (
    .clk                (clk            ),
    .rst                (rst            ),
    // inputs
    .inst_id            (inst_id        ),
    .bc_a_eq_b          (bc_a_eq_b      ),
    .bc_a_lt_b          (bc_a_lt_b      ),
    // .bp_taken           (bp_taken       ),
    // .bp_clear           (bp_clear       ),
    .store_mask_offset  (store_mask_offset),
    // pipeline inputs
    .inst_ex            (inst_ex        ),
    .reg_we_ex          (reg_we_ex      ),
    .rd_ex              (rd_addr_ex     ),
    .store_inst_ex      (store_inst_ex  ),
    // pipeline outputs
    .stall_if           (stall_if       ),
    .clear_if           (clear_if       ),
    .clear_id           (clear_id       ),
    .clear_ex           (clear_ex       ),
    .clear_mem          (clear_mem      ),
    // pipeline resets                  
                                        
    // outputs                          
    .pc_sel             (pc_sel_if          ),
    .pc_we              (pc_we_if           ),
    // .imem_en            (imem_en           ),
    .store_inst         (store_inst_id      ),
    .branch_inst        (branch_inst_id     ),
    .jump_inst          (jump_inst_id       ),
    .alu_op_sel         (alu_op_sel_id      ),
    .ig_sel             (imm_gen_sel_id     ),
    .bc_uns             (bc_uns_id          ),
    .dmem_en            (dmem_en_id         ),
    .load_sm_en         (load_sm_en_id      ),
    .wb_sel             (wb_sel_id          ),
    .reg_we             (reg_we_id          ),
    .alu_a_sel_fwd      (alu_a_sel_fwd_id   ),
    .alu_b_sel_fwd      (alu_b_sel_fwd_id   ),
    .bc_a_sel_fwd       (bc_a_sel_fwd_id    ),
    .bcs_b_sel_fwd      (bcs_b_sel_fwd_id   ),
    .dmem_we            (dmem_we_id         )
);

//-----------------------------------------------------------------------------
// IF Stage
reg  [31:0] pc_mux_out  ;
reg  [31:0] pc          ;
wire [31:0] pc_inc4     ;
wire [13:0] imem_addr   ;
wire [31:0] alu_out     ;

// PC select mux
always @ (*) begin
    case (pc_sel_if)
        `PC_SEL_INC4:
            pc_mux_out =  pc_inc4;
        `PC_SEL_ALU:
            pc_mux_out =  alu_out;
        // `PC_SEL_BP:
            // pc_mux_out =  bp_out;
        `PC_SEL_START_ADDR:
            pc_mux_out =  32'h0;
        default: 
            pc_mux_out =  pc_inc4;
    endcase
end

// PC
always @ (posedge clk) begin
    if (rst)
        pc <= 32'h0;
    else if (pc_we_if)
        pc <= pc_mux_out;
end

assign pc_inc4 = pc + 32'd4;

// IMEM
wire [31:0] inst_id_read    ;
assign imem_addr = pc_mux_out[15:2];
ama_riscv_imem ama_riscv_imem_i (
    .clk   (clk         ),
    .ena   (1'b0        ),
    .wea   (4'd0        ),
    .addra (14'd0       ),
    .dina  (32'd0       ),
    .addrb (imem_addr   ),
    .doutb (inst_id_read)
);

// stall_if delay
reg         stall_if_q1;
always @ (posedge clk) begin
    if (rst)
        stall_if_q1 <= 32'h0;
    else
        stall_if_q1 <= stall_if;
end

//-----------------------------------------------------------------------------
// ID Stage

// Convert to NOP?
assign inst_id = (stall_if_q1) ? `NOP : inst_id_read;

// Signals - MEM stage
reg         reg_we_mem  ;
wire [31:0] writeback   ;
reg  [ 4:0] rd_addr_mem ;

// Signals - ID stage
wire [31:0] pc_id = pc;
// Reg file
wire [ 4:0] rs1_addr    = inst_id[19:15];
wire [ 4:0] rs2_addr    = inst_id[24:20];
wire [ 4:0] rd_addr_id  = inst_id[11: 7];
wire [31:0] rd_data     = writeback;
wire [31:0] rs1_data_id ;
wire [31:0] rs2_data_id ;
// Imm Gen
wire [24:0] imm_gen_in  = inst_id[31: 7];
wire [31:0] imm_gen_out_id  ;

// Register File
ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk    (clk        ),
    .rst    (rst        ),
    // inputs
    // .we     (reg_we_mem ),
    .we     (1'b0 ),
    .addr_a (rs1_addr     ),
    .addr_b (rs2_addr     ),
    // .addr_d (rd_addr_mem ),
    .addr_d (5'd0       ),
    // .data_d (rd_data     ),
    .data_d (32'd0      ),
    // outputs
    .data_a (rs1_data_id     ),
    .data_b (rs2_data_id     )
);

// Imm Gen
ama_riscv_imm_gen ama_riscv_imm_gen_i(
   .clk     (clk            ),
   .rst     (rst            ),
   // inputs    
   .ig_sel  (imm_gen_sel_id ),
   .ig_in   (imm_gen_in     ),
   // outputs
   .ig_out  (imm_gen_out_id )
);

//-----------------------------------------------------------------------------
// Pipeline FF ID/EX
// Signals
reg  [31:0] pc_ex               ; 
// reg  [ 4:0] rd_addr_ex          ;   // defined previously
reg  [31:0] rs1_data_ex         ;
reg  [31:0] rs2_data_ex         ;
reg  [31:0] imm_gen_out_ex      ;
// reg  [31:0] inst_ex             ;   // defined previously
reg         bc_a_sel_fwd_ex     ;
reg         bcs_b_sel_fwd_ex    ;
reg         bc_uns_ex           ;
reg  [ 1:0] alu_a_sel_fwd_ex    ;
reg  [ 1:0] alu_b_sel_fwd_ex    ;
reg  [ 3:0] alu_op_sel_ex       ;
reg         dmem_en_ex          ;
reg  [ 3:0] dmem_we_ex          ;
reg         load_sm_en_ex       ;
reg  [ 1:0] wb_sel_ex           ;
// reg         reg_we_ex           ;   // defined previously

always @ (posedge clk) begin
    if (rst) begin
        // datapath
        pc_ex            <= 32'h0;
        rd_addr_ex       <=  5'h0;
        rs1_data_ex      <= 32'h0;
        rs2_data_ex      <= 32'h0;
        imm_gen_out_ex   <= 32'h0;
        inst_ex          <= 32'h0;
        // control       
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
        dmem_we_ex       <=  4'h0;
        load_sm_en_ex    <=  1'b0;
        wb_sel_ex        <=  2'h0;
        reg_we_ex        <=  1'b0;
    end
    else if (clear_id) begin
        // datapath
        pc_ex            <= 32'h0;
        rd_addr_ex       <=  5'h0;
        rs1_data_ex      <= 32'h0;
        rs2_data_ex      <= 32'h0;
        imm_gen_out_ex   <= 32'h0;
        inst_ex          <= 32'h0;
        // control       
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
        dmem_we_ex       <=  4'h0;
        load_sm_en_ex    <=  1'b0;
        wb_sel_ex        <=  2'h0;
        reg_we_ex        <=  1'b0;
    end
    else begin
        // datapath
        pc_ex            <= pc_id           ;
        rd_addr_ex       <= rd_addr_id      ;
        rs1_data_ex      <= rs1_data_id     ;
        rs2_data_ex      <= rs2_data_id     ;
        imm_gen_out_ex   <= imm_gen_out_id  ;
        inst_ex          <= inst_id         ;        
        // control
        bc_a_sel_fwd_ex  <= bc_a_sel_fwd_id ;
        bcs_b_sel_fwd_ex <= bcs_b_sel_fwd_id;
        bc_uns_ex        <= bc_uns_id       ;
        alu_a_sel_fwd_ex <= alu_a_sel_fwd_id;
        alu_b_sel_fwd_ex <= alu_b_sel_fwd_id;
        alu_op_sel_ex    <= alu_op_sel_id   ;
        dmem_en_ex       <= dmem_en_id      ;
        dmem_we_ex       <= dmem_we_id      ;
        load_sm_en_ex    <= load_sm_en_id   ;
        wb_sel_ex        <= wb_sel_id       ;
        reg_we_ex        <= reg_we_id       ;
    end
end      

//-----------------------------------------------------------------------------
// EX stage



endmodule
