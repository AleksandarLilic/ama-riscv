`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"
`include "ama_riscv_perf.svh"

`define TB ama_riscv_tb

module `TB();

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
int unsigned errors = 0;
int unsigned warnings = 0;
bit errors_for_wave = 1'b0;
bit cosim_chk_en = 1'b0;
bit stop_on_cosim_error = 1'b0;
logic tohost_source;
int unsigned timeout_clocks;
int unsigned log_level;

// uart
string uart_out;
int uart_char; // wider than char so it can fit and print specials like newline

// events
event go_in_reset;
event reset_end;

// cosim
int unsigned cosim_pc;
int unsigned cosim_inst;
string cosim_inst_asm_str;
string cosim_stack_top_str;
int unsigned cosim_rf[RF_NUM];
bit [RF_NUM-1:0] rf_chk_act;

// perf
typedef struct {
    integer unsigned ref_cnt = 'h0;
    integer unsigned hit_cnt = 'h0;
    integer unsigned miss_cnt = 'h0;
    integer unsigned wb_cnt = 'h0;
} cache_stats_counters_t;

cache_stats_counters_t ic_stats;
cache_stats_counters_t dc_stats;
perf_stats stats;
perf_counters_t core_stats;

//------------------------------------------------------------------------------
// DUT
logic clk = 0;
logic rst;
logic inst_retired;
logic uart_serial_in;
logic uart_serial_out;
ama_riscv_top #(.CLOCK_FREQ (CLOCK_FREQ), .UART_BR (BR_921600)) `DUT ( .* );

rv_if #(.DW(8)) recv_rsp_ch ();
rv_if #(.DW(8)) dummy_send_req_ch ();
uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BR_921600)
) uart_host (
    .clk (clk),
    .rst (rst),
    .send_req (dummy_send_req_ch.RX),
    .recv_rsp (recv_rsp_ch.TX),
    // NOTE: lines are cross connected from first UART
    .serial_in (uart_serial_out),
    .serial_out (uart_serial_in)
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

// TODO: rework for uart output?
//string log_name = "run.log";
//int log_fd = open_file(log_name, "w");

function automatic void load_memories;
    input string test_hex_path;
    int fd;
    begin
        fd = open_file(test_hex_path, "r"); // check that it can be opened
        $fclose(fd); // and close for the readmemh to use it
        $readmemh(test_hex_path, `MEM_ARRAY, 0, MEM_SIZE_Q-1);
        `LOG_D("Finished loading main memory");
    end
endfunction

`ifdef ENABLE_COSIM
function void cosim_check_inst_cnt;
    `LOGNT($sformatf("Cosim instruction count: %0d", cosim_get_inst_cnt()));
    `LOGNT($sformatf("DUT instruction count: %0d", stats.get_inst(core_stats)));
    if (cosim_get_inst_cnt() != stats.get_inst(core_stats)) begin
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
            if (`CORE.csr.tohost !== `TOHOST_PASS) begin
                status_tohost = 1'b0;
                `LOGNT($sformatf(
                    "Failed tohost test # : %0d",`CORE.csr.tohost[31:1]));
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
// TODO: inst checker should be 'inst_width_t'
function void checker_t;
    // TODO: for back-annotated GLS, timing has to be taken into account,
    // so might revert to task, or disable checkers for GLS
    input string name;
    input bit active;
    input arch_width_t dut_val;
    input arch_width_t model_val;
    begin
        if (active == 1'b1 && dut_val !== model_val) begin
            `LOG_E($sformatf(
                "Mismatch @ %0t. Checker: \"%0s\"; DUT: 0x%8h, Model: 0x%8h",
                $time, name, dut_val, model_val)
            );
        end
    end
endfunction

function void cosim_run_checkers;
    input bit [RF_NUM-1:0] rf_chk_act;
    int unsigned checker_errors_prev;
    begin
        checker_errors_prev = errors;
        checker_t("pc", `CHECKER_ACTIVE, `CORE.pc.wbk, cosim_pc);
        checker_t("inst", `CHECKER_ACTIVE, `CORE.inst.wbk, cosim_inst);
        for (int i = 1; i < RF_NUM; i = i + 1) begin
            checker_t(
                $sformatf("x%0d", i),
                `CHECKER_ACTIVE && rf_chk_act[i],
                `RF.rf[i],
                cosim_rf[i]
            );
        end
        errors_for_wave = (errors != checker_errors_prev);
    end
endfunction
`endif

function string strip_extension(string test_path);
    // strips extension, if it exists, brute-force on last dot
    int dot_pos;
    dot_pos = test_path.len();
    for (int i = test_path.len()-1; i >= 0; i--) begin
        if (test_path[i] == ".") begin
            dot_pos = i;
            break;
        end
    end
    return test_path.substr(0, dot_pos - 1);
endfunction

function void get_plusargs();
    automatic string log_str;
    begin
        if (!$value$plusargs("test_path=%s", test_path)) begin
            `LOG_E("test_path not defined. Exiting.");
            $finish();
        end
        test_path = strip_extension(test_path);
        `ifdef ENABLE_COSIM
        if ($test$plusargs("enable_cosim_checkers")) cosim_chk_en = 1'b1;
        if ($test$plusargs("stop_on_cosim_error")) stop_on_cosim_error = 1'b1;
        `endif
        if (!$value$plusargs("timeout_clocks=%d", timeout_clocks)) begin
            timeout_clocks = `DEFAULT_TIMEOUT_CLOCKS;
        end
        if (!$value$plusargs("log_level=%s", log_str)) begin
            log_level = LOG_INFO;
        end else begin
            if      (log_str == "NONE")     log_level = LOG_NONE;
            else if (log_str == "ERROR")    log_level = LOG_ERROR;
            else if (log_str == "WARN")     log_level = LOG_WARN;
            else if (log_str == "INFO")     log_level = LOG_INFO;
            else if (log_str == "VERBOSE")  log_level = LOG_VERBOSE;
            else if (log_str == "DEBUG")    log_level = LOG_DEBUG;
            else begin
                `LOGNT($sformatf(
                    "Unknown log_level=%s, defaulting to INFO", log_str));
                log_level = LOG_INFO;
                log_str = "INFO";
            end
            `LOGNT($sformatf("Using log level '%s'", log_str));
        end
        `LOGNT($sformatf("CPU core path: %0s", `TO_STRING(`CORE)));
        `LOGNT($sformatf(
            "Frequency: %.2f MHz", 1.0 / (`CLK_HALF_PERIOD * 2 * 1e-3)));
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
        $fdisplay(fd, "%8x", `CORE.inst.wbk );
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

function automatic byte get_cache_status(
    ref cache_stats_counters_t stats,
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

`ifdef ENABLE_COSIM
function automatic void add_trace_entry(longint unsigned clk_cnt);
    byte unsigned dc_hm;
    byte unsigned bp_hm;
    begin
        dc_hm = hw_status_t_none;
        bp_hm = hw_status_t_none;

        cosim_add_te(
            clk_cnt,
            `CORE.inst.wbk & {ARCH_WIDTH{inst_retired}},
            `CORE.pc.wbk & {ARCH_WIDTH{inst_retired}},
            `RF.rf[2],

            1'b0, // FIXME: temp tied to 0. dmem_addr
            1'b0, // FIXME: temp tied to 0. dmem size
            1'b0, // FIXME: temp tied to 0. `DEC.branch_taken_wbk,

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

            `ifdef USE_BP
            get_bp_status(),
            `else
            hw_status_t_none // no bp
            `endif
        );
    end
endfunction
`endif

string core_ret;
string isa_ret;
task automatic single_step(longint unsigned clk_cnt);
    stats.update(core_stats, `CORE.inst.wbk, (inst_retired == 1'b0));
    `LOG_V($sformatf(
        "Core [F] %5h: %8h %0s",
        `CORE.pc.dec,
        `CORE.imem_rsp.data,
        `CORE.fe_ctrl.bubble_dec ? ("(fe stalled)") : "")
    );

    `ifdef ENABLE_COSIM
    add_trace_entry(clk_cnt);
    `endif
    // cosim advances only if rtl retires an instruction
    if (inst_retired == 1'b0) return;

    `ifdef ENABLE_COSIM
    cosim_exec(clk_cnt, cosim_pc, cosim_inst,
               cosim_inst_asm_str, cosim_stack_top_str, cosim_rf);

    core_ret = $sformatf(
        "Core [R] %5h: %8h", `CORE.pc.wbk, `CORE.inst.wbk);
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
always #(`CLK_HALF_PERIOD) clk = ~clk;

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
    rf_chk_act = {RF_NUM{1'b0}};
    @reset_end;
    // set bit to active when the corresponding register is first written to
    // checker remains active for the entire test
    // once all checkers are active, disable the setup
    rf_chk_act[0] = 1'b1; // x0 active right away, same as PC and inst
    while (!(&rf_chk_act)) begin
        @(posedge clk);
        dut_rf_addr = `RF.addr_d;
        if ((rf_chk_act[dut_rf_addr] == 1'b0) && (`RF.we)) begin
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
    load_memories({test_path, ".hex"});
    `ifdef ENABLE_COSIM
    cosim_setup({test_path, ".elf"});
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
            while (recv_rsp_ch.valid == 1'b0) begin
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

    `LOGNT("\n=== UART START ===");
    `LOGNT(uart_out);
    `LOGNT("=== UART END ===");

    check_test_status();
    `ifdef ENABLE_COSIM
    if (cosim_chk_en == 1'b1) cosim_check_inst_cnt();
    cosim_finish();
    `endif
    `LOGNT(stats.get(core_stats));

    $display("icache Ref: %0d, H: %0d, M: %0d, HR: %0.2f%%",
             ic_stats.ref_cnt, ic_stats.hit_cnt, ic_stats.miss_cnt,
             (ic_stats.ref_cnt != 0) ?
                (ic_stats.hit_cnt*100.0)/ic_stats.ref_cnt : 0.0);
    $display("dcache Ref: %0d, H: %0d, M: %0d, WB: %0d, HR: %0.2f%%",
             dc_stats.ref_cnt, dc_stats.hit_cnt,
             dc_stats.miss_cnt, dc_stats.wb_cnt,
             (dc_stats.ref_cnt != 0) ?
                (dc_stats.hit_cnt*100.0)/dc_stats.ref_cnt : 0.0);
    $display("");

    `LOGNT($sformatf("cycles: %0d", `CORE.csr.mcycle));
    `LOGNT($sformatf("instret: %0d", `CORE.csr.minstret));

    $finish();
end // test

endmodule
