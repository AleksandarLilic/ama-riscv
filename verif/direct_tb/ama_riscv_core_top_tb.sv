`include "ama_riscv_defines.svh"
`include "ama_riscv_perf.svh"

`define DEFAULT_HALF_PERIOD 5 // ns

// TB
`define TOHOST_CHECK 1'b1
`define DEFAULT_TIMEOUT_CLOCKS 5_000_000
`define RST_PULSES 2
// per checker enable defines
`define CHECKER_ACTIVE 1'b1
`define CHECKER_INACTIVE 1'b0

`define DUT DUT_ama_riscv_core_top_i
`define DUT_IMEM `DUT.ama_riscv_imem_i.mem
`define DUT_DMEM `DUT.ama_riscv_dmem_i.mem
`define DUT_CORE `DUT.ama_riscv_core_i
`define DUT_DEC `DUT_CORE.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF `DUT_CORE.ama_riscv_reg_file_i

`define TOHOST_PASS 32'd1

`define INST_ASM_LEN 80 // must match #define in dpi wrapper

`define TO_STRING(x) `"x`"
`define LOG(x) $display("%0t: %0s", $time, x)
`define LOG_WARNING(x) \
    warnings += 1; \
    `LOG($sformatf("WARNING: %0s", x))
`define LOGNT(x) $display("%0s", x)
//`define LOG(x) $fwrite(log_fd, "%0t: %0s\n", $time, x)
//`define LOGNT(x) $fwrite(log_fd, "%0s\n", x)

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
    output int unsigned rf[32]);

import "DPI-C" function
unsigned int cosim_get_inst_cnt();

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
        $readmemh(test_hex_path, `DUT_IMEM, 0, `MEM_SIZE-1);
        $readmemh(test_hex_path, `DUT_DMEM, 0, `MEM_SIZE-1);
    end
endfunction

`ifdef ENABLE_COSIM
function void cosim_check_inst_cnt;
    `LOGNT($sformatf("Cosim instruction count: %0d", cosim_get_inst_cnt()));
    `LOGNT($sformatf("DUT instruction count: %0d", stats.perf_cnt_instr));
    if (cosim_get_inst_cnt() != stats.perf_cnt_instr) begin
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
    if (!$value$plusargs("test_path=%s", test_path)) begin
        $error("test_path not defined. Exiting.");
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
    `LOGNT($sformatf("CPU core path: %0s", `TO_STRING(`DUT_CORE)));
    `LOGNT($sformatf("Frequency: %.2f MHz", 1.0 / (half_period * 2 * 1e-3)));
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

task automatic single_step(longint unsigned clk_cnt);
    stats.update(`DUT_CORE.inst.p.wbk, `DUT_CORE.bubble_dec_seq[2]);
    `LOG($sformatf("Core [F] %5h: %8h %0s",
                    `DUT_CORE.pc.p.dec, `DUT_CORE.imem_rsp.data,
                    `DUT_CORE.bubble_dec ? ("(fe stalled)") : ""));

    if (`DUT_CORE.inst_wb_nop_or_clear == 1'b1) return;

    `LOG($sformatf(
        "Core [R] %5h: %8h", `DUT_CORE.pc.p.wbk, `DUT_CORE.inst.p.wbk));
    `ifdef ENABLE_COSIM
    cosim_exec(clk_cnt, cosim_pc, cosim_inst,
               cosim_inst_asm_str, cosim_stack_top_str, cosim_rf);
    // TODO: should be conditional, based on verbosity
    cosim_stack_top_str_wave = pack_string(cosim_stack_top_str);
    `LOG($sformatf("COSIM    %5h: %8h %0s",
                   cosim_pc, cosim_inst, cosim_inst_asm_str));
    if (cosim_chk_en == 1'b1) cosim_run_checkers(rf_chk_act);
    if (stop_on_cosim_error == 1'b1 && errors > 0) begin
        `LOG(msg_fail);
        $finish();
    end
    `endif
    //print_single_instruction_results();

endtask

task run_test();
    automatic longint unsigned clk_cnt = 0;
    while (tohost_source !== 1'b1) begin
        @(posedge clk); #1;
        clk_cnt += 1;
        //$display("clk_cnt: %0d", clk_cnt);
        single_step(clk_cnt);
    end
endtask

// clk gen
always #(half_period) clk = ~clk;

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
initial begin
    rf_chk_act = 32'h0;
    @reset_end;
    // set bit to active when the corresponding register is first written to
    // checker remains active for the entire test
    // once all checkers are active, disable the setup
    while (!(&rf_chk_act)) begin
        @(posedge clk);
        if (rf_chk_act[`DUT_RF.addr_d] == 1'b0) begin
            `LOG($sformatf("RF checker active for x%0d", `DUT_RF.addr_d));
        end
        rf_chk_act[`DUT_RF.addr_d] = 1'b1;
    end
    `LOG("All RF checkers active");
end

// Test
assign tohost_source = `DUT_CORE.csr_tohost[0];
perf_stats stats;
initial begin
    /* set %t:
     * - scaled in ns (-9),
     * - with 2 precision digits
     * - with the " ns" string
     * - taking up a total of 15 characters, including the string
     */
    $timeformat(-9, 2, " ns", 15);

    get_plusargs();
    stats = new();

    `LOG("Simulation started");
    load_memories({test_path, ".hex"});
    `ifdef ENABLE_COSIM
    cosim_setup({test_path, ".elf"});
    `endif

    ->go_in_reset;
    @reset_end;
    `LOG("Reset released");

    fork: run_f
    begin
        run_test();
    end
    begin
        repeat (timeout_clocks) @(posedge clk);
        $error("Test timed out");
        `LOG(msg_fail);
        $finish();
    end
    join_any;
    disable run_f;

    `LOG("Simulation finished");
    if (!(&rf_chk_act)) begin
        `LOG_WARNING(
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
