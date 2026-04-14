/**********************************************************************/
/*   ____  ____                                                       */
/*  /   /\/   /                                                       */
/* /___/  \  /                                                        */
/* \   \   \/                                                         */
/*  \   \        Copyright (c) 2003-2020 Xilinx, Inc.                 */
/*  /   /        All Right Reserved.                                  */
/* /---/   /\                                                         */
/* \   \  /  \                                                        */
/*  \___\/\___\                                                       */
/**********************************************************************/


/* NOTE: DO NOT EDIT. AUTOMATICALLY GENERATED FILE. CHANGES WILL BE LOST. */

#ifndef DPI_H
#define DPI_H
#ifdef __cplusplus
#define DPI_LINKER_DECL  extern "C" 
#else
#define DPI_LINKER_DECL
#endif

#include "svdpi.h"



/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_setup(
	const char* test_bin ,
	unsigned int prof_pc_start ,
	unsigned int prof_pc_stop ,
	unsigned int prof_pc_single_match ,
	char prof_trace ,
	char log_isa_sim ,
	const char** cosim_out_dir);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_exec(
	uint64_t clk_cnt ,
	unsigned int* pc ,
	unsigned int* inst ,
	unsigned int* tohost ,
	const char** inst_asm_str ,
	const char** stack_top_str ,
	unsigned int rf[32]);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 unsigned int cosim_get_inst_cnt(
);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_finish(
);

typedef struct {
	uint64_t mtime;
	uint64_t mhpmcounter[9];
} csr_sync_t;



/* Exported (from SV) function */
DPI_LINKER_DECL 
 void cosim_sync_csrs(
	csr_sync_t* csr
);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_add_te(
	uint64_t clk_cnt ,
	unsigned int inst_ret ,
	unsigned int pc_ret ,
	unsigned int x2_sp ,
	unsigned int dmem_addr ,
	char dmem_size ,
	char branch_taken ,
	char ic_hm ,
	char dc_hm ,
	char bp_hm ,
	char ct_imem_core ,
	char ct_imem_mem ,
	char ct_dmem_core_r ,
	char ct_dmem_core_w ,
	char ct_dmem_mem_r ,
	char ct_dmem_mem_w);

typedef struct {
	char ret;
	char bad_spec;
	char stall_be;
	char stall_l1d;
	char stall_l1d_r;
	char stall_l1d_w;
	char stall_fe;
	char stall_l1i;
	char stall_simd;
	char stall_load;
	char ret_ctrl_flow;
	char ret_ctrl_flow_j;
	char ret_ctrl_flow_jr;
	char ret_ctrl_flow_br;
	char ret_mem;
	char ret_mem_load;
	char ret_mem_store;
	char ret_simd;
	char ret_simd_arith;
	char ret_simd_data_fmt;
	char bp_miss;
	char l1i_ref;
	char l1i_miss;
	char l1i_spec_miss;
	char l1i_spec_miss_bad;
	char l1i_spec_miss_good;
	char l1d_ref;
	char l1d_ref_r;
	char l1d_ref_w;
	char l1d_miss;
	char l1d_miss_r;
	char l1d_miss_w;
	char l1d_writeback;
} core_events_t;


typedef struct {
	char aref;
	char hit;
	char miss;
	char wb;
	char load;
	char size;
	char hm;
} hw_events_t;



/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_log_stats(
	const core_events_t* core ,
	const hw_events_t* icache ,
	const hw_events_t* dcache ,
	const hw_events_t* bp);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_open(
	const char* outdir);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_cycle(
	uint64_t cycle);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_inst(
	unsigned int id);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_label(
	unsigned int id ,
	unsigned int pc ,
	unsigned int inst ,
	const char* inst_asm_str);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_label_str(
	unsigned int id ,
	unsigned int lane ,
	const char* str);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_start_stage(
	unsigned int id ,
	const char* stage);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_end_stage(
	unsigned int id ,
	const char* stage);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_retire(
	unsigned int id ,
	unsigned int retire_id ,
	char is_flush);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void konata_close(
);


#endif
