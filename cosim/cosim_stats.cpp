
#include "cosim_stats.h"

void cosim_stats::profiling(bool enable) {
    core_stats.profiling(enable);
    icache_stats.profiling(enable);
    dcache_stats.profiling(enable);
    bp_stats.profiling(enable);
}

void cosim_stats::show() {
    std::cout << "Simulation cycles: " << core_stats.get_cycles_all() << "\n";
    std::cout << "Stats - Profiling Summary (approx.):\n";
    std::cout << "core";
    std::cout << "\n" << INDENT;
    core_stats.show();
    std::cout << "\n";

    std::cout << "bpred";
    std::cout << "\n" << INDENT;
    bp_stats.summarize(core_stats.get_total_insts());
    bp_stats.show();
    std::cout << "\n";

    std::cout << "icache";
    std::cout << "\n" << INDENT;
    icache_stats.show(cache_type_t::inst);
    std::cout << "\n";

    std::cout << "dcache";
    std::cout << "\n" << INDENT;
    dcache_stats.show(cache_type_t::data);
    std::cout << "\n\n";
}

void cosim_stats::log_core_event(const core_events_t* ev) {
    core_stats.add_events(ev);
}

void cosim_stats::log_icache_event(const hw_events_t* ev) {
    mem_op_t atype = mem_op_t::read;
    if (ev->aref) {
        icache_stats.referenced(atype, ev->size);
        if (ev->hit) icache_stats.hit(atype);
        else if (ev->miss) icache_stats.miss(atype);
        // FIXME: warning?
    }
}

void cosim_stats::log_dcache_event(const hw_events_t* ev) {
    mem_op_t atype = (ev->load) ? mem_op_t::read : mem_op_t::write;
    if (ev->aref) {
        //stats.replace(act_line.metadata.dirty); // not needed atm
        dcache_stats.referenced(atype, ev->size);
        if (ev->hit) dcache_stats.hit(atype);
        else if (ev->miss) {
            dcache_stats.miss(atype);
            if (ev->wb) dcache_stats.writeback();
        }
    }
}

void cosim_stats::log_bp_event(const hw_events_t* ev) {
    if (ev->aref) bp_stats.collect(ev->hit);
}

void cosim_stats::log_hw_stats(std::string out_dir) {
    std::ofstream ofs;
    ofs.open(out_dir + "hw_stats.json");
    ofs << "{\n";

    ofs << "\"" << "core" << "\"" << ": [";
    core_stats.log(ofs);
    ofs << "\n],\n";

    ofs << "\"" << "icache" << "\"" << ": {";
    icache_stats.log(ofs);
    ofs << "\n},\n";

    ofs << "\"" << "dcache" << "\"" << ": {";
    dcache_stats.log(ofs);
    ofs << "\n},\n";

    ofs << "\"" << "bpred" << "\"" << ": {";
    bp_stats.log(ofs);
    ofs << "\n},";

    ofs << "\n\"_done\": true"; // to avoid trailing comma
    ofs << "\n}\n";
    ofs.close();
}
