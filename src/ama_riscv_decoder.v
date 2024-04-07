`include "ama_riscv_defines.v"

module ama_riscv_decoder (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] inst_id,
    input  wire [31:0] inst_ex,
    input  wire        bc_a_eq_b,
    input  wire        bc_a_lt_b,
    // input  wire        bp_taken,
    // input  wire        bp_clear,
    output wire        stall_if,
    output wire        clear_if,
    output wire        clear_id,
    output wire        clear_ex,
    output wire        clear_mem,
    output wire [ 1:0] pc_sel,
    output wire        pc_we,
    // output wire        imem_en,
    output wire        load_inst,
    output wire        store_inst,
    output wire        branch_inst,
    output wire        jump_inst,
    output wire        csr_en,
    output wire        csr_we,
    output wire        csr_ui,
    output wire [ 3:0] alu_op_sel,
    output wire        alu_a_sel,
    output wire        alu_b_sel,
    output wire [ 2:0] ig_sel,
    output wire        bc_uns,
    output wire        dmem_en,
    output wire        load_sm_en,
    output wire [ 1:0] wb_sel,
    output wire        reg_we
);

// ID stage CSR addresses
wire  [11:0] csr_addr    =  inst_id[31:20];
// ID stage register addresses
wire  [ 4:0] rs1_addr_id =  inst_id[19:15];
wire  [ 4:0] rd_addr_id  =  inst_id[11: 7];
// ID stage functions
wire  [ 6:0] opc7_id     =  inst_id[ 6: 0];
wire  [ 2:0] funct3_id   =  inst_id[14:12];
wire  [ 6:0] funct7_id   =  inst_id[31:25];
// EX stage functions                         
wire  [ 6:0] opc7_ex     =  inst_ex[ 6: 0];
wire  [ 2:0] funct3_ex   =  inst_ex[14:12];
wire  [ 6:0] funct7_ex   =  inst_ex[31:25];

// Switch-Case outputs
reg [ 1:0] pc_sel_r;
reg        pc_we_r;
reg        load_inst_r;
reg        store_inst_r;
reg        branch_inst_r;
reg        jump_inst_r;
reg        csr_en_r;
reg        csr_we_r;
reg        csr_ui_r;
reg [ 3:0] alu_op_sel_r;
reg        alu_a_sel_r;
reg        alu_b_sel_r;
reg [ 2:0] ig_sel_r;
reg        bc_uns_r;
reg        dmem_en_r;
reg        load_sm_en_r;
reg [ 1:0] wb_sel_r;
reg        reg_we_r;

reg         pc_sel_rst;
reg  [ 1:0] pc_sel_d;
reg         pc_we_d;
reg         load_inst_d;
reg         store_inst_d;
reg         branch_inst_d;
reg         jump_inst_d;
reg         csr_en_d;
reg         csr_we_d;
reg         csr_ui_d;
reg  [ 3:0] alu_op_sel_d;
reg         alu_a_sel_d;
reg         alu_b_sel_d;
reg  [ 2:0] ig_sel_d;
reg         bc_uns_d;
reg         dmem_en_d;
reg         load_sm_en_d;
reg  [ 1:0] wb_sel_d;
reg         reg_we_d;

// Reset sequence
reg  [ 2:0] reset_seq;
always @ (posedge clk) begin
    if (rst) reset_seq <= 3'b111;
    else reset_seq <= {reset_seq[1:0],1'b0};
end

wire rst_seq_id  = reset_seq[0]; // keeps it clear 1 clk after rst ends
wire rst_seq_ex  = reset_seq[1]; // keeps it clear 2 clks after rst ends
wire rst_seq_mem = reset_seq[2]; // keeps it clear 3 clks after rst ends

// Pipeline FFs clear
assign clear_id  = rst_seq_id;
assign clear_ex  = rst_seq_ex;
assign clear_mem = rst_seq_mem;

// TODO: decoder should be implemented with SV struct for cleaner code
// Decoder
always @ (*) begin
    pc_sel_r = pc_sel_d;
    pc_we_r = pc_we_d;
    load_inst_r = load_inst_d;
    store_inst_r = store_inst_d;
    branch_inst_r = branch_inst_d;
    jump_inst_r = jump_inst_d;
    csr_en_r = csr_en_d;
    csr_we_r = csr_we_d;
    csr_ui_r = csr_ui_d;
    alu_op_sel_r = alu_op_sel_d;
    alu_a_sel_r = alu_a_sel_d;
    alu_b_sel_r = alu_b_sel_d;
    ig_sel_r = ig_sel_d;
    bc_uns_r = bc_uns_d;
    dmem_en_r = dmem_en_d;
    load_sm_en_r = load_sm_en_d;
    wb_sel_r = wb_sel_d;
    reg_we_r = reg_we_d;
    
    case (opc7_id)
        `OPC7_R_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b1;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b1;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b1;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = 1'b0;
            csr_we_r      = 1'b0;
            csr_ui_r      = 1'b0;
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
        
        `OPC7_SYSTEM: begin     // supports only CSRRW and CSRRWI
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_en_r      = (csr_addr == `CSR_TOHOST) && (rs1_addr_id != `RF_X0_ZERO);
            csr_we_r      = 1'b1;
            csr_ui_r      = funct3_id[2];
            // alu_op_sel_r  = *;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            // alu_b_sel_r   = *;
            // ig_sel_r      = *;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_CSR;
            reg_we_r      = (rd_addr_id != `RF_X0_ZERO);
        end
        
        default: begin
            pc_sel_r      = pc_sel_d      ;
            pc_we_r       = pc_we_d       ;
            load_inst_r   = load_inst_d   ;
            store_inst_r  = store_inst_d  ;
            branch_inst_r = branch_inst_d ;
            jump_inst_r   = jump_inst_d   ;
            csr_en_r      = csr_en_d      ;
            csr_we_r      = csr_we_d      ;
            csr_ui_r      = csr_ui_d      ;
            alu_op_sel_r  = alu_op_sel_d  ;
            alu_a_sel_r   = alu_a_sel_d   ;
            alu_b_sel_r   = alu_b_sel_d   ;
            ig_sel_r      = ig_sel_d      ;
            bc_uns_r      = bc_uns_d      ;
            dmem_en_r     = dmem_en_d     ;
            load_sm_en_r  = load_sm_en_d  ;
            wb_sel_r      = wb_sel_d      ;
            reg_we_r      = reg_we_d      ;
        end
        
    endcase
end

// Branch Resolution
wire [ 1:0] funct3_ex_b = {funct3_ex[2], funct3_ex[0]}; // branch conditions
reg         branch_res;
reg         branch_inst_ex;

always @ (posedge clk) begin
    if (rst) branch_inst_ex <= 1'b0;
    else branch_inst_ex <= branch_inst_r;
end

always @ (*) begin
    case (funct3_ex_b)
        `BR_SEL_BEQ: branch_res = bc_a_eq_b; 
        `BR_SEL_BNE: branch_res = !bc_a_eq_b; 
        `BR_SEL_BLT: branch_res = bc_a_lt_b;
        `BR_SEL_BGE: branch_res = bc_a_eq_b || !bc_a_lt_b;
        default: branch_res = 1'b0;
    endcase
end

// Jump instructions
reg jump_inst_ex;
always @ (posedge clk) begin
    if (rst) jump_inst_ex <= 1'b0;
    else jump_inst_ex <= jump_inst_r;
end

// Flow change
wire flow_change = (branch_res && branch_inst_ex) | (jump_inst_ex);

// Stall
// PC stalls directly; IMEM stall thru FF in datapath
assign stall_if = branch_inst_r || jump_inst_r;

// Output assignment
assign pc_sel = (pc_sel_rst) ? `PC_SEL_START_ADDR :
                (flow_change) ? `PC_SEL_ALU :
                pc_sel_r;
assign pc_we = (stall_if) ? 1'b0 : pc_we_r; // ... (1) overwritten for now
assign load_inst = load_inst_r;
assign store_inst = store_inst_r;
assign branch_inst = branch_inst_r;
assign jump_inst = jump_inst_r;
assign csr_en = csr_en_r;
assign csr_we = csr_we_r;
assign csr_ui = csr_ui_r;
assign alu_op_sel = alu_op_sel_r;
assign alu_a_sel = alu_a_sel_r;
assign alu_b_sel = alu_b_sel_r;
assign ig_sel = ig_sel_r;
assign bc_uns = bc_uns_r;
assign dmem_en = dmem_en_r;
assign load_sm_en = load_sm_en_r;
assign wb_sel = wb_sel_r;
assign reg_we = reg_we_r;

// Store values
always @ (posedge clk) begin
    if (rst) begin
        // load start address to pc
        pc_sel_rst <= 1'b1;
        // disable or some defaults for others
        pc_sel_d <= `PC_SEL_START_ADDR;
        pc_we_d <= 1'b1;   // it'll increment start_address always after rst -> fine
        load_inst_d <= 1'b0;
        store_inst_d <= 1'b0;
        branch_inst_d <= 1'b0;
        jump_inst_d <= 1'b0;
        csr_en_d <= 1'b0;
        csr_we_d <= 1'b0;
        csr_ui_d <= 1'b0;
        alu_op_sel_d <= `ALU_ADD;
        alu_a_sel_d <= `ALU_A_SEL_RS1;
        alu_b_sel_d <= `ALU_B_SEL_RS2;
        ig_sel_d <= `IG_DISABLED;
        bc_uns_d <= 1'b0;
        dmem_en_d <= 1'b0;
        load_sm_en_d <= 1'b0;
        wb_sel_d <= `WB_SEL_DMEM;
        reg_we_d <= 1'b0;
    end
    else begin
        pc_sel_rst <= 1'b0;
        pc_sel_d <= pc_sel;
        pc_we_d <= pc_we;
        load_inst_d <= load_inst;
        store_inst_d <= store_inst;
        branch_inst_d <= branch_inst;
        jump_inst_d <= jump_inst;
        csr_en_d <= csr_en;
        csr_we_d <= csr_we;
        csr_ui_d <= csr_ui;
        alu_op_sel_d <= alu_op_sel;
        alu_a_sel_d <= alu_a_sel;
        alu_b_sel_d <= alu_b_sel;
        ig_sel_d <= ig_sel;
        bc_uns_d <= bc_uns;
        dmem_en_d <= dmem_en;
        load_sm_en_d <= load_sm_en;
        wb_sel_d <= wb_sel;
        reg_we_d <= reg_we;
    end
end

endmodule
