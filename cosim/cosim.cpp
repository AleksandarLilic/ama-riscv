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
void cosim_setup(
    const char *test_elf,
    unsigned int prof_pc_start,
    unsigned int prof_pc_stop,
    unsigned int prof_pc_single_match,
    char prof_trace,
    char log_isa_sim
) {
    cfg.perf_event = perf_event_t::cycle; // TODO: plusarg
    cfg.prof_pc.start = prof_pc_start;
    cfg.prof_pc.stop = prof_pc_stop;
    cfg.prof_pc.single_match_num = prof_pc_single_match;
    cfg.prof_trace = (prof_trace == 1);
    cfg.log = (log_isa_sim == 1);
    cfg.sink_uart = true;

    std::string l_test_elf(test_elf);
    cfg.out_dir = gen_out_dir(l_test_elf, "cosim");

    mem = new memory(l_test_elf, cfg, hw_cfg);
    rv32 = new core(mem, cfg, hw_cfg);
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_add_te(
    uint64_t clk_cnt,
    unsigned int inst_ret,
    unsigned int pc_ret,
    unsigned int x2_sp,
    unsigned int dmem_addr,
    char dmem_size,
    char branch_taken,
    char ic_hm,
    char dc_hm,
    char bp_hm,
    char ct_imem_core,
    char ct_imem_mem,
    char ct_dmem_core_r,
    char ct_dmem_core_w,
    char ct_dmem_mem_r,
    char ct_dmem_mem_w)
{
    te.rst();
    te.inst = inst_ret;
    te.pc = pc_ret;
    // te.next_pc = 0u; // next_pc not always known in DPI, default rst value
    te.sp = x2_sp;
    te.taken = branch_taken;
    te.inst_size = 4; // always 4 bytes in DPI, RV32C not supported
    te.dmem = dmem_addr;
    te.dmem_size = dmem_size;
    te.sample_cnt = clk_cnt; // new sample every clock
    te.ic_hm = ic_hm;
    te.dc_hm = dc_hm;
    te.bp_hm = bp_hm;
    te.ct_imem_core = ct_imem_core;
    te.ct_imem_mem = ct_imem_mem;
    te.ct_dmem_core_r = ct_dmem_core_r;
    te.ct_dmem_core_w = ct_dmem_core_w;
    te.ct_dmem_mem_r = ct_dmem_mem_r;
    te.ct_dmem_mem_w = ct_dmem_mem_w;
    rv32->save_trace_entry(te);
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_exec(
    uint64_t clk_cnt,
    unsigned int* pc,
    unsigned int* inst,
    unsigned int* tohost,
    const char** inst_asm_str,
    const char** stack_top_str,
    unsigned int rf[32])
{
    // before the instruction - callstack is updated at the end of previous inst
    stack_top = rv32->get_callstack_top_str().c_str();
    *stack_top_str = stack_top.c_str();

    rv32->update_clk(clk_cnt); // issue for profiling multiple windows
    *pc = rv32->get_pc();
    rv32->exec_inst();
    *inst = rv32->get_inst();
    *tohost = rv32->get_csr(CSR_TOHOST);
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
