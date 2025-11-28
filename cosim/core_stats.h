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

// rest can be added if needed, but all info is provided as is, just add up
#define CORE_STATS_JSON_ENTRY(stat_struct) \
    JSON_N << "[\"bad_spec\", \"None\", " << stat_struct->bad_spec << "]," \
    JSON_N << "[\"frontend\", \"icache\", " << stat_struct->fe_ic << "]," \
    JSON_N << "[\"frontend\", \"core\", " << stat_struct->fe_core << "]," \
    JSON_N << "[\"backend\", \"dcache\", " << stat_struct->be_dc << "]," \
    JSON_N << "[\"backend\", \"core\", " << stat_struct->be_core << "]," \
    JSON_N << "[\"retiring\", \"integer\", " << stat_struct->ret_int << "]," \
    JSON_N << "[\"retiring\", \"simd\", " << stat_struct->ret_simd << "]"

/*
Core stats:
    Cycles: 940, Instr: 727, Stall cycles: 213, CPI: 1.293 (IPC: 0.773)
TDA:
    L1: bad spec 57, fe bound 132, be bound 20, retiring 733
    L2: fe mem 95, fe core 37, be mem 20, be core 0, int 733, simd 0
 */
struct core_stats_t {
    private:
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
        float_t cpi = -1.0;
        float_t ipc = -1.0;
        bool prof_active = false;
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
            if (!prof_active) return;
            bad_spec += ev->bad_spec;
            fe += ev->fe;
            fe_ic += ev->fe_ic;
            be += ev->be;
            be_dc += ev->be_dc;
            ret_simd += ev->ret_simd;
            cycles += 1;
        }
        void show() {
            summarize();
            std::cout << "Cycles: " << cycles
                      << ", Inst: " <<  ret
                      << ", Stalls: " <<  stalls
                      << std::fixed << std::setprecision(3)
                      << ", CPI: " <<  cpi
                      << " (IPC: " <<  ipc << ")"
                      << "\n" << INDENT << "TDA\n" << INDENT << INDENT << "L1: "
                      << "Bad Spec: " <<  bad_spec
                      << ", FE: " <<  fe
                      << ", BE: " <<  be
                      << ", Retired: " <<  ret
                      << "\n" << INDENT << INDENT << "L2: "
                      << "FE Mem: " <<  fe_ic
                      << ", FE Core: " << fe_core
                      << ", BE Mem: " <<  be_dc
                      << ", BE Core: " <<  be_core
                      << ", INT: " <<  ret_int
                      << ", SIMD: " <<  ret_simd;
        }
        void log(std::ofstream& hw_ofs) const {
            hw_ofs << CORE_STATS_JSON_ENTRY(this);
        }
        uint64_t get_total_insts() const {
            return ret;
        }
};
