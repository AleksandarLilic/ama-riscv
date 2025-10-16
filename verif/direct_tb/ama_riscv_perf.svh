`include "ama_riscv_defines.svh"

typedef struct {
    integer unsigned cycle;
    integer unsigned inst;
    integer unsigned empty_cycles;
    integer unsigned nop;
    integer unsigned hw_stall;
    integer unsigned flush;
} perf_counters_t;

class perf_stats;
    perf_counters_t cnt;
    real cpi, ipc;
    bit at_least_once;

    function new();
        reset();
    endfunction

    function void reset();
        cnt.cycle = 0;
        cnt.inst = 0;
        cnt.empty_cycles = 0;
        cnt.nop = 0;
        cnt.hw_stall = 0;
        cnt.flush = 0;
        cpi = 0;
        ipc = 0;
        at_least_once = 0;
    endfunction

    function void update(inst_width_t inst_wb, logic stall_wb);
        at_least_once = 1'b1;
        cnt.cycle++;
        if (inst_wb[6:0] == 7'd0) begin
            cnt.flush++;
        end else if (inst_wb == `NOP) begin
            cnt.nop++;
            if (stall_wb == 1'b1) cnt.hw_stall++;
            else cnt.inst++; // nop in sw
        end else begin
            cnt.inst++;
        end
    endfunction

    function string get();
        string sout = "";
        if (at_least_once == 1'b0) begin
            sout = $sformatf("No instuctions executed\n");
            return sout;
        end

        cpi = real'(cnt.cycle) / real'(cnt.inst);
        ipc = 1/cpi;
        cnt.empty_cycles = cnt.hw_stall + cnt.flush;
        sout = "DUT Performance stats: \n";
        sout = {sout, $sformatf(
            {"    Cycles: %0d, Instr: %0d, Empty cycles: %0d,",
             " CPI: %0.3f (IPC: %0.3f)\n"},
            cnt.cycle, cnt.inst, cnt.empty_cycles, cpi, ipc)};
        sout = {sout, $sformatf(
            "    SW NOP: %0d, HW Stall: %0d, Flush: %0d\n",
            (cnt.nop - cnt.hw_stall), cnt.hw_stall, cnt.flush)};

        return sout;
    endfunction

    function integer unsigned get_inst();
        return cnt.inst;
    endfunction

endclass
