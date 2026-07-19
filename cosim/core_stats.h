#pragma once

#include "defines.h"
#include "hw_model_types.h"
#include "dpi_functions.h"

#define CORE_STATS_JSON_LINE_LAST(key) \
    JSON_N << "\"" << #key << "\": " << this->key

#define CORE_STATS_JSON_LINE(key) \
    CORE_STATS_JSON_LINE_LAST(key) << "," <<

// ==== PERF_EVENT AUTOGEN BEGIN ====
#define CORE_STATS_JSON_ENTRY_AUTOGEN \
    CORE_STATS_JSON_LINE(bad_spec) \
    CORE_STATS_JSON_LINE(stall_be) \
    CORE_STATS_JSON_LINE(stall_l1d) \
    CORE_STATS_JSON_LINE(stall_l1d_r) \
    CORE_STATS_JSON_LINE(stall_fe) \
    CORE_STATS_JSON_LINE(stall_l1i) \
    CORE_STATS_JSON_LINE(stall_load_use) \
    CORE_STATS_JSON_LINE(stall_mul_simd_use) \
    CORE_STATS_JSON_LINE(stall_div) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow_jr) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow_br) \
    CORE_STATS_JSON_LINE(ret_mem) \
    CORE_STATS_JSON_LINE(ret_mem_load) \
    CORE_STATS_JSON_LINE(ret_mul) \
    CORE_STATS_JSON_LINE(ret_div) \
    CORE_STATS_JSON_LINE(ret_simd) \
    CORE_STATS_JSON_LINE(ret_simd_arith) \
    CORE_STATS_JSON_LINE(ret_simd_arith_dot) \
    CORE_STATS_JSON_LINE(bp_miss) \
    CORE_STATS_JSON_LINE(l1i_ref) \
    CORE_STATS_JSON_LINE(l1i_miss) \
    CORE_STATS_JSON_LINE(l1i_spec_miss) \
    CORE_STATS_JSON_LINE(l1i_spec_miss_bad) \
    CORE_STATS_JSON_LINE(l1d_ref) \
    CORE_STATS_JSON_LINE(l1d_ref_r) \
    CORE_STATS_JSON_LINE(l1d_miss) \
    CORE_STATS_JSON_LINE(l1d_miss_r) \
    CORE_STATS_JSON_LINE(l1d_writeback)

// ==== PERF_EVENT AUTOGEN END ====

#define CORE_STATS_JSON_ENTRY_MANUAL \
    CORE_STATS_JSON_LINE(ret_inst) \
    CORE_STATS_JSON_LINE(cycles) \
    CORE_STATS_JSON_LINE(empty) \
    CORE_STATS_JSON_LINE(stalls) \
    CORE_STATS_JSON_LINE(lost) \
    CORE_STATS_JSON_LINE(lost_other) \
    CORE_STATS_JSON_LINE(stall_fe_core) \
    CORE_STATS_JSON_LINE(stall_be_core) \
    CORE_STATS_JSON_LINE(ret_int) \
    CORE_STATS_JSON_LINE(cpi) \
    CORE_STATS_JSON_LINE_LAST(ipc)

/*
Core stats:
    Cycles: 940, Instr: 727, Stall cycles: 213, CPI: 1.293 (IPC: 0.773)
TDA:
    L1: bad spec 57, fe bound 132, be bound 20, retiring 733
    L2: fe mem 95, fe core 37, be mem 20, be core 0, int 733, simd 0
 */
struct core_stats_t {
    private:
        uint64_t cycles_all = 0;
        uint64_t ret_all = 0;
        // profiler active
        uint64_t cycles = 0;
        // ==== PERF_EVENT AUTOGEN BEGIN ====
        uint64_t ret_inst = 0;
        uint64_t bad_spec = 0;
        uint64_t stall_be = 0;
        uint64_t stall_l1d = 0;
        uint64_t stall_l1d_r = 0;
        uint64_t stall_fe = 0;
        uint64_t stall_l1i = 0;
        uint64_t stall_load_use = 0;
        uint64_t stall_mul_simd_use = 0;
        uint64_t stall_div = 0;
        uint64_t ret_ctrl_flow = 0;
        uint64_t ret_ctrl_flow_jr = 0;
        uint64_t ret_ctrl_flow_br = 0;
        uint64_t ret_mem = 0;
        uint64_t ret_mem_load = 0;
        uint64_t ret_mul = 0;
        uint64_t ret_div = 0;
        uint64_t ret_simd = 0;
        uint64_t ret_simd_arith = 0;
        uint64_t ret_simd_arith_dot = 0;
        uint64_t bp_miss = 0;
        uint64_t l1i_ref = 0;
        uint64_t l1i_miss = 0;
        uint64_t l1i_spec_miss = 0;
        uint64_t l1i_spec_miss_bad = 0;
        uint64_t l1d_ref = 0;
        uint64_t l1d_ref_r = 0;
        uint64_t l1d_miss = 0;
        uint64_t l1d_miss_r = 0;
        uint64_t l1d_writeback = 0;
        // ==== PERF_EVENT AUTOGEN END ====
        // derived
        uint64_t empty = 0;
        uint64_t stalls = 0;
        uint64_t lost = 0;
        uint64_t lost_other = 0;
        uint64_t stall_fe_core = 0;
        uint64_t stall_be_core = 0;
        uint64_t ret_int = 0;
        float_t ipc = -1.0;
        float_t cpi = -1.0;
        // misc
        bool prof_active = false;
    private:
        void summarize() {
            empty = (cycles - ret_inst);
            stalls = (stall_be + stall_fe);
            lost = (empty - stalls);
            lost_other = (lost - bad_spec);
            stall_fe_core = (stall_fe - stall_l1i);
            stall_be_core = (stall_be - stall_l1d);
            ret_int = (ret_inst - ret_simd);
            if ((cycles > 0) && (ret_inst > 0)) {
                ipc = (TO_F32(ret_inst) / TO_F32(cycles));
                cpi = (1/ipc);
            }
        };
    public:
        void profiling(bool enable) { prof_active = enable; }
        void add_events(const perf_event_bytes_t* ev) {
            cycles_all++;
            ret_all += ev->ret_inst;
            if (!prof_active) return;
            cycles += 1;
            // ==== PERF_EVENT AUTOGEN BEGIN ====
            ret_inst += ev->ret_inst;
            bad_spec += ev->bad_spec;
            stall_be += ev->stall_be;
            stall_l1d += ev->stall_l1d;
            stall_l1d_r += ev->stall_l1d_r;
            stall_fe += ev->stall_fe;
            stall_l1i += ev->stall_l1i;
            stall_load_use += ev->stall_load_use;
            stall_mul_simd_use += ev->stall_mul_simd_use;
            stall_div += ev->stall_div;
            ret_ctrl_flow += ev->ret_ctrl_flow;
            ret_ctrl_flow_jr += ev->ret_ctrl_flow_jr;
            ret_ctrl_flow_br += ev->ret_ctrl_flow_br;
            ret_mem += ev->ret_mem;
            ret_mem_load += ev->ret_mem_load;
            ret_mul += ev->ret_mul;
            ret_div += ev->ret_div;
            ret_simd += ev->ret_simd;
            ret_simd_arith += ev->ret_simd_arith;
            ret_simd_arith_dot += ev->ret_simd_arith_dot;
            bp_miss += ev->bp_miss;
            l1i_ref += ev->l1i_ref;
            l1i_miss += ev->l1i_miss;
            l1i_spec_miss += ev->l1i_spec_miss;
            l1i_spec_miss_bad += ev->l1i_spec_miss_bad;
            l1d_ref += ev->l1d_ref;
            l1d_ref_r += ev->l1d_ref_r;
            l1d_miss += ev->l1d_miss;
            l1d_miss_r += ev->l1d_miss_r;
            l1d_writeback += ev->l1d_writeback;
            // ==== PERF_EVENT AUTOGEN END ====
        }
        void show_tda() {
            summarize();
            std::cout << "Cycles: " << cycles
                      << ", Retired: " << ret_inst
                      << ", Empty: " << empty
                      << std::fixed << std::setprecision(3)
                      << ", IPC: " << ipc << "\n"
                      << INDENT << "TDA:\n"
                      << INDENT << INDENT << "L1: "
                      << "Retired: " << ret_inst
                      << ", FE: " << stall_fe
                      << ", BE: " << stall_be
                      << ", Lost: " << lost
                      << "\n"
                      << INDENT << INDENT << "L2: "
                      << "INT: " << ret_int
                      << ", SIMD: " << ret_simd
                      << ", FE Icache: " << stall_l1i
                      << ", FE Core: " << stall_fe_core
                      << ", BE Dcache: " << stall_l1d
                      << ", BE Core: " << stall_be_core
                      << ", Bad Spec: " << bad_spec
                      << ", Other: " << lost_other;
        }
        void show_all() {
            float_t amat_l1i, amat_l1d, hits;
            hits = TO_F32(l1i_ref - l1i_miss);
            amat_l1i = ((hits + TO_F32(stall_l1i)) / hits);
            hits = TO_F32(l1d_ref - l1d_miss);
            amat_l1d = ((hits + TO_F32(stall_l1d)) / hits);
            std::cout
                << "Control Flow: " << ret_ctrl_flow
                << " - J: " <<
                    (ret_ctrl_flow - ret_ctrl_flow_jr - ret_ctrl_flow_br)
                << ", JR: " << ret_ctrl_flow_jr
                << ", BR: " << ret_ctrl_flow_br
                << "\n" << INDENT << "Memory: " << ret_mem
                << " - Load: " << ret_mem_load
                << ", Store: " << (ret_mem - ret_mem_load)
                << "\n" << INDENT << "SIMD: " << ret_simd
                << " - Arith: " << ret_simd_arith
                << ", Data Format: " << (ret_simd - ret_simd_arith)
                << "\n" << INDENT << "Stall -"
                << " Load: " << stall_load_use
                << ", SIMD: " << stall_mul_simd_use
                << ", DIV: " << stall_div
                << "\n" << INDENT << "bpred -"
                << " M: " << bp_miss
                << "\n" << INDENT << "icache -"
                << " A: " << l1i_ref
                << ", M: " << l1i_miss
                << ", SM: " << l1i_spec_miss
                << ", SMB: " << l1i_spec_miss_bad
                << std::fixed << std::setprecision(2)
                << ", AMAT: " << amat_l1i
                << "\n" << INDENT << "dcache -"
                << " A: " << l1d_ref
                << ", M: " << l1d_miss
                << ", WB: " << l1d_writeback
                << std::fixed << std::setprecision(2)
                << ", AMAT: " << amat_l1d;
        };
        void log(std::ofstream& hw_ofs) const {
            hw_ofs << CORE_STATS_JSON_ENTRY_AUTOGEN "";
            hw_ofs << CORE_STATS_JSON_ENTRY_MANUAL;
        }
        uint64_t get_insts_profiled() const { return ret_inst; }
        uint64_t get_cycles_all() const { return cycles_all; }
        uint64_t get_inst_all() const { return ret_all; }
};
