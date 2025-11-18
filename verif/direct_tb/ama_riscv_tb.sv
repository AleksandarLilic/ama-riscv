`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"
`include "ama_riscv_perf.svh"

`define TB ama_riscv_tb

module `TB();

`ifdef ENABLE_COSIM
// imported functions/tasks
import "DPI-C" task
cosim_setup(
    input string test_bin,
    input int unsigned prof_pc_start,
    input int unsigned prof_pc_stop,
    input int unsigned prof_pc_single_match,
    input byte unsigned prof_trace,
    input byte unsigned log_isa_sim
);

import "DPI-C" function
void cosim_exec(
    input longint unsigned clk_cnt,
    input longint unsigned mtime,
    output int unsigned pc,
    output int unsigned inst,
    output int unsigned tohost,
    output string inst_asm_str,
    output string stack_top_str,
    output int unsigned rf[32]
);

import "DPI-C" function
void cosim_add_te(
    input longint unsigned clk_cnt,
    input int unsigned inst_ret,
    input int unsigned pc_ret,
    input int unsigned x2_sp,
    input int unsigned dmem_addr,
    input byte dmem_size,
    input byte branch_taken,
    input byte ic_hm,
    input byte dc_hm,
    input byte bp_hm,
    input byte ct_imem_core,
    input byte ct_imem_mem,
    input byte ct_dmem_core_r,
    input byte ct_dmem_core_w,
    input byte ct_dmem_mem_r,
    input byte ct_dmem_mem_w
);

import "DPI-C" function
int unsigned cosim_get_inst_cnt();

import "DPI-C" function
void cosim_finish();
`endif // ENABLE_COSIM

//------------------------------------------------------------------------------
// Testbench variables
int unsigned errors = 0;
int unsigned warnings = 0;
bit errors_for_wave = 1'b0;
logic tohost_source;
bit chk_pass_tohost = 1'b1;
bit chk_pass_cosim = 1'b1;

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

string core_ret;
string isa_ret;

longint unsigned clk_cnt = 0;
logic [ARCH_WIDTH_D-1:0] mtime_d[3];
logic [ARCH_WIDTH_D-1:0] clk_cnt_d[3];

typedef struct {
    string test_path;
    bit tohost_chk_en;
    bit cosim_chk_en;
    bit stop_on_cosim_error;
    int unsigned timeout_clocks;
    int unsigned log_level;
    int unsigned prof_pc_start;
    int unsigned prof_pc_stop;
    int unsigned prof_pc_single_match;
    bit prof_trace;
    bit log_isa_sim;
} plusargs_t;

plusargs_t args;

// uart
string uart_out;
int uart_char; // wider than char so it can fit and print specials like newline

// events
event go_in_reset;
event reset_end;

// cosim
bit [RF_NUM-1:0] rf_chk_act;
localparam int SLEN = 32; // number of characters in the string

typedef struct {
    int unsigned pc;
    int unsigned inst;
    int unsigned tohost;
    int unsigned rf[RF_NUM];
    logic [8*SLEN-1:0] stack_top_str_wave;
    logic [8*SLEN-1:0] inst_asm_str_wave;
} cosim_t;

typedef struct {
    string inst_asm;
    string stack_top;
} cosim_str_t;

cosim_t cosim;
cosim_str_t cosim_str;

// perf
typedef struct {
    int unsigned ref_cnt = 'h0;
    int unsigned hit_cnt = 'h0;
    int unsigned miss_cnt = 'h0;
    int unsigned wb_cnt = 'h0;
} stats_counters_t;

stats_counters_t ic_stats, dc_stats, bp_stats;
perf_stats stats;
perf_counters_t core_stats;

//------------------------------------------------------------------------------
// DUT
logic clk = 1;
logic rst;
logic inst_retired;
logic uart_serial_in;
logic uart_serial_out;
ama_riscv_top #(.CLOCK_FREQ (CLOCK_FREQ), .UART_BR (BR_921600)) `DUT ( .* );

// bind to a specific instance
bind `CORE ama_riscv_core_view ama_riscv_core_view_i (
    .clk (clk),
    .rst (rst),
    .dmem_req (dmem_req),
    .inst_retired (inst_retired),
    // internal
    .ctrl_dec_exe (ctrl_dec_exe),
    .ctrl_exe_mem (ctrl_exe_mem),
    .ctrl_mem_wbk (ctrl_mem_wbk),
    .ctrl_wbk_ret (ctrl_wbk_ret),
    .inst_ret (inst_ret),
    .pc_ret (pc_ret),
    .decoded_exe (decoded_exe),
    .branch_resolution (branch_resolution),
    .csr_tohost (csr.tohost),
    `ifdef USE_BP
    .bp_hit (bp_hit),
    `endif
    .dc_stalled (dc_stalled)
);

rv_if #(.DW(8)) recv_rsp_ch ();
rv_if #(.DW(8)) send_req_ch (); // not in use, but required for instantiation
`ifndef UART_SHORTCUT
uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BR_921600)
) uart_host (
    .clk (clk),
    .rst (rst),
    .send_req (send_req_ch.RX),
    .recv_rsp (recv_rsp_ch.TX),
    // NOTE: lines are cross connected from first UART
    .serial_in (uart_serial_out),
    .serial_out (uart_serial_in)
);
`else
assign recv_rsp_ch.valid = 1'b0;
`endif

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

function automatic void load_memories;
    input string test_hex_path;
    int fd;
    begin
        `ifdef FPGA_SYNT
        `LOG_W({"Build targeting FPGA, memory preloaded in RTL, ",
                "-testplusarg 'test_path' ignored"}, 1);
        return;
        `endif
        fd = open_file(test_hex_path, "r"); // check that it can be opened
        $fclose(fd); // and close for the readmemh to use it
        $readmemh(test_hex_path, `MEM_ARRAY, 0, MEM_SIZE_Q-1);
        `LOG_D("Finished loading main memory");
    end
endfunction

`ifdef ENABLE_COSIM
function void cosim_check_inst_cnt;
    int unsigned cosim, core;
    cosim = cosim_get_inst_cnt();
    core = stats.get_inst_cnt(core_stats);
    `LOGNT($sformatf("Cosim instruction count: %0d", cosim));
    `LOGNT($sformatf("DUT instruction count: %0d", core));
    if (cosim != core) `LOGNT($sformatf("Instruction count mismatch"));
endfunction
`endif

function automatic void check_test_status(input bit completed);
    string msg;

    begin
        if (completed) `LOGNT("\nTest ran to completion");
        else `LOGNT("\nTest failed to complete");

        msg = {"Checker 1/2 - 'tohost': "};
        if (args.tohost_chk_en) begin
            msg = {msg, "ENABLED: "};
            if (completed) begin // tohost meaningless unless test completes
                chk_pass_tohost = (`CORE.csr.tohost === `TOHOST_PASS);
                msg = {msg, chk_pass_tohost ? "PASS" : "FAIL"};
                if (!chk_pass_tohost) begin
                    `LOGNT($sformatf("'tohost' failed # %0d",
                                     `CORE.csr.tohost[31:1]));
                end
            end else begin
                msg = {msg, "invalid result, test didn't complete"};
            end
        end else begin
            msg = {msg, "DISABLED"};
        end
        `LOGNT(msg);

        `ifdef ENABLE_COSIM
        msg = {"Checker 2/2 - 'cosim' : "};
        if (args.cosim_chk_en) begin
            msg = {msg, "ENABLED: "};
            msg = {msg, chk_pass_cosim ? "PASS" : "FAIL"};
        end else begin
            msg = {msg, "DISABLED"};
        end
        `LOGNT(msg);
        `endif

        if (!completed) begin
            `LOGNT(msg_fail);
        end else if (args.tohost_chk_en || args.cosim_chk_en) begin
            if (chk_pass_cosim && chk_pass_tohost) `LOGNT(msg_pass);
            else `LOGNT(msg_fail);
        end else begin
            `LOGNT_W("Neither 'tohost' nor 'cosim' checker is enabled", 1);
        end

        `LOGNT($sformatf("Warnings: %2d", warnings));
        `LOGNT($sformatf("Errors:   %2d\n", errors));
    end
endfunction

`ifdef ENABLE_COSIM
// TODO: inst checker should be 'inst_width_t'
function void checker_t;
    // TODO: for back-annotated GLS, timing has to be taken into account,
    // so might revert to task, or disable checkers for GLS
    input string name;
    input bit active;
    input arch_width_t dut_val;
    input arch_width_t model_val;
    begin
        if (active && (dut_val !== model_val)) begin
            chk_pass_cosim = 1'b0;
            `LOG_E($sformatf(
                "Mismatch @ %0t. Checker: \"%0s\"; DUT: 0x%8h, Model: 0x%8h",
                $time, name, dut_val, model_val),
                1
            );
        end
    end
endfunction

function bit cosim_run_checkers;
    input bit [RF_NUM-1:0] rf_chk_act;
    int unsigned checker_errors_prev;
    begin
        checker_errors_prev = errors;
        checker_t("pc", `CHK_ACT, `CORE.pc_ret, cosim.pc);
        checker_t("inst", `CHK_ACT, `CORE.inst_ret, cosim.inst);
        checker_t("tohost", `CHK_ACT, `CORE_VIEW.csr_tohost_wbk, cosim.tohost);
        for (int unsigned i = 1; i < RF_NUM; i = i + 1) begin
            checker_t(
                $sformatf("x%0d", i),
                (`CHK_ACT && rf_chk_act[i]),
                `RF.rf[i],
                cosim.rf[i]
            );
        end
        errors_for_wave = (errors != checker_errors_prev);
    end
    return errors_for_wave;
endfunction
`endif

function string strip_extension(string path);
    // strips extension, if it exists, brute-force on last dot
    int dot_pos;
    dot_pos = path.len();
    for (int i = path.len()-1; i >= 0; i--) begin
        if (path[i] == "/") break; // don't go past filename
        if (path[i] == ".") begin
            dot_pos = i;
            break;
        end
    end
    return path.substr(0, dot_pos - 1);
endfunction

function void get_plusargs();
    automatic string log_str;
    begin
        `ifdef FPGA_SYNT
        args.test_path = `TO_STRING(`FPGA_HEX_PATH);
        `else
        if (!$value$plusargs("test_path=%s", args.test_path)) begin
            `LOG_E("test_path not defined. Exiting.", 1);
            $finish();
        end
        `endif
        args.test_path = strip_extension(args.test_path);
        args.tohost_chk_en = $test$plusargs("enable_tohost_checker");

        `ifdef ENABLE_COSIM
        args.cosim_chk_en = $test$plusargs("enable_cosim_checkers");
        args.stop_on_cosim_error = $test$plusargs("stop_on_cosim_error");

        if (!$value$plusargs("prof_pc_start=%h", args.prof_pc_start)) begin
            args.prof_pc_start = 0;
        end
        if (!$value$plusargs("prof_pc_stop=%h", args.prof_pc_stop)) begin
            args.prof_pc_stop = 0;
        end
        if (!$value$plusargs(
            "prof_pc_single_match=%h", args.prof_pc_single_match)) begin
            args.prof_pc_single_match = 0;
        end
        args.prof_trace = $test$plusargs("prof_trace");
        args.log_isa_sim = $test$plusargs("log_isa_sim");
        `endif

        if (!$value$plusargs("timeout_clocks=%d", args.timeout_clocks)) begin
            args.timeout_clocks = `DEFAULT_TIMEOUT_CLOCKS;
        end

        if (!$value$plusargs("log_level=%s", log_str)) begin
            args.log_level = LOG_INFO;
        end else begin
            if      (log_str == "NONE")     args.log_level = LOG_NONE;
            else if (log_str == "ERROR")    args.log_level = LOG_ERROR;
            else if (log_str == "WARN")     args.log_level = LOG_WARN;
            else if (log_str == "INFO")     args.log_level = LOG_INFO;
            else if (log_str == "VERBOSE")  args.log_level = LOG_VERBOSE;
            else if (log_str == "DEBUG")    args.log_level = LOG_DEBUG;
            else begin
                `LOGNT($sformatf(
                    "Unknown log_level=%s, defaulting to INFO", log_str));
                args.log_level = LOG_INFO;
                log_str = "INFO";
            end
            `LOGNT($sformatf("Using log level '%s'", log_str));
        end

        `LOGNT($sformatf("CPU core path: %0s", `TO_STRING(`CORE)));
        `LOGNT($sformatf(
            "Frequency: %.2f MHz", 1.0 / (`CLK_HALF_PERIOD * 2 * 1e-3)));
    end
endfunction

function string trim_after_double_space(string s);
    // keep everything *before* the first of the two spaces
    for (int unsigned i = 0; i < s.len()-1; i++) begin
        if (s[i] == " " && s[i+1] == " ") return s.substr(0, i-1);
    end
    return s;
endfunction

function automatic [8*SLEN-1:0] pack_string(input string str);
    logic [8*SLEN-1:0] packed_str;
    begin
        packed_str = '0;
        // place the characters starting from the highest byte
        for (int unsigned j = 0; j < SLEN && j < str.len(); j = j + 1) begin
            packed_str[(SLEN-1-j)*8 +: 8] = str.getc(j);
        end
        return packed_str;
    end
endfunction

function automatic byte get_cache_status(
    ref stats_counters_t stats,
    input logic new_core_req_d,
    input logic hit_d,
    input logic cr_victim_dirty_d,
    input logic cr_pend_active
);
    byte hm;
    bit hit;
    bit miss;
    bit wb; // writeback
    bit handle_pending_req;
    begin
        hm = hw_status_t_none;

        hit = (new_core_req_d && hit_d);
        miss = (new_core_req_d && !hit_d);
        wb = miss && cr_victim_dirty_d;
        handle_pending_req = ((cr_pend_active && !new_core_req_d));

        if (miss) hm = hw_status_t_miss;
        else if (hit) hm = hw_status_t_hit;

        stats.ref_cnt += (new_core_req_d);
        stats.hit_cnt += hit;
        stats.miss_cnt += miss;
        stats.wb_cnt += wb;

        return hm;
    end
endfunction

function automatic byte get_bp_status(ref stats_counters_t stats);
    byte bp_hm;
    begin
        bp_hm = hw_status_t_none;
        if (`CORE_VIEW.r.branch_inst) begin
            stats.ref_cnt++;
            if (`CORE_VIEW.r.bp_hit) begin
                bp_hm = hw_status_t_hit;
                stats.hit_cnt++;
            end else begin
                bp_hm = hw_status_t_miss;
                stats.miss_cnt++;
            end
        end
        return bp_hm;
    end
endfunction

`ifdef ENABLE_COSIM
function automatic void add_trace_entry(longint unsigned clk_cnt);
    // NOTE: hw stats collected when they happen, inst when retired
    bit imem2core, imem2mem, dmem2core_r, dmem2mem_r, dmem2core_w, dmem2mem_w;
    byte dmem2core_r_s, dmem2core_w_s; // transfer sizes
    // imem, only reads
    imem2core = `ICACHE.rsp_core.valid;
    imem2mem = `ICACHE.rsp_mem.valid;
    // dmem reads
    dmem2core_r = `DCACHE.rsp_core.valid;
    dmem2core_r_s = (`DCACHE.load_dw == DMEM_DTYPE_WORD) ? 4 : `DCACHE.load_dw;
    dmem2mem_r = `DCACHE.rsp_mem.valid;
    // dmem writes
    dmem2core_w = (`DCACHE.store_req_pending || `DCACHE.store_req_hit);
    dmem2core_w_s = $countones(`DCACHE.store_mask_q);
    dmem2mem_w = `DCACHE.req_mem_w.valid;

    cosim_add_te(
        clk_cnt,
        `CORE_VIEW.r.inst,
        `CORE_VIEW.r.pc,
        `RF.rf[RF_X2_SP],
        `CORE_VIEW.r.dmem_addr,
        `CORE_VIEW.r.dmem_size,
        `CORE_VIEW.r.branch_taken,
        get_cache_status(
            ic_stats,
            `ICACHE.new_core_req_d,
            `ICACHE.hit_d,
            1'b0,
            `ICACHE.cr_pend.active
        ),
        get_cache_status(
            dc_stats,
            `DCACHE.new_core_req_d,
            `DCACHE.hit_d,
            `DCACHE.cr_victim_dirty_d,
            `DCACHE.cr_pend.active
        ),
        get_bp_status(bp_stats),
        (imem2core * CORE_DATA_BUS_B), // all instructions are 4 bytes
        (imem2mem * MEM_DATA_BUS_B),
        (dmem2core_r * dmem2core_r_s),
        (dmem2core_w * dmem2core_w_s),
        (dmem2mem_r * MEM_DATA_BUS_B),
        (dmem2mem_w * MEM_DATA_BUS_B)
    );
endfunction
`endif

task automatic single_step();
    bit new_errors;
    stats.update(core_stats, inst_retired);
    `LOG_V($sformatf(
        "Core [F] %5h: %8h %0s",
        `CORE.pc.dec,
        `CORE.imem_rsp.data,
        `CORE.fe_ctrl.bubble_dec ? ("(fe stalled)") : "")
    );

    `ifdef ENABLE_COSIM
    add_trace_entry(clk_cnt - `RST_PULSES); // don't count time in reset
    `endif
    // cosim advances only if rtl retires an instruction
    if (!inst_retired) return;

    `ifdef ENABLE_COSIM
    cosim_exec(clk_cnt_d[2], mtime_d[2], cosim.pc, cosim.inst, cosim.tohost,
               cosim_str.inst_asm, cosim_str.stack_top, cosim.rf);

    core_ret = $sformatf(
        "Core [R] %5h: %8h", `CORE.pc_ret, `CORE.inst_ret);
    isa_ret = $sformatf(
        "COSIM    %5h: %8h %0s", cosim.pc, cosim.inst, cosim_str.inst_asm);
    `LOG_V(core_ret);
    `LOG_V(isa_ret);

    cosim.stack_top_str_wave = pack_string(cosim_str.stack_top);
    cosim.inst_asm_str_wave =
        pack_string(trim_after_double_space(cosim_str.inst_asm));
    if (args.cosim_chk_en) new_errors = cosim_run_checkers(rf_chk_act);
    if (new_errors) begin
        `LOG_E(core_ret, 0);
        `LOG_E(isa_ret, 0);
        if (args.stop_on_cosim_error) begin
            `LOG_I("Exiting on first error");
            check_test_status(1'b0);
            $finish();
        end
    end
    `endif
endtask

task run_test();
    automatic int unsigned clks_to_retire_last_inst = 2;
    while (tohost_source !== 1'b1) begin
        @(posedge clk); #1;
        single_step();
    end

    // retire csr inst writing to tohost
    // thus matching number of executed instructions with isa sim standalone run
    repeat(clks_to_retire_last_inst) begin
        @(posedge clk); #1;
        single_step();
    end
endtask

//------------------------------------------------------------------------------
// setup and run

always #(`CLK_HALF_PERIOD) clk = ~clk;
always @(posedge clk) clk_cnt += 1;

// 3 clk delay between CSR access and inst ret
`DFF_CI_RI_RVI(
    {`CORE.csr.mtime, mtime_d[0], mtime_d[1]},
    {mtime_d[0], mtime_d[1], mtime_d[2]}
)

`DFF_CI_RI_RVI(
    {clk_cnt, clk_cnt_d[0], clk_cnt_d[1]},
    {clk_cnt_d[0], clk_cnt_d[1], clk_cnt_d[2]}
)

initial begin
    // set %t:
    // - scaled in ns (-9),
    // - with 0 precision digits
    // - with the " ns" string
    // - taking up a total of 12 characters, including the string
    $timeformat(-9, 0, " ns", 12);
end

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
    bit is_unknown;
    rf_chk_act = {RF_NUM{1'b0}};
    @reset_end;
    // set bit to active when the corresponding register is first written to
    // checker remains active for the entire test
    // once all checkers are active, disable the setup
    rf_chk_act[0] = 1'b1; // x0 active right away, same as PC and inst
    while (!(&rf_chk_act)) begin
        @(posedge clk);
        dut_rf_addr = `RF.addr_d;
        is_unknown = $isunknown(dut_rf_addr);
        if (is_unknown) begin
            `LOG_E("RF address is unknown value", 1);
        end

        if (!is_unknown && !rf_chk_act[dut_rf_addr] && `RF.we) begin
            #1;
            `LOG_V($sformatf(
                "First write to x%0d. Checker activated", dut_rf_addr));
            rf_chk_act[dut_rf_addr] = 1'b1;
        end
    end

    `LOG_I("All RF checkers active");
end

// Test
assign tohost_source = `CORE.csr.tohost[0];
initial begin
    `LOGNT("");
    get_plusargs();
    stats = new(core_stats);

    `LOG_I("Simulation started");

    `ifdef SYNT
    `ifdef DEBUG
    `LOGNT_W({"Both `SYNT and `DEBUG have been defined, ",
              "but they are incompatibale. `DEBUG is ignored"}, 1);
    `endif
    `endif

    load_memories({args.test_path, ".hex"});
    `ifdef ENABLE_COSIM
    cosim_setup(
        {args.test_path, ".elf"},
        args.prof_pc_start,
        args.prof_pc_stop,
        args.prof_pc_single_match,
        args.prof_trace,
        args.log_isa_sim
    );
    `endif

    ->go_in_reset;
    @reset_end;
    `LOG_I("Reset released");

    //uart_serial_in = 1'b1; // line idle atm
    recv_rsp_ch.ready = 1'b0;
    fork: run_f
    begin: run_test_f
        run_test();
    end
    begin: uart_listen_f
        while (1) begin
            while (!recv_rsp_ch.valid) begin
                @(posedge clk);
                #1;
            end
            uart_char = recv_rsp_ch.data;
            if (uart_char == 'h0A) uart_char = "\\n"; // escape newline
            `LOG_D($sformatf(
                "Host UART received: %h (%0s)",
                recv_rsp_ch.data, uart_char
            ));
            @(posedge clk);
            // Consume data
            recv_rsp_ch.ready = 1'b1;
            @(posedge clk);
            #1;
            recv_rsp_ch.ready = 1'b0;
            @(posedge clk);
            #1;
        end
    end
    begin: catch_timeout_f
        repeat (args.timeout_clocks) @(posedge clk);
        `LOG_E("Test timed out", 1);
        check_test_status(1'b0);
        $finish();
    end
    join_any;
    disable run_f;

    `LOG_I("Simulation finished");
    if (!(&rf_chk_act)) begin
        `LOG_W(
            {"Test finished but not all checkers were activated. ",
             "Something likely went wrong"}, 1);
    end

    `LOGNT("\n=== UART START ===");
    `LOGNT(uart_out);
    `LOGNT("=== UART END ===");

    check_test_status(1'b1);
    `ifdef ENABLE_COSIM
    if (args.cosim_chk_en) cosim_check_inst_cnt();
    cosim_finish();
    `endif
    `LOGNT(stats.get(core_stats));

    // TODO: these stats really need to be consolidated like core stats
    $display(
        "bpred: P: %0d, M: %0d, ACC: %0.2f%%, MPKI: %0.2f",
            bp_stats.hit_cnt,
            bp_stats.miss_cnt,
            (bp_stats.hit_cnt != 0) ?
                (bp_stats.hit_cnt * 100.0) / bp_stats.ref_cnt : 0.0,
            (bp_stats.miss_cnt != 0) ?
                bp_stats.miss_cnt / (stats.get_inst_cnt(core_stats) / 1000.0) :
                0.0
        );
    $display(
        "icache: Ref: %0d, H: %0d, M: %0d, HR: %0.2f%%",
            ic_stats.ref_cnt,
            ic_stats.hit_cnt,
            ic_stats.miss_cnt,
            (ic_stats.ref_cnt != 0) ?
                (ic_stats.hit_cnt * 100.0) / ic_stats.ref_cnt : 0.0
        );
    $display(
        "dcache: Ref: %0d, H: %0d, M: %0d, WB: %0d, HR: %0.2f%%",
            dc_stats.ref_cnt,
            dc_stats.hit_cnt,
            dc_stats.miss_cnt,
            dc_stats.wb_cnt,
            (dc_stats.ref_cnt != 0) ?
                (dc_stats.hit_cnt * 100.0) / dc_stats.ref_cnt : 0.0
        );
    $display("");

    $finish();
end // test

endmodule
