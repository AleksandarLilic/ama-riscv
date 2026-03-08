#pragma once

#include "defines.h"
#include "hw_model_types.h"
#include "dpi_functions.h"

/*
json_out = [
    ["bad_spec", None, 367],
    ["frontend", "icache", 996],
    ["frontend", "core", 303],
    ["backend", "dcache", 2593],
    ["backend", "core", 84],
    ["retiring", "integer", 32126],
    ["retiring", "simd", 6304],
]
 */

#define CORE_STATS_JSON_LINE_LAST(l1, l2, val) \
    JSON_N << "[\"" << l1 << "\", \"" << l2 << "\", " << val << "]"

#define CORE_STATS_JSON_LINE(l1, l2, val) \
    CORE_STATS_JSON_LINE_LAST(l1, l2, val) << "," <<

#define CORE_STATS_JSON_ENTRY(st) \
    CORE_STATS_JSON_LINE("bad_spec", "None", st->bad_spec) \
    CORE_STATS_JSON_LINE("frontend", "icache", st->fe_ic) \
    CORE_STATS_JSON_LINE("frontend", "core", st->fe_core) \
    CORE_STATS_JSON_LINE("backend", "dcache", st->be_dc) \
    CORE_STATS_JSON_LINE("backend", "core", st->be_core) \
    CORE_STATS_JSON_LINE("retiring", "integer", st->ret_int) \
    CORE_STATS_JSON_LINE("retiring", "simd", st->ret_simd) \
    CORE_STATS_JSON_LINE("cnt", "ret_ctrl_flow", st->ret_ctrl_flow) \
    CORE_STATS_JSON_LINE("cnt", "ret_ctrl_flow_j", st->ret_ctrl_flow_j) \
    CORE_STATS_JSON_LINE("cnt", "ret_ctrl_flow_jr", st->ret_ctrl_flow_jr) \
    CORE_STATS_JSON_LINE("cnt", "ret_ctrl_flow_br", st->ret_ctrl_flow_br) \
    CORE_STATS_JSON_LINE("cnt", "ret_mem", st->ret_mem) \
    CORE_STATS_JSON_LINE("cnt", "ret_mem_load", st->ret_mem_load) \
    CORE_STATS_JSON_LINE("cnt", "ret_mem_store", st->ret_mem_store) \
    CORE_STATS_JSON_LINE("cnt", "ret_simd_arith", st->ret_simd_arith) \
    CORE_STATS_JSON_LINE("cnt", "ret_simd_data_fmt", st->ret_simd_data_fmt) \
    CORE_STATS_JSON_LINE("cnt", "core_stall_simd", st->core_stall_simd) \
    CORE_STATS_JSON_LINE("cnt", "core_stall_load", st->core_stall_load) \
    CORE_STATS_JSON_LINE("cnt", "l1i_ref", st->l1i_ref) \
    CORE_STATS_JSON_LINE("cnt", "l1i_miss", st->l1i_miss) \
    CORE_STATS_JSON_LINE("cnt", "l1i_spec_miss", st->l1i_spec_miss) \
    CORE_STATS_JSON_LINE("cnt", "l1i_spec_miss_bad", st->l1i_spec_miss_bad) \
    CORE_STATS_JSON_LINE("cnt", "l1i_spec_miss_good", st->l1i_spec_miss_good) \
    CORE_STATS_JSON_LINE("cnt", "l1d_ref", st->l1d_ref) \
    CORE_STATS_JSON_LINE("cnt", "l1d_miss", st->l1d_miss) \
    CORE_STATS_JSON_LINE_LAST("cnt", "l1d_writeback", st->l1d_writeback)

/*
Core stats:
    Cycles: 940, Instr: 727, Stall cycles: 213, CPI: 1.293 (IPC: 0.773)
TDA:
    L1: bad spec 57, fe bound 132, be bound 20, retiring 733
    L2: fe mem 95, fe core 37, be mem 20, be core 0, int 733, simd 0
 */
struct core_stats_t {
    private:
        // tda
        uint64_t bad_spec;
        uint64_t be;
        uint64_t be_dc;
        uint64_t be_core;
        uint64_t fe;
        uint64_t fe_ic;
        uint64_t fe_core;
        uint64_t ret_simd;
        uint64_t ret_int;
        uint64_t ret;
        uint64_t cycles;
        uint64_t stalls;
        uint64_t cycles_all;
        // other
        uint64_t ret_ctrl_flow;
        uint64_t ret_ctrl_flow_j;
        uint64_t ret_ctrl_flow_jr;
        uint64_t ret_ctrl_flow_br;
        uint64_t ret_mem;
        uint64_t ret_mem_load;
        uint64_t ret_mem_store;
        uint64_t ret_simd_arith;
        uint64_t ret_simd_data_fmt;
        uint64_t core_stall_simd;
        uint64_t core_stall_load;
        uint64_t l1i_ref;
        uint64_t l1i_miss;
        uint64_t l1i_spec_miss;
        uint64_t l1i_spec_miss_bad;
        uint64_t l1i_spec_miss_good;
        uint64_t l1d_ref;
        uint64_t l1d_miss;
        uint64_t l1d_writeback;
        // summary
        float_t cpi = -1.0;
        float_t ipc = -1.0;
        // misc
        bool prof_active = false;
        static constexpr uint64_t bad_spec_penalty = 2;
    private:
        void summarize() {
            stalls = (bad_spec + be + fe);
            ret = (cycles - stalls);
            ret_int = (ret - ret_simd);
            fe_core = (fe - fe_ic);
            be_core = (be - be_dc);
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
            // tda
            bad_spec += (ev->bad_spec * bad_spec_penalty);
            fe += ev->fe;
            fe_ic += ev->fe_ic;
            be += ev->be;
            be_dc += ev->be_dc;
            ret_simd += ev->ret_simd;
            cycles += 1;
            // others
            ret_ctrl_flow += ev->ret_ctrl_flow;
            ret_ctrl_flow_j += ev->ret_ctrl_flow_j;
            ret_ctrl_flow_jr += ev->ret_ctrl_flow_jr;
            ret_ctrl_flow_br += ev->ret_ctrl_flow_br;
            ret_mem += ev->ret_mem;
            ret_mem_load += ev->ret_mem_load;
            ret_mem_store += ev->ret_mem_store;
            ret_simd_arith += ev->ret_simd_arith;
            ret_simd_data_fmt += ev->ret_simd_data_fmt;
            core_stall_simd += ev->core_stall_simd;
            core_stall_load += ev->core_stall_load;
            l1i_ref += ev->l1i_ref;
            l1i_miss += ev->l1i_miss;
            l1i_spec_miss += ev->l1i_spec_miss;
            l1i_spec_miss_bad += ev->l1i_spec_miss_bad;
            l1i_spec_miss_good += ev->l1i_spec_miss_good;
            l1d_ref += ev->l1d_ref;
            l1d_miss += ev->l1d_miss;
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
                      << ", FE: " <<  fe
                      << ", BE: " <<  be
                      << ", Retired: " <<  ret << "\n"
                      << INDENT << INDENT << "L2: "
                      << "FE Mem: " <<  fe_ic
                      << ", FE Core: " << fe_core
                      << ", BE Mem: " <<  be_dc
                      << ", BE Core: " <<  be_core
                      << ", INT: " <<  ret_int
                      << ", SIMD: " <<  ret_simd;
        }
        void show_all() {
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
                << " SIMD: " << core_stall_simd
                << ", Load: " << core_stall_load
                << "\n" << INDENT << "icache -"
                << " A: " << l1i_ref
                << ", M: " << l1i_miss
                << ", SM (G/B): " << l1i_spec_miss
                << "(" << l1i_spec_miss_good << "/" << l1i_spec_miss_bad << ")"
                << "\n" << INDENT << "dcache -"
                << " A: " << l1d_ref
                << ", M: " << l1d_miss
                << ", WB: " << l1d_writeback;
        };
        void log(std::ofstream& hw_ofs) const {
            hw_ofs << CORE_STATS_JSON_ENTRY(this);
        }
        uint64_t get_total_insts() const {
            return ret;
        }
        uint64_t get_cycles_all() const {
            return cycles_all;
        }
};
