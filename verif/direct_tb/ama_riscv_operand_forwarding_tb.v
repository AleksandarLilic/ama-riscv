//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Operand Forwarding Testbench
// File:            ama_riscv_operand_forwarding_tb.v
// Date created:    2021-08-12
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  No forwarding when there is no dependency - pass decoder values
//                      2.  Forwarding data when dependency occurs in the pipeline
//                      3.  Test that no forwarding occurs when:
//                          - Dependency exists but its x0   
//                          - Dependency exists but reg_we_ex = 0   
//
// Version history:
//      2021-08-13  AL  0.1.0 - Initial - Add no forwarding no dependency test
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define NFND_TEST                5  // No Forwarding No Dependency
`define TEST_CASES               `NFND_TEST

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
reg         reg_we_ex     ;
reg  [ 5:0] rs1_id        ;
reg  [ 5:0] rs2_id        ;
reg  [ 5:0] rd_ex         ;
reg         alu_a_sel     ;
reg         alu_b_sel     ;
// outputs
wire [ 1:0] alu_a_sel_fwd ;
wire [ 1:0] alu_b_sel_fwd ;

// DUT model Outputs
reg  [ 1:0] dut_m_alu_a_sel_fwd ;
reg  [ 1:0] dut_m_alu_b_sel_fwd ;

// DUT environment
reg  [31:0] dut_env_inst_id     ;
reg  [31:0] dut_env_inst_ex     ;
reg         dut_env_reg_we_id   ;
reg         dut_env_reg_we_ex   ;
reg  [ 5:0] dut_env_rs1_id      ;
reg  [ 5:0] dut_env_rs2_id      ;
reg  [ 5:0] dut_env_rd_id       ;
reg  [ 5:0] dut_env_rd_ex       ;
reg         dut_env_alu_a_sel   ;
reg         dut_env_alu_b_sel   ;

// Reset hold for
reg  [ 3:0] rst_pulses = 4'd3;

// Testbench variables
integer     i                   ;              // used for all loops
integer     run_test_pc_target  ;
integer     run_test_pc_current ;
integer     errors              ;
integer     warnings            ;

// file read
integer fd;
integer status;
reg  [24*7:0] str;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [  31:0] test_values_inst_hex_nop;
reg  [24*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [24*7:0] test_values_inst_asm_nop;
reg  [24*7:0] dut_env_inst_id_asm;
reg  [24*7:0] dut_env_inst_ex_asm;

// events
event ev_rst    [1:0];
integer rst_done = 0;


//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_operand_forwarding DUT_ama_riscv_operand_forwarding_i (
    // inputs    
    .reg_we_ex      (reg_we_ex     ),
    .rs1_id         (rs1_id        ),
    .rs2_id         (rs2_id        ),
    .rd_ex          (rd_ex         ),
    .alu_a_sel      (alu_a_sel     ),
    .alu_b_sel      (alu_b_sel     ),
    // outputs   
    .alu_a_sel_fwd  (alu_a_sel_fwd ),
    .alu_b_sel_fwd  (alu_b_sel_fwd )   
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task print_test_results;
    begin
        $display("Instruction at PC# %2d done. ", run_test_pc_current); 
        $write  ("ID stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_id, dut_env_inst_id_asm);
        $write  ("EX stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
    end
endtask

task tb_driver;
    input [ 0:0] task_alu_a_sel;
    input [ 0:0] task_alu_b_sel;
    input [ 5:0] task_rs1_id   ;
    input [ 5:0] task_rs2_id   ;
    input [ 5:0] task_rd_ex    ;
    input [ 0:0] task_reg_we_ex;
    
    begin
        reg_we_ex = task_reg_we_ex ;
        rs1_id    = task_rs1_id    ;
        rs2_id    = task_rs2_id    ;
        rd_ex     = task_rd_ex     ;
        alu_a_sel = task_alu_a_sel ;
        alu_b_sel = task_alu_b_sel ;
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
    end // main task body
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
        if ((dut_env_rs1_id != `RF_X0_ZERO) && (dut_env_rs1_id == dut_env_rd_ex) && (dut_env_reg_we_ex))
            dut_m_alu_a_sel_fwd = `ALU_A_SEL_FWD_ALU;  // forward previous ALU result
        else
            dut_m_alu_a_sel_fwd = {1'b0, dut_env_alu_a_sel};  // don't forward
        
        // Operand B
        if ((dut_env_rs2_id != `RF_X0_ZERO) && (dut_env_rs2_id == dut_env_rd_ex) && (dut_env_reg_we_ex))
            dut_m_alu_b_sel_fwd = `ALU_B_SEL_FWD_ALU;  // forward previous ALU result
        else
            dut_m_alu_b_sel_fwd = {1'b0, dut_env_alu_b_sel};  // don't forward
        
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

task env_reg_we_id_update;
    begin
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
        $write("inst_ex - FF reg:    'h%8h    %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        env_reg_addr_ex_update();
        $display("dut_env_rd_ex: %0d", dut_env_rd_ex);
        env_reg_we_ex_update();
        $display("dut_env_reg_we_id: 'b%0b", dut_env_reg_we_id);
        
        //----- ID stage updates
        env_inst_id_update();
        $write("inst_id - IMEM read: 'h%8h    %0s", dut_env_inst_id, dut_env_inst_id_asm);
        env_reg_addr_id_update();
        $display("dut_env_rs1_id: %0d, dut_env_rs2_id: %0d, dut_env_rd_id: %0d", dut_env_rs1_id, dut_env_rs2_id, dut_env_rd_id);
        env_reg_we_id_update();
        $display("dut_env_reg_we_ex: 'b%0b", dut_env_reg_we_ex);
        env_alu_op_sel_id_update();
        $display("dut_env_alu_a_sel: 'b%0b, dut_env_alu_b_sel: 'b%0b", dut_env_alu_a_sel, dut_env_alu_b_sel);
        
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
        if(!rst_done) begin @(posedge clk); env_update_seq(); #1; end

        tb_driver(dut_env_alu_a_sel, dut_env_alu_b_sel, dut_env_rs1_id, dut_env_rs2_id, dut_env_rd_ex, dut_env_reg_we_ex);
        dut_m_decode();
    end
    $display("Reset done, time: %0t \n", $time);
    
    // wait for DUT to actually go out of reset
    @(posedge clk); #1; 
    $display("Checking reset exit, time: %0t \n", $time);
    env_update_seq();
    tb_driver(dut_env_alu_a_sel, dut_env_alu_b_sel, dut_env_rs1_id, dut_env_rs2_id, dut_env_rd_ex, dut_env_reg_we_ex);
    dut_m_decode();
    #1; tb_checker();
    print_test_results();
    $display("\nTest  0: Wait for reset: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: No Forwarding No Dependency
    $display("\nTest  1: Hit specific case [No Forwarding No Dependency]: Start \n");
    run_test_pc_target  = run_test_pc_current + `NFND_TEST;
    while(run_test_pc_current < run_test_pc_target) begin
        @(posedge clk); #1;
       env_update_seq();
        tb_driver(dut_env_alu_a_sel, dut_env_alu_b_sel, dut_env_rs1_id, dut_env_rs2_id, dut_env_rd_ex, dut_env_reg_we_ex);
        dut_m_decode();
        #1; tb_checker();
        print_test_results();
        run_test_pc_current = run_test_pc_current + 1;
    end
    $display("\nTest  1: Hit specific case [No Forwarding No Dependency]: Done \n");
     /* 
    //-----------------------------------------------------------------------------
    // Test 2: I-type
    $display("\nTest  2: Hit specific case [I-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `I_TYPE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
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
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
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
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
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
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(`LABEL_TGT, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
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
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
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
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
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
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
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
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
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
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
        env_update_comb('hE, 'b0);  // ALU is actually used for write to RF, but data is not relevant to this TB, only control signals in checker
    end
    $display("\nTest  9: Hit specific case [AUIPC]: Done \n");
     */
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
