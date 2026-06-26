`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"
`include "ama_riscv_perf.svh"

`define TB ama_riscv_tb

module `TB();

`ifdef ENABLE_COSIM
// cosim execution
import "DPI-C" function void cosim_setup(
    input string test_bin,
    input int unsigned prof_pc_start,
    input int unsigned prof_pc_stop,
    input int unsigned prof_pc_single_match,
    input byte unsigned prof_trace,
    input byte unsigned log_isa_sim,
    output string cosim_out_dir
);

import "DPI-C" function void cosim_exec(
    input longint unsigned clk_cnt,
    output int unsigned pc,
    output int unsigned inst,
    output int unsigned tohost,
    output string inst_asm_str,
    output string stack_top_str,
    output int unsigned rf[32]
);

import "DPI-C" function int unsigned cosim_get_inst_cnt();
import "DPI-C" function void cosim_finish();

import "DPI-C" function void cosim_force_irq(
    input byte unsigned mtip,
    input byte unsigned meip
);

export "DPI-C" function get_rtl_rf_value;

// cosim tracing and stats
import "DPI-C" function void cosim_add_te(
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

import "DPI-C" function void cosim_log_stats(
    core_events_t core,
    hw_events_t icache,
    hw_events_t dcache,
    hw_events_t bp
);

`ifdef ENABLE_KONATA
import "DPI-C" function void konata_open(input string outdir);
import "DPI-C" function void konata_cycle(input longint unsigned cycle);
import "DPI-C" function void konata_inst(input int unsigned id);

import "DPI-C" function void konata_label(
    input int unsigned id,
    input int unsigned pc,
    input int unsigned inst,
    input string inst_asm_str
);

import "DPI-C" function void konata_label_str(
    input int unsigned id,
    input int unsigned lane,
    input string str
);

import "DPI-C" function void konata_start_stage(
    input int unsigned id,
    input string stage
);

import "DPI-C" function void konata_end_stage(
    input int unsigned id,
    input string stage
);

import "DPI-C" function void konata_retire(
    input int unsigned id,
    input int unsigned retire_id,
    input byte unsigned is_flush
);

import "DPI-C" function void konata_close();

`endif // ENABLE_KONATA
`endif // ENABLE_COSIM

//------------------------------------------------------------------------------
// Testbench variables
plusargs_t args;
int unsigned errors = 0;
int unsigned warnings = 0;
bit errors_for_wave = 1'b0;
logic tohost_source;
bit chk_pass_tohost = 1'b1;
bit chk_pass_cosim = 1'b1;
bit completed = 1'b0;
bit core_trapped = 1'b0;
int log_level;

string core_ret;
string core_ret_tag;
string isa_ret;

longint unsigned clk_cnt = 0;
logic [ARCH_WIDTH_D-1:0] clk_cnt_d[3];

// cosim
bit [RF_NUM-1:0] rf_chk_act;
cosim_t cosim;
cosim_str_t cosim_str;
string cosim_outdir;

// konata: dec-id mark + set of fetch-only ids already flushed by spec.wrong
// so the redirect-phantom gap-flush doesn't re-flush them
longint unsigned k_dec_last = 0; // highest konata id that has entered DEC
bit k_done [longint unsigned]; // assoc. array to track IDs that are odne

// perf
hw_counters_t ic_stats, dc_stats, bp_stats;
core_events_t core_events;
tda_counters_t tda;
mem_active_ports_counters_t mem_active_ports;
hw_events_t e_ic, e_dc, e_bp; // so they are available for wave

// works without probing core internally, needed for GLS
core_counters_t core_cnt_main;

// uart
string uart_out;
int uart_char; // wider than char so it can fit and print specials like newline

//------------------------------------------------------------------------------
// DUT

// events
event go_in_reset;
event reset_end;

// DUT and its ports
logic clk = 1;
logic rst;
logic inst_retired;
logic uart_serial_in;
logic uart_serial_out;
ama_riscv_top #(.CLOCK_FREQ (CLOCK_FREQ), .UART_BR (UART_BR_TB)) `DUT (
    .clk,
    .rst,
    .uart_serial_in,
    .uart_serial_out,
    .inst_retired
);

// bind to a specific instance
bind `CORE ama_riscv_core_view ama_riscv_core_view_i (
    .clk,
    .rst,
    .imem_req,
    .imem_rsp,
    .dmem_req,
    .spec,
    .inst_retired,
    // internal
    .ctrl_dec_exe,
    .ctrl_exe_mem,
    .ctrl_mem_wbk,
    .ctrl_wbk_ret,
    .be_stalled_d,
    .decoded_exe,
    .branch_resolution_mem,
    .csr_tohost (`CSR.csr.tohost),
    .dc_stalled
);

rv_if #(.DW(8)) recv_rsp_ch ();
rv_if #(.DW(8)) send_req_ch (); // not in use, but required for instantiation
`ifndef UART_SHORTCUT
uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (UART_BR_TB)
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
assign uart_serial_in = 1'b1; // idle if shortcut is used
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

function automatic void write_test_status(
    input bit passed,
    input bit completed,
    input string reason
);
    int fd;
    fd = $fopen("test.status", "w");
    if (fd == 0) begin
        `LOG_E("Could not open test.status", 1);
        return;
    end

    if (passed) $fwrite(fd, "status=PASSED\n");
    else $fwrite(fd, "status=FAILED\n");

    $fwrite(fd, "completed=%0d\n", completed);
    $fwrite(fd, "tohost=0x%08h\n", `CSR.csr.tohost);
    $fwrite(fd, "tohost_checker=%0d\n", args.tohost_chk_en);
    $fwrite(fd, "tohost_pass=%0d\n", chk_pass_tohost);
    `ifdef ENABLE_COSIM
    $fwrite(fd, "cosim_checker=%0d\n", args.cosim_chk_en);
    $fwrite(fd, "cosim_pass=%0d\n", chk_pass_cosim);
    `else
    $fwrite(fd, "cosim_checker=0\n");
    $fwrite(fd, "cosim_pass=1\n");
    `endif
    $fwrite(fd, "warnings=%0d\n", warnings);
    $fwrite(fd, "errors=%0d\n", errors);
    $fwrite(fd, "reason=%0s\n", reason);

    $fclose(fd);
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

function automatic void check_test_status(input bit completed);
    string msg;
    string reason;
    bit checked;
    bit passed;

    begin
        checked = args.tohost_chk_en;
        `ifdef ENABLE_COSIM
        checked |= args.cosim_chk_en;
        `endif

        if (completed) `LOGNT("\nTest ran to completion");
        else `LOGNT("\nTest failed to complete");

        msg = {"Checker 1/2 - 'tohost': "};
        if (args.tohost_chk_en) begin
            msg = {msg, "ENABLED: "};
            if (completed) begin // tohost meaningless unless test completes
                chk_pass_tohost = (`CSR.csr.tohost === `TOHOST_PASS);
                msg = {msg, chk_pass_tohost ? "PASS" : "FAIL"};
                if (!chk_pass_tohost) begin
                    `LOGNT($sformatf("'tohost' failed # %0d",
                                     `CSR.csr.tohost[31:1]));
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

        passed = (completed && checked && chk_pass_cosim && chk_pass_tohost);
        reason = "none";
        if (!completed) begin
            reason = "test did not complete";
        end else if (!checked) begin
            reason = "no checkers enabled";
        end else if (args.tohost_chk_en && !chk_pass_tohost) begin
            `ifdef ENABLE_COSIM
            if (args.cosim_chk_en && !chk_pass_cosim) begin
                reason = "tohost and cosim failed";
            end else begin
                reason = "tohost failed";
            end
            `else
            reason = "tohost failed";
            `endif
        end
        `ifdef ENABLE_COSIM
        else if (args.cosim_chk_en && !chk_pass_cosim) begin
            reason = "cosim failed";
        end
        `endif

        if (!completed) begin
            `LOGNT(msg_fail);
        end else if (checked) begin
            if (passed) `LOGNT(msg_pass);
            else `LOGNT(msg_fail);
        end else begin
            `LOGNT_W("Neither 'tohost' nor 'cosim' checker is enabled", 1);
        end

        write_test_status(passed, completed, reason);

        `LOGNT($sformatf("Warnings: %2d", warnings));
        `LOGNT($sformatf("Errors:   %2d\n", errors));
    end
endfunction

function automatic void print_mem_ports_stats(mem_active_ports_counters_t mem);
    real perc;
    perc = (real'(mem.all) / real'(mem.any));
    $display(
        "DEBUG: MEM ports - any: %0d, both: %0d (%0.3f%%)\n",
        mem.any, mem.all, perc
    );
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
        checker_t("pc", `CHK_ACT, `CORE.pc.ret, cosim.pc);
        checker_t("inst", `CHK_ACT, `CORE.inst.ret, cosim.inst);
        checker_t("tohost", `CHK_ACT, `CORE_VIEW.csr_tohost_wbk, cosim.tohost);
        for (int unsigned i = 1; i < RF_NUM; i = i + 1) begin
            checker_t(
                $sformatf("x%0d", i),
                (`CHK_ACT && rf_chk_act[i]),
                `RF.rf_v[i],
                cosim.rf[i]
            );
        end
        errors_for_wave = (errors != checker_errors_prev);
    end
    return errors_for_wave;
endfunction

function void cosim_check_inst_cnt;
    int unsigned cosim_i, core_i;
    cosim_i = cosim_get_inst_cnt();
    core_i = core_stats::get_inst_cnt(core_cnt_main);
    if (cosim_i != core_i) begin
        `LOGNT($sformatf("Instruction count mismatch"));
        `LOGNT($sformatf("Cosim instruction count: %0d", cosim_i));
        `LOGNT($sformatf("DUT instruction count: %0d", core_i));
    end
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
        args.konata_en = $test$plusargs("enable_konata");
        args.prof_trace = $test$plusargs("prof_trace");
        args.log_isa_sim = $test$plusargs("log_isa_sim");

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

        `endif

        if (!$value$plusargs("timeout_clocks=%d", args.timeout_clocks)) begin
            args.timeout_clocks = `DEFAULT_TIMEOUT_CLOCKS;
        end

        if (!$value$plusargs("heartbeat_clocks=%d", args.heartbeat_clocks)) begin
            args.heartbeat_clocks = `DEFAULT_HEARTBEAT_CLOCKS;
        end

        if (!$value$plusargs("uart_in=%s", args.uart_in)) begin
            args.uart_in = "";
        end
        `ifdef UART_SHORTCUT
        else begin
            $fatal(1, $sformatf("%0s",
                {"Plusarg 'uart_in' is provided for simulation ",
                "but UART_SHORTCUT (timing ignored) is used for build"}
            ));
        end
        `endif

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

// drive one RX byte into the DUT UART via the host
task automatic uart_send_byte(input logic [7:0] b);
    forever begin
        @(posedge clk); #1;
        if (send_req_ch.ready) break;
    end
    send_req_ch.data = b;
    send_req_ch.valid = 1'b1;
    @(posedge clk); #1; // accept edge: start = valid && ready takes the byte
    send_req_ch.valid = 1'b0;
    // wait out the transmission (ready high again) before the next byte
    forever begin
        @(posedge clk); #1;
        if (send_req_ch.ready) break;
    end
endtask

function string trim_ws(string s);
    // keep everything *before* the first of the two whitespaces
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

function automatic string classify_empty_cycle();
    if (`CORE.cpe.bad_spec) return "lost: bad spec";
    if (`CORE.cpe.stall_be) return "stall: backend";
    if (`CORE.cpe.stall_fe) return "stall: frontend";
    return "lost: other";
endfunction

function automatic hw_events_t
get_cache_status(
    input logic new_core_req,
    input logic hit,
    input logic cr_victim_dirty,
    input logic access_load,
    input byte size
);
    hw_events_t e;
    begin
        e.aref = new_core_req;
        e.hit = (new_core_req && hit);
        e.miss = (new_core_req && !hit);
        e.wb = (e.miss && cr_victim_dirty);
        e.load = access_load;
        e.size = size;
        // e.handle_pending_req = ((cr_pend_active && !new_core_req));

        e.hm = hw_status_t_none;
        if (e.miss) e.hm = hw_status_t_miss;
        else if (e.hit) e.hm = hw_status_t_hit;

        return e;
    end
endfunction

function automatic hw_events_t
get_bp_status(input logic branch_inst, input logic hit);
    hw_events_t e;
    begin
        e.aref = branch_inst;
        e.hit = e.aref && hit;
        e.miss = e.aref && !hit;

        e.hm = hw_status_t_none;
        if (e.miss) e.hm = hw_status_t_miss;
        else if (e.hit) e.hm = hw_status_t_hit;

        return e;
    end
endfunction

function automatic void
add_up_events(ref hw_counters_t cnt, input hw_events_t e);
    cnt.aref += e.aref;
    cnt.hit += e.hit;
    cnt.miss += e.miss;
    cnt.wb += e.wb;
endfunction

`ifdef ENABLE_COSIM
function automatic void
add_trace_entry(longint unsigned clk_cnt, byte ic_hm, byte dc_hm, byte bp_hm);

    // NOTE: hw stats collected when they happen, inst when retired
    bit imem2core, imem2mem, dmem2core_r, dmem2mem_r, dmem2core_w, dmem2mem_w;
    byte dmem2core_r_s, dmem2core_w_s; // transfer sizes
    // imem, only reads
    imem2core = `ICACHE.rsp_core.valid;
    imem2mem = `ICACHE.rsp_mem.valid;
    // dmem reads
    dmem2core_r = `DCACHE.rsp_core.valid;
    dmem2core_r_s = (`DCACHE.load_dw == DMEM_DTYPE_WORD) ? 4 :`DCACHE.load_dw+1;
    dmem2mem_r = `DCACHE.rsp_mem.valid;
    // dmem writes
    dmem2core_w = (`DCACHE.store_req_pending || `DCACHE.store_req_hit);
    dmem2core_w_s = $countones(`DCACHE.store_mask_q);
    dmem2mem_w = `DCACHE.req_mem_w.valid;

    cosim_add_te(
        clk_cnt,
        `CORE_VIEW.r.inst,
        `CORE_VIEW.r.pc,
        `RF.rf_v[RF_X2_SP],
        `CORE_VIEW.r.dmem_addr,
        `CORE_VIEW.r.dmem_size,
        `CORE_VIEW.r.branch_taken,
        ic_hm,
        dc_hm,
        bp_hm,
        (imem2core * CORE_DATA_BUS_B), // all instructions are 4 bytes
        (imem2mem * MEM_DATA_BUS_B),
        (dmem2core_r * dmem2core_r_s),
        (dmem2core_w * dmem2core_w_s),
        (dmem2mem_r * MEM_DATA_BUS_B),
        (dmem2mem_w * MEM_DATA_BUS_B)
    );
endfunction

// CSRs that increment by core logic (time, cycles, uarch counters) can't be
// emulated in a timed environment, so the ISA sim trusts the RTL on them:
// it asks for the retiring CSR instruction's destination register value and
// injects it into its own register file
function int unsigned get_rtl_rf_value(input int unsigned reg_idx);
    logic [4:0] rd;
    logic [2:0] fn3;
    opc7_t opc7;
    rd = get_rd(`CORE.inst.ret, 1'b1);
    fn3 = get_fn3(`CORE.inst.ret);
    opc7 = get_opc7(`CORE.inst.ret);

    // guard against accidental usage/silent ISA-RTL drift
    if (!`CORE.inst_retired) begin
        `LOG_E("get_rtl_rf_value called outside instruction retire", 1);
    //end else if (!((opc7 == OPC7_SYSTEM) && (fn3 != 3'b0))) begin
    //    `LOG_E("get_rtl_rf_value called on a non-CSR instruction", 1);
    end else if (reg_idx !== rd) begin
        `LOG_E($sformatf(
            "get_rtl_rf_value rd mismatch: requested x%0d, RTL retiring x%0d",
            reg_idx, rd),
        1);
    end

    return `RF.rf_v[reg_idx];
endfunction

`ifdef ENABLE_KONATA
function automatic void konata_log_events();
    if (!args.konata_en) return;

    // advance cycle - sets the time for all events this cycle
    konata_cycle(clk_cnt - `RST_PULSES);
    if (`CORE_VIEW.k_valid.fet) begin
        konata_inst(`CORE_VIEW.k_id.fet);
        konata_start_stage(`CORE_VIEW.k_id.fet, "F");
    end

    if (`CORE_VIEW.k_valid.dec) konata_start_stage(`CORE_VIEW.k_id.dec,"D");
    if (`CORE_VIEW.k_valid_s_exe) begin
        konata_start_stage(`CORE_VIEW.k_id.exe, "E");
    end
    if (`CORE_VIEW.k_valid.mem) konata_start_stage(`CORE_VIEW.k_id.mem,"M");
    if (`CORE_VIEW.k_valid.wbk) konata_start_stage(`CORE_VIEW.k_id.wbk,"W");

    // speculative exec gone wrong
    // dec wrong-path entry: doomed in-flight fetch (ic miss) vs already
    // fetched - different label source, but flushed either way
    // k_id.dec here can be a fetch-only wrong-path id (no S D)
    // record so the redirect gap-flush below treats it as already handled
    if (`CORE_VIEW.spec_wrong_on_ic_miss) begin
        konata_retire(`CORE_VIEW.k_id.dec, 0, 1);
        konata_label(`CORE_VIEW.k_id.dec, `CORE.pc_fet_last, 'h0, "");
        k_done[`CORE_VIEW.k_id.dec] = 1'b1;
    end else if (`CORE_VIEW.spec.wrong &&
        (!`CORE_VIEW.spec_wrong_on_jump_exe)
    ) begin
        // if it stalls on jump, nothing to flush
        konata_retire(`CORE_VIEW.k_id.dec, 0, 1);
        konata_label(
            `CORE_VIEW.k_id.dec, `CORE.pc.dec, `CORE.inst.dec, "");
        k_done[`CORE_VIEW.k_id.dec] = 1'b1;
    end

    // exe wrong-path entry: flush only if it holds a real inst (pc.exe!=0)
    // a mispredict over an ic miss can leave exe an empty bubble with
    // k_id.exe still == k_id.dec - flushing then double-retires the dec
    // entry with a pc=0 label
    if (`CORE_VIEW.spec.wrong && (`CORE.pc.exe != 'h0)) begin
        konata_retire(`CORE_VIEW.k_id.exe, 0, 1);
        konata_label(
            `CORE_VIEW.k_id.exe, `CORE.pc.exe, `CORE.inst.exe, "");
    end

    // a trap/mret/wfi redirect can fetch (S F) an id that is then squashed
    // before decode, advancing k_id.dec non-contiguously;
    // flush such skipped ids or they orphan as never-ending F;
    // spec.wrong skips are already flushed above (k_done)
    // before the gap shows up here,
    // so only redirect phantoms reach the flush;
    // delete-on-pass keeps k_done small
    if (`CORE_VIEW.k_valid.dec) begin
        while ((k_dec_last + 1) < `CORE_VIEW.k_id.dec) begin
            k_dec_last = k_dec_last + 1;
            if (!k_done.exists(k_dec_last)) begin
                konata_retire(k_dec_last, 0, 1);
                konata_label(k_dec_last, `CORE.pc_fet_last, 'h0, "");
            end
            k_done.delete(k_dec_last);
        end
        k_dec_last = `CORE_VIEW.k_id.dec;
    end
endfunction

function automatic void konata_log_events_retired();
    if (!args.konata_en) return;

    if (`CORE_VIEW.k_valid.ret) begin
        konata_retire(`CORE_VIEW.k_id.ret, 0, 0);
        konata_label(
            `CORE_VIEW.k_id.ret, cosim.pc, cosim.inst, cosim_str.inst_asm);
        konata_label_str(`CORE_VIEW.k_id.ret, 1, cosim_str.stack_top);
    end
endfunction
`endif

`endif

function automatic void get_perf_events();
    byte dc_bytes;

    core_stats::update(core_cnt_main, inst_retired);

    // mem ports
    mem_active_ports.any += `MEM.ports_active_any;
    mem_active_ports.all += `MEM.ports_active_all;

    // icache
    // never dirty, always load, always 4 byte inst
    e_ic = get_cache_status(`ICACHE.new_core_req, `ICACHE.hit, 1'b0, 1'b1, 4);

    // dcache
    if (`DCACHE.load_req) begin
        dc_bytes = 0;
        case (`DCACHE.cr.dtype)
            DMEM_DTYPE_BYTE,
            DMEM_DTYPE_UBYTE: dc_bytes = 1;
            DMEM_DTYPE_HALF,
            DMEM_DTYPE_UHALF: dc_bytes = 2;
            DMEM_DTYPE_WORD: dc_bytes = 4;
        endcase
    end else begin
        dc_bytes = $countones(`DCACHE.store_mask_q);
    end
    e_dc = get_cache_status(
        `DCACHE.new_core_req,
        `DCACHE.hit,
        `DCACHE.cr_victim_dirty,
        `DCACHE.load_req,
        dc_bytes
    );

    // branch predictor
    e_bp = get_bp_status(`CORE_VIEW.r.branch_inst, `CORE_VIEW.r.bp_hit);

    // add up collected events in their respective structs
    add_up_events(ic_stats, e_ic);
    add_up_events(dc_stats, e_dc);
    add_up_events(bp_stats, e_bp);
endfunction

task automatic single_step();
    bit new_errors;
    get_perf_events();

    `ifdef ENABLE_COSIM
    add_trace_entry((clk_cnt - `RST_PULSES), e_ic.hm, e_dc.hm, e_bp.hm);
    cosim_log_stats(core_events, e_ic, e_dc, e_bp);

    `ifdef ENABLE_KONATA
    konata_log_events();
    `endif

    `endif

    `ifdef ENABLE_COSIM
    // wfi wake without trap: nothing retires or traps this cycle
    // force the isa sim wakeup here as well
    // isa sim's own mstatus state is used to decide wake-vs-trap
    // tb only delivers the raw bit
    if (`TRAP_CTRL.ctrl.wfi_resume) begin
        `LOG_I("Core wfi wakeup (no trap). Forcing Cosim wakeup.");
        cosim_force_irq(8'(`TRAP_CTRL.irq.mtip), 8'(`TRAP_CTRL.irq.meip));
    end
    `endif

    // cosim advances only if rtl retires an instruction
    if (!inst_retired && !`CORE.trap_tag.ret.trapped) begin
        `LOG_V($sformatf(
            "Core empty cycle (%0s)", classify_empty_cycle()));
        return;
    end

    `ifndef SYNT
    core_ret = $sformatf("Core [R] %5h: %8h", `CORE.pc.ret, `CORE.inst.ret);
    `else
    core_ret = $sformatf("Core [R] %8h", `CORE.inst.ret);
    `endif

    core_trapped = `CORE.trap_tag.ret.trapped;
    if (core_trapped) core_ret = $sformatf(
        "Core trapped (mcause %0h)", `TRAP_CTRL.trap_info.mcause
    );

    `LOG_V(core_ret);

    `ifdef ENABLE_COSIM
    // RTL-driven interrupts
    // when RTL takes an interrupt, force the ISS to take the same one
    // mcause[31] = interrupt (vs exception, which the ISS self-takes).
    if (core_trapped && `TRAP_CTRL.trap_info.mcause[31]) begin
        `LOG_I($sformatf(
            "Core trapped on interrupt (mcause %0h). Forcing Cosim trap." ,
            `TRAP_CTRL.trap_info.mcause
        ));
        case (`TRAP_CTRL.trap_info.mcause[30:0])
            31'd7:  cosim_force_irq(8'd1, 8'd0); // MTI
            31'd11: cosim_force_irq(8'd0, 8'd1); // MEI
            default: $fatal(1,
                "cosim: core took unsupported interrupt, mcause=%08h",
                `TRAP_CTRL.trap_info.mcause
            );
        endcase
    end

    cosim_exec(
        clk_cnt_d[2], cosim.pc, cosim.inst, cosim.tohost,
        cosim_str.inst_asm, cosim_str.stack_top, cosim.rf
    );

    isa_ret = $sformatf(
        "COSIM    %5h: %8h %0s", cosim.pc, cosim.inst, cosim_str.inst_asm);
    `LOG_V(isa_ret);

    cosim.stack_top_str_wave = pack_string(cosim_str.stack_top);
    cosim.inst_asm_str_wave = pack_string(trim_ws(cosim_str.inst_asm));

    // trap handled differently, match on the next retired inst
    if (core_trapped) return;

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

    `ifdef ENABLE_KONATA
    konata_log_events_retired();
    `endif

    `endif // ENABLE_COSIM

endtask

function automatic void heartbeat(ref int unsigned inst_ret_prev);
    int unsigned inst_ret, diff;
    if ((clk_cnt % args.heartbeat_clocks) != 0) return;

    inst_ret = core_stats::get_inst_cnt(core_cnt_main);
    diff = (inst_ret - inst_ret_prev);
    inst_ret_prev = inst_ret;
    `LOG_I($sformatf(
        "Heartbeat - cycles: %0d, retired instructions: %0d (+%0d)",
        clk_cnt, inst_ret, diff
    ));
endfunction

task run_test();
    automatic int unsigned clks_to_retire_last_inst = 2;
    automatic int unsigned inst_ret_prev = 0;
    while (tohost_source !== 1'b1) begin
        @(posedge clk); #0.1;
        single_step();
        heartbeat(inst_ret_prev);
    end

    // retire csr inst writing to tohost
    // thus matching number of executed instructions with isa sim standalone run
    repeat(clks_to_retire_last_inst) begin
        @(posedge clk); #0.1;
        single_step();
    end
endtask

//------------------------------------------------------------------------------
// setup and run

always #(`CLK_HALF_PERIOD) clk = ~clk;
always @(posedge clk) clk_cnt += 1;

// delayed clk count fed to cosim_exec for profiling window alignment
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

// perf counters
always_comb begin
    core_events.ret = `CORE.inst_retired;
    core_events.bad_spec = `CORE.perf_events.bad_spec;
    core_events.stall_be = `CORE.perf_events.stall_be;
    core_events.stall_l1d = `CORE.perf_events.stall_l1d;
    core_events.stall_l1d_r = `CORE.perf_events.stall_l1d_r;
    core_events.stall_l1d_w = `CORE.perf_events.stall_l1d_w;
    core_events.stall_fe = `CORE.perf_events.stall_fe;
    core_events.stall_l1i = `CORE.perf_events.stall_l1i;
    core_events.stall_simd = `CORE.perf_events.stall_simd;
    core_events.stall_div = `CORE.perf_events.stall_div;
    core_events.stall_load = `CORE.perf_events.stall_load;
    core_events.ret_ctrl_flow = `CORE.perf_events.ret_ctrl_flow;
    core_events.ret_ctrl_flow_j = `CORE.perf_events.ret_ctrl_flow_j;
    core_events.ret_ctrl_flow_jr = `CORE.perf_events.ret_ctrl_flow_jr;
    core_events.ret_ctrl_flow_br = `CORE.perf_events.ret_ctrl_flow_br;
    core_events.ret_mem = `CORE.perf_events.ret_mem;
    core_events.ret_mem_load = `CORE.perf_events.ret_mem_load;
    core_events.ret_mem_store = `CORE.perf_events.ret_mem_store;
    core_events.ret_simd = `CORE.perf_events.ret_simd;
    core_events.ret_simd_arith = `CORE.perf_events.ret_simd_arith;
    core_events.ret_simd_data_fmt = `CORE.perf_events.ret_simd_data_fmt;
    core_events.bp_miss = `CORE.perf_events.bp_miss;
    core_events.l1i_ref = `CORE.perf_events.l1i_ref;
    core_events.l1i_miss = `CORE.perf_events.l1i_miss;
    core_events.l1i_spec_miss = `CORE.perf_events.l1i_spec_miss;
    core_events.l1i_spec_miss_bad = `CORE.perf_events.l1i_spec_miss_bad;
    core_events.l1d_ref = `CORE.perf_events.l1d_ref;
    core_events.l1d_ref_r = `CORE.perf_events.l1d_ref_r;
    core_events.l1d_ref_w = `CORE.perf_events.l1d_ref_w;
    core_events.l1d_miss = `CORE.perf_events.l1d_miss;
    core_events.l1d_miss_r = `CORE.perf_events.l1d_miss_r;
    core_events.l1d_miss_w = `CORE.perf_events.l1d_miss_w;
    core_events.l1d_writeback = `CORE.perf_events.l1d_writeback;
end

always_ff @(posedge clk) begin
    tda.bad_spec += core_events.bad_spec;
    tda.stall_be += core_events.stall_be;
    tda.stall_l1d += core_events.stall_l1d;
    tda.stall_fe += core_events.stall_fe;
    tda.stall_l1i += core_events.stall_l1i;
    tda.ret_simd += core_events.ret_simd;
    tda.cycles += 1;
end

// Test
assign tohost_source = `CSR.csr.tohost[0];
initial begin
    `LOGNT("");
    get_plusargs();
    core_stats::reset(core_cnt_main);

    `LOG_I("Simulation started");

    `ifdef SYNT
    `ifdef DEBUG
    `LOGNT_W({"Both `SYNT and `DEBUG have been defined, ",
              "but they are incompatibale. `DEBUG is ignored"}, 1);
    `endif
    `endif

    load_memories({args.test_path, ".mem"});

    `ifdef ENABLE_COSIM
    cosim_setup(
        {args.test_path, ".elf"},
        args.prof_pc_start,
        args.prof_pc_stop,
        args.prof_pc_single_match,
        args.prof_trace,
        args.log_isa_sim,
        cosim_outdir
    );
    `ifdef ENABLE_KONATA
    if (args.konata_en) konata_open(cosim_outdir);
    `endif
    `endif

    ->go_in_reset;
    @reset_end;
    `LOG_I("Reset released");

    //uart_serial_in = 1'b1; // line idle atm
    recv_rsp_ch.ready = 1'b0;
    send_req_ch.valid = 1'b0;
    send_req_ch.data = 8'h0;
    fork: run_f
    begin: run_test_f
        run_test();
        completed = 1;
    end
    begin: uart_drive_f
        // feed +uart_in RX bytes to the DUT UART
        // idle forever after so this branch never triggers join_any
        foreach (args.uart_in[i]) uart_send_byte(args.uart_in[i]);
        forever @(posedge clk);
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
        repeat (args.timeout_clocks + 1) @(posedge clk);
        `LOG_E("Test timed out", 1);
        completed = 0;
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

    check_test_status(completed);

    `ifdef ENABLE_COSIM
    if (args.cosim_chk_en) cosim_check_inst_cnt();
    cosim_finish(); // incl. cosim stats
    `ifdef ENABLE_KONATA
    if (args.konata_en) konata_close();
    `endif
    `endif

    `ifdef DEBUG
    print_mem_ports_stats(mem_active_ports);
    `endif

    $display("");

    `ifdef ENABLE_COSIM
    $finish();
    `endif

    `LOGNT(core_stats::get(core_cnt_main));

    // TODO: these really need to be consolidated like core core_stats
    tda.stall_be_core = (tda.stall_be - tda.stall_l1d);
    tda.stall_fe_core = (tda.stall_fe - tda.stall_l1i);
    tda.ret = (tda.cycles - (tda.bad_spec + tda.stall_fe + tda.stall_be));
    tda.ret_int = (tda.ret - tda.ret_simd);
    $display("TDA: ");
    $display(
        "    L1: bad spec %0d, fe bound %0d, be bound %0d, retiring %0d",
        tda.bad_spec, tda.stall_fe, tda.stall_be, tda.ret
    );
    $display(
        "    L2: ",
        "fe mem %0d, fe core %0d, be mem %0d, be core %0d, int %0d, simd %0d",
        tda.stall_l1i, tda.stall_fe_core, tda.stall_l1d, tda.stall_be_core,
        tda.ret_int, tda.ret_simd
    );

    $display(
        "bpred:\n    P: %0d, M: %0d, ACC: %0.2f%%, MPKI: %0.2f",
        bp_stats.hit,
        bp_stats.miss,
        (bp_stats.hit != 0) ?
            ((bp_stats.hit * 100.0) / bp_stats.aref) : 0.0,
        (bp_stats.miss != 0) ?
            (bp_stats.miss / (core_stats::get_kinst(core_cnt_main))) : 0.0
    );

    $display(
        "icache:\n    Ref: %0d, H: %0d, M: %0d, HR: %0.2f%%",
        ic_stats.aref,
        ic_stats.hit,
        ic_stats.miss,
        (ic_stats.aref != 0) ? ((ic_stats.hit * 100.0) / ic_stats.aref) : 0.0
    );

    $display(
        "dcache:\n    Ref: %0d, H: %0d, M: %0d, WB: %0d, HR: %0.2f%%",
        dc_stats.aref,
        dc_stats.hit,
        dc_stats.miss,
        dc_stats.wb,
        (dc_stats.aref != 0) ? ((dc_stats.hit * 100.0) / dc_stats.aref) : 0.0
    );

    $finish();

end // test

endmodule
