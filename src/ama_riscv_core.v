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
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_core (
    input   wire        clk  ,
    input   wire        rst
);

//-----------------------------------------------------------------------------
// Signals
wire [31:0] inst_id             ;
wire        bc_a_eq_b           ;
wire        bc_a_lt_b           ;
// wire        bp_taken  ;
// wire        bp_clear  ;
wire [ 1:0] store_mask_offset   ;

// pipeline inputs               
wire [31:0] inst_ex             ;
wire        reg_we_ex           ;
wire [ 4:0] rd_ex               ;
wire        store_inst_ex       ;

// pipeline outputs              
wire        stall_if            ;
wire        clear_if            ;
wire        clear_id            ;
wire        clear_ex            ;
wire        clear_mem           ;
// outputs                       
wire [ 1:0] pc_sel              ;
wire        pc_we               ;
wire        store_inst          ;
wire        branch_inst         ;
wire        jump_inst           ;
wire [ 3:0] alu_op_sel          ;
wire [ 2:0] ig_sel              ;
wire        bc_uns              ;
wire        dmem_en             ;
wire        load_sm_en          ;
wire [ 1:0] wb_sel              ;
wire        reg_we              ;
wire [ 1:0] alu_a_sel_fwd       ;
wire [ 1:0] alu_b_sel_fwd       ;
wire        bc_a_sel_fwd        ;
wire        bcs_b_sel_fwd       ;
wire [ 3:0] dmem_we             ;

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
    .rd_ex              (rd_ex          ),
    .store_inst_ex      (store_inst_ex  ),
    // pipeline outputs
    .stall_if           (stall_if       ),
    .clear_if           (clear_if       ),
    .clear_id           (clear_id       ),
    .clear_ex           (clear_ex       ),
    .clear_mem          (clear_mem      ),
    // pipeline resets                  
                                        
    // outputs                          
    .pc_sel             (pc_sel         ),
    .pc_we              (pc_we          ),
    // .imem_en            (imem_en        ),
    .store_inst         (store_inst     ),
    .branch_inst        (branch_inst    ),
    .jump_inst          (jump_inst      ),
    .alu_op_sel         (alu_op_sel     ),
    .ig_sel             (ig_sel         ),
    .bc_uns             (bc_uns         ),
    .dmem_en            (dmem_en        ),
    .load_sm_en         (load_sm_en     ),
    .wb_sel             (wb_sel         ),
    .reg_we             (reg_we         ),
    .alu_a_sel_fwd      (alu_a_sel_fwd  ),
    .alu_b_sel_fwd      (alu_b_sel_fwd  ),
    .bc_a_sel_fwd       (bc_a_sel_fwd   ),
    .bcs_b_sel_fwd      (bcs_b_sel_fwd  ),
    .dmem_we            (dmem_we        )
);

//-----------------------------------------------------------------------------
// IF Stage
reg  [31:0] pc_sel_mux_out  ;
reg  [31:0] pc              ;
wire [31:0] pc_inc4         ;
wire [31:0] imem_addr       ;
wire [31:0] alu_out         ;

// PC select mux
always @ (*) begin
    case (pc_sel)
        `PC_SEL_INC4:
            pc_sel_mux_out =  pc_inc4;
        `PC_SEL_ALU:
            pc_sel_mux_out =  alu_out;
        // `PC_SEL_BP:
            // pc_sel_mux_out =  bp_out;
        `PC_SEL_START_ADDR:
            pc_sel_mux_out =  32'h0;
        default: 
            pc_sel_mux_out =  pc_inc4;
    endcase
end

// PC
always @ (posedge clk) begin
    if (rst)
        pc <= 32'h0;
    else if (pc_we)
        pc <= pc_sel_mux_out;
end

assign pc_inc4 = pc + 32'd4;

// IMEM
wire [31:0] inst_id_read    ;
assign imem_addr = pc_sel_mux_out[13:0];
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
    else if (pc_we)
        stall_if_q1 <= stall_if;
end

//-----------------------------------------------------------------------------
// ID Stage

assign inst_id = (stall_if_q1) ? `NOP : inst_id_read;



endmodule
