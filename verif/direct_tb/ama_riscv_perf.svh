`include "ama_riscv_defines.svh"

typedef struct {
    int unsigned cycle;
    int unsigned inst;
    int unsigned hw_stall;
    bit at_least_once;
} perf_counters_t;

class perf_stats;
    int unsigned empty_cycles;
    real cpi, ipc;

    function new(ref perf_counters_t cnt);
        reset(cnt);
    endfunction

    function void reset(ref perf_counters_t cnt);
        cnt.cycle = 0;
        cnt.inst = 0;
        cnt.hw_stall = 0;
        cnt.at_least_once = 0;
    endfunction

    function void update(ref perf_counters_t cnt, input logic inst_retired);
        cnt.at_least_once = 1'b1;
        cnt.cycle++;
        cnt.inst += inst_retired;
        cnt.hw_stall += !inst_retired;
    endfunction

    function string get(ref perf_counters_t cnt);
        string sout = "";
        if (cnt.at_least_once == 1'b0) begin
            sout = $sformatf("No stats collected\n");
            return sout;
        end

        cpi = real'(cnt.cycle) / real'(cnt.inst);
        ipc = 1/cpi;
        sout = "DUT Performance stats: \n";
        sout = {sout, $sformatf(
            {"    Cycles: %0d, Instr: %0d, Stall cycles: %0d,",
             " CPI: %0.3f (IPC: %0.3f)\n"},
            cnt.cycle, cnt.inst, cnt.hw_stall, cpi, ipc)};

        return sout;
    endfunction

    function int unsigned get_inst_cnt(ref perf_counters_t cnt);
        return cnt.inst;
    endfunction

endclass
