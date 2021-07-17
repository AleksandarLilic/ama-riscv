//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Decoder
// File:            ama_riscv_decoder.v
// Date created:    2021-07-16
// Author:          Aleksandar Lilic
// Description:     Instruction Decoder
//
// Version history:
//      2021-07-16  AL  0.1.0 - Initial - Support for R-types
//      2021-07-16  AL  0.1.1 - Add imem_en signal
//
//-----------------------------------------------------------------------------
`include "ama_riscv_defines.v"

module ama_riscv_decoder (
    input   wire        clk         ,
    input   wire        rst         ,
    // inputs
    input   wire [31:0] inst_id     ,
    input   wire        bc_a_eq_b   ,
    input   wire        bc_a_lt_b   ,
    input   wire        bp_taken    ,
    input   wire        bp_clear    ,
    // pipeline outputs
    output  reg         stall_if    ,
    output  reg         clear_if    ,
    output  reg         clear_id    ,
    output  reg         clear_mem   ,
    // outputs
    output  reg  [ 1:0] pc_sel      ,
    output  reg  [ 1:0] pc_we       ,
    output  reg         imem_en     ,
    output  reg         branch_inst ,
    output  reg         store_inst  ,
    output  reg  [ 3:0] alu_op_sel  ,
    output  reg         alu_a_sel   ,
    output  reg         alu_b_sel   ,
    output  reg  [ 2:0] ig_sel      ,
    output  reg         bc_uns      ,
    output  reg         dmem_en     ,
    output  reg         load_sm_en  ,
    output  reg  [ 1:0] wb_sel      ,
    output  reg         reg_we
);

//-----------------------------------------------------------------------------
// Signals

wire  [ 4:0] opc5   =  inst_id[ 6: 2];
wire  [ 2:0] funct3 =  inst_id[14:12];
wire  [ 6:0] funct7 =  inst_id[31:25];

reg   [ 1:0] pc_sel_r      ;
reg   [ 1:0] pc_we_r       ;
reg          imem_en_r     ; 
reg          branch_inst_r ;
reg          store_inst_r  ;
reg   [ 3:0] alu_op_sel_r  ;
reg          alu_a_sel_r   ;
reg          alu_b_sel_r   ;
reg   [ 2:0] ig_sel_r      ;
reg          bc_uns_r      ;
reg          dmem_en_r     ;
reg          load_sm_en_r  ;
reg   [ 1:0] wb_sel_r      ;
reg          reg_we_r      ;

//-----------------------------------------------------------------------------
// Output assignment
always @ (posedge clk) begin
    if (rst) begin
        // load start address to pc
        pc_sel      <= `PC_SEL_START_ADDR;
        pc_we       <= 1'b1;
        imem_en     <= 1'b1;
        // disable or some defaults for others
        branch_inst <= 1'b0;
        store_inst  <= 1'b0;
        alu_op_sel  <= 4'b0000;  // decodes to add operation
        alu_a_sel   <= `ALU_A_SEL_RS1;
        alu_b_sel   <= `ALU_B_SEL_RS2;
        ig_sel      <= `IG_DISABLED;
        bc_uns      <= 1'b0;
        dmem_en     <= 1'b0;
        load_sm_en  <= 1'b0;
        wb_sel      <= `WB_SEL_DMEM;
        reg_we      <= 1'b0;
        // pipeline registers? though they are reset with rst=1 regardless
    end
    else begin
        pc_sel      <= pc_sel_r      ;
        pc_we       <= pc_we_r       ;
        imem_en     <= imem_en_r     ;
        branch_inst <= branch_inst_r ;
        store_inst  <= store_inst_r  ;
        alu_op_sel  <= alu_op_sel_r  ;
        alu_a_sel   <= alu_a_sel_r   ;
        alu_b_sel   <= alu_b_sel_r   ;
        ig_sel      <= ig_sel_r      ;
        bc_uns      <= bc_uns_r      ;
        dmem_en     <= dmem_en_r     ;
        load_sm_en  <= load_sm_en_r  ;
        wb_sel      <= wb_sel_r      ;
        reg_we      <= reg_we_r      ;
    end
end

//-----------------------------------------------------------------------------
// Decoder
always @ (*) begin
    // Defaults, cover don't care/change cases
    pc_sel_r      = pc_sel      ;
    pc_we_r       = pc_we       ;
    imem_en_r     = imem_en     ;
    branch_inst_r = branch_inst ;
    store_inst_r  = store_inst  ;
    alu_op_sel_r  = alu_op_sel  ;
    alu_a_sel_r   = alu_a_sel   ;
    alu_b_sel_r   = alu_b_sel   ;
    ig_sel_r      = ig_sel      ;
    bc_uns_r      = bc_uns      ;
    dmem_en_r     = dmem_en     ;
    load_sm_en_r  = load_sm_en  ;
    wb_sel_r      = wb_sel      ;
    reg_we_r      = reg_we      ;
    
    case (opc5)
        `OPC5_ARI_R_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            imem_en_r     = 1'b1;
            branch_inst_r = 1'b0;
            store_inst_r  = 1'b0;
            alu_op_sel_r  = {funct7[5],funct3};
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_RS2;
            ig_sel_r      = `IG_DISABLED;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            wb_sel_r      = `WB_SEL_DMEM;
            reg_we_r      = 1'b1;
        end
        
        `OPC5_ARI_I_TYPE: begin
            
        end
        
        `OPC5_LOAD: begin
            
        end
        
        `OPC5_STORE: begin
            
        end
        
        `OPC5_BRANCH: begin
            
        end
        
        `OPC5_JALR: begin
            
        end
        
        `OPC5_JAL: begin
            
        end
        
        `OPC5_LUI: begin
            
        end
        
        `OPC5_AUIPC: begin
            
        end
        
        default: begin
            
        end
        
    endcase
end


endmodule

