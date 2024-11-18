`timescale 1ns/1ps

`include "ama_riscv_defines.v"
`include "ama_riscv_perf.svh"

`define DEFAULT_HALF_PERIOD 4

// TB
`define TOHOST_CHECK 1'b1
`define DEFAULT_TIMEOUT_CLOCKS 5_000_000
`define RST_PULSES 2
// per checker enable defines
`define CHECKER_ACTIVE 1'b1
`define CHECKER_INACTIVE 1'b0

`ifdef CORE_ONLY
    `define DUT DUT_ama_riscv_core_i
    `define DUT_IMEM imem_tb.mem
    `define DUT_DMEM dmem_tb.mem
    `define DUT_CORE `DUT
`else // CORE_TOP
    `define DUT DUT_ama_riscv_core_top_i
    `define DUT_IMEM `DUT.ama_riscv_imem_i.mem
    `define DUT_DMEM `DUT.ama_riscv_dmem_i.mem
    `define DUT_CORE `DUT.ama_riscv_core_i
`endif

`define DUT_DEC `DUT_CORE.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF `DUT_CORE.ama_riscv_reg_file_i

`define TOHOST_PASS 32'd1

`define MEM_SIZE 16384
`define INST_ASM_LEN 64

`define LOG(x) $display("%0s: %0s", timestamp, x);

`define DELIM "-----------------------"

// Cosim
`ifdef ENABLE_COSIM
import "DPI-C" function void cosim_setup(input string test_bin,
                                         input int unsigned base_address);
import "DPI-C" function void cosim_exec(output int unsigned pc,
                                        output int unsigned inst,
                                        output byte inst_asm[`INST_ASM_LEN],
                                        output int unsigned rf[32]);
import "DPI-C" function unsigned int cosim_get_inst_cnt();
import "DPI-C" function void cosim_finish();
`endif

module ama_riscv_core_top_tb();

//------------------------------------------------------------------------------
// Testbench variables
string test_path;
string timestamp;
int errors = 0;
int warnings = 0;
bit errors_for_wave = 1'b0;
bit enable_cosim_checkers = 1'b0;
bit stop_on_cosim_error = 1'b0;
wire tohost_source;
int unsigned timeout_clocks;
int unsigned half_period;
real frequency;

// events
event ev_rst [1:0];
event ev_load_stim;
event ev_load_vector;
event ev_load_vector_done;
event go_in_reset;
event reset_end;

// cosim
int unsigned cosim_pc;
int unsigned cosim_inst;
byte cosim_inst_asm[`INST_ASM_LEN];
int unsigned cosim_rf[32];

//------------------------------------------------------------------------------
// DUT I/O
reg clk = 0;
reg rst;
//wire mmio_instr_cnt;
//wire mmio_cycle_cnt;
wire inst_wb_nop_or_clear;
wire mmio_reset_cnt;

//------------------------------------------------------------------------------
// DUT internals for checkers only
//wire dut_internal_branch_taken = `DUT_DEC.branch_res && `DUT_DEC.branch_inst_ex;

//------------------------------------------------------------------------------
// DUT instance
`ifdef CORE_ONLY
    // IMEM
    wire [31:0] inst_id_read;
    wire [13:0] imem_addr;
    // DMEM
    wire [31:0] dmem_write_data;
    wire [13:0] dmem_addr;
    wire        dmem_en;
    wire [ 3:0] dmem_we;
    wire [31:0] dmem_read_data_mem;

    // core
    ama_riscv_core DUT_ama_riscv_core_i(
        .clk                (clk               ),
        .rst                (rst               ),
        // mem in
        .inst_id_read       (inst_id_read      ),
        .dmem_read_data_mem (dmem_read_data_mem),
        // mem out
        .imem_addr          (imem_addr         ),
        .dmem_write_data    (dmem_write_data   ),
        .dmem_addr          (dmem_addr         ),
        .dmem_en            (dmem_en           ),
        .dmem_we            (dmem_we           )
        // mmio in
        //.mmio_instr_cnt         (mmio_instr_cnt         ),
        //.mmio_cycle_cnt         (mmio_cycle_cnt         )
        //.mmio_uart_data_out     (mmio_uart_data_out     ),
        //.mmio_data_out_valid    (mmio_data_out_valid    ),
        //.mmio_data_in_ready     (mmio_data_in_ready     ),
        //// mmio out
        //.store_to_uart          (store_to_uart          ),
        //.load_from_uart         (load_from_uart         ),
        //.inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
        //.mmio_reset_cnt         (mmio_reset_cnt         ),
        //.mmio_uart_data_in      (mmio_uart_data_in      )
    );
    // IMEM
    ama_riscv_imem imem_tb (
        .clk   (clk         ),
        .addrb (imem_addr   ),
        .doutb (inst_id_read)
    );
    // DMEM
    ama_riscv_dmem dmem_tb (
        .clk    (clk                ),
        .en     (dmem_en            ),
        .we     (dmem_we            ),
        .addr   (dmem_addr          ),
        .din    (dmem_write_data    ),
        .dout   (dmem_read_data_mem )
    );
`else
    ama_riscv_core_top DUT_ama_riscv_core_top_i (
        .clk    (clk    ),
        .rst    (rst    ),
        // outputs
        .inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
        .mmio_reset_cnt         (mmio_reset_cnt         )
    );
`endif

//------------------------------------------------------------------------------
// Testbench functions
function void load_memories;
    input string test_hex_path;
    int fd;
    begin
        fd = $fopen(test_hex_path, "r");
        if (fd == 0) begin
            `LOG($sformatf("Error: Could not open file %0s", test_hex_path));
            $finish();
        end
        $fclose(fd);
        $readmemh(test_hex_path, `DUT_IMEM, 0, `MEM_SIZE-1);
        $readmemh(test_hex_path, `DUT_DMEM, 0, `MEM_SIZE-1);
    end
endfunction

`ifdef ENABLE_COSIM
function void cosim_check_inst_cnt;
    $display("Cosim instruction count: %0d", cosim_get_inst_cnt());
    $display("DUT instruction count: %0d", stats.perf_cnt_instr);
    if (cosim_get_inst_cnt() != stats.perf_cnt_instr) begin
        $display("Instruction count mismatch");
    end
endfunction
`endif

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

function void check_test_status();
    automatic bit status_cosim = 1'b1;
    automatic bit status_tohost = 1'b1;
    automatic bit checker_exists = 1'b0;

    begin
        $display("\nTest ran to completion");
        if (`TOHOST_CHECK == 1'b1) begin
            $display("TOHOST checker enabled");
            checker_exists = 1'b1;
            if (`DUT_CORE.tohost !== `TOHOST_PASS) begin
                status_tohost = 1'b0;
                $display("Failed tohost test # : %0d", `DUT_CORE.tohost[31:1]);
            end
        end

        `ifdef ENABLE_COSIM
        if (enable_cosim_checkers == 1'b1) begin
            $display("Cosim checker enabled");
            $display("Warnings: %2d", warnings);
            $display("Errors:   %2d", errors);
            checker_exists = 1'b1;
            if (errors > 0) begin
                status_cosim = 1'b0;
                $display("Test failed: cosim errors = %0d", errors);
            end
        end
        `endif

        if (checker_exists == 1'b1) begin
            if (status_cosim && status_tohost) $display(msg_pass);
            else $display(msg_fail);
        end else begin
            $display("Neither 'TOHOST' nor 'cosim' checker are enabled");
        end
    end
endfunction

// task print_single_instruction_results;
//     int last_pc;
//     reg     stalled;
//     begin
//         if(`VERBOSITY >= 3) begin
//             stalled = (last_pc == dut_m_pc);
//             $display("Instruction at PC# %2d, 0x%4h,  %s ", dut_m_pc, dut_m_pc, stalled ? "stalled " : "executed");
//             $display("ID  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_id , dut_m_inst_id_asm );
//             $display("EX  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_ex , dut_m_inst_ex_asm );
//             $display("MEM stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_mem, dut_m_inst_mem_asm);
//             last_pc = dut_m_pc;
//         end
//     end
// endtask

`ifdef ENABLE_COSIM
`include "checkers.svh"
`endif

function void get_plusargs();
    if (! $value$plusargs("test_path=%s", test_path)) begin
        $error("test_path not defined. Exiting.");
        $finish();
    end
    if ($test$plusargs("enable_cosim_checkers")) enable_cosim_checkers = 1'b1;
    if ($test$plusargs("stop_on_cosim_error")) stop_on_cosim_error = 1'b1;
    if (! $value$plusargs("timeout_clocks=%d", timeout_clocks)) begin
        timeout_clocks = `DEFAULT_TIMEOUT_CLOCKS;
    end
    if (! $value$plusargs("half_period=%d", half_period)) begin
        half_period = `DEFAULT_HALF_PERIOD;
    end
    `LOG($sformatf("Frequency: %.2f MHz", 1.0 / (half_period * 2 * 1e-3)));
endfunction

//------------------------------------------------------------------------------
// Config

// Log to file
// int lclk_cnt = 0;
// initial begin
//     forever begin
//         @(posedge clk);
//         #1;
//         lclk_cnt = lclk_cnt + 1;
//         $fwrite(fd, "clk: ");
//         $fwrite(fd, "%0d", lclk_cnt);
//         $fwrite(fd, "; Inst WB: ");
//         $fdisplay(fd, "%8x", `DUT_CORE.inst_wb );
//     end
// end

always #(half_period) clk = ~clk;

// Timestamp
initial begin
    /* set %t:
     * - scaled in ns (-9),
     * - with 2 precision digits
     * - with the " ns" string
     * - taking up a total of 15 characters, including the string
     */
    $timeformat(-9, 2, " ns", 15);
    forever begin
        timestamp = $sformatf("%t", $time);
        @(posedge clk);
    end
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

//------------------------------------------------------------------------------
// Test
assign tohost_source = `DUT_CORE.tohost[0];
perf_stats stats;
initial begin
    get_plusargs();
    stats = new();

    `LOG($sformatf("Simulation started"));
    load_memories({test_path,".hex"});
    `ifdef ENABLE_COSIM
    cosim_setup({test_path,".bin"}, `RESET_VECTOR);
    `endif

    ->go_in_reset;
    @reset_end;
    `LOG("Reset released");

    fork: run_test
    begin
        while (tohost_source !== 1'b1) begin
            @(posedge clk); #1;
            stats.update(`DUT_CORE.inst_wb, `DUT_CORE.stall_id_seq[2]);
            `LOG($sformatf("Core [F] %5h: %8h %0s",
                           `DUT_CORE.pc_id, `DUT_CORE.inst_id_read,
                           `DUT_CORE.stall_id ? ("(stalled)") : ""));
            if (`DUT_CORE.inst_wb_nop_or_clear == 1'b0) begin
                `LOG($sformatf("Core [R] %5h: %8h",
                               `DUT_CORE.pc_wb, `DUT_CORE.inst_wb));
                `ifdef ENABLE_COSIM
                cosim_exec(cosim_pc, cosim_inst, cosim_inst_asm, cosim_rf);
                // TODO: should be conditional, based on verbosity
                `LOG($sformatf("COSIM    %5h: %8h %0s",
                               cosim_pc, cosim_inst, cosim_inst_asm))
                if (enable_cosim_checkers == 1'b1) cosim_run_checkers();
                if (stop_on_cosim_error == 1'b1 && errors > 0) begin
                    `LOG(msg_fail);
                    $finish();
                end
                `endif
            end
            //print_single_instruction_results();
        end
    end
    begin
        repeat (timeout_clocks) @(posedge clk);
        $error("Test timed out");
        `LOG(msg_fail);
        $finish();
    end
    join_any;
    disable run_test;
    `LOG("Simulation finished");

    check_test_status();
    `ifdef ENABLE_COSIM
    if (enable_cosim_checkers == 1'b1) cosim_check_inst_cnt();
    cosim_finish();
    `endif
    stats.display();
    //stats.compare_dut(mmio_cycle_cnt, mmio_instr_cnt);
    $finish();
end // test

endmodule
