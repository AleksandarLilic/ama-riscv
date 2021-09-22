//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Core
// File:            ama_riscv_core.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     CPU Core - Control & Datapath
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Version history:
//      2021-09-11  AL  0.1.0 - Initial - IF stage
//      2021-09-13  AL  0.1.1 - Fix IMEM address signal
//      2021-09-14  AL  0.2.0 - Add ID stage
//      2021-09-18  AL  0.3.0 - Finish ID/EX pipeline
//      2021-09-18  AL  0.4.0 - Add EX stage
//      2021-09-18  AL  0.4.1 - Fix dmem_we
//      2021-09-18  AL  0.4.2 - Fix dmem_addr
//      2021-09-21  AL  0.4.3 - Fix store_inst_ex
//      2021-09-21  AL  0.5.0 - Add MEM stage and Writeback
//      2021-09-22  AL  0.6.0 - Add RF forwarding
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
reg         reg_we_mem              ;
reg  [ 4:0] rd_addr_mem             ;
    
// Signals - EX stage   
reg  [31:0] inst_ex                 ;
reg         reg_we_ex               ;
reg  [ 4:0] rd_addr_ex              ;
reg         store_inst_ex           ;
// from datapath
wire        bc_out_a_eq_b           ;
wire        bc_out_a_lt_b           ;
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
wire        rf_a_sel_fwd_id         ;
wire        rf_b_sel_fwd_id         ;
wire        bc_uns_id               ;
wire        dmem_en_id              ;
wire        load_sm_en_id           ;
wire [ 1:0] wb_sel_id               ;
wire        reg_we_id               ;

// Signals - EX stage
wire [ 3:0] dmem_we_ex              ;

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
    .bc_a_eq_b          (bc_out_a_eq_b  ),
    .bc_a_lt_b          (bc_out_a_lt_b  ),
    // .bp_taken           (bp_taken       ),
    // .bp_clear           (bp_clear       ),
    .store_mask_offset  (store_mask_offset),
    // pipeline inputs
    .inst_ex            (inst_ex        ),
    .reg_we_ex          (reg_we_ex      ),
    .reg_we_mem         (reg_we_mem     ),
    .rd_ex              (rd_addr_ex     ),
    .rd_mem             (rd_addr_mem    ),
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
    .rf_a_sel_fwd       (rf_a_sel_fwd_id    ),
    .rf_b_sel_fwd       (rf_b_sel_fwd_id    ),
    .dmem_we            (dmem_we_ex         )
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
// reg         reg_we_mem  ;       // defined previously
wire [31:0] writeback   ;
// reg  [ 4:0] rd_addr_mem ;       // defined previously

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
    .clk    (clk            ),
    .rst    (rst            ),
    // inputs
    .we     (reg_we_mem     ),
    .addr_a (rs1_addr       ),
    .addr_b (rs2_addr       ),
    .addr_d (rd_addr_mem    ),
    .data_d (rd_data        ),
    // outputs
    .data_a (rs1_data_id    ),
    .data_b (rs2_data_id    )
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
        store_inst_ex    <=  1'b0;
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
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
        store_inst_ex    <=  1'b0;
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
        load_sm_en_ex    <=  1'b0;
        wb_sel_ex        <=  2'h0;
        reg_we_ex        <=  1'b0;
    end
    else begin
        // datapath
        pc_ex            <= pc_id           ;
        rd_addr_ex       <= rd_addr_id      ;
        rs1_data_ex      <= rf_a_sel_fwd_id ? writeback : rs1_data_id;
        rs2_data_ex      <= rf_b_sel_fwd_id ? writeback : rs2_data_id;
        imm_gen_out_ex   <= imm_gen_out_id  ;
        inst_ex          <= inst_id         ;        
        // control
        store_inst_ex    <= store_inst_id   ;
        bc_a_sel_fwd_ex  <= bc_a_sel_fwd_id ;
        bcs_b_sel_fwd_ex <= bcs_b_sel_fwd_id;
        bc_uns_ex        <= bc_uns_id       ;
        alu_a_sel_fwd_ex <= alu_a_sel_fwd_id;
        alu_b_sel_fwd_ex <= alu_b_sel_fwd_id;
        alu_op_sel_ex    <= alu_op_sel_id   ;
        dmem_en_ex       <= dmem_en_id      ;
        load_sm_en_ex    <= load_sm_en_id   ;
        wb_sel_ex        <= wb_sel_id       ;
        reg_we_ex        <= reg_we_id       ;
    end
end      

//-----------------------------------------------------------------------------
// EX stage

// Branch Compare
// wire        bc_uns_id     ;     // defined previously
wire [31:0] bc_in_a  = bc_a_sel_fwd_ex  ? writeback : rs1_data_ex;
wire [31:0] bcs_in_b = bcs_b_sel_fwd_ex ? writeback : rs2_data_ex;
// wire        bc_out_a_eq_b   ;   // defined previously
// wire        bc_out_a_lt_b   ;   // defined previously

// control mux is shared between bc and dmem din
wire [31:0] dmem_write_data =  bcs_in_b ;

ama_riscv_branch_compare ama_riscv_branch_compare_i (
    // inputs
    .op_uns     (bc_uns_id      ),
    .in_a       (bc_in_a        ),
    .in_b       (bcs_in_b       ),
    // outputs
    .op_a_eq_b  (bc_out_a_eq_b  ),
    .op_a_lt_b  (bc_out_a_lt_b  )
);

// ALU
// wire [ 3:0] alu_op_sel_ex ;     // defined previously
wire [31:0] alu_in_a =  (alu_a_sel_fwd_ex == `ALU_A_SEL_RS1)     ?    rs1_data_ex     :
                        (alu_a_sel_fwd_ex == `ALU_A_SEL_PC )     ?    pc_ex           :
                     /* (alu_a_sel_fwd_ex == `ALU_A_SEL_FWD_ALU) ? */ writeback      ;

wire [31:0] alu_in_b =  (alu_b_sel_fwd_ex == `ALU_B_SEL_RS2)     ?    rs2_data_ex     :
                        (alu_b_sel_fwd_ex == `ALU_B_SEL_IMM)     ?    imm_gen_out_ex  :
                     /* (alu_b_sel_fwd_ex == `ALU_B_SEL_FWD_ALU) ? */ writeback      ;

// wire [31:0] alu_out  ;          // defined previously

ama_riscv_alu ama_riscv_alu_i (
    // inputs
    .op_sel     (alu_op_sel_ex  ),
    .in_a       (alu_in_a       ),
    .in_b       (alu_in_b       ),
    // outputs
    .out_s      (alu_out        )
);

assign store_mask_offset = alu_out[1:0];
wire [ 1:0] load_sm_offset_ex = store_mask_offset;

// DMEM
wire [13:0] dmem_addr = alu_out[15:2];
wire [31:0] dmem_read_data_mem  ;

ama_riscv_dmem ama_riscv_dmem_i (
    .clk    (clk                ),
    .en     (dmem_en_ex         ),
    .we     (dmem_we_ex         ),
    .addr   (dmem_addr          ),
    .din    (dmem_write_data    ),
    .dout   (dmem_read_data_mem )
);

//-----------------------------------------------------------------------------
// Pipeline FF EX/MEM
// Signals
reg  [31:0] pc_mem              ; 
reg  [31:0] alu_out_mem         ; 
// wire [31:0] dmem_read_data_mem  ;   // defined previously
reg  [ 1:0] load_sm_offset_mem  ;
reg  [31:0] inst_mem            ;
reg         load_sm_en_mem      ;
reg  [ 1:0] wb_sel_mem          ;
// reg  [ 4:0] rd_addr_mem         ;   // defined previously
// reg         reg_we_mem          ;   // defined previously

always @ (posedge clk) begin
    if (rst) begin
        // datapath
        pc_mem              <= 32'h0;
        alu_out_mem         <= 32'h0;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <=  2'h0;
        inst_mem            <= 32'h0;
        rd_addr_mem         <=  5'h0;
        // control
        load_sm_en_mem      <=  1'b0;
        wb_sel_mem          <=  2'h0;
        reg_we_mem          <=  1'b0;
    end
    else if (clear_ex) begin
        // datapath
        pc_mem              <= 32'h0;
        alu_out_mem         <= 32'h0;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <=  2'h0;
        inst_mem            <= 32'h0;
        rd_addr_mem         <=  5'h0;
        // control
        load_sm_en_mem      <=  1'b0;
        wb_sel_mem          <=  2'h0;
        reg_we_mem          <=  1'b0;
    end
    else begin
        // datapath
        pc_mem              <= pc_ex            ;
        alu_out_mem         <= alu_out          ;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <= load_sm_offset_ex;
        inst_mem            <= inst_ex          ;
        rd_addr_mem         <= rd_addr_ex       ;
        // control
        load_sm_en_mem      <= load_sm_en_ex    ;
        wb_sel_mem          <= wb_sel_ex        ;
        reg_we_mem          <= reg_we_ex        ;
    end
end

//-----------------------------------------------------------------------------
// MEM stage
wire [ 2:0] funct3_mem  = inst_mem[14:12];

// Load Shift & Mask
// wire        load_sm_en_mem      ;   // defined previously
// wire [ 1:0] load_sm_offset_mem  ;   // defined previously
wire [ 2:0] load_sm_width = funct3_mem;
// wire [31:0] load_sm_data_in     ;   // defined previously as dmem_read_data_mem
wire [31:0] load_sm_data_out    ;

ama_riscv_load_shift_mask ama_riscv_load_shift_mask_i (
    .clk        (clk                ),
    .rst        (rst                ),
    // inputs
    .en         (load_sm_en_mem     ),
    .offset     (load_sm_offset_mem ),
    .width      (load_sm_width      ),
    .data_in    (dmem_read_data_mem ),
    // outputs
    .data_out   (load_sm_data_out   )
);

//-----------------------------------------------------------------------------
// Writeback
assign writeback = (wb_sel_mem == `WB_SEL_DMEM) ?    load_sm_data_out  :
                   (wb_sel_mem == `WB_SEL_ALU ) ?    alu_out_mem       :
                /* (wb_sel_mem == `WB_SEL_INC4) ? */ pc_mem + 32'd4   ;


endmodule
