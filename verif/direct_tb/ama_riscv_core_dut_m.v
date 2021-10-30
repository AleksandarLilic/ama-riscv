//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Core Software Model 
// File:            ama_riscv_core_dut_m.v
// Date created:    2021-10-18
// Author:          Aleksandar Lilic
// Description:     Software model of AMA-RISCV Core
//                  Include in TB as needed
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Version history:
//      2021-10-25  AL  0.1.0 - Initial
//      2021-10-29  AL  0.2.0 - WIP - Add disassembler - R-type
//      2021-10-30  AL        - WIP - DASM - add I-type
//
//-----------------------------------------------------------------------------

`include "../../src/ama_riscv_defines.v"

// Reg File
`define RF_WID              32
`define RF_NUM              32

// default size if not specified before model include
`ifndef MEM_SIZE
`define MEM_SIZE            16384
`endif

//-----------------------------------------------------------------------------
// Macro Functions
`define warning_m(string)                                               \
    $write({"*WARNING @ %0t.", string, "Input inst_id: 'h%8h  %0s"},    \
            $time, dut_m_inst_id, dut_m_inst_id_asm               );    \
    warnings = warnings + 1;                                            \

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT Model I/O
reg          dut_m_rst;

//-----------------------------------------------------------------------------
// Model

// Memories
reg  [31:0] dut_m_imem  [`MEM_SIZE-1:0];
reg  [31:0] dut_m_dmem  [`MEM_SIZE-1:0];

// Datapath
// IF stage
reg  [31:0] dut_m_pc                ;
reg  [31:0] dut_m_pc_mux_out        ;

// ID stage
// in
reg  [31:0] dut_m_inst_id           ;
reg  [ 4:0] dut_m_rs1_addr_id       ;
reg  [ 4:0] dut_m_rs2_addr_id       ;
reg  [ 4:0] dut_m_rd_addr_id        ;
reg  [24:0] dut_m_imm_gen_in        ;
reg  [31:0] dut_m_tohost            ;
reg  [31:0] dut_m_csr_data_id       ;
// out
reg  [31:0] dut_m_rs1_data_id       ;
reg  [31:0] dut_m_rs2_data_id       ;
reg  [31:0] dut_m_imm_gen_out_id    ;

// EX stage
// in
reg  [31:0] dut_m_pc_ex             ;
reg  [31:0] dut_m_inst_ex           ;
reg  [ 2:0] dut_m_funct3_ex         ;
reg  [ 4:0] dut_m_rs1_addr_ex       ;
reg  [31:0] dut_m_rs1_data_ex       ;
reg  [31:0] dut_m_rs2_data_ex       ;
reg  [ 4:0] dut_m_rd_addr_ex        ;
reg  [31:0] dut_m_imm_gen_out_ex    ;
reg  [31:0] dut_m_csr_data_ex       ;
// out
reg  [31:0] dut_m_alu_out           ;
reg  [ 1:0] dut_m_load_sm_offset_ex ;
reg  [13:0] dut_m_dmem_addr         ;
reg  [31:0] dut_m_dmem_write_data   ;
// to control
reg         dut_m_bc_a_eq_b         ;
reg         dut_m_bc_a_lt_b         ;
reg  [ 1:0] dut_m_store_mask_offset ;

// MEM stage
// in
reg  [31:0] dut_m_pc_mem            ;
reg  [31:0] dut_m_alu_out_mem       ;
reg  [31:0] dut_m_alu_in_a_mem      ;
reg  [31:0] dut_m_dmem_read_data_mem;
reg  [ 1:0] dut_m_load_sm_offset_mem;
reg  [31:0] dut_m_inst_mem          ;
reg  [ 4:0] dut_m_rs1_addr_mem      ;
reg  [ 4:0] dut_m_rd_addr_mem       ;
reg  [31:0] dut_m_csr_data_mem      ;
// out
reg  [31:0] dut_m_load_sm_data_out  ;
reg  [31:0] dut_m_writeback         ;


// Control Outputs - Pipeline Registers
reg         dut_m_stall_if          ;
reg         dut_m_stall_if_q1       ;
reg         dut_m_clear_if          ;
reg         dut_m_clear_id          ;
reg         dut_m_clear_ex          ;
reg         dut_m_clear_mem         ;


// Control Outputs
// for IF stage
reg  [ 1:0] dut_m_pc_sel_if         ;
reg         dut_m_pc_we_if          ;
// for ID stage 
reg         dut_m_store_inst_id     ;
reg         dut_m_load_inst_id      ;
reg         dut_m_branch_inst_id    ;
reg         dut_m_jump_inst_id      ;
reg         dut_m_csr_en_id         ;
reg         dut_m_csr_we_id         ;
reg         dut_m_csr_ui_id         ;
reg  [11:0] dut_m_csr_addr          ;
reg  [ 3:0] dut_m_alu_op_sel_id     ;
reg  [ 2:0] dut_m_imm_gen_sel_id    ;
reg         dut_m_reg_we_id         ;
reg  [ 1:0] dut_m_alu_a_sel_fwd_id  ;
reg  [ 1:0] dut_m_alu_b_sel_fwd_id  ;
// for EX stage 
reg         dut_m_bc_uns_id         ;
reg         dut_m_dmem_en_id        ;
reg         dut_m_bc_a_sel_fwd_id   ;
reg         dut_m_bcs_b_sel_fwd_id  ;
reg         dut_m_rf_a_sel_fwd_id   ;
reg         dut_m_rf_b_sel_fwd_id   ;
reg  [ 3:0] dut_m_dmem_we_ex        ;
// for MEM stage    
reg         dut_m_load_sm_en_id     ;
reg  [ 1:0] dut_m_wb_sel_id         ;

// Control Outputs in datapath
// in EX stage
reg         dut_m_reg_we_ex         ;
reg         dut_m_csr_en_ex         ;
reg         dut_m_csr_we_ex         ;
reg         dut_m_csr_ui_ex         ;
reg         dut_m_bc_uns_ex         ;
reg         dut_m_bc_a_sel_fwd_ex   ;
reg         dut_m_bcs_b_sel_fwd_ex  ;
reg  [ 1:0] dut_m_alu_a_sel_fwd_ex  ;
reg  [ 1:0] dut_m_alu_b_sel_fwd_ex  ;
reg  [ 3:0] dut_m_alu_op_sel_ex     ;
reg         dut_m_dmem_en_ex        ;
reg         dut_m_load_sm_en_ex     ;
reg  [ 1:0] dut_m_wb_sel_ex         ;
// in MEM stage
reg         dut_m_reg_we_mem        ;
reg         dut_m_csr_en_mem        ;
reg         dut_m_csr_we_mem        ;
reg         dut_m_csr_ui_mem        ;
reg         dut_m_load_sm_en_mem    ;
reg  [ 1:0] dut_m_wb_sel_mem        ;



// Model internal signals
reg  [31:0] dut_m_pc_mux_out_div4       ;
reg  [31:0] dut_m_inst_id_read          ;
// reg[30*7:0] dut_m_inst_id_read_asm      ;
reg  [31:0] dut_m_imm_gen_out_id_prev   ;
reg  [31:0] dut_m_csr_din_imm           ;
reg         dut_m_alu_a_sel_id          ;
reg         dut_m_alu_b_sel_id          ;
reg         dut_m_branch_taken          ;
reg         dut_m_jump_taken            ;
reg         dut_m_branch_inst_ex        ;
reg         dut_m_jump_inst_ex          ;
reg         dut_m_store_inst_ex         ;
reg         dut_m_load_inst_ex          ;
// branch compare inputs
reg  [31:0] dut_m_bc_in_a               ;
reg  [31:0] dut_m_bc_in_b               ;
// alu inputs
reg  [31:0] dut_m_alu_in_a              ;
reg  [31:0] dut_m_alu_in_b              ;
reg  [ 4:0] dut_m_alu_shamt             ;
// load shift and mask
reg  [ 2:0] dut_m_load_sm_width         ;
reg  [31:0] dut_m_load_sm_data_out_prev ;

wire [31:0] dut_m_rd_data = dut_m_writeback ;

// Reg File
reg  [`RF_WID-1:0] dut_m_rf32 [`RF_NUM-1:0];
// RF named
// name: register_abi-name                   // Description
wire [31:0] dut_m_x0_zero = dut_m_rf32[0];   // hard-wired zero
wire [31:0] dut_m_x1_ra   = dut_m_rf32[1];   // return address
wire [31:0] dut_m_x2_sp   = dut_m_rf32[2];   // stack pointer 
wire [31:0] dut_m_x3_gp   = dut_m_rf32[3];   // global pointer
wire [31:0] dut_m_x4_tp   = dut_m_rf32[4];   // thread pointer
wire [31:0] dut_m_x5_t0   = dut_m_rf32[5];   // temporary/alternate link register
wire [31:0] dut_m_x6_t1   = dut_m_rf32[6];   // temporary
wire [31:0] dut_m_x7_t2   = dut_m_rf32[7];   // temporary
wire [31:0] dut_m_x8_s0   = dut_m_rf32[8];   // saved register/frame pointer
wire [31:0] dut_m_x9_s1   = dut_m_rf32[9];   // saved register
wire [31:0] dut_m_x10_a0  = dut_m_rf32[10];  // function argument/return value
wire [31:0] dut_m_x11_a1  = dut_m_rf32[11];  // function argument/return value
wire [31:0] dut_m_x12_a2  = dut_m_rf32[12];  // function argument
wire [31:0] dut_m_x13_a3  = dut_m_rf32[13];  // function argument
wire [31:0] dut_m_x14_a4  = dut_m_rf32[14];  // function argument
wire [31:0] dut_m_x15_a5  = dut_m_rf32[15];  // function argument
wire [31:0] dut_m_x16_a6  = dut_m_rf32[16];  // function argument
wire [31:0] dut_m_x17_a7  = dut_m_rf32[17];  // function argument
wire [31:0] dut_m_x18_s2  = dut_m_rf32[18];  // saved register
wire [31:0] dut_m_x19_s3  = dut_m_rf32[19];  // saved register
wire [31:0] dut_m_x20_s4  = dut_m_rf32[20];  // saved register
wire [31:0] dut_m_x21_s5  = dut_m_rf32[21];  // saved register
wire [31:0] dut_m_x22_s6  = dut_m_rf32[22];  // saved register
wire [31:0] dut_m_x23_s7  = dut_m_rf32[23];  // saved register
wire [31:0] dut_m_x24_s8  = dut_m_rf32[24];  // saved register
wire [31:0] dut_m_x25_s9  = dut_m_rf32[25];  // saved register
wire [31:0] dut_m_x26_s10 = dut_m_rf32[26];  // saved register
wire [31:0] dut_m_x27_s11 = dut_m_rf32[27];  // saved register
wire [31:0] dut_m_x28_t3  = dut_m_rf32[28];  // temporary
wire [31:0] dut_m_x29_t4  = dut_m_rf32[29];  // temporary
wire [31:0] dut_m_x30_t5  = dut_m_rf32[30];  // temporary
wire [31:0] dut_m_x31_t6  = dut_m_rf32[31];  // temporary

//-----------------------------------------------------------------------------
// Testbench variables
integer       dut_m_i               ;              // used for all loops
// performance counters
integer       perf_cnt_cycle        ;
integer       perf_cnt_instr        ;
integer       perf_cnt_empty_cycles ;
integer       perf_cnt_all_nops     ;
integer       perf_cnt_hw_nops      ;
integer       perf_cnt_compiler_nops;

integer       warnings              ;

/* TODO: Make these counters SW only

//-----------------------------------------------------------------------------
// Cycle counter
reg   [31:0] mmio_cycle_cnt         ;
always @ (posedge clk) begin
    if (dut_m_rst)
        mmio_cycle_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        mmio_cycle_cnt <= 32'd0;
    else
        mmio_cycle_cnt <= mmio_cycle_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Instruction counter
reg   [31:0] mmio_instr_cnt         ;
always @ (posedge clk) begin
    if (dut_m_rst)
        mmio_instr_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        mmio_instr_cnt <= 32'd0;
    else if (!inst_wb_nop_or_clear)        // prevent counting nop and pipe clear
        mmio_instr_cnt <= mmio_instr_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Count inserted Clears and NOPs
reg   [31:0] hw_inserted_nop_or_clear_cnt         ;
always @ (posedge clk) begin
    if (dut_m_rst)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (`DUT.stall_if_q1 || `DUT.clear_mem)    // clear_mem is enough in this implementation, predictor may change this
        hw_inserted_nop_or_clear_cnt <= hw_inserted_nop_or_clear_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Count all Clears and NOPs
reg   [31:0] hw_all_nop_or_clear_cnt         ;
always @ (posedge clk) begin
    if (dut_m_rst)
        hw_all_nop_or_clear_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        hw_all_nop_or_clear_cnt <= 32'd0;
    else if (inst_wb_nop_or_clear)
        hw_all_nop_or_clear_cnt <= hw_all_nop_or_clear_cnt + 32'd1;
end
*/

//-----------------------------------------------------------------------------
// Disassembler functions

// TODO: disassembler for wave and console print
reg  [30*7:0] dut_m_inst_id_asm  = 'h0;
reg  [30*7:0] dut_m_inst_ex_asm  = 'h0;
reg  [30*7:0] dut_m_inst_mem_asm = 'h0;

reg  [ 5*8:0] dasm_r_type_list [0:15] = {"add", "sll", "slt", "sltu", "xor", "srl", "or", "and", 
                                         "sub", "",    "",    "",     "",    "sra", "",   ""    };

reg  [ 5*8:0] dasm_i_type_list [0:15] = {"addi", "slli", "slti", "sltiu", "xori", "srli", "ori", "andi", 
                                         "",     "",     "",     "",      "",     "srai", "",    ""     };

function [ 4:0] dasm_rs1 (input [31:0] inst); begin dasm_rs1 = ((inst & 32'h000f_8000)>>15); end endfunction
function [ 4:0] dasm_rs2 (input [31:0] inst); begin dasm_rs2 = ((inst & 32'h01f0_8000)>>20); end endfunction
function [ 4:0] dasm_rd  (input [31:0] inst); begin dasm_rd  = ((inst & 32'h0000_0f80)>>7);  end endfunction
function [ 6:0] dasm_opc (input [31:0] inst); begin dasm_opc =  (inst & 32'h0000_007f);      end endfunction
function [ 2:0] dasm_fn3 (input [31:0] inst); begin dasm_fn3 = ((inst & 32'h0000_7000)>>12); end endfunction
function [ 6:0] dasm_fn7 (input [31:0] inst); begin dasm_fn7 = ((inst & 32'hfe00_0000)>>25); end endfunction
function dasm_fn7_b5 (input [31:0] inst); begin dasm_fn7_b5 = ((inst & 32'h4000_0000)>>30); end endfunction

function [31:0] dasm_imm_i (input [31:0] inst); 
    begin dasm_imm_i = $signed(inst) >>> 20; end 
endfunction

function [3:0] dasm_r_type_idx (input [31:0] inst); 
    begin dasm_r_type_idx = {dasm_fn7_b5(inst), dasm_fn3(inst)}; end 
endfunction

function [3:0] dasm_i_type_idx (input [31:0] inst); 
    begin dasm_i_type_idx = ((dasm_fn3(inst)) == 3'b101) ? {dasm_fn7_b5(inst), dasm_fn3(inst)} : 
                                                           {1'b0,              dasm_fn3(inst)}; end 
endfunction

/*    
`define dasm_get_imm_s(inst, imm_s)                         \
    imm_s = (($signed(inst) >>> 20) & 32'hffff_ffe0) |      \
            ((inst >> 7) & 32'h0000_001f);                  \
*/

//-----------------------------------------------------------------------------
// DUT model tasks
task dut_m_decode();
    begin
    dut_m_funct3_ex = dut_m_inst_ex[14:12];
    dut_m_csr_addr  = dut_m_inst_id[31:20];
    
        if (!dut_m_rst) begin
            case (dut_m_inst_id[6:0])
                `OPC7_R_TYPE :  begin dut_m_decode_r_type();      end
                `OPC7_I_TYPE :  begin dut_m_decode_i_type();      end
                `OPC7_LOAD   :  begin dut_m_decode_load();        end
                `OPC7_STORE  :  begin dut_m_decode_store();       end
                `OPC7_BRANCH :  begin dut_m_decode_branch();      end
                `OPC7_JALR   :  begin dut_m_decode_jalr();        end
                `OPC7_JAL    :  begin dut_m_decode_jal();         end
                `OPC7_LUI    :  begin dut_m_decode_lui();         end
                `OPC7_AUIPC  :  begin dut_m_decode_auipc();       end
                `OPC7_SYSTEM :  begin dut_m_decode_system();      end
                default      :  begin dut_m_decode_unsupported(); end
            endcase
        end
        else /*if (dut_m_rst)*/ begin dut_m_decode_reset();       end
        
        // check if instruction will stall
        dut_m_stall_if = (dut_m_branch_inst_id || dut_m_jump_inst_id);
        
        // if it stalls, we = 0
        dut_m_pc_we_if = dut_m_pc_we_if && (!dut_m_stall_if);
         
        // Operand Forwarding
        dut_m_decode_op_fwd_alu();
        dut_m_decode_op_fwd_bcs();
        dut_m_decode_op_fwd_rf();
         
        // Store Mask
        dut_m_decode_store_mask();
         
        // Branch resolution
        dut_m_decode_branch_resolution();

    end                  
endtask // dut_m_decode

task dut_m_decode_r_type();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = ({dut_m_inst_id[30], dut_m_inst_id[14:12]});
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_RS2;
        dut_m_imm_gen_sel_id = `IG_DISABLED;
        // dut_m_bc_uns_id      = 1'b0;
        dut_m_dmem_en_id     = 1'b0;
        dut_m_load_sm_en_id  = 1'b0;
        dut_m_wb_sel_id      = `WB_SEL_ALU;
        dut_m_reg_we_id      = 1'b1;
        $sformat(dut_m_inst_id_asm, "%0s x%0d, x%0d, x%0d", dasm_r_type_list[dasm_r_type_idx(dut_m_inst_id)], 
            dasm_rd(dut_m_inst_id), dasm_rs1(dut_m_inst_id), dasm_rs2(dut_m_inst_id));
    end
endtask

task dut_m_decode_i_type();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = (dut_m_inst_id[13:12] == 2'b01)  ? 
                               {dut_m_inst_id[30], dut_m_inst_id[14:12]} : {1'b0, dut_m_inst_id[14:12]};
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_I_TYPE;
        // dut_m_bc_uns_id      = 1'b0;
        dut_m_dmem_en_id     = 1'b0;
        dut_m_load_sm_en_id  = 1'b0;
        dut_m_wb_sel_id      = `WB_SEL_ALU;
        dut_m_reg_we_id      = 1'b1;
        $sformat(dut_m_inst_id_asm, "%0s x%0d, x%0d, %0d", dasm_i_type_list[dasm_i_type_idx(dut_m_inst_id)], 
            dasm_rd(dut_m_inst_id), dasm_rs1(dut_m_inst_id), $signed(dasm_imm_i(dut_m_inst_id)));
    end
endtask

task dut_m_decode_load();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b1;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_I_TYPE;
        // dut_m_bc_uns_id      = 1'b0;
        dut_m_dmem_en_id     = 1'b1;
        dut_m_load_sm_en_id  = 1'b1;
        dut_m_wb_sel_id      = `WB_SEL_DMEM;
        dut_m_reg_we_id      = 1'b1;
    end
endtask

task dut_m_decode_store();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b1;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_S_TYPE;
        // dut_m_bc_uns_id      = 1'b0;
        dut_m_dmem_en_id     = 1'b1;
        dut_m_load_sm_en_id  = 1'b0;
        // dut_m_wb_sel_id      = `WB_SEL_DMEM;
        dut_m_reg_we_id      = 1'b0;
    end
endtask

task dut_m_decode_branch();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b0;
        dut_m_branch_inst_id = 1'b1;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_B_TYPE;
        dut_m_bc_uns_id      = dut_m_inst_id[13];     // funct3[1]
        dut_m_dmem_en_id     = 1'b0;
        dut_m_load_sm_en_id  = 1'b0;
        // dut_m_wb_sel_id      = `WB_SEL_DMEM;
        dut_m_reg_we_id      = 1'b0;
    end
endtask

task dut_m_decode_jalr();
    begin
        dut_m_pc_sel_if      = `PC_SEL_ALU;
        dut_m_pc_we_if       = 1'b0;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b1;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_I_TYPE;
        // dut_m_bc_uns_id      = *;
        dut_m_dmem_en_id     = 1'b0;
        // dut_m_load_sm_en_id  = *;
        dut_m_wb_sel_id      = `WB_SEL_INC4;
        dut_m_reg_we_id      = 1'b1;
    end
endtask

task dut_m_decode_jal();
    begin
        dut_m_pc_sel_if      = `PC_SEL_ALU;
        dut_m_pc_we_if       = 1'b0;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b1;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_J_TYPE;
        // dut_m_bc_uns_id      = *;
        dut_m_dmem_en_id     = 1'b0;
        // dut_m_load_sm_en_id  = *;
        dut_m_wb_sel_id      = `WB_SEL_INC4;
        dut_m_reg_we_id      = 1'b1;
    end
endtask

task dut_m_decode_lui();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b1111;    // pass b
        // dut_m_alu_a_sel_id   = *;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_U_TYPE;
        // dut_m_bc_uns_id      = *;
        dut_m_dmem_en_id     = 1'b0;
        // dut_m_load_sm_en_id  = *;
        dut_m_wb_sel_id      = `WB_SEL_ALU;
        dut_m_reg_we_id      = 1'b1;
    end
endtask

task dut_m_decode_auipc();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = 1'b0;
        dut_m_csr_we_id      = 1'b0;
        dut_m_csr_ui_id      = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;    // add
        dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        dut_m_imm_gen_sel_id = `IG_U_TYPE;
        // dut_m_bc_uns_id      = *;
        dut_m_dmem_en_id     = 1'b0;
        // dut_m_load_sm_en_id  = *;
        dut_m_wb_sel_id      = `WB_SEL_ALU;
        dut_m_reg_we_id      = 1'b1;
    end
endtask

task dut_m_decode_system();
    begin
        dut_m_pc_sel_if      = `PC_SEL_INC4;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_csr_en_id      = (dut_m_csr_addr == `CSR_TOHOST) && (dut_m_rs1_addr_id != `RF_X0_ZERO);
        dut_m_csr_we_id      = 1'b1;
        dut_m_csr_ui_id      = dut_m_inst_id[13];     // funct3[2]
        // dut_m_alu_op_sel_id  = 4'b0000;    
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        // dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
        // dut_m_imm_gen_sel_id = `IG_U_TYPE;
        // dut_m_bc_uns_id      = *;
        dut_m_dmem_en_id     = 1'b0;
        // dut_m_load_sm_en_id  = *;
        dut_m_wb_sel_id      = `WB_SEL_CSR;
        dut_m_reg_we_id      = (dut_m_rs1_addr_id != `RF_X0_ZERO);
    end
endtask

task dut_m_decode_unsupported();
    begin
        $display("*WARNING @ %0t. Decoder model 'default' case. Input inst_id: 'h%8h", // %0s",
        $time, dut_m_inst_id, /* dut_m_inst_id_asm */);
        warnings = warnings + 1;
    end
endtask

task dut_m_decode_op_fwd_alu();
    begin
        // Operand A
        if ( (dut_m_rs1_addr_id != `RF_X0_ZERO       ) && 
             (dut_m_rs1_addr_id == dut_m_rd_addr_ex  ) && 
             (dut_m_reg_we_ex                        ) && 
             (!dut_m_alu_a_sel_id                    )    ) begin
            dut_m_alu_a_sel_fwd_id = `ALU_A_SEL_FWD_ALU;            // forward previous ALU result
        end
        else begin
            dut_m_alu_a_sel_fwd_id = {1'b0, dut_m_alu_a_sel_id};    // don't forward
        end
        
        // Operand B
        if ( (dut_m_rs2_addr_id != `RF_X0_ZERO       ) && 
             (dut_m_rs2_addr_id == dut_m_rd_addr_ex  ) && 
             (dut_m_reg_we_ex                        ) && 
             (!dut_m_alu_b_sel_id                    )    ) begin
            dut_m_alu_b_sel_fwd_id = `ALU_B_SEL_FWD_ALU;            // forward previous ALU result
        end
        else begin
            dut_m_alu_b_sel_fwd_id = {1'b0, dut_m_alu_b_sel_id};    // don't forward
        end
    end
endtask

task dut_m_decode_op_fwd_bcs();
    begin
        // BC A
        dut_m_bc_a_sel_fwd_id  = ( (dut_m_rs1_addr_id != `RF_X0_ZERO                ) && 
                                   (dut_m_rs1_addr_id == dut_m_rd_addr_ex           ) && 
                                   (dut_m_reg_we_ex                                 ) && 
                                   (dut_m_branch_inst_id                            )    );
        
        // BC B or DMEM din for store
        dut_m_bcs_b_sel_fwd_id = ( (dut_m_rs2_addr_id != `RF_X0_ZERO                ) && 
                                   (dut_m_rs2_addr_id == dut_m_rd_addr_ex           ) && 
                                   (dut_m_reg_we_ex                                 ) && 
                                   (dut_m_store_inst_id || dut_m_branch_inst_id     )    );
        
    end
endtask

task dut_m_decode_op_fwd_rf();
    begin
        dut_m_rf_a_sel_fwd_id  = ( (dut_m_rs1_addr_id != `RF_X0_ZERO                ) && 
                                   (dut_m_rs1_addr_id == dut_m_rd_addr_mem          ) && 
                                   (dut_m_reg_we_mem                                ) && 
                                   ((!dut_m_alu_a_sel_id) || (dut_m_branch_inst_id) )    );
        
        // RF B
        dut_m_rf_b_sel_fwd_id  = ( (dut_m_rs2_addr_id != `RF_X0_ZERO                ) && 
                                   (dut_m_rs2_addr_id == dut_m_rd_addr_mem          ) && 
                                   (dut_m_reg_we_mem                                ) && 
                                   ( (!dut_m_alu_b_sel_id  ) || 
                                     (dut_m_branch_inst_id ) || 
                                     (dut_m_store_inst_id  )                        )     );
        
    end
endtask

task dut_m_decode_store_mask();
    reg [1:0] store_mask_width;

    begin
        dut_m_store_mask_offset = dut_m_alu_out[1:0];
        store_mask_width        = dut_m_funct3_ex[1:0];

        if(dut_m_store_inst_ex) begin               // store mask enable
            case(store_mask_width)
                5'd0: begin  // byte
                    case (dut_m_store_mask_offset)  // (offset != 0) valid for byte and half only
                        2'd0:    begin dut_m_dmem_we_ex = 4'b0001; end 
                        2'd1:    begin dut_m_dmem_we_ex = 4'b0010; end
                        2'd2:    begin dut_m_dmem_we_ex = 4'b0100; end
                        2'd3:    begin dut_m_dmem_we_ex = 4'b1000; end
                        default: begin `warning_m(`"Store Mask offset default case - Byte`") end
                    endcase
                end

                5'd1: begin   // half
                    case (dut_m_store_mask_offset)
                        2'd0:    begin dut_m_dmem_we_ex = 4'b0011; end
                        2'd1:    begin dut_m_dmem_we_ex = 4'b0110; end
                        2'd2:    begin dut_m_dmem_we_ex = 4'b1100; end
                        2'd3:    begin `warning_m(`"Unaligned Access - Half`")
                                       dut_m_dmem_we_ex = 4'b0000; end
                        default: begin `warning_m(`"Store Mask offset default case - Half`")  end
                    endcase
                end

                5'd2: begin   // word
                    case (dut_m_store_mask_offset)
                        2'd0:    begin dut_m_dmem_we_ex = 4'b1111; end
                        2'd1,
                        2'd2,
                        2'd3:    begin `warning_m(`"Unaligned Access - Word`") 
                                       dut_m_dmem_we_ex = 4'b0000; end
                        default: begin `warning_m(`"Store Mask offset default case - Word`")  end
                    endcase
                end

                default: begin `warning_m(`"Store Mask width default case`") 
                               dut_m_dmem_we_ex = 4'b0000;   end
            endcase // store_mask_width
        end
        else /*(!dut_m_store_inst_ex)*/ begin
            dut_m_dmem_we_ex = 4'b0000;
        end 
    end

endtask

task dut_m_decode_branch_resolution();
    reg [1:0] branch_type;

    begin
        branch_type = {dut_m_inst_ex[14], dut_m_inst_ex[12]};
        case (branch_type)
            `BR_SEL_BEQ: begin dut_m_branch_taken = dut_m_bc_a_eq_b;                     end
            `BR_SEL_BNE: begin dut_m_branch_taken = !dut_m_bc_a_eq_b;                    end
            `BR_SEL_BLT: begin dut_m_branch_taken = dut_m_bc_a_lt_b;                     end
            `BR_SEL_BGE: begin dut_m_branch_taken = dut_m_bc_a_eq_b || !dut_m_bc_a_lt_b; end
            default:     begin `warning_m(`"Branch Resolution default case`")            end
        endcase

        // Override if dut_m_rst == 1
        if (dut_m_rst) dut_m_branch_taken = 1'b0;

        // if not branch instruction, it cannot be taken
        dut_m_branch_taken = dut_m_branch_taken && dut_m_branch_inst_ex;
        
        // flow change instructions use ALU out as destination address
        if(dut_m_branch_taken || dut_m_jump_inst_ex) dut_m_pc_sel_if = `PC_SEL_ALU;
                
    end
endtask

task dut_m_decode_reset();
    begin
        dut_m_pc_sel_if      = 2'b11;
        dut_m_pc_we_if       = 1'b1;
        dut_m_branch_inst_id = 1'b0;
        dut_m_jump_inst_id   = 1'b0;
        dut_m_store_inst_id  = 1'b0;
        dut_m_load_inst_id   = 1'b0;
        dut_m_alu_op_sel_id  = 4'b0000;
        dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel_id   = `ALU_B_SEL_RS2;
        dut_m_imm_gen_sel_id = `IG_DISABLED;
        dut_m_bc_uns_id      = 1'b0;
        dut_m_dmem_en_id     = 1'b0;
        dut_m_load_sm_en_id  = 1'b0;
        dut_m_wb_sel_id      = `WB_SEL_DMEM;
        dut_m_reg_we_id      = 1'b0;
    end
endtask

/*
task dut_m_decode_temp();
    begin
        
    end
endtask
*/

task dut_m_pc_mux_update();
    begin
        case (dut_m_pc_sel_if)
            2'd0: begin
                dut_m_pc_mux_out =  dut_m_pc + 4;
            end
            
            2'd1: begin
                dut_m_pc_mux_out =  dut_m_alu_out;
            end
            
            2'd2: begin
                $display("*WARNING @ %0t. pc_sel = 2 is not supported yet - TBD for prediction", $time);
                warnings = warnings + 1;
            end
            
            2'd3: begin
                dut_m_pc_mux_out =  'h0;  // start address
            end
            
            default: begin
                $display("*WARNING @ %0t. pc_sel not valid", $time);
                warnings = warnings + 1;
            end
        endcase
        // used for all accesses
        // arch is byte addressable, memory is word addressable
        dut_m_pc_mux_out_div4 = dut_m_pc_mux_out>>2;
    end
endtask

task dut_m_pc_update();
    begin
        dut_m_pc = (!dut_m_rst)     ? 
                   (dut_m_pc_we_if) ? dut_m_pc_mux_out   :   // mux
                                      dut_m_pc           :   // pc_we = 0
                                      'h0;                   // dut_m_rst = 1
    end
endtask

task dut_m_imem_update();
    begin
        dut_m_inst_id_read      = dut_m_imem[dut_m_pc_mux_out_div4];
       //  dut_m_inst_id_read_asm  = dut_m_imem[dut_m_pc_mux_out_div4];
    end
endtask

task dut_m_reg_file_read_update();
    begin
        // move to pipeline task
        dut_m_rs1_addr_id = dut_m_inst_id[19:15];
        dut_m_rs2_addr_id = dut_m_inst_id[24:20];
        dut_m_rd_addr_id  = dut_m_inst_id[11: 7];
        
        dut_m_rs1_data_id = dut_m_rf32[dut_m_rs1_addr_id];
        dut_m_rs2_data_id = dut_m_rf32[dut_m_rs2_addr_id];
        
    end
endtask

task dut_m_reg_file_write_update();
    integer j;
    begin
        if (dut_m_rst) begin
            for(j = 0; j < `RF_NUM; j = j + 1) begin
                dut_m_rf32[j] = 'h0;
            end
        end
        else if (dut_m_reg_we_mem && (dut_m_rd_addr_mem != 5'd0)) begin     // no writes to x0
            dut_m_rf32[dut_m_rd_addr_mem] = dut_m_rd_data;
        end
    end
endtask

task dut_m_imm_gen_update();
    reg    [11:0] imm_temp_12;
    reg    [12:0] imm_temp_13;
    reg    [20:0] imm_temp_21;
    
    begin
        dut_m_imm_gen_in = dut_m_inst_id[31: 7];
        case (dut_m_imm_gen_sel_id)
            `IG_I_TYPE: begin
                imm_temp_12          = dut_m_inst_id[31:20];
                dut_m_imm_gen_out_id = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
            end
            
            `IG_S_TYPE: begin
                imm_temp_12          = {dut_m_inst_id[31:25], dut_m_inst_id[11: 7]};
                dut_m_imm_gen_out_id = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
            end
            
            `IG_B_TYPE: begin
                imm_temp_13          = {dut_m_inst_id[31], dut_m_inst_id[7], dut_m_inst_id[30:25], dut_m_inst_id[11: 8], 1'b0};
                dut_m_imm_gen_out_id = $signed({imm_temp_13, 19'h0}) >>> 19;    // shift 13 MSBs to 13 LSBs, keep sign
            end
            
            `IG_J_TYPE: begin
                imm_temp_21          = {dut_m_inst_id[31], dut_m_inst_id[19:12], dut_m_inst_id[20], dut_m_inst_id[30:21], 1'b0};
                dut_m_imm_gen_out_id = $signed({imm_temp_21, 11'h0}) >>> 11;    // shift 21 MSBs to 21 LSBs, keep sign
            end
            
            `IG_U_TYPE: begin
                imm_temp_21          = dut_m_inst_id[31:12];
                dut_m_imm_gen_out_id = {imm_temp_21, 12'h0};                    // keep 21 MSBs, pad 11 bits with zeros
            end
            
            `IG_DISABLED: begin
                dut_m_imm_gen_out_id = dut_m_imm_gen_out_id_prev;               // keep previous result
            end
                            
            default: begin  // invalid operation
                $display("*WARNING @ %0t. Imm Gen model 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_m_inst_id, dut_m_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
    end
endtask

task dut_m_imm_gen_seq_update();
    begin
        if (dut_m_rst) 
            dut_m_imm_gen_out_id_prev = 'h0;
        else
            dut_m_imm_gen_out_id_prev = dut_m_imm_gen_out_id;
    end
endtask

task dut_m_csr_read_update();
    begin
        if (dut_m_csr_en_id)
            dut_m_csr_data_id = dut_m_tohost;
        else
            dut_m_csr_data_id = 'h0;
    end
endtask

task dut_m_csr_write_update();
    begin
        // zero-extend uimm
        dut_m_csr_din_imm = {27'h0, dut_m_rs1_addr_mem};
        
        if (dut_m_rst) begin
            dut_m_tohost = 'h0;
        end
        else if (dut_m_csr_we_mem) begin
            dut_m_tohost = dut_m_csr_ui_mem ? dut_m_csr_din_imm : dut_m_alu_in_a_mem;
        end
    end
endtask

task dut_m_bc_update();
    begin
        dut_m_bc_in_a = dut_m_bc_a_sel_fwd_ex  ? dut_m_writeback : dut_m_rs1_data_ex;
        dut_m_bc_in_b = dut_m_bcs_b_sel_fwd_ex ? dut_m_writeback : dut_m_rs2_data_ex;
        
        case (dut_m_bc_uns_ex)
            1'b0: begin     // signed
                dut_m_bc_a_eq_b = ($signed(dut_m_bc_in_a) == $signed(dut_m_bc_in_b));
                dut_m_bc_a_lt_b = ($signed(dut_m_bc_in_a) <  $signed(dut_m_bc_in_b));
            end
            
            1'b1: begin     // unsigned
                dut_m_bc_a_eq_b = (dut_m_bc_in_a == dut_m_bc_in_b);
                dut_m_bc_a_lt_b = (dut_m_bc_in_a <  dut_m_bc_in_b);
            end
            
            default: begin
                $display("*WARNING @ %0t. Branch Compare 'default' case. Input bc_uns: 'b%1b ",
                $time, dut_m_bc_uns_ex);
                warnings = warnings + 1;
                dut_m_bc_a_eq_b = 1'b0;
                dut_m_bc_a_lt_b = 1'b0;
            end
        endcase
    end
endtask

task dut_m_alu_update();
    begin
        dut_m_alu_in_a =  (dut_m_alu_a_sel_fwd_ex == 2'd0) ?    dut_m_rs1_data_ex     :
                          (dut_m_alu_a_sel_fwd_ex == 2'd1) ?    dut_m_pc_ex           :
                       /* (dut_m_alu_a_sel_fwd_ex == 2'd2) ? */ dut_m_writeback      ;
        
        dut_m_alu_in_b =  (dut_m_alu_b_sel_fwd_ex == 2'd0) ?    dut_m_rs2_data_ex     :
                          (dut_m_alu_b_sel_fwd_ex == 2'd1) ?    dut_m_imm_gen_out_ex  :
                       /* (dut_m_alu_b_sel_fwd_ex == 2'd2) ? */ dut_m_writeback      ;
        
        dut_m_alu_shamt = dut_m_alu_in_b[4:0];
        
        case (dut_m_alu_op_sel_ex)
            `ALU_ADD: begin
                dut_m_alu_out = dut_m_alu_in_a + dut_m_alu_in_b;
            end
            
            `ALU_SUB: begin
                dut_m_alu_out = dut_m_alu_in_a - dut_m_alu_in_b;
            end
            
            `ALU_SLL: begin
                dut_m_alu_out = dut_m_alu_in_a << dut_m_alu_shamt;
            end
            
            `ALU_SRL: begin
                dut_m_alu_out = dut_m_alu_in_a >> dut_m_alu_shamt;
            end
            
            `ALU_SRA: begin
                dut_m_alu_out = $signed(dut_m_alu_in_a) >>> dut_m_alu_shamt;
            end
            
            `ALU_SLT: begin
                dut_m_alu_out = ($signed(dut_m_alu_in_a) < $signed(dut_m_alu_in_b)) ? 32'h0001 : 32'h0000;
            end
            
            `ALU_SLTU: begin
                dut_m_alu_out = (dut_m_alu_in_a < dut_m_alu_in_b) ? 32'h0001 : 32'h0000;
            end
            
            `ALU_XOR: begin
                dut_m_alu_out = dut_m_alu_in_a ^ dut_m_alu_in_b;
            end
            
            `ALU_OR: begin
                dut_m_alu_out = dut_m_alu_in_a | dut_m_alu_in_b;
            end
            
            `ALU_AND: begin
                dut_m_alu_out = dut_m_alu_in_a & dut_m_alu_in_b;
            end
            
            `ALU_PASS_B: begin
                dut_m_alu_out = dut_m_alu_in_b;
            end
            
            default: begin  // invalid operation
                $display("*WARNING @ %0t. ALU op sel 'default' case. Input alu_op_sel_ex: %0d ",
                $time, dut_m_alu_op_sel_ex);
                warnings = warnings + 1;
                dut_m_alu_out = 32'h0000;
            end
        endcase
    end
endtask

task dut_m_dmem_inputs_update();
    begin
        dut_m_dmem_addr         = dut_m_alu_out[15:2];
        dut_m_load_sm_offset_ex = dut_m_alu_out[1:0];                                           // byte offset
        dut_m_dmem_write_data   = dut_m_bcs_b_sel_fwd_id ? dut_m_writeback : dut_m_rs2_data_ex;
        dut_m_dmem_write_data   = dut_m_dmem_write_data << (dut_m_load_sm_offset_ex*8);         // byte shift left 0, 1, 2 or 3 times
    end
endtask

task dut_m_dmem_update();
    begin
        if(dut_m_dmem_en_ex) begin
            dut_m_dmem_read_data_mem = dut_m_dmem[dut_m_dmem_addr];
            if(dut_m_dmem_we_ex[0]) dut_m_dmem[dut_m_dmem_addr][ 7: 0] = dut_m_dmem_write_data[ 7: 0];
            if(dut_m_dmem_we_ex[1]) dut_m_dmem[dut_m_dmem_addr][15: 8] = dut_m_dmem_write_data[15: 8];
            if(dut_m_dmem_we_ex[2]) dut_m_dmem[dut_m_dmem_addr][23:16] = dut_m_dmem_write_data[23:16];
            if(dut_m_dmem_we_ex[3]) dut_m_dmem[dut_m_dmem_addr][31:24] = dut_m_dmem_write_data[31:24];
        end
    end
endtask

task dut_m_load_sm_update();
    reg [31:0] task_din;
    reg [ 0:0] task_sign_bit;
    begin
        task_din            = dut_m_dmem_read_data_mem;
        dut_m_load_sm_width = dut_m_inst_mem[14:12];
        task_sign_bit       = dut_m_load_sm_width[2];
        
        if (dut_m_load_sm_en_mem) begin
            case (dut_m_load_sm_width[1:0])
            2'd0:   // byte
                case (dut_m_load_sm_offset_mem)
                2'd0:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[ 7: 0]} : 
                                                             {{24{task_din[ 7]}}, task_din[ 7: 0]};
                2'd1:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[15: 8]} : 
                                                             {{24{task_din[15]}}, task_din[15: 8]};
                2'd2:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[23:16]} : 
                                                             {{24{task_din[23]}}, task_din[23:16]};
                2'd3:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[31:24]} : 
                                                             {{24{task_din[31]}}, task_din[31:24]};
                // default: 
                    // $display("Offset input not valid");
                endcase
            
            2'd1:   // half
                case (dut_m_load_sm_offset_mem)
                 2'd0:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[15: 0]} : 
                                                             {{16{task_din[15]}}, task_din[15: 0]};
                2'd1:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[23: 8]} : 
                                                             {{16{task_din[23]}}, task_din[23: 8]};
                2'd2:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[31:16]} : 
                                                             {{16{task_din[31]}}, task_din[31:16]};
                2'd3: 
                begin
                    // $display("Unaligned access not supported");
                    dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
                end
                // default: 
                    // $display("Offset input not valid");
                endcase
           
            2'd2:   // word
                case (dut_m_load_sm_offset_mem)
                2'd0:
                    dut_m_load_sm_data_out = task_din;
                2'd1,
                2'd2,
                2'd3:
                begin
                    // $display("Unaligned access not supported");
                    dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
                end
                // default: 
                    // $display("Offset input not valid");
                endcase
            
            default: 
            begin
                // $display("Width input not valid");
                dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
            end
            endcase
        end
        else /*dut_m_load_sm_en_mem = 0*/ begin
            dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
        end
    end
endtask

task dut_m_load_sm_seq_update();
    begin
        if (dut_m_rst) 
            dut_m_load_sm_data_out_prev = 'h0;
        else
            dut_m_load_sm_data_out_prev = dut_m_load_sm_data_out;
    end
endtask

task dut_m_writeback_update();
    begin
        dut_m_writeback = (dut_m_wb_sel_mem == `WB_SEL_DMEM) ?    dut_m_load_sm_data_out    :
                          (dut_m_wb_sel_mem == `WB_SEL_ALU ) ?    dut_m_alu_out_mem         :
                          (dut_m_wb_sel_mem == `WB_SEL_INC4) ?    dut_m_pc_mem + 32'd4      :
                       /* (dut_m_wb_sel_mem == `WB_SEL_CSR ) ? */ dut_m_csr_data_mem       ;
    end
endtask

task dut_m_nop_id_update();
    begin
        dut_m_inst_id           = (dut_m_stall_if_q1) ? `NOP : dut_m_inst_id_read;
    end
endtask

task dut_m_if_pipeline_update();
    begin
        dut_m_stall_if_q1       = (!dut_m_rst) ? dut_m_stall_if : 'b1;
    end
endtask

task dut_m_id_ex_pipeline_update();
    begin
        // instruction update
        // datapath
        dut_m_pc_ex              = (!dut_m_rst && !dut_m_clear_id) ? dut_m_pc                  : 'h0;
        dut_m_rd_addr_ex         = (!dut_m_rst && !dut_m_clear_id) ? dut_m_rd_addr_id          : 'h0;        
        dut_m_rs1_addr_ex        = (!dut_m_rst && !dut_m_clear_id) ? dut_m_rs1_addr_id         : 'h0;        
        dut_m_rs1_data_ex        = (!dut_m_rst && !dut_m_clear_id) ? 
                                    dut_m_rf_a_sel_fwd_id          ? dut_m_writeback           : 
                                                                     dut_m_rs1_data_id         : 
                                             /*dut_m_rst or clear*/  'h0                      ;
        dut_m_rs2_data_ex        = (!dut_m_rst && !dut_m_clear_id) ? 
                                    dut_m_rf_b_sel_fwd_id          ? dut_m_writeback           : 
                                                                     dut_m_rs2_data_id         : 
                                             /*dut_m_rst or clear*/  'h0                      ;        
        dut_m_imm_gen_out_ex     = (!dut_m_rst && !dut_m_clear_id) ? dut_m_imm_gen_out_id      : 'h0;
        dut_m_csr_data_ex        = (!dut_m_rst && !dut_m_clear_id) ? dut_m_csr_data_id         : 'h0;
        dut_m_inst_ex            = (!dut_m_rst && !dut_m_clear_id) ? dut_m_inst_id             : 'h0;
        dut_m_inst_ex_asm        = (!dut_m_rst && !dut_m_clear_id) ? dut_m_inst_id_asm         : 'h0;
        
        // control
        dut_m_bc_uns_ex          = (!dut_m_rst && !dut_m_clear_id) ? dut_m_bc_uns_id           : 'b0;
        dut_m_bc_a_sel_fwd_ex    = (!dut_m_rst && !dut_m_clear_id) ? dut_m_bc_a_sel_fwd_id     : 'b0;
        dut_m_bcs_b_sel_fwd_ex   = (!dut_m_rst && !dut_m_clear_id) ? dut_m_bcs_b_sel_fwd_id    : 'b0;
        dut_m_alu_a_sel_fwd_ex   = (!dut_m_rst && !dut_m_clear_id) ? dut_m_alu_a_sel_fwd_id    : 'h0;
        dut_m_alu_b_sel_fwd_ex   = (!dut_m_rst && !dut_m_clear_id) ? dut_m_alu_b_sel_fwd_id    : 'h0;
        dut_m_alu_op_sel_ex      = (!dut_m_rst && !dut_m_clear_id) ? dut_m_alu_op_sel_id       : 'h0;
        dut_m_dmem_en_ex         = (!dut_m_rst && !dut_m_clear_id) ? dut_m_dmem_en_id          : 'b0;
        dut_m_load_sm_en_ex      = (!dut_m_rst && !dut_m_clear_id) ? dut_m_load_sm_en_id       : 'b0;
        dut_m_wb_sel_ex          = (!dut_m_rst && !dut_m_clear_id) ? dut_m_wb_sel_id           : 'h0;
        dut_m_reg_we_ex          = (!dut_m_rst && !dut_m_clear_id) ? dut_m_reg_we_id           : 'b0;
        dut_m_csr_we_ex          = (!dut_m_rst && !dut_m_clear_id) ? dut_m_csr_we_id           : 'b0;
        dut_m_csr_ui_ex          = (!dut_m_rst && !dut_m_clear_id) ? dut_m_csr_ui_id           : 'b0;
        
        // internal only
        dut_m_store_inst_ex      = (!dut_m_rst && !dut_m_clear_id) ? dut_m_store_inst_id       : 'b0;
        dut_m_load_inst_ex       = (!dut_m_rst && !dut_m_clear_id) ? dut_m_load_inst_id        : 'b0;
        dut_m_branch_inst_ex     = (!dut_m_rst && !dut_m_clear_id) ? dut_m_branch_inst_id      : 'b0;
        dut_m_jump_inst_ex       = (!dut_m_rst && !dut_m_clear_id) ? dut_m_jump_inst_id        : 'b0;
    end
endtask

task dut_m_ex_mem_pipeline_update();
    begin
        dut_m_pc_mem             = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_pc_ex              : 'h0;
        dut_m_alu_out_mem        = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_alu_out            : 'h0;
        dut_m_alu_in_a_mem       = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_alu_in_a           : 'h0;
        dut_m_dmem_update();
        dut_m_load_sm_offset_mem = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_load_sm_offset_ex  : 'h0;
        dut_m_inst_mem           = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_inst_ex            : 'h0;
        dut_m_inst_mem_asm       = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_inst_ex_asm        : 'h0;
        dut_m_rd_addr_mem        = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_rd_addr_ex         : 'h0;
        dut_m_rs1_addr_mem       = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_rs1_addr_ex        : 'h0;
        dut_m_csr_data_mem       = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_csr_data_ex        : 'h0;
        dut_m_load_sm_en_mem     = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_load_sm_en_ex      : 'b0;
        dut_m_wb_sel_mem         = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_wb_sel_ex          : 'h0;
        dut_m_reg_we_mem         = (!dut_m_rst && !dut_m_clear_ex) ? dut_m_reg_we_ex          : 'b0;
        dut_m_csr_we_mem         = (!dut_m_rst && !dut_m_clear_id) ? dut_m_csr_we_ex          : 'b0;
        dut_m_csr_ui_mem         = (!dut_m_rst && !dut_m_clear_id) ? dut_m_csr_ui_ex          : 'b0;
        
    end
endtask

task dut_m_rst_sequence_update();
    reg   [ 2:0] reset_seq  ;
    reg          dut_m_rst_seq_id ;
    reg          dut_m_rst_seq_ex ;
    reg          dut_m_rst_seq_mem;
    begin
        reset_seq       = (!dut_m_rst) ? {reset_seq[1:0],1'b0} : 3'b111;
        dut_m_rst_seq_id      = reset_seq[0];
        dut_m_rst_seq_ex      = reset_seq[1];
        dut_m_rst_seq_mem     = reset_seq[2];
        
        dut_m_clear_id  = dut_m_rst_seq_id   ;
        dut_m_clear_ex  = dut_m_rst_seq_ex   ;
        dut_m_clear_mem = dut_m_rst_seq_mem  ;
        
    end
endtask

task dut_m_seq_update();
    begin
        //----- MEM/WB stage updates
        dut_m_reg_file_write_update();
        dut_m_csr_write_update();
                
        //----- EX/MEM stage updates
        dut_m_load_sm_seq_update();
        dut_m_ex_mem_pipeline_update();
        
        //----- ID/EX stage updates
        dut_m_imm_gen_seq_update();
        dut_m_id_ex_pipeline_update();
        dut_m_rst_sequence_update();
        
        //----- IF/ID stage updates
        dut_m_imem_update();
        dut_m_pc_update();
        dut_m_if_pipeline_update();
    end
endtask

task dut_m_comb_update();
    begin
        //----- MEM stage updates
        dut_m_load_sm_update();
        dut_m_writeback_update();
        
        //----- EX stage updates
        dut_m_bc_update();
        dut_m_alu_update();
        dut_m_dmem_inputs_update();
        
        //----- ID stage updates
        dut_m_nop_id_update();
        dut_m_reg_file_read_update();
        dut_m_decode();
        dut_m_imm_gen_update();
        dut_m_csr_read_update();
        
        //----- IF stage updates
        dut_m_pc_mux_update();
    end
endtask

task dut_m_update();
    begin
        dut_m_seq_update();
        dut_m_comb_update();
    end
endtask

