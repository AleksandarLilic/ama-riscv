//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Control Testbench
// File:            ama_riscv_core_tb.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//
// Version history:
//      2021-09-11  AL  0.1.0 - Initial - IF stage
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
`define TEST_CASES_DEC           `RST_TEST + `R_TYPE_TESTS + `I_TYPE_TESTS + `LOAD_TESTS + `STORE_TESTS + `BRANCH_TESTS + `JALR_TEST + `JAL_TEST + `LUI_TEST + `AUIPC_TEST + `BRANCH_TESTS_NOPS_PAD
`define LABEL_TGT                `TEST_CASES_DEC - 1 // location to which to branch

`define NFND_TEST                5           // No Forwarding No Dependency
`define FDRT_TEST                12*2 + 3*2  // Forwarding with Dependency R-type
`define FDIT_TEST                12*2 + 3*2  // Forwarding with Dependency I-type
`define FDL_TEST                 12*2 + 3*2  // Forwarding with Dependency Load
`define NFX0_TEST                7*2         // No Forwarding with Dependency on x0
`define NFWE0_TEST               4*2         // No Forwarding with reg_we_ex = 0
`define TEST_CASES_FWD           `NFND_TEST + `FDRT_TEST + `FDIT_TEST + `FDL_TEST + `NFX0_TEST+ `NFWE0_TEST

`define TEST_CASES               `TEST_CASES_DEC + `TEST_CASES_FWD

// Expected dependencies in each of the dependency tests
`define FD_TEST_EXP_ALU_A      7  // for ALU A
`define FD_TEST_EXP_ALU_B      2  // for ALU B
`define FD_TEST_EXP_BC_A       2  // for BC A 
`define FD_TEST_EXP_BCS_B      4  // for BCS B

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

module ama_riscv_core_tb();

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O
reg           clk = 0             ;
reg           rst                 ;

//-----------------------------------------------------------------------------
// checkers
reg    [31:0] dut_env_inst_id     ;

//-----------------------------------------------------------------------------
// Testbench variables
integer       i                   ;              // used for all loops
integer       clocks_to_execute   ;
integer       run_test_pc_target  ;
integer       errors              ;
integer       warnings            ;

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// file read
integer       fd;
integer       status;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [  31:0] test_values_inst_hex_nop;
reg  [30*7:0] str;
reg  [30*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [30*7:0] test_values_inst_asm_nop  ;
reg  [30*7:0] dut_env_inst_id_asm       ;
reg  [30*7:0] dut_env_inst_ex_asm       ;
reg  [30*7:0] dut_env_inst_mem_asm      ;

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_core DUT_ama_riscv_core_i (
    .clk                (clk         ),
    .rst                (rst         )
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
    integer last_pc;
    reg     stalled;
    begin
        stalled = 0;//(last_pc == dut_env_pc);
        // $display("Instruction at PC# %2d %s ", dut_env_pc, stalled ? "stalled " : "executed"); 
        $write  ("ID  stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_id,  dut_env_inst_id_asm );
        // $write  ("EX  stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_ex,  dut_env_inst_ex_asm );
        // $write  ("MEM stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_mem, dut_env_inst_mem_asm);
        // last_pc = dut_env_pc;
    end
endtask

task tb_checker;
    begin
        // check that inst_id is equal to what is written with readmemh
        
        // additionally, reuse all code from control tb
    
    end // main task body */
endtask // tb_checker

task read_test_instructions;
    begin
        // Instructions HEX
        // From decoder test
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
        
        // From op fwd test, concat to same array
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/op_fwd_inst_hex.txt"}, "r");    
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end    
        while(!$feof(fd)) begin
            $fscanf (fd, "%h", test_values_inst_hex[i]);
            // $display("'h%h", test_values_inst_hex[i]);
            i = i + 1;
        end
        $fclose(fd);
        test_values_inst_hex_nop = 'h0000_0013;
        
        // Instructions ASM
        // From decoder test
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
        
        // From op fwd test, concat to same array
        // asm txt has empty newline at the end
        // decrement counter by one to overwrite it with actual instruction
        // to match hex txt
        i = i - 1;
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/op_fwd_inst_asm.txt"}, "r");    
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end    
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

//-----------------------------------------------------------------------------
// Environment update tasks
task env_reset;
    begin
        dut_env_inst_id = 'h0;
        // dut_env_inst_ex = 'h0;
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
    // $readmemh("../../software/assembly_tests/assembly_tests.hex", CPU.bios_mem.mem, 0, 4095);
    $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/decoder_inst_hex.txt"}, DUT_ama_riscv_core_i.ama_riscv_imem_i.mem, 0, 4095);
    read_test_instructions();
    env_reset();
    errors            = 0;
    warnings          = 0;
    // clear_forwarding_counters();
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

        // env_update_seq();
        // tb_driver();
        // dut_m_decode();
        // #1; env_update_comb('h0, 'b0);
    end
    $display("Reset done, time: %0t \n", $time);
    
    // wait for DUT to actually go out of reset
    @(posedge clk); #1; 
    $display("Checking reset exit, time: %0t \n", $time);
    // env_update_seq();
    // tb_driver();
    // dut_m_decode();
    // #1; tb_checker();
    // print_single_instruction_results();
    // env_update_comb('h0, 'b0);
    // clear_forwarding_counters();
    $display("\nTest  0: Wait for reset: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: R-type
    $display("\nTest  1: Hit specific case [R-type]: Start \n");
    run_test_pc_target  = 3; //dut_env_pc_mux_out + `R_TYPE_TESTS;
    // while(dut_env_pc_mux_out < run_test_pc_target) begin
    repeat(run_test_pc_target) begin
        @(posedge clk); #1;
        // env_update_seq();
        // tb_driver();
        // dut_m_decode();
        // #1; tb_checker();
        // print_single_instruction_results();
        // env_update_comb('h0, 'b0);
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
    $display("\nTest  9: Hit specific case [AUIPC]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 10: NOPs
    $display("\nTest 10: Execute NOPs: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `BRANCH_TESTS_NOPS_PAD - 1;  // without last beq
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    
    run_test_pc_target  = dut_env_pc_mux_out + 1;  // beq
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
            env_update_comb('h0, 'b0);  // don't branch
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
    end
    
    $display("\nTest 10: Execute NOPs: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 11: No Forwarding No Dependency
    $display("\nTest 11: Hit specific case [No Forwarding No Dependency]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `NFND_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; tb_checker();
        print_single_instruction_results();
        dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
    end
    dependency_checker();
    $display("\nTest 11: Hit specific case [No Forwarding No Dependency]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12a: Forwarding with Dependency R-type
    $display("\nTest 12a: Hit specific case [Forwarding with Dependency R-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `FDRT_TEST;
    expected_dependencies(`FD_TEST_EXP_ALU_A, 
                          `FD_TEST_EXP_ALU_B, 
                          `FD_TEST_EXP_BC_A, 
                          `FD_TEST_EXP_BCS_B);
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; tb_checker();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12a: Hit specific case [Forwarding with Dependency R-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12b: Forwarding with Dependency I-type
    $display("\nTest 12b: Hit specific case [Forwarding with Dependency I-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `FDIT_TEST;
    // expected_dependencies are the same as R-type
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; tb_checker();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12b: Hit specific case [Forwarding with Dependency I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12c: Forwarding with Dependency Load
    $display("\nTest 12c: Hit specific case [Forwarding with Dependency Load]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `FDL_TEST;
    // expected_dependencies are the same as R-type and I-type
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; tb_checker();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12c: Hit specific case [Forwarding with Dependency Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 13: No forwarding false dependency - writes to x0
    $display("\nTest 13: Hit specific case [No forwarding false dependency - writes to x0]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `NFX0_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; tb_checker();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 13: Hit specific case [No forwarding false dependency - writes to x0]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 14: No forwarding false dependency - reg_we_ex = 0
    $display("\nTest 14: Hit specific case [No forwarding false dependency - reg_we_ex = 0]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `NFWE0_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; tb_checker();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_env_pc_mux_out = dut_env_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 14: Hit specific case [No forwarding false dependency - reg_we_ex = 0]: Done \n");
    */
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    print_test_status();
    $finish();
    
end // test

endmodule
