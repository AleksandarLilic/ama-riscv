#define DPI

#include "defines.h"
#include "hw_model_types.h"
#include "memory.h"
#include "core.h"
#include "utils.h"

#include "dpi_functions.h"

memory* mem;
core* rv32;
cfg_t cfg;
hw_cfg_t hw_cfg; // placeholder, dc

std::string stack_top;
std::string inst_asm;

trace_entry te;

DPI_LINKER_DECL DPI_DLLESPEC
int cosim_setup(const char *test_elf) {
    cfg.perf_event = perf_event_t::cycle;
    cfg.prof_pc.start = BASE_ADDR; // FIXME: should be passed as plusarg
    cfg.prof_trace = true; // FIXME: also plusarg
    cfg.dpi_prof_on_boot = true; // FIXME: also plusarg

    std::string l_test_elf(test_elf);
    cfg.out_dir = gen_out_dir(l_test_elf, "cosim");

    mem = new memory(l_test_elf, cfg, hw_cfg);
    rv32 = new core(mem, cfg, hw_cfg);

    return 0;
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_add_te(
    uint64_t clk_cnt,
    unsigned int inst_wbk,
    unsigned int pc_wbk,
    unsigned int x2_sp,
    char dmem_addr,
    char dmem_size,
    char branch_taken,
    char ic_hm,
    char dc_hm,
    char bp_hm)
{
    te.inst = inst_wbk;
    te.pc = pc_wbk;
    // te.next_pc = 0u; // next_pc not always known in DPI, default from rst_te
    te.sp = x2_sp;
    te.taken = branch_taken;
    te.inst_size = 4; // always 4 bytes in DPI, RV32C not supported
    te.dmem = dmem_addr;
    te.dmem_size = dmem_size;
    te.sample_cnt = clk_cnt; // every clock is this called
    te.ic_hm = ic_hm;
    te.dc_hm = dc_hm;
    te.bp_hm = bp_hm;
    rv32->save_trace_entry(te);
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_exec(
    uint64_t clk_cnt,
    unsigned int* pc,
    unsigned int* inst,
    const char** inst_asm_str,
    const char** stack_top_str,
    unsigned int rf[32])
{
    // before the instruction - callstack is updated at the end of previous inst
    stack_top = rv32->get_callstack_top_str().c_str();
    *stack_top_str = stack_top.c_str();

    rv32->update_clk(clk_cnt); // issue for profiling for multiple windows
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
