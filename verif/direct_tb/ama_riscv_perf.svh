`include "ama_riscv_defines.svh"

class perf_stats;
    integer unsigned perf_cnt_cycle;
    integer unsigned perf_cnt_instr;
    integer unsigned perf_cnt_empty_cycles;
    integer unsigned perf_cnt_nop;
    integer unsigned perf_cnt_hw_stall;
    integer unsigned perf_cnt_flush;
    real cpi, ipc;
    bit at_least_once;

    function new();
        reset();
    endfunction

    function void reset();
        perf_cnt_cycle = 0;
        perf_cnt_instr = 0;
        perf_cnt_empty_cycles = 0;
        perf_cnt_nop = 0;
        perf_cnt_hw_stall = 0;
        perf_cnt_flush = 0;
        cpi = 0;
        ipc = 0;
        at_least_once = 0;
    endfunction

    function void update(reg [31:0] inst_wb, reg stall_wb);
        at_least_once = 1'b1;
        perf_cnt_cycle++;
        if (inst_wb[6:0] == 7'd0) begin
            perf_cnt_flush++;
        end else if (inst_wb == `NOP) begin
            perf_cnt_nop++;
            if (stall_wb == 1'b1) perf_cnt_hw_stall++;
            else perf_cnt_instr++; // nop in sw
        end else begin
            perf_cnt_instr++;
        end
    endfunction

    /*
    function void compare_dut(bit [31:0] DUT_cycles, bit [31:0] DUT_instr);
        if (perf_cnt_cycle != DUT_cycles) begin
            $display("DUT Cycle count mismatch: Expected %0d, Got %0d",
                     DUT_cycles, perf_cnt_cycle);
        end else begin
            $display("DUT Cycle count match: %0d", perf_cnt_cycle);
        end
        if (perf_cnt_instr != DUT_instr) begin
            $display("DUT Instruction count mismatch: Expected %0d, Got %0d",
                     DUT_instr, perf_cnt_instr);
        end else begin
            $display("DUT Instruction count match: %0d", perf_cnt_instr);
        end
    endfunction
    */

    function string get();
        string sout = "";
        if (at_least_once == 1'b0) begin
            sout = $sformatf("No instructions executed\n");
            return sout;
        end

        cpi = real'(perf_cnt_cycle) / real'(perf_cnt_instr);
        ipc = 1/cpi;
        perf_cnt_empty_cycles = perf_cnt_hw_stall + perf_cnt_flush;
        sout = "DUT Performance stats: \n";
        sout = {sout, $sformatf(
            {"    Cycles: %0d, Instr: %0d, Empty cycles: %0d,",
             " CPI: %0.3f (IPC: %0.3f)\n"},
            perf_cnt_cycle, perf_cnt_instr, perf_cnt_empty_cycles, cpi, ipc)};
        sout = {sout, $sformatf(
            "    SW NOP: %0d, HW Stall: %0d, Flush: %0d\n",
            perf_cnt_nop-perf_cnt_hw_stall, perf_cnt_hw_stall, perf_cnt_flush)};

        return sout;
    endfunction

endclass
