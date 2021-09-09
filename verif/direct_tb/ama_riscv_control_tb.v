//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Control Testbench
// File:            ama_riscv_control_tb.v
// Date created:    2021-09-07
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Status check after reset
//                      2.  R-type checks direct
//                      3.  Load instructions checks direct
//                      4.  Store instructions checks direct
//                      5.  Branch instructions checks direct
//                      6.  JALR instruction check direct
//                      7.  JAL instruction check direct
//                      8.  LUI instruction check direct
//                      9.  AUIPC instruction check direct
//
// Version history:
//      2021-09-07  AL  0.1.0 - Initial - Reset and R-type
//      2021-09-09  AL  0.2.0 - Finish model and checker for decoder and forwarding
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define RST_TEST                 1
`define R_TYPE_TESTS            10
`define I_TYPE_TESTS             9
`define LOAD_TESTS               5
`define STORE_TESTS              3
`define BRANCH_TESTS             6
`define JALR_TEST                1
`define JAL_TEST                 1
`define LUI_TEST                 1
`define AUIPC_TEST               1
`define BRANCH_TESTS_NOPS_PAD    4+1    // 4 nops + 1 branch back instruction
`define TEST_CASES               `RST_TEST + `R_TYPE_TESTS + `I_TYPE_TESTS + `LOAD_TESTS + `STORE_TESTS + `BRANCH_TESTS + `JALR_TEST + `JAL_TEST + `LUI_TEST + `AUIPC_TEST + `BRANCH_TESTS_NOPS_PAD
`define LABEL_TGT                `TEST_CASES - 1 // location to which to branch

// Register Field
`define RF_X0_ZERO          5'd0

// MUX select signals
// PC select
`define PC_SEL_INC4         2'd0  // PC = PC + 4
`define PC_SEL_ALU          2'd1  // ALU output, used for jump/branch
`define PC_SEL_BP           2'd2  // PC = Branch prediction output
`define PC_SEL_START_ADDR   2'd3  // PC = Hardwired start address

// ALU A operand select
`define ALU_A_SEL_RS1       2'd0  // A = Reg[rs1]
`define ALU_A_SEL_PC        2'd1  // A = PC
`define ALU_A_SEL_FWD_ALU   2'd2  // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_RS2       2'd0  // B = Reg[rs2]
`define ALU_B_SEL_IMM       2'd1  // B = Immediate value; from Imm Gen
`define ALU_B_SEL_FWD_ALU   2'd2  // B = ALU; forwarding from MEM stage

// Write back select
`define WB_SEL_DMEM         2'd0  // Reg[rd] = DMEM[ALU]
`define WB_SEL_ALU          2'd1  // Reg[rd] = ALU
`define WB_SEL_INC4         2'd2  // Reg[rd] = PC + 4

// Imm Gen
`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

`define PROJECT_PATH        "C:/Users/Aleksandar/Documents/xilinx/ama-riscv/"

module ama_riscv_control_tb();

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O                              // Environment signals
reg         clk = 0;
reg         rst;
// inputs                               // inputs
reg  [31:0] inst_id             ;       reg  [31:0] dut_env_inst_id             ;
reg         bc_a_eq_b           ;       reg         dut_env_bc_a_eq_b           ;
reg         bc_a_lt_b           ;       reg         dut_env_bc_a_lt_b           ;
// reg         bp_taken  ;
// reg         bp_clear  ;
reg  [ 1:0] store_mask_offset   ;       reg  [ 1:0] dut_env_store_mask_offset   ;

// pipeline inputs                      // pipeline inputs
reg  [31:0] inst_ex             ;       reg  [31:0] dut_env_inst_ex             ;
reg         reg_we_ex           ;       reg         dut_env_reg_we_ex           ;
reg  [ 4:0] rd_ex               ;       reg  [ 4:0] dut_env_rd_ex               ;
reg         store_inst_ex       ;       reg         dut_env_store_inst_ex       ;

                                        // Model outputs
// pipeline outputs                     // pipeline outputs
wire        stall_if            ;       reg         dut_m_stall_if      ;
wire        clear_if            ;       reg         dut_m_clear_if      ;
wire        clear_id            ;       reg         dut_m_clear_id      ;
wire        clear_ex            ;       reg         dut_m_clear_ex      ;
wire        clear_mem           ;       reg         dut_m_clear_mem     ;
// outputs                              // outputs
wire [ 1:0] pc_sel              ;       reg  [ 1:0] dut_m_pc_sel        ;
wire        pc_we               ;       reg         dut_m_pc_we         ;
wire        store_inst          ;       reg         dut_m_store_inst    ;
wire        branch_inst         ;       reg         dut_m_branch_inst   ;
wire        jump_inst           ;       reg         dut_m_jump_inst     ;
wire [ 3:0] alu_op_sel          ;       reg  [ 3:0] dut_m_alu_op_sel    ;
wire [ 2:0] ig_sel              ;       reg  [ 2:0] dut_m_ig_sel        ;
wire        bc_uns              ;       reg         dut_m_bc_uns        ;

wire        dmem_en             ;       reg         dut_m_dmem_en       ;
wire        load_sm_en          ;       reg         dut_m_load_sm_en    ;
wire [ 1:0] wb_sel              ;       reg  [ 1:0] dut_m_wb_sel        ;
wire        reg_we              ;       reg         dut_m_reg_we        ;
wire [ 1:0] alu_a_sel_fwd       ;       reg  [ 1:0] dut_m_alu_a_sel_fwd ;
wire [ 1:0] alu_b_sel_fwd       ;       reg  [ 1:0] dut_m_alu_b_sel_fwd ;
wire        bc_a_sel_fwd        ;       reg         dut_m_bc_a_sel_fwd  ;
wire        bcs_b_sel_fwd       ;       reg         dut_m_bcs_b_sel_fwd ;
wire [ 3:0] dmem_we             ;       reg  [ 3:0] dut_m_dmem_we       ;
                                        // Model internal signals
                                        reg         dut_m_alu_a_sel     ;
                                        reg         dut_m_alu_b_sel     ;
                                        reg         dut_m_branch_taken  ;
                                        reg         dut_m_branch_inst_ex;
                                        reg         dut_m_jump_inst_ex  ;
                                        reg         dut_m_jump_taken    ;
                                        // Env misc signals
                                        reg  [ 4:0] dut_env_rs1_id      ;
                                        reg  [ 4:0] dut_env_rs2_id      ;
                                        reg  [ 4:0] dut_env_rd_id       ;

//-----------------------------------------------------------------------------
// DUT environment datapath
integer     dut_env_pc          ;
integer     dut_env_alu         ;
integer     dut_env_pc_mux_out  ;

//-----------------------------------------------------------------------------
// Testbench variables
integer       i                   ;              // used for all loops
integer       run_test_pc_target  ;
integer       alu_return_address  ;
integer       errors              ;
integer       warnings            ;

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// file read
integer       fd;
integer       status;
reg  [24*7:0] str;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [  31:0] test_values_inst_hex_nop;
reg  [24*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [24*7:0] test_values_inst_asm_nop;
reg  [24*7:0] dut_env_inst_id_asm;
reg  [24*7:0] dut_env_inst_ex_asm;

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_control DUT_ama_riscv_control_i (
    .clk                (clk         ),
    .rst                (rst         ),
    // inputs
    .inst_id            (inst_id          ),
    .bc_a_eq_b          (bc_a_eq_b        ),
    .bc_a_lt_b          (bc_a_lt_b        ),
    // .bp_taken           (bp_taken         ),
    // .bp_clear           (bp_clear         ),
    .store_mask_offset  (store_mask_offset),
    // pipeline inputs
    .inst_ex            (inst_ex          ),
    .reg_we_ex          (reg_we_ex        ),
    .rd_ex              (rd_ex            ),
    .store_inst_ex      (store_inst_ex    ),
    // pipeline outputs
    .stall_if           (stall_if         ),
    .clear_if           (clear_if         ),
    .clear_id           (clear_id         ),
    .clear_ex           (clear_ex         ),
    .clear_mem          (clear_mem        ),
    // pipeline resets
    
    // outputs
    .pc_sel             (pc_sel           ),
    .pc_we              (pc_we            ),
    // .imem_en            (imem_en          ),
    .store_inst         (store_inst       ),
    .branch_inst        (branch_inst      ),
    .jump_inst          (jump_inst        ),
    .alu_op_sel         (alu_op_sel       ),
    .ig_sel             (ig_sel           ),
    .bc_uns             (bc_uns           ),
    .dmem_en            (dmem_en          ),
    .load_sm_en         (load_sm_en       ),
    .wb_sel             (wb_sel           ),
    .reg_we             (reg_we           ),
    .alu_a_sel_fwd      (alu_a_sel_fwd    ),
    .alu_b_sel_fwd      (alu_b_sel_fwd    ),
    .bc_a_sel_fwd       (bc_a_sel_fwd     ),
    .bcs_b_sel_fwd      (bcs_b_sel_fwd    ),
    .dmem_we            (dmem_we          ) 
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Testbench tasks
task print_test_status;
    begin
        $display("\n----------------------- Simulation results -----------------------");
        $display("Tests ran to completion");
        $write("Status: ");
        if(!errors)
            $display("Passed");
        else
            $display("Failed");
        $display("Warnings: %2d", warnings);
        $display("Errors:   %2d", errors);
        $display("--------------------- End of the simulation ----------------------\n");
    end
endtask

task print_single_instruction_results;
    begin
        $display("Instruction at PC# %2d done. ", dut_env_pc); 
        $write  ("ID stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_id, dut_env_inst_id_asm);
        $write  ("EX stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
    end
endtask

task tb_driver;
    begin
        // inputs
        inst_id             = dut_env_inst_id           ;
        bc_a_eq_b           = dut_env_bc_a_eq_b         ;
        bc_a_lt_b           = dut_env_bc_a_lt_b         ;
        store_mask_offset   = dut_env_store_mask_offset ;
        
        // pipeline inputs
        inst_ex             = dut_env_inst_ex           ;
        reg_we_ex           = dut_env_reg_we_ex         ;
        rd_ex               = dut_env_rd_ex             ;
        store_inst_ex       = dut_env_store_inst_ex     ;
    end
    
endtask

task tb_checker;
    begin
        // Decoder
        // pc_sel
        if (pc_sel !== dut_m_pc_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT pc_sel: 'b%2b, Model pc_sel: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, pc_sel, dut_m_pc_sel);
            errors = errors + 1;
        end
        
        // pc_we
        if (pc_we !== dut_m_pc_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT pc_we: 'b%2b, Model pc_we: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, pc_we, dut_m_pc_we);
            errors = errors + 1;
        end
        
        // branch_inst
        if (branch_inst !== dut_m_branch_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT branch_inst: 'b%1b, Model branch_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, branch_inst, dut_m_branch_inst);
            errors = errors + 1;
        end
        
         // jump_inst
        if (jump_inst !== dut_m_jump_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT jump_inst: 'b%1b, Model jump_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, jump_inst, dut_m_jump_inst);
            errors = errors + 1;
        end
        
        // store_inst
        if (store_inst !== dut_m_store_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT store_inst: 'b%1b, Model store_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, store_inst, dut_m_store_inst);
            errors = errors + 1;
        end
        
        // alu_op_sel
        if (alu_op_sel !== dut_m_alu_op_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_op_sel: 'b%4b, Model alu_op_sel: 'b%4b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_op_sel, dut_m_alu_op_sel);
            errors = errors + 1;
        end
        /* 
        // alu_a_sel_fwd
        if (alu_a_sel_fwd !== dut_m_alu_a_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_a_sel_fwd: 'b%1b, Model alu_a_sel_fwd: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_a_sel_fwd, dut_m_alu_a_sel_fwd);
            errors = errors + 1;
        end
        
        // alu_b_sel_fwd
        if (alu_b_sel_fwd !== dut_m_alu_b_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_b_sel_fwd: 'b%1b, Model alu_b_sel_fwd: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_b_sel_fwd, dut_m_alu_b_sel_fwd);
            errors = errors + 1;
        end
         */
        // ig_sel
        if (ig_sel !== dut_m_ig_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT ig_sel: 'b%3b, Model ig_sel: 'b%3b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, ig_sel, dut_m_ig_sel);
            errors = errors + 1;
        end
        
        // bc_uns
        if (bc_uns !== dut_m_bc_uns) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT bc_uns: 'b%1b, Model bc_uns: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, bc_uns, dut_m_bc_uns);
            errors = errors + 1;
        end
        
        // dmem_en
        if (dmem_en !== dut_m_dmem_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT dmem_en: 'b%1b, Model dmem_en: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, dmem_en, dut_m_dmem_en);
            errors = errors + 1;
        end
        
        // load_sm_en
        if (load_sm_en !== dut_m_load_sm_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT load_sm_en: 'b%1b, Model load_sm_en: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, load_sm_en, dut_m_load_sm_en);
            errors = errors + 1;
        end
        
        // wb_sel
        if (wb_sel !== dut_m_wb_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT wb_sel: 'b%2b, Model wb_sel: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, wb_sel, dut_m_wb_sel);
            errors = errors + 1;
        end
        
        // reg_we
        if (reg_we !== dut_m_reg_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT reg_we: 'b%1b, Model reg_we: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, reg_we, dut_m_reg_we);
            errors = errors + 1;
        end
        
        // Operand Forwarding
        // alu_a_sel_fwd
        if (alu_a_sel_fwd !== dut_m_alu_a_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_a_sel_fwd: %0d, Model alu_a_sel_fwd: %0d ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_a_sel_fwd, dut_m_alu_a_sel_fwd);
            errors = errors + 1;
        end
        
        // alu_b_sel_fwd
        if (alu_b_sel_fwd !== dut_m_alu_b_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_b_sel_fwd: %0d, Model alu_b_sel_fwd: %0d ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_b_sel_fwd, dut_m_alu_b_sel_fwd);
            errors = errors + 1;
        end
        
        // bc_a_sel_fwd
        if (bc_a_sel_fwd !== dut_m_bc_a_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT bc_a_sel_fwd: %0d, Model bc_a_sel_fwd: %0d ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, bc_a_sel_fwd, dut_m_bc_a_sel_fwd);
            errors = errors + 1;
        end
        
        // bcs_b_sel_fwd
        if (bcs_b_sel_fwd !== dut_m_bcs_b_sel_fwd) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT bcs_b_sel_fwd: %0d, Model bcs_b_sel_fwd: %0d ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, bcs_b_sel_fwd, dut_m_bcs_b_sel_fwd);
            errors = errors + 1;
        end
    
    end // main task body */
endtask // tb_checker

task read_test_instructions;
    begin
        // Instructions HEX
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/decoder_inst_hex.txt"}, "r");
    
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end
    
        i = 0;
        while(!$feof(fd)) begin
            $fscanf (fd, "%h", test_values_inst_hex[i]);
            // $display("'h%h", test_values_inst_hex[i]);
            i = i + 1;
        end
        $fclose(fd);        
        test_values_inst_hex_nop = 'h0000_0013;
        
        // Instructions ASM
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/decoder_inst_asm.txt"}, "r");
        
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end
                
        i = 0;
        while(!$feof(fd)) begin
            status = $fgets(str, fd);
            // $write("%0s", str);
            test_values_inst_asm[i] = str;
            // $write("%0s", test_values_inst_asm[i]);
            i = i + 1;
        end
        $fclose(fd);
        test_values_inst_asm_nop = "addi  x0 x0 0 \n";
    end
endtask

task randomize_instructions;
    begin
        
    // detect instruction
    //      randomize fields that given instruction can
    //      asm text file will no longer be valid -> pass thru disassembler if inst fails
    //      remove printing asm text when randomizing
    end

endtask

//-----------------------------------------------------------------------------
// DUT model tasks
task dut_m_decode;
    reg  [31:0] inst_id;
    reg  [31:0] inst_ex;
    
    begin
    inst_id       = dut_env_inst_id;
    inst_ex       = dut_env_inst_ex;
    
        case (inst_id[6:0])
            'b011_0011: begin   // R-type instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = ({inst_id[30], inst_id[14:12]});
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_RS2;
                dut_m_ig_sel      = `IG_DISABLED;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            'b001_0011: begin   // I-type instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = (inst_id[13:12] == 2'b01)  ? 
                                    {inst_id[30], inst_id[14:12]} : {1'b0, inst_id[14:12]};
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            'b000_0011: begin   // Load instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b1;
                dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b1;
            end
            
            'b010_0011: begin   // Store instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b1;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_S_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b0;
                // dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b0;
            end
            
            'b110_0011: begin   // Branch instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b0;
                dut_m_branch_inst = 1'b1;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_B_TYPE;
                dut_m_bc_uns      = inst_id[13];
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                // dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b0;
            end
            
            'b110_0111: begin   // JALR instruction
                dut_m_pc_sel      = `PC_SEL_ALU;
                dut_m_pc_we       = 1'b0;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b1;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = *;
                dut_m_dmem_en     = 1'b0;
                // dut_m_load_sm_en  = *;
                dut_m_wb_sel      = `WB_SEL_INC4;
                dut_m_reg_we      = 1'b1;
            end
            
            'b110_1111: begin   // JAL instruction
                dut_m_pc_sel      = `PC_SEL_ALU;
                dut_m_pc_we       = 1'b0;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b1;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_J_TYPE;
                // dut_m_bc_uns      = *;
                dut_m_dmem_en     = 1'b0;
                // dut_m_load_sm_en  = *;
                dut_m_wb_sel      = `WB_SEL_INC4;
                dut_m_reg_we      = 1'b1;
            end
            
            'b011_0111: begin   // LUI instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b1111;    // pass b
                // dut_m_alu_a_sel   = *;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_U_TYPE;
                // dut_m_bc_uns      = *;
                dut_m_dmem_en     = 1'b0;
                // dut_m_load_sm_en  = *;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            'b001_0111: begin   // AUIPC instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_U_TYPE;
                // dut_m_bc_uns      = *;
                dut_m_dmem_en     = 1'b0;
                // dut_m_load_sm_en  = *;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            default: begin
                $write("*WARNING @ %0t. Model 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_env_inst_id, dut_env_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
        
        // Override if rst == 1
        if (rst) begin
            dut_m_pc_sel      = 2'b11;
            dut_m_pc_we       = 1'b1;
            dut_m_branch_inst = 1'b0;
            dut_m_jump_inst   = 1'b0;
            dut_m_store_inst  = 1'b0;
            dut_m_alu_op_sel  = 4'b0000;
            dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
            dut_m_alu_b_sel   = `ALU_B_SEL_RS2;
            dut_m_ig_sel      = `IG_DISABLED;
            dut_m_bc_uns      = 1'b0;
            dut_m_dmem_en     = 1'b0;
            dut_m_load_sm_en  = 1'b0;
            dut_m_wb_sel      = `WB_SEL_DMEM;
            dut_m_reg_we      = 1'b0;
        end
        
        // operand forwarding
        // Operand A
        if ((dut_env_rs1_id != `RF_X0_ZERO) && (dut_env_rs1_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (!dut_m_alu_a_sel))
            dut_m_alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;           // forward previous ALU result
        else
            dut_m_alu_a_sel_fwd = {1'b0, dut_m_alu_a_sel};      // don't forward
        
        // Operand B
        if ((dut_env_rs2_id != `RF_X0_ZERO) && (dut_env_rs2_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (!dut_m_alu_b_sel))
            dut_m_alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;           // forward previous ALU result
        else
            dut_m_alu_b_sel_fwd = {1'b0, dut_m_alu_b_sel};      // don't forward
        
        // BC A
        dut_m_bc_a_sel_fwd  = ((dut_env_rs1_id != `RF_X0_ZERO) && (dut_env_rs1_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (dut_m_branch_inst));
        
        // BC B / DMEM din
        dut_m_bcs_b_sel_fwd = ((dut_env_rs2_id != `RF_X0_ZERO) && (dut_env_rs2_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (dut_m_store_inst || dut_m_branch_inst));
        
        
        // branch resolution
        case ({inst_ex[14],inst_ex[12]})
            2'b00:      // beq -> a == b
                dut_m_branch_taken = dut_env_bc_a_eq_b;
            
            2'b01:      // bne -> a != b
                dut_m_branch_taken = !dut_env_bc_a_eq_b;
            
            2'b10:      // blt -> a < b
                dut_m_branch_taken = dut_env_bc_a_lt_b;
            
            2'b11:      // bge -> a >= b
                dut_m_branch_taken = dut_env_bc_a_eq_b || !dut_env_bc_a_lt_b;
            
            default: begin
                $write("*WARNING @ %0t. Branch model 'default' case. Input inst_ex: 'h%8h  %0s",
                $time, dut_env_inst_ex, dut_env_inst_ex_asm);
                warnings = warnings + 1;
            end
        endcase
        // Override if rst == 1
        if (rst) dut_m_branch_taken = 1'b0;
        // if not branch instruction, it cannot be taken
        dut_m_branch_taken = dut_m_branch_taken && dut_m_branch_inst_ex;
        
        
        // jump?
        dut_m_jump_taken = dut_m_jump_inst_ex;
        
        
        // flow change instructions use ALU out as destination address
        if(dut_m_branch_taken || dut_m_jump_taken) dut_m_pc_sel = 2'b01; // alu input
        
        // $display("\nBranch used inst ex: %8h, branch_instr: %1b ", dut_env_inst_ex, dut_m_branch_inst_ex);
        
    end                  
endtask // dut_m_decode

task dut_m_ex_pipeline_update;
    begin
        // instruction update model
        dut_m_branch_inst_ex = (!rst) ? dut_m_branch_inst   : 'b0;
        dut_m_jump_inst_ex   = (!rst) ? dut_m_jump_inst     : 'b0;
    end
endtask

/* task dut_m_id_pipeline_update;
    begin
        // reg addresses update
        dut_m_rs1_id = dut_env_inst_id[19:15];
        dut_m_rs2_id = dut_env_inst_id[24:20];
        dut_m_rd_id  = dut_env_inst_id[11: 7];
        
    end
endtask */

//-----------------------------------------------------------------------------
// Environment update tasks
task env_reset;
    begin
        dut_env_inst_id = 'h0;
        dut_env_inst_ex = 'h0;
        // dut_env_pc      = 0;
        dut_env_alu     = 'h1;  // temp, always return to second (idx=1) instruction
    end
endtask

// IF Stage - Environment update tasks
task env_pc_mux_update;
    begin
        case (pc_sel)   // use DUT or model?
            2'd0: begin
                dut_env_pc_mux_out =  dut_env_pc + 1;
            end
            
            2'd1: begin
                dut_env_pc_mux_out =  dut_env_alu;
            end
            
            2'd2: begin
                $display("*WARNING @ %0t. pc_sel = 2 is not supported yet - TBD for prediction", $time);
                warnings = warnings + 1;
            end
            
            2'd3: begin
                dut_env_pc_mux_out =  'h0;  // start address
            end
            
            default: begin
                if(rst_done) begin
                    $display("*ERROR @ %0t. pc_sel not valid", $time);
                    errors = errors + 1;
                end 
                else /* !rst_done */ begin
                    $display("*WARNING @ %0t. pc_sel not valid", $time);
                    warnings = warnings + 1;
                end
            end
        endcase
    end
endtask

task env_pc_update;
    begin
        dut_env_pc = (!rst)         ? 
                     (dut_m_pc_we)  ? dut_env_pc_mux_out   :   // mux
                                      dut_env_pc           :   // pc_we = 0
                                      'h0;                     // rst = 1
    end
endtask

// ID Stage - Environment update tasks
task env_id_pipeline_update;
    reg stall_if;
    begin
        // instruction update
        stall_if = dut_m_branch_inst_ex || dut_m_jump_inst_ex;
        if (stall_if) begin    // stall_if, convert to nop
            dut_env_inst_id      = test_values_inst_hex_nop;
            dut_env_inst_id_asm  = test_values_inst_asm_nop;
        end
        else begin
            dut_env_inst_id      = test_values_inst_hex[dut_env_pc_mux_out];
            dut_env_inst_id_asm  = test_values_inst_asm[dut_env_pc_mux_out];
        end
        
        dut_env_rs1_id  = dut_env_inst_id[19:15];
        dut_env_rs2_id  = dut_env_inst_id[24:20];
        dut_env_rd_id   = dut_env_inst_id[11: 7];
    end
endtask

// EX Stage - Environment update tasks
task env_ex_pipeline_update;
    begin
        // instruction update env
        dut_env_inst_ex      = (!rst) ? dut_env_inst_id     : 'h0;
        dut_env_inst_ex_asm  = (!rst) ? dut_env_inst_id_asm : 'h0;
                
        // rd address update
        dut_env_rd_ex        = (!rst) ? dut_env_rd_id       : 'h0;
        
        // we update
        dut_env_reg_we_ex    = (!rst) ? reg_we              : 'b0;
        
        // update model
        dut_m_ex_pipeline_update();
        
    end
endtask

task env_branch_compare_update;
    input take_branch;
    begin
        // $display("env_branch_compare_update, take_branch: 'b%0b, input inst_ex: 'h%8h  %0s", take_branch, dut_env_inst_ex, dut_env_inst_ex_asm);
        case ({dut_env_inst_ex[14], dut_env_inst_ex[12]})
            2'b00: begin     // beq -> a == b
                dut_env_bc_a_eq_b = take_branch;
                dut_env_bc_a_lt_b = dut_env_bc_a_eq_b ? 1'b0 : $random;
                // $display("env_branch_compare_update, beq");
            end
            
            2'b01: begin     // bne -> a != b
                // $display("env_branch_compare_update, bne");
                dut_env_bc_a_eq_b = !take_branch;
                dut_env_bc_a_lt_b = $random;
            end
            
            2'b10: begin     // blt -> a < b
                // $display("env_branch_compare_update, blt");
                dut_env_bc_a_lt_b = take_branch;
                dut_env_bc_a_eq_b = dut_env_bc_a_lt_b ? 1'b0 : $random;
            end
            
            2'b11: begin     // bge -> a >= b
                // $display("env_branch_compare_update, bge");
                dut_env_bc_a_eq_b = ($random & take_branch);
                dut_env_bc_a_lt_b = dut_env_bc_a_eq_b ? 1'b0 : !take_branch;
            end
            
            default: begin
                $write("*WARNING @ %0t. env_branch_compare_update 'default' case. Input inst_ex: 'h%8h  %0s",
                $time, dut_env_inst_ex, dut_env_inst_ex_asm);
                warnings = warnings + 1;
            end
            
        endcase
    end
endtask

task env_alu_out_update;
    input [31:0] in_dut_env_alu;
    begin
        dut_env_alu = in_dut_env_alu;
    end
endtask

// Sequential logic - Environment update tasks
task env_update_seq;
    begin
        //----- EX stage updates
        env_ex_pipeline_update();
        // $write  ("inst_ex - FF :     'h%8h    %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        // $display("dut_env_rd_ex:       %0d", dut_env_rd_ex     );
        // $display("dut_env_reg_we_ex: 'b%0b", dut_env_reg_we_ex );
        
        //----- ID stage updates
        env_id_pipeline_update();
        // $write("inst_id - IMEM read: 'h%8h    %0s", dut_env_inst_id, dut_env_inst_id_asm);
        env_pc_update();
        // $display("PC reg: %0d ", dut_env_pc);
    end
endtask

// Combinational logic - Environment update tasks
task env_update_comb;
    input [31:0] alu_out_update;
    input        branch_compare_update;
    begin
        env_branch_compare_update(branch_compare_update);
        // $display("Branch compare result - eq: %0b, lt: %0b ", dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        env_alu_out_update(alu_out_update);
        // $display("ALU out: %0d ", dut_env_alu);
        env_pc_mux_update();
        // $display("PC sel: %0d ", pc_sel);
        // $display("PC MUX: %0d ", dut_env_pc_mux_out);
    end
endtask

//-----------------------------------------------------------------------------
// Reset
initial begin
    // sync this thread with events from main thread
    @(ev_rst[0]); // #1;
    $display("\nReset Sequence start \n");    
    rst = 1'b0;
    
    @(ev_rst[0]); // @(posedge clk); #1;
    
    rst = 1'b1;
    repeat (rst_pulses) begin
        @(ev_rst[0]); //@(posedge clk); #1;          
    end
    rst = 1'b0;
    // @(ev_rst[0]); //@(posedge clk); #1;  
    // ->ev_rst_done;
    $display("\nReset Sequence end \n");
    rst_done = 1;
    
end

//-----------------------------------------------------------------------------
// Config

// Initial setup
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    read_test_instructions();
    env_reset();
    errors   <= 0;
    warnings <= 0;
end

// Timestamp print
initial begin
    forever begin
        $display("\n\n\n --- Sim time : %0t ---\n", $time);
        @(posedge clk);
    end
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n----------------------- Simulation started -----------------------\n");
    
    // Test 0: Wait for reset
    $display("\nTest  0: Wait for reset: Start \n");
    @(posedge clk); #1;
    while (!rst_done) begin
        // $display("Reset not done, time: %0t \n", $time);
         ->ev_rst[0]; #1;
        
        // if still not done, wait for next clk else update env and exit
        if(!rst_done) begin @(posedge clk); #1; end

        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; env_update_comb('h0, 'b0);
    end
    $display("Reset done, time: %0t \n", $time);
    
    // wait for DUT to actually go out of reset
    @(posedge clk); #1; 
    $display("Checking reset exit, time: %0t \n", $time);
    env_update_seq();
    tb_driver();
    dut_m_decode();
    #1; tb_checker();
    print_single_instruction_results();
    env_update_comb('h0, 'b0);
    $display("\nTest  0: Wait for reset: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: R-type
    $display("\nTest  1: Hit specific case [R-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `R_TYPE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  1: Hit specific case [R-type]: Done \n");
    
/*    
    //-----------------------------------------------------------------------------
    // Test 2: I-type
    $display("\nTest  2: Hit specific case [I-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `I_TYPE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  2: Hit specific case [I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 3: Load
    $display("\nTest  3: Hit specific case [Load]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `LOAD_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  3: Hit specific case [Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 4: Store
    $display("\nTest  4: Hit specific case [Stores]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `STORE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  4: Hit specific case [Stores]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 5: Branch
    $display("\nTest  5: Hit specific cases [Branches]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `BRANCH_TESTS ;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_env_pc_mux_out + 1;
        // $display("\ndut_env_pc: %0d ",          dut_env_pc);
        // $display("\ndut_env_pc_mux_out: %0d ",  dut_env_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute branch instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(`LABEL_TGT, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was branched to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
    end // while(dut_env_pc_mux_out < run_test_pc_target)
    $display("\nTest  5: Hit specific cases [Branches]: Done \n");    
    
    //-----------------------------------------------------------------------------
    // Test 6: JALR
    $display("\nTest  6: Hit specific case [JALR]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `JALR_TEST ;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_env_pc_mux_out + 1;
        // $display("\ndut_env_pc: %0d ",          dut_env_pc);
        // $display("\ndut_env_pc_mux_out: %0d ",  dut_env_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute JALR instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
    end // while(dut_env_pc_mux_out < run_test_pc_target)
    $display("\nTest  6: Hit specific case [JALR]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 7: JALR
    $display("\nTest  7: Hit specific case [JAL]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `JAL_TEST ;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_env_pc_mux_out + 1;
        // $display("\ndut_env_pc: %0d ",          dut_env_pc);
        // $display("\ndut_env_pc_mux_out: %0d ",  dut_env_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute JAL instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; tb_checker();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
    end // while(dut_env_pc_mux_out < run_test_pc_target)
    $display("\nTest  7: Hit specific case [JAL]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 8: LUI
    $display("\nTest  8: Hit specific case [LUI]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `LUI_TEST;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('hA, 'b0);  // ALU is actually used for write to RF, but data is not relevant to this TB, only control signals in checker
    end
    $display("\nTest  8: Hit specific case [LUI]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 9: AUIPC
    $display("\nTest  9: Hit specific case [AUIPC]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `AUIPC_TEST;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('hE, 'b0);  // ALU is actually used for write to RF, but data is not relevant to this TB, only control signals in checker
    end
    $display("\nTest  9: Hit specific case [AUIPC]: Done \n");*/
    
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    print_test_status();
    $finish();
end

endmodule
