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



/* Imported (by SV) task */
DPI_LINKER_DECL DPI_DLLESPEC int cosim_setup(
	const char* test_bin ,
	unsigned int prof_pc_start ,
	unsigned int prof_pc_stop ,
	unsigned int prof_pc_single_match ,
	char prof_trace);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_exec(
	uint64_t clk_cnt ,
	uint64_t mtime ,
	unsigned int* pc ,
	unsigned int* inst ,
	unsigned int* tohost ,
	const char** inst_asm_str ,
	const char** stack_top_str ,
	unsigned int rf[32]);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_add_te(
	uint64_t clk_cnt ,
	unsigned int inst_wbk ,
	unsigned int pc_wbk ,
	unsigned int x2_sp ,
	unsigned int dmem_addr ,
	char dmem_size ,
	char branch_taken ,
	char ic_hm ,
	char dc_hm ,
	char bp_hm);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 unsigned int cosim_get_inst_cnt(
);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_finish(
);


#endif
