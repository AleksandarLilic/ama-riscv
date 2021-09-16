//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Decoder
// File:            ama_riscv_decoder.v
// Date created:    2021-07-16
// Author:          Aleksandar Lilic
// Description:     Instruction Decoder
//
// Version history:
//      2021-07-16  AL  0.1.0 - Initial - Support for R-type
//      2021-07-16  AL  0.1.1 - Add imem_en signal
//      2021-07-16  AL  0.1.2 - Fix wb_sel signal
//      2021-07-17  AL  0.1.3 - Remove imem_en signal (needed for write, tbd)
//      2021-07-17  AL  0.2.0 - Add support for I-type
//      2021-07-17  AL  0.3.0 - Add support for Load
//      2021-07-18  AL  0.4.0 - Add support for Store
//      2021-07-18  AL  0.4.1 - Fix reset
//      2021-07-18  AL  0.5.0 - Add support for Branch
//                            - Add inst_ex input
//                            - Add Branch Resolution block
//                            - Add Stalling
//      2021-08-10  AL  0.6.0 - Add support for JALR
//      2021-08-12  AL  0.7.0 - Add support for JAL
//      2021-08-12  AL  0.8.0 - Add support for LUI
//      2021-08-12  AL  0.9.0 - Add support for AUIPC
//      2021-09-08  AL 0.10.0 - Remove imem_en and branch prediction I/O
//      2021-09-16  AL 0.11.0 - Add reset sequence
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_decoder (
    input   wire        clk         ,
    input   wire        rst         ,
    // inputs
    input   wire [31:0] inst_id     ,
    input   wire [31:0] inst_ex     ,
    input   wire        bc_a_eq_b   ,
    input   wire        bc_a_lt_b   ,
    // input   wire        bp_taken    ,
    // input   wire        bp_clear    ,
    // pipeline outputs
    output  wire        stall_if    ,
    output  wire        clear_if    ,
    output  wire        clear_id    ,
    output  wire        clear_ex    ,
    output  wire        clear_mem   ,
    // outputs
    output  wire [ 1:0] pc_sel      ,
    output  wire        pc_we       ,
    // output  wire        imem_en     ,
    output  wire        store_inst  ,
    output  wire        branch_inst ,
    output  wire        jump_inst   ,
    output  wire [ 3:0] alu_op_sel  ,
    output  wire        alu_a_sel   ,
    output  wire        alu_b_sel   ,
    output  wire [ 2:0] ig_sel      ,
    output  wire        bc_uns      ,
    output  wire        dmem_en     ,
    output  wire        load_sm_en  ,
    output  wire [ 1:0] wb_sel      ,
    output  wire        reg_we
);

//-----------------------------------------------------------------------------
// Signals

// ID stage functions
wire  [ 6:0] opc7_id     =  inst_id[ 6: 0];
wire  [ 2:0] funct3_id   =  inst_id[14:12];
wire  [ 6:0] funct7_id   =  inst_id[31:25];

// EX stage functions                         
wire  [ 6:0] opc7_ex     =  inst_ex[ 6: 0];
wire  [ 2:0] funct3_ex   =  inst_ex[14:12];
wire  [ 6:0] funct7_ex   =  inst_ex[31:25];

// Switch-Case outputs
reg   [ 1:0] pc_sel_r           ;
reg          pc_we_r            ;
reg          store_inst_r       ;
reg          branch_inst_r      ;
reg          jump_inst_r        ;
reg   [ 3:0] alu_op_sel_r       ;
reg          alu_a_sel_r        ;
reg          alu_b_sel_r        ;
reg   [ 2:0] ig_sel_r           ;
reg          bc_uns_r           ;
reg          dmem_en_r          ;
reg          load_sm_en_r       ;
reg   [ 1:0] wb_sel_r           ;
reg          reg_we_r           ;

// Previous values hold
reg          pc_sel_rst         ;
reg   [ 1:0] pc_sel_prev        ;
reg          pc_we_prev         ;
reg          store_inst_prev    ;
reg          branch_inst_prev   ;
reg          jump_inst_prev     ;
reg   [ 3:0] alu_op_sel_prev    ;
reg          alu_a_sel_prev     ;
reg          alu_b_sel_prev     ;
reg   [ 2:0] ig_sel_prev        ;
reg          bc_uns_prev        ;
reg          dmem_en_prev       ;
reg          load_sm_en_prev    ;
reg   [ 1:0] wb_sel_prev        ;
reg          reg_we_prev        ;

//-----------------------------------------------------------------------------
// Reset sequence
reg   [ 2:0] reset_seq          ;
always @ (posedge clk) begin
    if (rst)
        reset_seq <= 3'b111;
    else
        reset_seq <= {reset_seq[1:0],1'b0};
end

wire rst_seq_id  = reset_seq[0];        // keeps it clear 1 clk after rst ends
wire rst_seq_ex  = reset_seq[1];        // keeps it clear 2 clks after rst ends
wire rst_seq_mem = reset_seq[2];        // keeps it clear 3 clks after rst ends

//-----------------------------------------------------------------------------
// Pipeline FFs clear
assign clear_id  = rst_seq_id   ;
assign clear_ex  = rst_seq_ex   ;
assign clear_mem = rst_seq_mem  ;

//-----------------------------------------------------------------------------
// Decoder
always @ (*) begin    
    case (opc7_id)
        `OPC7_R_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = {funct7_id[5],funct3_id};
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_RS2;
            ig_sel_r      = `IG_DISABLED;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            wb_sel_r      = `WB_SEL_ALU;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_I_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            //                                           --------- shift -------- : ------ imm ------
            alu_op_sel_r  = (funct3_id[1:0] == 2'b01) ? {funct7_id[5], funct3_id} : {1'b0, funct3_id};
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            wb_sel_r      = `WB_SEL_ALU;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_LOAD: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b1;
            load_sm_en_r  = 1'b1;
            wb_sel_r      = `WB_SEL_DMEM;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_STORE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            store_inst_r  = 1'b1;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_S_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b1;
            load_sm_en_r  = 1'b0;
            // wb_sel_r      = *;
            reg_we_r      = 1'b0;
        end
        
        `OPC7_BRANCH: begin
            pc_sel_r      = `PC_SEL_INC4;   // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b1;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_B_TYPE;
            bc_uns_r      = funct3_id[1];
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            // wb_sel_r      = *;
            reg_we_r      = 1'b0;
        end
        
        `OPC7_JALR: begin
            pc_sel_r      = `PC_SEL_ALU;    // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_INC4;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_JAL: begin
            pc_sel_r      = `PC_SEL_ALU;    // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_J_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_INC4;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_LUI: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;       
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_PASS_B;
            // alu_a_sel_r   = *;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_U_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_ALU;
            reg_we_r      = 1'b1;
        end
        
        `OPC7_AUIPC: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;       
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_U_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_ALU;
            reg_we_r      = 1'b1;
        end
        
        default: begin
            pc_sel_r      = pc_sel_prev      ;
            pc_we_r       = pc_we_prev       ;
            store_inst_r  = store_inst_prev  ;
            branch_inst_r = branch_inst_prev ;
            jump_inst_r   = jump_inst_prev   ;
            alu_op_sel_r  = alu_op_sel_prev  ;
            alu_a_sel_r   = alu_a_sel_prev   ;
            alu_b_sel_r   = alu_b_sel_prev   ;
            ig_sel_r      = ig_sel_prev      ;
            bc_uns_r      = bc_uns_prev      ;
            dmem_en_r     = dmem_en_prev     ;
            load_sm_en_r  = load_sm_en_prev  ;
            wb_sel_r      = wb_sel_prev      ;
            reg_we_r      = reg_we_prev      ;
        end
        
    endcase
end

//-----------------------------------------------------------------------------
// Branch Resolution
wire  [ 1:0] funct3_ex_b = {funct3_ex[2], funct3_ex[0]}; // branch conditions
reg          branch_res;
reg          branch_inst_ex;

always @ (posedge clk) begin
    if (rst)
        branch_inst_ex <= 1'b0;
    else
        branch_inst_ex <= branch_inst_r;
end

// Branch outcome is always resolved
always @ (*) begin
    case (funct3_ex_b)
        `BR_SEL_BEQ:
            branch_res =  bc_a_eq_b;                  // a == b
        `BR_SEL_BNE:
            branch_res = !bc_a_eq_b;                  // a != b
        `BR_SEL_BLT:
            branch_res =  bc_a_lt_b;                  // a <  b
        `BR_SEL_BGE:
            branch_res =  bc_a_eq_b || !bc_a_lt_b;    // a >= b
        default: 
            branch_res = 1'b0;
    endcase
end

//-----------------------------------------------------------------------------
// Jump instructions
reg          jump_inst_ex;

always @ (posedge clk) begin
    if (rst)
        jump_inst_ex <= 1'b0;
    else
        jump_inst_ex <= jump_inst_r;
end

//-----------------------------------------------------------------------------
// Flow change
wire flow_change = (branch_res && branch_inst_ex) | (jump_inst_ex);

//-----------------------------------------------------------------------------
// Stall
assign stall_if     = branch_inst_r || jump_inst_r; // PC stall directly; IMEM stall thru FF in datapath

//-----------------------------------------------------------------------------
// Output assignment
assign pc_sel       = (pc_sel_rst)  ? `PC_SEL_START_ADDR  :
                      (flow_change) ? `PC_SEL_ALU         : pc_sel_r;
assign pc_we        = (stall_if)    ? 1'b0 : pc_we_r       ; // ... (1) overwritten for now
assign store_inst   = store_inst_r  ;
assign branch_inst  = branch_inst_r ;
assign jump_inst    = jump_inst_r   ;
assign alu_op_sel   = alu_op_sel_r  ;
assign alu_a_sel    = alu_a_sel_r   ;
assign alu_b_sel    = alu_b_sel_r   ;
assign ig_sel       = ig_sel_r      ;
assign bc_uns       = bc_uns_r      ;
assign dmem_en      = dmem_en_r     ;
assign load_sm_en   = load_sm_en_r  ;
assign wb_sel       = wb_sel_r      ;
assign reg_we       = reg_we_r      ;

//-----------------------------------------------------------------------------
// Store previous values
always @ (posedge clk) begin
    if (rst) begin
        // load start address to pc
        pc_sel_rst       <= 1'b1;
        // disable or some defaults for others
        pc_sel_prev      <= `PC_SEL_START_ADDR;
        pc_we_prev       <= 1'b1;   // it'll increment start_address always after rst -> fine
        store_inst_prev  <= 1'b0;
        branch_inst_prev <= 1'b0;
        jump_inst_prev   <= 1'b0;
        alu_op_sel_prev  <= `ALU_ADD;
        alu_a_sel_prev   <= `ALU_A_SEL_RS1;
        alu_b_sel_prev   <= `ALU_B_SEL_RS2;
        ig_sel_prev      <= `IG_DISABLED;
        bc_uns_prev      <= 1'b0;
        dmem_en_prev     <= 1'b0;
        load_sm_en_prev  <= 1'b0;
        wb_sel_prev      <= `WB_SEL_DMEM;
        reg_we_prev      <= 1'b0;
    end
    else begin
        pc_sel_rst       <= 1'b0;
        pc_sel_prev      <= pc_sel     ;
        pc_we_prev       <= pc_we      ;
        store_inst_prev  <= store_inst ;
        branch_inst_prev <= branch_inst;
        jump_inst_prev   <= jump_inst  ;
        alu_op_sel_prev  <= alu_op_sel ;
        alu_a_sel_prev   <= alu_a_sel  ;
        alu_b_sel_prev   <= alu_b_sel  ;
        ig_sel_prev      <= ig_sel     ;
        bc_uns_prev      <= bc_uns     ;
        dmem_en_prev     <= dmem_en    ;
        load_sm_en_prev  <= load_sm_en ;
        wb_sel_prev      <= wb_sel     ;
        reg_we_prev      <= reg_we     ;
    end
end

endmodule

