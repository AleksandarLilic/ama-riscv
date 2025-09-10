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
	const char* test_bin);


/* Imported (by SV) function */
DPI_LINKER_DECL DPI_DLLESPEC 
 void cosim_exec(
	uint64_t clk_cnt ,
	unsigned int* pc ,
	unsigned int* inst ,
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


#endif
