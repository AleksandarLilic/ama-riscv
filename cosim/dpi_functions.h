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
	char log_isa_sim);


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
	char bad_spec;
	char fe;
	char fe_ic;
	char be;
	char be_dc;
	char ret_simd;
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


#endif
