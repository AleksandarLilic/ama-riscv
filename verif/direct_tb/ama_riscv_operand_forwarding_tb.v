//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Operand Forwarding Testbench
// File:            ama_riscv_operand_forwarding_tb.v
// Date created:    2021-08-12
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  No forwarding when there is no dependency - pass decoder values
//                      2.  Forwarding data when dependency occurs in the pipeline
//                        2a. R-type followed by all dependency options
//                        2b. I-type followed by all dependency options
//                        2c. Load followed by all dependency options
//                      4.  No forwarding occurs when dependency exists but its x0   
//                      5.  No forwarding occurs when dependency exists but reg_we_ex = 0   
//                      * All dependency options are:
//                       - R-type   : rs1(ALU A), rs2(ALU B),    rs1(ALU A) and rs2(ALU B)
//                       - I-type   : rs1(ALU A)
//                       - Load     : rs1(ALU A)
//                       - Store    : rs1(ALU A), rs2(DMEM Din), rs1(ALU A) and rs2(DMEM Din)
//                       - Branch   : rs1(BC A) , rs2(BC B),     rs1(BC A)  and rs2(BC B)
//                       - JALR     : rs1(ALU A)
//                         Total dependencies: 12
//                       - Additionally, another 3 instructions (JAL, LUI, AUIPC) should be 
//                         checked to verify that they do not cause forwarding
//                         Total checks: 15
//
// Version history:
//      2021-08-13  AL  0.1.0 - Initial - Add no forwarding no dependency tests
//      2021-08-13  AL  0.2.0 - Add forwarding with dependency tests (test set)
//      2021-08-16  AL  0.3.0 - Match RTL DMEM forwarding implementation
//      2021-08-18  AL  0.4.0 - Match RTL Branch Compare and DMEM forwarding implementation
//      2021-08-18  AL  0.5.0 - Add forwarding with dependency tests for R-type
//      2021-08-19  AL  0.6.0 - Add forwarding with dependency tests for I-type
//      2021-08-19  AL  0.7.0 - Add forwarding with dependency tests for Load
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define NFND_TEST                5           // No Forwarding No Dependency
`define FDRT_TEST                12*2 + 3*2  // Forwarding with Dependency R-type
`define FDIT_TEST                12*2 + 3*2  // Forwarding with Dependency I-type
`define FDL_TEST                 12*2 + 3*2  // Forwarding with Dependency Load
`define TEST_CASES               `NFND_TEST + `FDRT_TEST + `FDIT_TEST + `FDL_TEST

// Expected dependencies in each of the dependency tests
`define FD_TEST_EXP_ALU_A      7  // for ALU A
`define FD_TEST_EXP_ALU_B      2  // for ALU B
`define FD_TEST_EXP_BC_A       2  // for BC A 
`define FD_TEST_EXP_BCS_B      4  // for BCS B

// MUX select signals
// ALU A operand select
`define ALU_A_SEL_FWD_ALU    2'd2  // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_FWD_ALU    2'd2  // B = ALU; forwarding from MEM stage

`define PROJECT_PATH        "C:/Users/Aleksandar/Documents/xilinx/ama-riscv/"

module ama_riscv_operand_forwarding_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
reg         rst;
// inputs
reg         reg_we_ex       ;
reg         store_inst_id   ;
reg         branch_inst_id  ;
reg  [ 5:0] rs1_id          ;
reg  [ 5:0] rs2_id          ;
reg  [ 5:0] rd_ex           ;
reg         alu_a_sel       ;
reg         alu_b_sel       ;
// outputs                  
wire [ 1:0] alu_a_sel_fwd   ;
wire [ 1:0] alu_b_sel_fwd   ;
wire        bc_a_sel_fwd    ;
wire        bcs_b_sel_fwd   ;

// DUT model Outputs
reg  [ 1:0] dut_m_alu_a_sel_fwd   ;
reg  [ 1:0] dut_m_alu_b_sel_fwd   ;
reg         dut_m_bc_a_sel_fwd    ;
reg         dut_m_bcs_b_sel_fwd   ;

// DUT environment
reg  [31:0] dut_env_inst_id       ;
reg  [31:0] dut_env_inst_ex       ;
reg         dut_env_reg_we_id     ;
reg         dut_env_reg_we_ex     ;
reg         dut_env_store_inst_id ;
reg         dut_env_branch_inst_id;
reg  [ 5:0] dut_env_rs1_id        ;
reg  [ 5:0] dut_env_rs2_id        ;
reg  [ 5:0] dut_env_rd_id         ;
reg  [ 5:0] dut_env_rd_ex         ;
reg         dut_env_alu_a_sel     ;
reg         dut_env_alu_b_sel     ;

// Reset hold for
reg  [ 3:0] rst_pulses = 4'd3;

// Testbench variables
integer     i                   ;              // used for all loops
integer     run_test_pc_target  ;
integer     run_test_pc_current ;
integer     errors              ;
integer     warnings            ;
integer     checker_exp_alu_a   ;
integer     checker_exp_alu_b   ;
integer     checker_exp_bc_a    ;
integer     checker_exp_bcs_b   ;
integer     alu_a_sel_fwd_cnt   ;
integer     alu_b_sel_fwd_cnt   ;
integer     bc_a_sel_fwd_cnt    ;
integer     bcs_b_sel_fwd_cnt   ;

// file read
integer fd;
integer status;
reg  [26*7:0] str;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [  31:0] test_values_inst_hex_nop;
reg  [26*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [26*7:0] test_values_inst_asm_nop;
reg  [26*7:0] dut_env_inst_id_asm;
reg  [26*7:0] dut_env_inst_ex_asm;

// events
event ev_rst    [1:0];
integer rst_done = 0;


//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_operand_forwarding DUT_ama_riscv_operand_forwarding_i (
    // inputs    
    .reg_we_ex        (reg_we_ex     ),
    .store_inst_id    (store_inst_id ),
    .branch_inst_id   (branch_inst_id),
    .rs1_id           (rs1_id        ),
    .rs2_id           (rs2_id        ),
    .rd_ex            (rd_ex         ),
    .alu_a_sel        (alu_a_sel     ),
    .alu_b_sel        (alu_b_sel     ),
    // outputs                       
    .alu_a_sel_fwd    (alu_a_sel_fwd ),
    .alu_b_sel_fwd    (alu_b_sel_fwd ),
    .bc_a_sel_fwd     (bc_a_sel_fwd  ),
    .bcs_b_sel_fwd    (bcs_b_sel_fwd )
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task print_dependency_counters;
    begin
        $display("");
        $write("Dependency counters:  ");
        $write("alu_a_sel_fwd_cnt: %2d;  ", alu_a_sel_fwd_cnt);
        $write("alu_b_sel_fwd_cnt: %2d;  ", alu_b_sel_fwd_cnt);
        $write("bc_a_sel_fwd_cnt : %2d;  ",  bc_a_sel_fwd_cnt);
        $write("bcs_b_sel_fwd_cnt: %2d;  ", bcs_b_sel_fwd_cnt);
        $display("");
    end
endtask

task print_test_results;
    begin
        $display("Instruction at PC# %2d done. ", run_test_pc_current); 
        $write  ("ID stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_id, dut_env_inst_id_asm);
        $write  ("EX stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        $display("Input control signals : reg_we_ex:      'b%0b, store_inst_id: 'b%0b , branch_inst_id: 'b%0b ", reg_we_ex, store_inst_id, branch_inst_id); 
        $display("Decoder select signals: alu_a_sel:        %0d, alu_b_sel:       %0d ", alu_a_sel, alu_b_sel); 
        $display("OP FWD select signals : alu_a_sel_fwd:    %0d, alu_b_sel_fwd:   %0d ", alu_a_sel_fwd, alu_b_sel_fwd); 
        $display("BC FWD select signal  : bc_a_sel_fwd :    %0d", bc_a_sel_fwd );
        $display("BCS FWD select signal : bcs_b_sel_fwd:    %0d", bcs_b_sel_fwd);
    end
endtask

task tb_driver;    
    begin
        alu_a_sel      = dut_env_alu_a_sel      ;
        alu_b_sel      = dut_env_alu_b_sel      ;
        rs1_id         = dut_env_rs1_id         ;
        rs2_id         = dut_env_rs2_id         ;
        rd_ex          = dut_env_rd_ex          ;
        reg_we_ex      = dut_env_reg_we_ex      ;
        store_inst_id  = dut_env_store_inst_id  ;
        branch_inst_id = dut_env_branch_inst_id ;        
    end    
endtask

task tb_checker;
    begin    
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
        
    end // main task body
endtask

task expected_dependencies;
    input integer task_exp_alu_a;
    input integer task_exp_alu_b;
    input integer task_exp_bc_a;
    input integer task_exp_bcs_b;
    
    begin
        checker_exp_alu_a = task_exp_alu_a;
        checker_exp_alu_b = task_exp_alu_b;
        checker_exp_bc_a  = task_exp_bc_a ;
        checker_exp_bcs_b = task_exp_bcs_b;
    end
endtask

task dependency_checker;
    begin
        if(alu_a_sel_fwd_cnt !== checker_exp_alu_a) begin
            $display("*ERROR @ %0t. Mismatch in dependencies for ALU A. Expected: %0d, Counted: %0d,", 
            $time, checker_exp_alu_a, alu_a_sel_fwd_cnt);
            errors = errors + 1;
        end
        
        if(alu_b_sel_fwd_cnt !== checker_exp_alu_b) begin
            $display("*ERROR @ %0t. Mismatch in dependencies for ALU B. Expected: %0d, Counted: %0d,", 
            $time, checker_exp_alu_b, alu_b_sel_fwd_cnt);
            errors = errors + 1;
        end
        
        if(bc_a_sel_fwd_cnt !== checker_exp_bc_a) begin
            $display("*ERROR @ %0t. Mismatch in dependencies for BC A. Expected: %0d, Counted: %0d,", 
            $time, checker_exp_bc_a, bc_a_sel_fwd_cnt);
            errors = errors + 1;
        end
        
        if(bcs_b_sel_fwd_cnt !== checker_exp_bcs_b) begin
            $display("*ERROR @ %0t. Mismatch in dependencies for BCS B. Expected: %0d, Counted: %0d,", 
            $time, checker_exp_bcs_b, bcs_b_sel_fwd_cnt);
            errors = errors + 1;
        end
        
        print_dependency_counters();
        
        // reset counters for next test run
        alu_a_sel_fwd_cnt = 0;
        alu_b_sel_fwd_cnt = 0;
        bc_a_sel_fwd_cnt  = 0;
        bcs_b_sel_fwd_cnt = 0;
        
    end
endtask

task read_test_instructions;
    begin
        // Instructions HEX
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/op_fwd_inst_hex.txt"}, "r");
    
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
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/op_fwd_inst_asm.txt"}, "r");
        
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

task dut_m_decode;
    begin
        // Operand A
        if ((dut_env_rs1_id != `RF_X0_ZERO) && (dut_env_rs1_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (!dut_env_alu_a_sel))
            dut_m_alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;  // forward previous ALU result
        else
            dut_m_alu_a_sel_fwd = {1'b0, dut_env_alu_a_sel};  // don't forward
        
        // Operand B
        if ((dut_env_rs2_id != `RF_X0_ZERO) && (dut_env_rs2_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (!dut_env_alu_b_sel))
            dut_m_alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;  // forward previous ALU result
        else
            dut_m_alu_b_sel_fwd = {1'b0, dut_env_alu_b_sel};  // don't forward
        
        // BC A
        dut_m_bc_a_sel_fwd  = ((dut_env_rs1_id != `RF_X0_ZERO) && (dut_env_rs1_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (dut_env_branch_inst_id));
        
        // BC B / DMEM din
        dut_m_bcs_b_sel_fwd = ((dut_env_rs2_id != `RF_X0_ZERO) && (dut_env_rs2_id == dut_env_rd_ex) && (dut_env_reg_we_ex) && (dut_env_store_inst_id || dut_env_branch_inst_id));
        
        // Dependency counters:
        alu_a_sel_fwd_cnt  = alu_a_sel_fwd_cnt + dut_m_alu_a_sel_fwd[1];
        alu_b_sel_fwd_cnt  = alu_b_sel_fwd_cnt + dut_m_alu_b_sel_fwd[1];
        bc_a_sel_fwd_cnt   = bc_a_sel_fwd_cnt  + dut_m_bc_a_sel_fwd ;
        bcs_b_sel_fwd_cnt  = bcs_b_sel_fwd_cnt + dut_m_bcs_b_sel_fwd;
        
        // Print info
        if(dut_m_alu_a_sel_fwd[1])  $display("---> alu_a_sel forwarded");
        if(dut_m_alu_b_sel_fwd[1])  $display("---> alu_b_sel forwarded");
        if(dut_m_bc_a_sel_fwd )     $display("---> bc_a_sel_fwd  forwarded");
        if(dut_m_bcs_b_sel_fwd)     $display("---> bcs_b_sel_fwd forwarded");
    end
endtask // dut_m_decode

// Reset task
task env_reset;
    begin
        // dut_env_inst_id     = 'h0;
        // dut_env_inst_ex     = 'h0;
        // dut_env_alu         = 'h1;  // temp, always return to second (idx=1) instruction
        run_test_pc_current = 0;
        run_test_pc_target  = 0;
    end
endtask

// ID stage tasks
task env_inst_id_update;
    begin
        dut_env_inst_id      = test_values_inst_hex[run_test_pc_current];
        dut_env_inst_id_asm  = test_values_inst_asm[run_test_pc_current];
    end
endtask

task env_reg_addr_id_update;
        begin
            dut_env_rs1_id = dut_env_inst_id[19:15];
            dut_env_rs2_id = dut_env_inst_id[24:20];
            dut_env_rd_id  = dut_env_inst_id[11: 7];
        end
endtask

task env_decoder_id_update;
    begin
        // store instruction
        dut_env_store_inst_id  = (dut_env_inst_id[6:0] == 'b010_0011);
        
        // store instruction
        dut_env_branch_inst_id = (dut_env_inst_id[6:0] == 'b110_0011);
        
        // reg_we
        case (dut_env_inst_id[6:0])
            'b011_0011,     // R-type instruction
            'b001_0011,     // I-type instruction
            'b000_0011,     // Load instruction
            'b110_0111,     // JALR instruction
            'b110_1111,     // JAL instruction            
            'b011_0111,     // LUI instruction
            'b001_0111:     // AUIPC instruction
                dut_env_reg_we_id      = 1'b1;
            
            'b010_0011,     // Store instruction
            'b110_0011:     // Branch instruction
                dut_env_reg_we_id      = 1'b0;
            
            default: begin
                $write("*WARNING @ %0t. Env reg_we 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_env_inst_id, dut_env_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
    end
endtask

task env_alu_op_sel_id_update;
    begin
        case (dut_env_inst_id[6:0])
            'b011_0011:     // R-type instruction
            begin
                dut_env_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_env_alu_b_sel   = `ALU_B_SEL_RS2;
            end
            
            'b001_0011,     // I-type instruction
            'b000_0011,     // Load instruction
            'b010_0011,     // Store instruction
            'b110_0111:     // JALR instruction
            begin
                dut_env_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_env_alu_b_sel   = `ALU_B_SEL_IMM;
            end

            'b011_0111:     // LUI instruction
            begin
                // dut_env_alu_a_sel   = *;
                dut_env_alu_b_sel   = `ALU_B_SEL_IMM;
            end
            
            'b110_0011,     // Branch instruction
            'b110_1111,     // JAL instruction            
            'b001_0111:     // AUIPC instruction
            begin
                dut_env_alu_a_sel   = `ALU_A_SEL_PC;
                dut_env_alu_b_sel   = `ALU_B_SEL_IMM;
            end
            
            default: begin
                $write("*WARNING @ %0t. Env reg_we 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_env_inst_id, dut_env_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
    end
endtask

// EX stage tasks
task env_inst_ex_update;
    begin
        dut_env_inst_ex      = (!rst) ? dut_env_inst_id      : 'h0;
        dut_env_inst_ex_asm  = (!rst) ? dut_env_inst_id_asm  : 'h0;
    end
endtask

task env_reg_addr_ex_update;
        begin
            dut_env_rd_ex  = (!rst) ? dut_env_rd_id : 'h0;
        end
endtask

task env_reg_we_ex_update;
        begin
            dut_env_reg_we_ex = (!rst) ? dut_env_reg_we_id : 'h0;
        end
endtask

// task env_alu_out_update;
    // input [31:0] task_dut_env_alu;
    // begin
        // dut_env_alu = task_dut_env_alu;
    // end
// endtask

// ENV update tasks
task env_update_seq;
    begin
        //----- EX stage updates
        env_inst_ex_update();
        // $write("inst_ex - FF reg:    'h%8h    %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        env_reg_addr_ex_update();
        // $display("dut_env_rd_ex: %0d", dut_env_rd_ex);
        env_reg_we_ex_update();
        // $display("dut_env_reg_we_id: 'b%0b", dut_env_reg_we_id);
        
        //----- ID stage updates
        env_inst_id_update();
        // $write("inst_id - IMEM read: 'h%8h    %0s", dut_env_inst_id, dut_env_inst_id_asm);
        env_reg_addr_id_update();
        // $display("dut_env_rs1_id: %0d, dut_env_rs2_id: %0d, dut_env_rd_id: %0d", dut_env_rs1_id, dut_env_rs2_id, dut_env_rd_id);
        env_decoder_id_update();
        // $display("dut_env_reg_we_ex: 'b%0b", dut_env_reg_we_ex);
        env_alu_op_sel_id_update();
        // $display("dut_env_alu_a_sel: 'b%0b, dut_env_alu_b_sel: 'b%0b", dut_env_alu_a_sel, dut_env_alu_b_sel);
        
        // env_pc_update();
        // $display("PC reg: %0d ", dut_env_pc);
    end
endtask

// task env_update_comb;
    // input [31:0] task_alu_out_update;
    // begin
        // env_alu_out_update(task_alu_out_update);
        // $display("ALU out: %0d ", dut_env_alu);
    // end
// endtask

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
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    read_test_instructions();
    env_reset();
    errors            = 0;
    warnings          = 0;
    alu_a_sel_fwd_cnt = 0;
    alu_b_sel_fwd_cnt = 0;
    bc_a_sel_fwd_cnt  = 0;
    bcs_b_sel_fwd_cnt = 0;
end

// Timestamp print
initial begin
    forever begin
        @(posedge clk);
        $display("\n\n\n --- Sim time : %0t ---\n", $time);
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
        if(!rst_done) begin @(posedge clk); env_update_seq(); #1; end
        tb_driver();
        dut_m_decode();
    end
    $display("Reset done, time: %0t \n", $time);
    
    // wait for DUT to actually go out of reset
    @(posedge clk); #1; 
    $display("Checking reset exit, time: %0t \n", $time);
    env_update_seq();
    tb_driver();
    dut_m_decode();
    #1; tb_checker();
    print_test_results();
    $display("\nTest  0: Wait for reset: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: No Forwarding No Dependency
    $display("\nTest  1: Hit specific case [No Forwarding No Dependency]: Start \n");
    run_test_pc_target  = run_test_pc_current + `NFND_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(run_test_pc_current < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_test_results();
        run_test_pc_current = run_test_pc_current + 1;
    end
    dependency_checker();
    $display("\nTest  1: Hit specific case [No Forwarding No Dependency]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 2: Forwarding with Dependency R-type
    $display("\nTest  2: Hit specific case [Forwarding with Dependency R-type]: Start \n");
    run_test_pc_target  = run_test_pc_current + `FDRT_TEST;
    expected_dependencies(`FD_TEST_EXP_ALU_A, 
                          `FD_TEST_EXP_ALU_B, 
                          `FD_TEST_EXP_BC_A, 
                          `FD_TEST_EXP_BCS_B);
    while(run_test_pc_current < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_test_results();
        run_test_pc_current = run_test_pc_current + 1;
    end
    dependency_checker();
    $display("\nTest  2: Hit specific case [Forwarding with Dependency R-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 3: Forwarding with Dependency I-type
    $display("\nTest  3: Hit specific case [Forwarding with Dependency I-type]: Start \n");
    run_test_pc_target  = run_test_pc_current + `FDIT_TEST;
    // expected_dependencies are the same as R-type
    while(run_test_pc_current < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_test_results();
        run_test_pc_current = run_test_pc_current + 1;
    end
    dependency_checker();
    $display("\nTest  3: Hit specific case [Forwarding with Dependency I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 4: Forwarding with Dependency I-type
    $display("\nTest  4: Hit specific case [Forwarding with Dependency Load]: Start \n");
    run_test_pc_target  = run_test_pc_current + `FDL_TEST;
    // expected_dependencies are the same as R-type and I-type
    while(run_test_pc_current < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_test_results();
        run_test_pc_current = run_test_pc_current + 1;
    end
    dependency_checker();
    $display("\nTest  4: Hit specific case [Forwarding with Dependency Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
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
    $finish();
end

endmodule
