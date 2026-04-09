#pragma once

#include "defines.h"
#include "hw_model_types.h"
#include "dpi_functions.h"

#define CORE_STATS_JSON_LINE_LAST(key) \
    JSON_N << "\"" << #key << "\": " << this->key

#define CORE_STATS_JSON_LINE(key) \
    CORE_STATS_JSON_LINE_LAST(key) << "," <<

#define CORE_STATS_JSON_ENTRY \
    CORE_STATS_JSON_LINE(bad_spec) \
    CORE_STATS_JSON_LINE(stall_be) \
    CORE_STATS_JSON_LINE(stall_l1d) \
    CORE_STATS_JSON_LINE(stall_l1d_r) \
    CORE_STATS_JSON_LINE(stall_l1d_w) \
    CORE_STATS_JSON_LINE(stall_fe) \
    CORE_STATS_JSON_LINE(stall_l1i) \
    CORE_STATS_JSON_LINE(stall_simd) \
    CORE_STATS_JSON_LINE(stall_load) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow_j) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow_jr) \
    CORE_STATS_JSON_LINE(ret_ctrl_flow_br) \
    CORE_STATS_JSON_LINE(ret_mem) \
    CORE_STATS_JSON_LINE(ret_mem_load) \
    CORE_STATS_JSON_LINE(ret_mem_store) \
    CORE_STATS_JSON_LINE(ret_simd) \
    CORE_STATS_JSON_LINE(ret_simd_arith) \
    CORE_STATS_JSON_LINE(ret_simd_data_fmt) \
    CORE_STATS_JSON_LINE(bp_miss) \
    CORE_STATS_JSON_LINE(l1i_ref) \
    CORE_STATS_JSON_LINE(l1i_miss) \
    CORE_STATS_JSON_LINE(l1i_spec_miss) \
    CORE_STATS_JSON_LINE(l1i_spec_miss_bad) \
    CORE_STATS_JSON_LINE(l1i_spec_miss_good) \
    CORE_STATS_JSON_LINE(l1d_ref) \
    CORE_STATS_JSON_LINE(l1d_ref_r) \
    CORE_STATS_JSON_LINE(l1d_ref_w) \
    CORE_STATS_JSON_LINE(l1d_miss) \
    CORE_STATS_JSON_LINE(l1d_miss_r) \
    CORE_STATS_JSON_LINE(l1d_miss_w) \
    CORE_STATS_JSON_LINE(l1d_writeback) \
    CORE_STATS_JSON_LINE(ret) \
    CORE_STATS_JSON_LINE(cycles) \
    CORE_STATS_JSON_LINE(stalls) \
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
        uint64_t cycles_all;
        uint64_t bad_spec;
        uint64_t stall_be;
        uint64_t stall_l1d;
        uint64_t stall_l1d_r;
        uint64_t stall_l1d_w;
        uint64_t stall_fe;
        uint64_t stall_l1i;
        uint64_t stall_simd;
        uint64_t stall_load;
        uint64_t ret_ctrl_flow;
        uint64_t ret_ctrl_flow_j;
        uint64_t ret_ctrl_flow_jr;
        uint64_t ret_ctrl_flow_br;
        uint64_t ret_mem;
        uint64_t ret_mem_load;
        uint64_t ret_mem_store;
        uint64_t ret_simd;
        uint64_t ret_simd_arith;
        uint64_t ret_simd_data_fmt;
        uint64_t bp_miss;
        uint64_t l1i_ref;
        uint64_t l1i_miss;
        uint64_t l1i_spec_miss;
        uint64_t l1i_spec_miss_bad;
        uint64_t l1i_spec_miss_good;
        uint64_t l1d_ref;
        uint64_t l1d_ref_r;
        uint64_t l1d_ref_w;
        uint64_t l1d_miss;
        uint64_t l1d_miss_r;
        uint64_t l1d_miss_w;
        uint64_t l1d_writeback;
        // derived
        uint64_t ret;
        uint64_t cycles;
        uint64_t stalls;
        uint64_t stall_fe_core;
        uint64_t stall_be_core;
        uint64_t ret_int;
        float_t cpi = -1.0;
        float_t ipc = -1.0;
        // misc
        bool prof_active = false;
    private:
        void summarize() {
            stalls = (bad_spec + stall_be + stall_fe);
            ret = (cycles - stalls);
            ret_int = (ret - ret_simd);
            stall_fe_core = (stall_fe - stall_l1i);
            stall_be_core = (stall_be - stall_l1d);
            if ((cycles > 0) && (ret > 0)) {
                ipc = (TO_F32(ret) / TO_F32(cycles));
                cpi = (1/ipc);
            }
        };
    public:
        void profiling(bool enable) { prof_active = enable; }
        void add_events(const core_events_t* ev) {
            cycles_all++;
            if (!prof_active) return;
            cycles += 1;
            bad_spec += ev->bad_spec;
            stall_be += ev->stall_be;
            stall_l1d += ev->stall_l1d;
            stall_l1d_r += ev->stall_l1d_r;
            stall_l1d_w += ev->stall_l1d_w;
            stall_fe += ev->stall_fe;
            stall_l1i += ev->stall_l1i;
            stall_simd += ev->stall_simd;
            stall_load += ev->stall_load;
            ret_ctrl_flow += ev->ret_ctrl_flow;
            ret_ctrl_flow_j += ev->ret_ctrl_flow_j;
            ret_ctrl_flow_jr += ev->ret_ctrl_flow_jr;
            ret_ctrl_flow_br += ev->ret_ctrl_flow_br;
            ret_mem += ev->ret_mem;
            ret_mem_load += ev->ret_mem_load;
            ret_mem_store += ev->ret_mem_store;
            ret_simd += ev->ret_simd;
            ret_simd_arith += ev->ret_simd_arith;
            ret_simd_data_fmt += ev->ret_simd_data_fmt;
            bp_miss += ev->bp_miss;
            l1i_ref += ev->l1i_ref;
            l1i_miss += ev->l1i_miss;
            l1i_spec_miss += ev->l1i_spec_miss;
            l1i_spec_miss_bad += ev->l1i_spec_miss_bad;
            l1i_spec_miss_good += ev->l1i_spec_miss_good;
            l1d_ref += ev->l1d_ref;
            l1d_ref_r += ev->l1d_ref_r;
            l1d_ref_w += ev->l1d_ref_w;
            l1d_miss += ev->l1d_miss;
            l1d_miss_r += ev->l1d_miss_r;
            l1d_miss_w += ev->l1d_miss_w;
            l1d_writeback += ev->l1d_writeback;
        }
        void show_tda() {
            summarize();
            std::cout << "Cycles: " << cycles
                      << ", Inst: " <<  ret
                      << ", Stalls: " <<  stalls
                      << std::fixed << std::setprecision(3)
                      << ", CPI: " <<  cpi
                      << " (IPC: " <<  ipc << ")"
                      << "\n" << INDENT << "TDA:\n"
                      << INDENT << INDENT << "L1: "
                      << "Bad Spec: " <<  bad_spec
                      << ", FE: " <<  stall_fe
                      << ", BE: " <<  stall_be
                      << ", Retired: " <<  ret << "\n"
                      << INDENT << INDENT << "L2: "
                      << "FE Mem: " <<  stall_l1i
                      << ", FE Core: " << stall_fe_core
                      << ", BE Mem: " <<  stall_l1d
                      << ", BE Core: " <<  stall_be_core
                      << ", INT: " <<  ret_int
                      << ", SIMD: " <<  ret_simd;
        }
        void show_all() {
            float_t amat_l1i, amat_l1d, hits;
            hits = (l1i_ref - l1i_miss);
            amat_l1i = ((hits + stall_l1i) / hits);
            hits = (l1d_ref - l1d_miss);
            amat_l1d = ((hits + stall_l1d) / hits);
            std::cout
                << "Control Flow: " << ret_ctrl_flow
                << " - J: " << ret_ctrl_flow_j
                << ", JR: " << ret_ctrl_flow_jr
                << ", BR: " << ret_ctrl_flow_br
                << "\n" << INDENT << "Memory: " << ret_mem
                << " - Load: " << ret_mem_load
                << ", Store: " << ret_mem_store
                << "\n" << INDENT << "SIMD: " << ret_simd
                << " - Arith: " << ret_simd_arith
                << ", Data Format: " << ret_simd_data_fmt
                << "\n" << INDENT << "Stall -"
                << " SIMD: " << stall_simd
                << ", Load: " << stall_load
                << "\n" << INDENT << "bpred -"
                << " M: " << bp_miss
                << "\n" << INDENT << "icache -"
                << " A: " << l1i_ref
                << ", M: " << l1i_miss
                << ", SM (G/B): " << l1i_spec_miss
                << "(" << l1i_spec_miss_good << "/" << l1i_spec_miss_bad << ")"
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
            hw_ofs << CORE_STATS_JSON_ENTRY;
        }
        uint64_t get_total_insts() const {
            return ret;
        }
        uint64_t get_cycles_all() const {
            return cycles_all;
        }
};
