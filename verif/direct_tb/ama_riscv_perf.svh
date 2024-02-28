`include "ama_riscv_defines.v"

class perf_stats;
    integer unsigned perf_cnt_cycle;
    integer unsigned perf_cnt_instr;
    integer unsigned perf_cnt_empty_cycles;
    integer unsigned perf_cnt_nop;
    //integer unsigned perf_cnt_stall; // TODO: differentiate between hw and sw stall
    integer unsigned perf_cnt_flush;
    real unsigned cpi;
    bit at_least_once;

    function new();
        reset();
    endfunction

    function void reset();
        perf_cnt_cycle = 0;
        perf_cnt_instr = 0;
        perf_cnt_empty_cycles = 0;
        perf_cnt_nop = 0;
        perf_cnt_flush = 0;
        cpi = 0;
        at_least_once = 0;
    endfunction

    function void update(reg [31:0] inst_wb);
        at_least_once = 1'b1;
        perf_cnt_cycle++;
        if (inst_wb == `NOP) perf_cnt_nop++;
        else if (inst_wb[6:0] == 7'd0) perf_cnt_flush++;
        else perf_cnt_instr++;
    endfunction

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

    function void display();
        if (at_least_once == 1'b0) begin
            $display("No instructions executed");
            return;
        end
        cpi = real'(perf_cnt_cycle) / real'(perf_cnt_instr);
        perf_cnt_empty_cycles = perf_cnt_nop + perf_cnt_flush;
        $display("Performance stats: ");
        $display("    Cycles: %0d, Instr: %0d, Empty cycles: %0d, CPI: %0.3f", 
                 perf_cnt_cycle, perf_cnt_instr, perf_cnt_empty_cycles, cpi);
        $display("    NOP: %0d, Flush: %0d", perf_cnt_nop, perf_cnt_flush);
    endfunction

endclass
