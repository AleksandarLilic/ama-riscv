`include "ama_riscv_defines.svh"

typedef struct {
    longint unsigned cycle;
    longint unsigned inst;
    longint unsigned empty;
} core_counters_t;

virtual class core_stats;
    static function void reset(ref core_counters_t cnt);
        cnt.cycle = 0;
        cnt.inst = 0;
        cnt.empty = 0;
    endfunction

    static function void update(ref core_counters_t cnt, input logic inst_retired);
        cnt.cycle++;
        cnt.inst += inst_retired;
        cnt.empty += !inst_retired;
    endfunction

    static function string get(ref core_counters_t cnt);
        string s = "";
        real cpi, ipc;
        if (cnt.cycle == 0) begin
            s = $sformatf("No stats collected\n");
            return s;
        end

        cpi = real'(cnt.cycle) / real'(cnt.inst);
        ipc = 1/cpi;
        s = "Core stats: \n";
        s = {s, $sformatf(
                {"    Cycles: %0d, Inst: %0d, Empty: %0d,",
                 " CPI: %0.3f (IPC: %0.3f)"},
                cnt.cycle, cnt.inst, cnt.empty, cpi, ipc)
            };

        return s;
    endfunction

    static function longint unsigned get_inst_cnt(ref core_counters_t cnt);
        return cnt.inst;
    endfunction

    static function longint unsigned get_cycle_cnt(ref core_counters_t cnt);
        return cnt.cycle;
    endfunction

    static function real get_kinst(ref core_counters_t cnt);
        return (cnt.inst / 1000.0);
    endfunction

endclass
