#define DPI

#include "defines.h"
#include "memory.h"
#include "core.h"
#include "utils.h"

#include "dpi_tb_functions.h"

memory* mem;
core* rv32;
cfg_t cfg;
hw_cfg_t hw_cfg; // placeholder, dc

std::string stack_top;
std::string inst_asm;

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_setup(const char *test_elf) {
    cfg.prof_pc.start = 0x10000; // FIXME: should be passed as plusarg
    cfg.perf_event = perf_event_t::cycles;
    std::string l_test_elf(test_elf);
    mem = new memory(l_test_elf, hw_cfg);
    rv32 = new core(mem, gen_out_dir(l_test_elf, "cosim"), cfg, hw_cfg);
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_exec(
    uint64_t clk_cnt,
    uint32_t* pc,
    uint32_t* inst,
    const char** inst_asm_str,
    const char** stack_top_str,
    uint32_t* rf)
{
    // before the instruction - callstack is updated at the end of previous inst
    stack_top = rv32->get_callstack_top_str().c_str();
    *stack_top_str = stack_top.c_str();

    rv32->update_clk(clk_cnt);
    *pc = rv32->get_pc();
    rv32->exec_inst();
    *inst = rv32->get_inst();
    for (int i = 0; i < 32; i++) rf[i] = rv32->get_reg(i);
    inst_asm = rv32->get_inst_asm().c_str();
    *inst_asm_str = inst_asm.c_str();
}

DPI_LINKER_DECL DPI_DLLESPEC
uint32_t cosim_get_inst_cnt() {
    return rv32->get_inst_cnt();
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_finish() {
    rv32->finish(false);
}
