#pragma once

#include "defines.h"
#include "hw_model_types.h"
#include "cache_stats.h"
#include "bp_stats.h"

#include "dpi_functions.h"

class cosim_stats {
    public: // TEMP: revert to private, make functions
        cache_stats_t icache_stats;
        cache_stats_t dcache_stats;
        bp_stats_t bp_stats;

    public:
        cosim_stats() : bp_stats("rtl_defines") {};
        void profiling(bool enable);
        void log_icache_event(const hw_events_t* ev);
        void log_dcache_event(const hw_events_t* ev);
        void log_bp_event(const hw_events_t* ev);
        void show(uint64_t total_insts);
        void log_hw_stats(std::string out_dir);
};
