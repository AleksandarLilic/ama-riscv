`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"
`include "ama_riscv_perf.svh"

module ama_riscv_core_top_tb();

`ifdef ENABLE_COSIM

// imported functions/tasks
import "DPI-C" task
cosim_setup(input string test_bin);

import "DPI-C" function
void cosim_exec(
    input longint unsigned clk_cnt,
    output int unsigned pc,
    output int unsigned inst,
    output string inst_asm_str,
    output string stack_top_str,
    output int unsigned rf[32]
);

import "DPI-C" function
void cosim_add_te(
    input longint unsigned clk_cnt,
    input int unsigned inst_wbk,
    input int unsigned pc_wbk,
    input int unsigned x2_sp,
    input byte dmem_addr,
    input byte dmem_size,
    input byte branch_taken,
    input byte ic_hm,
    input byte dc_hm,
    input byte bp_hm
);

import "DPI-C" function
int unsigned cosim_get_inst_cnt();

import "DPI-C" function
void cosim_finish();
`endif // ENABLE_COSIM

//------------------------------------------------------------------------------
// Testbench variables
string test_path;
int errors = 0;
int warnings = 0;
bit errors_for_wave = 1'b0;
bit cosim_chk_en = 1'b0;
bit stop_on_cosim_error = 1'b0;
logic tohost_source;
int unsigned timeout_clocks;
int unsigned half_period;
real frequency;
int log_level;

// events
event ev_load_stim;
event ev_load_vector;
event ev_load_vector_done;
event go_in_reset;
event reset_end;

// cosim
int unsigned cosim_pc;
int unsigned cosim_inst;
string cosim_inst_asm_str;
string cosim_stack_top_str;
int unsigned cosim_rf[32];
logic [31:0] rf_chk_act;

//------------------------------------------------------------------------------
// DUT I/O
logic clk = 0;
logic rst;
//logic mmio_instr_cnt;
//logic mmio_cycle_cnt;
logic inst_wb_nop_or_clear;
logic mmio_reset_cnt;

//------------------------------------------------------------------------------
// DUT instance
ama_riscv_core_top DUT_ama_riscv_core_top_i (
    .clk,
    .rst,
    .inst_wb_nop_or_clear,
    .mmio_reset_cnt
);

//------------------------------------------------------------------------------
// Testbench functions

function automatic int open_file(string name, string op);
    int fd;
    begin
        fd = $fopen(name, op);
        if (fd == 0) begin
            $error($sformatf("Error: Could not open file %0s", name));
            $finish();
        end
    end
    return fd;
endfunction

//string log_name = "run.log";
//int log_fd = open_file(log_name, "w");

function automatic void load_memories;
    input string test_hex_path;
    int fd;
    begin
        fd = open_file(test_hex_path, "r"); // check that it can be opened
        $fclose(fd); // and close for the readmemh to use it
        $readmemh(test_hex_path, `DUT_IMEM, 0, MEM_SIZE_W-1);
        $readmemh(test_hex_path, `DUT_DMEM, 0, MEM_SIZE_W-1);
    end
endfunction

`ifdef ENABLE_COSIM
function void cosim_check_inst_cnt;
    `LOGNT($sformatf("Cosim instruction count: %0d", cosim_get_inst_cnt()));
    `LOGNT($sformatf("DUT instruction count: %0d", stats.get_inst()));
    if (cosim_get_inst_cnt() != stats.get_inst()) begin
        `LOGNT($sformatf("Instruction count mismatch"));
    end
endfunction
`endif

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

function automatic void check_test_status();
    automatic bit status_cosim = 1'b1;
    automatic bit status_tohost = 1'b1;
    automatic bit checker_exists = 1'b0;

    begin
        `LOGNT("\nTest ran to completion");
        if (`TOHOST_CHECK == 1'b1) begin
            `LOGNT("TOHOST checker enabled");
            checker_exists = 1'b1;
            if (`DUT_CORE.csr_tohost !== `TOHOST_PASS) begin
                status_tohost = 1'b0;
                `LOGNT($sformatf(
                    "Failed tohost test # : %0d",`DUT_CORE.csr_tohost[31:1]));
            end
        end

        `ifdef ENABLE_COSIM
        if (cosim_chk_en == 1'b1) begin
            `LOGNT("Cosim checker enabled");
            `LOGNT($sformatf("Warnings: %2d", warnings));
            `LOGNT($sformatf("Errors:   %2d", errors));
            checker_exists = 1'b1;
            if (errors > 0) begin
                status_cosim = 1'b0;
                `LOGNT($sformatf("Test failed: cosim errors = %0d", errors));
            end
        end
        `endif

        if (checker_exists == 1'b1) begin
            if (status_cosim && status_tohost) `LOGNT(msg_pass);
            else `LOGNT(msg_fail);
        end else begin
            `LOGNT("Neither 'TOHOST' nor 'cosim' checker are enabled");
        end
    end
endfunction

`ifdef ENABLE_COSIM
`include "checkers.svh"
`endif

function void get_plusargs();
    automatic string tmp_str;
    begin
        if (!$value$plusargs("test_path=%s", test_path)) begin
            `LOG_E("test_path not defined. Exiting.");
            $finish();
        end
        `ifdef ENABLE_COSIM
        if ($test$plusargs("enable_cosim_checkers")) cosim_chk_en = 1'b1;
        if ($test$plusargs("stop_on_cosim_error")) stop_on_cosim_error = 1'b1;
        `endif
        if (!$value$plusargs("timeout_clocks=%d", timeout_clocks)) begin
            timeout_clocks = `DEFAULT_TIMEOUT_CLOCKS;
        end
        if (!$value$plusargs("half_period=%d", half_period)) begin
            half_period = `DEFAULT_HALF_PERIOD;
        end
        if (!$value$plusargs("log_level=%s", tmp_str)) begin
            log_level = LOG_INFO;
        end else begin
            if      (tmp_str == "NONE")     log_level = LOG_NONE;
            else if (tmp_str == "ERROR")    log_level = LOG_ERROR;
            else if (tmp_str == "WARN")     log_level = LOG_WARN;
            else if (tmp_str == "INFO")     log_level = LOG_INFO;
            else if (tmp_str == "VERBOSE")  log_level = LOG_VERBOSE;
            else if (tmp_str == "DEBUG")    log_level = LOG_DEBUG;
            else begin
                `LOGNT($sformatf(
                    "Unknown log_level=%s, defaulting to INFO", tmp_str));
                log_level = LOG_INFO;
                tmp_str = "INFO";
            end
            `LOGNT($sformatf("Using log level '%s'", tmp_str));
        end
        `LOGNT($sformatf("CPU core path: %0s", `TO_STRING(`DUT_CORE)));
        `LOGNT($sformatf("Frequency: %.2f MHz", 1.0 / (half_period * 2 * 1e-3)));
    end
endfunction

/*
// Log to file
int lclk_cnt = 0;
initial begin
    forever begin
        @(posedge clk);
        #1;
        lclk_cnt = lclk_cnt + 1;
        $fwrite(fd, "clk: ");
        $fwrite(fd, "%0d", lclk_cnt);
        $fwrite(fd, "; Inst WB: ");
        $fdisplay(fd, "%8x", `DUT_CORE.inst.p.wbk );
    end
end
*/

localparam int SLEN = 32;
logic [8*SLEN-1:0] cosim_stack_top_str_wave;

function automatic [8*SLEN-1:0] pack_string(input string str);
    logic [8*SLEN-1:0] packed_str;
    integer j;
    begin
        packed_str = '0;
        // place the characters starting from the highest byte
        for (j = 0; j < SLEN && j < str.len(); j = j + 1) begin
            packed_str[(SLEN-1-j)*8 +: 8] = str.getc(j);
        end
        return packed_str;
    end
endfunction

`ifdef USE_CACHES
integer miss_cnt = 'h0; // move to a struct?
function automatic byte get_icache_status();
    byte ic_hm;
    bit ic_miss;
    bit ic_service_pending_req;
    bit ic_hit;
    begin
        ic_hm = hw_status_t_none;

        ic_miss = (
            ((`DUT_IC.state == IC_READY)) &&
            (`DUT_IC.nx_state == IC_MISS)
        );
        ic_service_pending_req = (
            (`DUT_IC.pending_req && !`DUT_IC.new_core_req)
        );
        ic_hit = (`DUT_IC.new_core_req && `DUT_IC.hit_d);
        if (ic_miss) ic_hm = hw_status_t_miss;
        else if (ic_service_pending_req || ic_hit) ic_hm = hw_status_t_hit;
        miss_cnt += ic_miss;

        return ic_hm;
    end
endfunction

function automatic byte get_dcache_status();
    byte dc_hm;
    begin
        dc_hm = hw_status_t_none;
        // TODO: to be implemented, no dcache atm
        return dc_hm;
    end
endfunction
`endif

`ifdef USE_BP
function automatic byte get_bp_status();
    byte bp_hm;
    begin
        bp_hm = hw_status_t_none;
        // TODO: to be implemented, no bp atm
        return bp_hm;
    end
endfunction
`endif

function automatic void add_trace_entry(longint unsigned clk_cnt);
    byte unsigned dc_hm;
    byte unsigned bp_hm;
    begin
        dc_hm = hw_status_t_none;
        bp_hm = hw_status_t_none;

        cosim_add_te(
            clk_cnt,
            `DUT_CORE.inst.p.wbk & ~{32{`DUT_CORE.inst_wb_nop_or_clear}},
            `DUT_CORE.pc.p.wbk & ~{32{`DUT_CORE.inst_wb_nop_or_clear}},
            `DUT_RF.rf[2],

            1'b0, // FIXME: temp tied to 0. dmem_addr
            1'b0, // FIXME: temp tied to 0. dmem size
            1'b0, // FIXME: temp tied to 0. `DUT_DEC.branch_taken_wbk,

            `ifdef USE_CACHES
            get_icache_status(),
            get_dcache_status(),
            `else
            hw_status_t_none, // no icache
            hw_status_t_none, // no dcache
            `endif

            `ifdef USE_BP
            get_bp_status()
            `else
            hw_status_t_none // no bp
            `endif
        );
    end
endfunction

string core_ret;
string isa_ret;

task automatic single_step(longint unsigned clk_cnt);
    stats.update(`DUT_CORE.inst.p.wbk, `DUT_CORE.bubble_track[2]);
    `LOG_V($sformatf(
        "Core [F] %5h: %8h %0s",
        `DUT_CORE.pc.p.dec,
        `DUT_CORE.imem_rsp.data,
        `DUT_CORE.bubble_decoder ? ("(fe stalled)") : "")
    );

    `ifdef ENABLE_COSIM
    add_trace_entry(clk_cnt);
    `endif
    // cosim advances only if rtl retires an instruction
    if (`DUT_CORE.inst_wb_nop_or_clear == 1'b1) return;

    `ifdef ENABLE_COSIM
    cosim_exec(clk_cnt, cosim_pc, cosim_inst,
               cosim_inst_asm_str, cosim_stack_top_str, cosim_rf);

    core_ret = $sformatf(
        "Core [R] %5h: %8h", `DUT_CORE.pc.p.wbk, `DUT_CORE.inst.p.wbk);
    isa_ret = $sformatf(
        "COSIM    %5h: %8h %0s", cosim_pc, cosim_inst, cosim_inst_asm_str);
    `LOG_V(core_ret);
    `LOG_V(isa_ret);

    cosim_stack_top_str_wave = pack_string(cosim_stack_top_str);
    if (cosim_chk_en == 1'b1) cosim_run_checkers(rf_chk_act);
    if (stop_on_cosim_error == 1'b1 && errors > 0) begin
        `LOG_E(core_ret);
        `LOG_E(isa_ret);
        `LOG_I("Exiting on first error");
        `LOGNT(msg_fail);
        $finish();
    end
    `endif
endtask

task run_test();
    automatic int unsigned clks_to_retire_csr_inst = 1;
    automatic longint unsigned clk_cnt = 0;
    while (tohost_source !== 1'b1) begin
        @(posedge clk); #1;
        clk_cnt += 1;
        single_step(clk_cnt);
    end

    repeat(clks_to_retire_csr_inst) begin // retire csr inst to match isa sim
        @(posedge clk); #1;
        clk_cnt += 1;
        single_step(clk_cnt);
    end

endtask

// clk gen
always #(half_period) clk = ~clk;

initial begin
    // set %t:
    // - scaled in ns (-9),
    // - with 0 precision digits
    // - with the " ns" string
    // - taking up a total of 12 characters, including the string
    //
    $timeformat(-9, 0, " ns", 12);
end

// Reset handler
initial begin
    @go_in_reset;
    #1;
    rst = 1;
    repeat (`RST_PULSES) @(posedge clk);
    #1;
    rst = 0;
    ->reset_end;
end

// checker setup
logic [4:0] dut_rf_addr;
initial begin
    rf_chk_act = 32'h0;
    @reset_end;
    // set bit to active when the corresponding register is first written to
    // checker remains active for the entire test
    // once all checkers are active, disable the setup
    rf_chk_act[0] = 1'b1; // x0 active right away, same as PC and inst
    while (!(&rf_chk_act)) begin
        @(posedge clk);
        dut_rf_addr = `DUT_RF.addr_d;
        if ((rf_chk_act[dut_rf_addr] == 1'b0) && (`DUT_RF.we)) begin
            #1;
            `LOG_V($sformatf(
                "First write to x%0d. Checker activated", dut_rf_addr));
            rf_chk_act[dut_rf_addr] = 1'b1;
        end
    end
    `LOG_I("All RF checkers active");
end

// Test
assign tohost_source = `DUT_CORE.csr_tohost[0];
perf_stats stats;
initial begin
    `LOGNT("");
    get_plusargs();
    stats = new();

    `LOG_I("Simulation started");
    load_memories({test_path, ".hex"});
    `ifdef ENABLE_COSIM
    cosim_setup({test_path, ".elf"});
    `endif

    ->go_in_reset;
    @reset_end;
    `LOG_I("Reset released");

    fork: run_f
    begin
        run_test();
    end
    begin
        repeat (timeout_clocks) @(posedge clk);
        `LOG_E("Test timed out");
        `LOGNT(msg_fail);
        $finish();
    end
    join_any;
    disable run_f;

    `LOG_I("Simulation finished");
    if (!(&rf_chk_act)) begin
        `LOG_W(
            {"Test finished but not all checkers were activated. ",
             "Something likely went wrong"});
    end

    check_test_status();
    `ifdef ENABLE_COSIM
    if (cosim_chk_en == 1'b1) cosim_check_inst_cnt();
    cosim_finish();
    `endif
    `LOGNT(stats.get());
    //stats.compare_dut(mmio_cycle_cnt, mmio_instr_cnt);
    $finish();
end // test

endmodule
