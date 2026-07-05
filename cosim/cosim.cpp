#include "cosim.h"

#include "arg_parse.h"
#include "str_utils.h"

memory* mem;
core* rv32;
cfg_t cfg;
hw_cfg_t hw_cfg; // placeholder, dc

std::string stack_top;
std::string inst_asm;

cosim_stats stats;
trace_entry te;
std::string out_dir;

// cpp side
void cosim_prof(bool enable) { stats.profiling(enable); }

// testbench side, from "dpi_functions.h"
DPI_LINKER_DECL DPI_DLLESPEC
void cosim_setup(
    const char *test_elf,
    unsigned int prof_pc_start,
    unsigned int prof_pc_stop,
    unsigned int prof_pc_single_match,
    char prof_trace,
    char log_isa_sim,
    const char* perf_events,
    const char** cosim_out_dir
) {
    // reuse the same resolver as the isa sim cli
    ordered_map<perf_event_t> pe_map;
    for (uint32_t i = 0; i < perf_event_names.size(); i++)
        pe_map.push_back({perf_event_names[i], static_cast<perf_event_t>(i)});
    cfg.perf_events = resolve_arg_list(
        "perf_events", str_utils::split(perf_events, ','), pe_map);
    cfg.prof_pc.start = prof_pc_start;
    cfg.prof_pc.stop = prof_pc_stop;
    cfg.prof_pc.single_match_num = prof_pc_single_match;
    cfg.prof_trace = (prof_trace == 1);
    cfg.log = (log_isa_sim == 1);
    cfg.log_always = (log_isa_sim == 1);

    std::string l_test_elf(test_elf);
    out_dir = gen_out_dir(l_test_elf, "cosim");
    cfg.out_dir = out_dir;
    *cosim_out_dir = out_dir.c_str();

    mem = new memory(l_test_elf, cfg, hw_cfg);
    rv32 = new core(mem, cfg, hw_cfg);
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
    rv32->single_step();
    *inst = rv32->get_inst();
    *tohost = rv32->get_csr(csr_map::addr::tohost);
    for (int i = 0; i < 32; i++) rf[i] = rv32->get_reg(i);
    inst_asm = rv32->get_inst_asm().c_str();
    *inst_asm_str = inst_asm.c_str();
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_force_irq(char mtip, char meip) {
    rv32->force_irq(mtip != 0, meip != 0);
}

DPI_LINKER_DECL DPI_DLLESPEC
uint32_t cosim_get_inst_cnt() {
    return rv32->get_inst_cnt();
}

DPI_LINKER_DECL DPI_DLLESPEC
void cosim_finish() {
    rv32->finish(false);
    stats.show();
    stats.log_hw_stats(out_dir);
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
void cosim_log_stats(
    const perf_event_bytes_t* core,
    const hw_events_t* icache,
    const hw_events_t* dcache,
    const hw_events_t* bp)
{
    stats.log_core_event(core);
    stats.log_icache_event(icache);
    stats.log_dcache_event(dcache);
    stats.log_bp_event(bp);

    // ==== PERF_EVENT AUTOGEN BEGIN ====
    #define SET_FLAG(ev) \
        rv32->set_perf_event_flag(perf_event_t::ev, core->ev);

    SET_FLAG(ret_inst)
    SET_FLAG(bad_spec)
    SET_FLAG(stall_be)
    SET_FLAG(stall_l1d)
    SET_FLAG(stall_l1d_r)
    SET_FLAG(stall_fe)
    SET_FLAG(stall_l1i)
    SET_FLAG(stall_load_use)
    SET_FLAG(stall_mul_simd_use)
    SET_FLAG(stall_div)
    SET_FLAG(ret_ctrl_flow)
    SET_FLAG(ret_ctrl_flow_jr)
    SET_FLAG(ret_ctrl_flow_br)
    SET_FLAG(ret_mem)
    SET_FLAG(ret_mem_load)
    SET_FLAG(ret_mul)
    SET_FLAG(ret_div)
    SET_FLAG(ret_simd)
    SET_FLAG(ret_simd_arith)
    SET_FLAG(ret_simd_arith_dot)
    SET_FLAG(bp_miss)
    SET_FLAG(l1i_ref)
    SET_FLAG(l1i_miss)
    SET_FLAG(l1i_spec_miss)
    SET_FLAG(l1i_spec_miss_bad)
    SET_FLAG(l1d_ref)
    SET_FLAG(l1d_ref_r)
    SET_FLAG(l1d_miss)
    SET_FLAG(l1d_miss_r)
    SET_FLAG(l1d_writeback)

    #undef SET_FLAG

    // ==== PERF_EVENT AUTOGEN END ====
}
