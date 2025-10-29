`include "ama_riscv_defines.svh"

typedef struct {
    int unsigned cycle;
    int unsigned inst;
    int unsigned hw_stall;
} perf_counters_t;

class perf_stats;
    function new(ref perf_counters_t cnt);
        reset(cnt);
    endfunction

    function void reset(ref perf_counters_t cnt);
        cnt.cycle = 0;
        cnt.inst = 0;
        cnt.hw_stall = 0;
    endfunction

    function void update(ref perf_counters_t cnt, input logic inst_retired);
        cnt.cycle++;
        cnt.inst += inst_retired;
        cnt.hw_stall += !inst_retired;
    endfunction

    function string get(ref perf_counters_t cnt);
        string s = "";
        real cpi, ipc;
        if (cnt.cycle == 0) begin
            s = $sformatf("No stats collected\n");
            return s;
        end

        cpi = real'(cnt.cycle) / real'(cnt.inst);
        ipc = 1/cpi;
        s = "DUT Performance stats: \n";
        s = {s, $sformatf(
                {"    Cycles: %0d, Instr: %0d, Stall cycles: %0d,",
                 " CPI: %0.3f (IPC: %0.3f)\n"},
                cnt.cycle, cnt.inst, cnt.hw_stall, cpi, ipc)
            };

        return s;
    endfunction

    function int unsigned get_inst_cnt(ref perf_counters_t cnt);
        return cnt.inst;
    endfunction

endclass
