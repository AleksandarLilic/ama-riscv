`timescale 1ns/1ps

`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_types.svh"

`define TB ama_riscv_div_tb

`define CLK_HALF_PERIOD 5 // ns

parameter unsigned CLK_PERIOD = (`CLK_HALF_PERIOD * 2);
parameter unsigned CLOCK_FREQ = (1_000 / CLK_PERIOD) * 1_000_000; // Hz
parameter unsigned TIMEOUT_CLKS = 8000;
parameter unsigned BUSY_ASSERT_TO = 5; // max cycles wait for busy to assert
parameter unsigned BUSY_RELEASE_TO = 50; // max cycles wait for busy to deassert

// OVERHEAD = non-iteration cycles counted in busy = 2 (SETUP + FIXUP)
// CLZ is computed in SETUP from registered inputs.
// all timing checks: max_busy_cyc = OVERHEAD + N_ITER
// N_ITER = W - clz(|dividend|); pow2/a<b/overflow/div-by-0 finish from SETUP
parameter unsigned OVERHEAD = 2;

`define FAILED \
    $display(msg_fail); \
    $finish();

module `TB();

logic clk = 1'b0;
logic rst;
logic start;
logic flush;
div_op_t op;
arch_width_t a, b;
arch_width_t result;
logic busy;
logic done = 1'b0;

int unsigned test_cnt = 0;
int unsigned err_cnt = 0;
longint unsigned clk_cnt = 0;

ama_riscv_div DUT (
    .clk (clk),
    .rst (rst),
    .start (start),
    .flush (flush),
    .op (op),
    .a (a),
    .b (b),
    .result (result),
    .busy (busy)
);

always #(`CLK_HALF_PERIOD) clk = ~clk;

always @(posedge clk) clk_cnt <= (clk_cnt + 1);

// drive a single-cycle start pulse, wait for busy to complete, check result.
// max_busy_cyc: if non-zero, error if busy stays high longer than this many cycles.
task automatic run_div(
    input string name,
    input div_op_t test_op,
    input logic [31:0] test_a,
    input logic [31:0] test_b,
    input logic [31:0] expected,
    input int unsigned max_busy_cyc
);
    int unsigned wait_cnt;
    int unsigned busy_cnt;
    logic timing_err;

    test_cnt++;
    timing_err = 1'b0;

    // apply operands and pulse start for one cycle
    @(posedge clk); #1;
    a = test_a;
    b = test_b;
    op = test_op;
    start = 1'b1;

    @(posedge clk); #1;
    start = 1'b0;

    // wait up to BUSY_ASSERT_TO cycles for busy to assert
    wait_cnt = 0;
    while (!busy && (wait_cnt < BUSY_ASSERT_TO)) begin
        wait_cnt++;
        @(posedge clk); #1;
    end

    // if busy asserted, wait for it to release
    if (busy) begin
        busy_cnt = 1;
        @(posedge clk); #1;
        while (busy && (busy_cnt < BUSY_RELEASE_TO)) begin
            busy_cnt++;
            @(posedge clk); #1;
        end
        if (busy_cnt >= BUSY_RELEASE_TO) begin
            $display(
                "Test %3d @ cycle %4d: %-36s - TIMEOUT busy never released",
                test_cnt, clk_cnt, name
            );
            err_cnt++;
            return;
        end
        if ((max_busy_cyc != 0) && (busy_cnt > max_busy_cyc)) begin
            timing_err = 1'b1;
        end
    end else begin
        // busy never asserted (stub or broken impl)
        busy_cnt = 0;
    end

    $display(
        "Test %3d @ cycle %4d: %-36s op=%b a=%h b=%h res=%h exp=%h cyc=%0d%s%s",
        test_cnt, clk_cnt, name, test_op, test_a, test_b,
        result, expected, busy_cnt,
        (result !== expected) ? "  <-- RESULT ERROR" : "",
        (timing_err)          ? "  <-- TIMING ERROR" : ""
    );

    if (result !== expected) err_cnt++;
    if (timing_err) err_cnt++;
endtask

// convenience wrapper with no timing check
task automatic run_div_nt(
    input string name,
    input div_op_t test_op,
    input logic [31:0] test_a,
    input logic [31:0] test_b,
    input logic [31:0] expected
);
    run_div(name, test_op, test_a, test_b, expected, 0);
endtask

// drive a single-cycle start pulse and require a combinational buffer hit:
// result must be correct while start is high and busy must stay low.
task automatic run_div_hit(
    input string name,
    input div_op_t test_op,
    input logic [31:0] test_a,
    input logic [31:0] test_b,
    input logic [31:0] expected
);
    logic result_err_now, result_err_hold, busy_err_now, busy_err_hold;

    test_cnt++;

    @(posedge clk); #1;
    a = test_a;
    b = test_b;
    op = test_op;
    start = 1'b1;

    #1;
    result_err_now = (result !== expected);
    busy_err_now = busy;

    @(posedge clk); #1;
    start = 1'b0;

    #1;
    result_err_hold = (result !== expected);
    busy_err_hold = busy;

    $display(
        "Test %3d @ cycle %4d: %-36s op=%b a=%h b=%h res=%h exp=%h cyc=0%s%s%s%s",
        test_cnt, clk_cnt, name, test_op, test_a, test_b, result, expected,
        result_err_now  ? "  <-- HIT RESULT ERROR" : "",
        busy_err_now    ? "  <-- HIT BUSY ERROR" : "",
        result_err_hold ? "  <-- HOLD RESULT ERROR" : "",
        busy_err_hold   ? "  <-- HOLD BUSY ERROR" : ""
    );

    if (result_err_now || result_err_hold) err_cnt++;
    if (busy_err_now || busy_err_hold) err_cnt++;
endtask

initial begin
    $timeformat(-9, 0, " ns", 20);

    rst = 1'b0;
    start = 1'b0;
    flush = 1'b0;
    op = DIV_DIV;
    a = '0;
    b = '0;

    repeat (4) @(posedge clk);
    #1;

    rst = 1'b1;
    @(posedge clk); #1;
    rst = 1'b0;

    repeat (2) @(posedge clk);
    #1;

    fork: run_f
    begin

        // ---------- DIV - signed quotient
        run_div_nt("div 20/3",          DIV_DIV, 32'd20,       32'd3,        32'd6);
        run_div_nt("div 100/7",         DIV_DIV, 32'd100,      32'd7,        32'd14);
        run_div_nt("div 255/16",        DIV_DIV, 32'd255,      32'd16,       32'd15);
        run_div_nt("div 48/6 exact",    DIV_DIV, 32'd48,       32'd6,        32'd8);
        run_div_nt("div 100/25 exact",  DIV_DIV, 32'd100,      32'd25,       32'd4);
        run_div_nt("div 0/5",           DIV_DIV, 32'd0,        32'd5,        32'd0);
        run_div_nt("div 9/7",           DIV_DIV, 32'd9,        32'd7,        32'd1);
        // dividend < divisor: early exit, quotient=0
        run_div_nt("div 3/7 (a<b)",     DIV_DIV, 32'd3,        32'd7,        32'd0);
        run_div_nt("div 0x7FFFFFFF/2",  DIV_DIV, 32'h7FFFFFFF, 32'd2,        32'h3FFFFFFF);
        run_div_nt("div 1024/32 pow2",  DIV_DIV, 32'd1024,     32'd32,       32'd32);
        // signed negatives - result truncates toward zero
        run_div_nt("div -20/3",         DIV_DIV, 32'hFFFFFFEC, 32'd3,        32'hFFFFFFFA);
        run_div_nt("div 20/-3",         DIV_DIV, 32'd20,       32'hFFFFFFFD, 32'hFFFFFFFA);
        run_div_nt("div -20/-3",        DIV_DIV, 32'hFFFFFFEC, 32'hFFFFFFFD, 32'd6);
        // INT_MIN / 2 (signed, not the overflow case)
        run_div_nt("div INT_MIN/2",     DIV_DIV, 32'h80000000, 32'd2,        32'hC0000000);

        // ---------- DIVU - unsigned quotient
        run_div_nt("divu 20/3",         DIV_DIVU, 32'd20,       32'd3,       32'd6);
        // 0xFFFFFFFF / 3 = 0x55555555 (exact, remainder 0)
        run_div_nt("divu 0xFFFFFFFF/3", DIV_DIVU, 32'hFFFFFFFF, 32'd3,       32'h55555555);
        run_div_nt("divu 1024/32",      DIV_DIVU, 32'd1024,     32'd32,      32'd32);
        run_div_nt("divu 5/7 (a<b)",    DIV_DIVU, 32'd5,        32'd7,       32'd0);
        // high bit set: would be negative for signed but is a large unsigned value
        run_div_nt("divu 0x80000000/2", DIV_DIVU, 32'h80000000, 32'd2,       32'h40000000);

        // ---------- REM - signed remainder (sign follows dividend)
        run_div_nt("rem 20/3",          DIV_REM, 32'd20,       32'd3,        32'd2);
        run_div_nt("rem 100/7",         DIV_REM, 32'd100,      32'd7,        32'd2);
        run_div_nt("rem 48/6 exact",    DIV_REM, 32'd48,       32'd6,        32'd0);
        // dividend < divisor: remainder == dividend
        run_div_nt("rem 3/7 (a<b)",     DIV_REM, 32'd3,        32'd7,        32'd3);
        run_div_nt("rem -20/3",         DIV_REM, 32'hFFFFFFEC, 32'd3,        32'hFFFFFFFE);
        run_div_nt("rem 20/-3",         DIV_REM, 32'd20,       32'hFFFFFFFD, 32'd2);
        run_div_nt("rem -20/-3",        DIV_REM, 32'hFFFFFFEC, 32'hFFFFFFFD, 32'hFFFFFFFE);

        // ---------- REMU - unsigned remainder
        run_div_nt("remu 20/3",         DIV_REMU, 32'd20,       32'd3,       32'd2);
        // 0xFFFFFFFF is exactly divisible by 3 -> remainder 0
        run_div_nt("remu 0xFFFFFFFF/3", DIV_REMU, 32'hFFFFFFFF, 32'd3,       32'd0);
        run_div_nt("remu 100/25 exact", DIV_REMU, 32'd100,      32'd25,      32'd0);
        // dividend < divisor: remainder == dividend
        run_div_nt("remu 5/7 (a<b)",    DIV_REMU, 32'd5,        32'd7,       32'd5);

        // ---------- Special cases: divide by zero (spec-mandated results)
        run_div_nt("div-by-0 DIV",      DIV_DIV,  32'd5, 32'd0, 32'hFFFFFFFF);
        run_div_nt("div-by-0 DIVU",     DIV_DIVU, 32'd5, 32'd0, 32'hFFFFFFFF);
        run_div_nt("div-by-0 REM",      DIV_REM,  32'd5, 32'd0, 32'd5);
        run_div_nt("div-by-0 REMU",     DIV_REMU, 32'd5, 32'd0, 32'd5);
        // div-by-0 with negative dividend
        run_div_nt("div-by-0 REM neg",  DIV_REM,  32'hFFFFFFEC, 32'd0, 32'hFFFFFFEC);

        // ---------- Special case: signed overflow (INT_MIN / -1)
        run_div_nt("overflow DIV",       DIV_DIV, 32'h80000000, 32'hFFFFFFFF, 32'h80000000);
        run_div_nt("overflow REM",       DIV_REM, 32'h80000000, 32'hFFFFFFFF, 32'd0);

        // ---------- Power-of-2 divisor with signed operands (SPECIAL path)
        // 21/4=5 rem 1; -21/4=-5 rem -1
        run_div_nt("div  21/ 4 pow2",  DIV_DIV, 32'd21,       32'd4, 32'd5);
        run_div_nt("rem  21/ 4 pow2",  DIV_REM, 32'd21,       32'd4, 32'd1);
        run_div_nt("div -21/ 4 pow2",  DIV_DIV, 32'hFFFFFFEB, 32'd4, 32'hFFFFFFFB);
        run_div_nt("rem -21/ 4 pow2",  DIV_REM, 32'hFFFFFFEB, 32'd4, 32'hFFFFFFFF);

        // ---------- Timing: max_busy_cyc = OVERHEAD + N_ITER
        // N_ITER = W - clz(|dividend|); use non-pow2 divisors to exercise ITER path

        // N=32 (clz=0): a has all bits set, b non-pow2 -> full 32 iterations
        //   0xFFFFFFFF / 3 = 0x55555555 (exact)
        run_div("timing N=32 (clz=0)",
                DIV_DIVU, 32'hFFFFFFFF, 32'd3, 32'h55555555,
                OVERHEAD + 'd32);

        // N=8 (clz=24): light dividend, non-pow2 divisor
        //   255(0xFF) / 7 = 36 rem 3
        run_div("timing N=8  (clz=24) 255/7",
                DIV_DIVU, 32'h000000FF, 32'd7, 32'd36,
                OVERHEAD + 'd8);

        // N=5 (clz=27): same dividend as div 20/3 above
        //   20 / 3 = 6 rem 2
        run_div("timing N=5  (clz=27) 20/3",
                DIV_DIVU, 32'd20, 32'd3, 32'd6,
                OVERHEAD + 'd5);

        // N=2 (clz=30): near-minimum; a=b=3 (equal, not less-than, b non-pow2)
        //   3 / 3 = 1 rem 0
        run_div("timing N=2  (clz=30) 3/3",
                DIV_DIVU, 32'd3, 32'd3, 32'd1,
                OVERHEAD + 'd2);

        // SPECIAL a<b: result is written in SETUP, so busy is 1 cycle
        run_div("timing SPECIAL a<b",
                DIV_DIV, 32'd3, 32'd7, 32'd0, 'd1);

        // SPECIAL pow2 divisor: result is written in SETUP, so busy is 1 cycle
        run_div("timing SPECIAL pow2 1024/32",
                DIV_DIVU, 32'd1024, 32'd32, 32'd32, 'd1);

        // ---------- Flush: start a long divide, flush mid-way, verify busy drops
        begin
            @(posedge clk); #1;
            a = 32'hFFFFFFFF;
            b = 32'd7;
            op = DIV_DIVU;
            start = 1'b1;

            @(posedge clk); #1;
            start = 1'b0;

            // let it run a few cycles then assert flush
            repeat (5) @(posedge clk); #1;
            flush = 1'b1;

            @(posedge clk); #1;
            flush = 1'b0;

            // busy must be 0 immediately after flush deasserts
            test_cnt++;
            if (busy) begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - busy still high after flush <-- ERROR",
                    test_cnt, clk_cnt, "flush deasserts busy"
                );
                err_cnt++;
            end else begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - OK",
                    test_cnt, clk_cnt, "flush deasserts busy"
                );
            end

            // verify module accepts a new start immediately after flush
            run_div_nt("after-flush 20/3", DIV_DIV, 32'd20, 32'd3, 32'd6);
        end

        // ---------- back-to-back:
        // second operation starts after first busy deasserts
        // (run_div task naturally chains: second call starts on next cycle
        // after task returns, with no idle gap beyond the @(posedge clk) in
        // the task preamble)
        run_div_nt("back2back first",  DIV_DIV,  32'd100,  32'd7,  32'd14);
        run_div_nt("back2back second", DIV_DIVU, 32'd1024, 32'd32, 32'd32);

        // ---------- buffer hit / miss checks
        run_div("buffer seed div 20/3", DIV_DIV, 32'd20, 32'd3, 32'd6, OVERHEAD + 'd5);
        run_div_hit("buffer hit  div 20/3", DIV_DIV, 32'd20, 32'd3, 32'd6);

        run_div("buffer seed div 100/7", DIV_DIV, 32'd100, 32'd7, 32'd14, OVERHEAD + 'd7);
        run_div_hit("buffer pair rem 100/7", DIV_REM, 32'd100, 32'd7, 32'd2);

        run_div("buffer seed rem -20/3", DIV_REM, 32'hFFFFFFEC, 32'd3, 32'hFFFFFFFE, OVERHEAD + 'd5);
        run_div_hit("buffer pair div -20/3", DIV_DIV, 32'hFFFFFFEC, 32'd3, 32'hFFFFFFFA);

        run_div("buffer seed divu F/3", DIV_DIVU, 32'hFFFFFFFF, 32'd3, 32'h55555555, OVERHEAD + 'd32);
        run_div_hit("buffer pair remu F/3", DIV_REMU, 32'hFFFFFFFF, 32'd3, 32'd0);

        run_div("buffer special seed div-by-0", DIV_DIV, 32'd5, 32'd0, 32'hFFFFFFFF, 'd1);
        run_div("buffer special pair rem-by-0", DIV_REM, 32'd5, 32'd0, 32'd5, 'd1);

        run_div("buffer signed seed -20/3", DIV_DIV, 32'hFFFFFFEC, 32'd3, 32'hFFFFFFFA, OVERHEAD + 'd5);
        run_div("buffer miss unsigned -20/3", DIV_DIVU, 32'hFFFFFFEC, 32'd3, 32'h5555554E, OVERHEAD + 'd32);

        // ---------- reset should clear only buffer valid
        run_div("buffer reset seed divu 20/3", DIV_DIVU, 32'd20, 32'd3, 32'd6, OVERHEAD + 'd5);
        run_div_hit("buffer reset hit  divu 20/3", DIV_DIVU, 32'd20, 32'd3, 32'd6);

        rst = 1'b1;
        @(posedge clk); #1;
        rst = 1'b0;
        repeat (2) @(posedge clk);
        #1;

        run_div("buffer reset miss divu 20/3", DIV_DIVU, 32'd20, 32'd3, 32'd6, OVERHEAD + 'd5);

        // ---------- invalidate old entry on real start, then keep invalid on flush
        run_div("buffer old seed div 20/3", DIV_DIV, 32'd20, 32'd3, 32'd6, OVERHEAD + 'd5);

        begin
            @(posedge clk); #1;
            a = 32'hFFFFFFFF;
            b = 32'd7;
            op = DIV_DIVU;
            start = 1'b1;

            @(posedge clk); #1;
            start = 1'b0;

            repeat (5) @(posedge clk); #1;
            flush = 1'b1;

            @(posedge clk); #1;
            flush = 1'b0;

            test_cnt++;
            if (busy) begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - busy still high after flush <-- ERROR",
                    test_cnt, clk_cnt, "buffer invalidate flush"
                );
                err_cnt++;
            end else begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - OK",
                    test_cnt, clk_cnt, "buffer invalidate flush"
                );
            end

            run_div("buffer old miss after flush", DIV_DIV, 32'd20, 32'd3, 32'd6, OVERHEAD + 'd5);
            run_div("buffer flush miss F/7", DIV_DIVU, 32'hFFFFFFFF, 32'd7, 32'h24924924, OVERHEAD + 'd32);
        end

        // ---------- flush should not seed buffer
        begin
            @(posedge clk); #1;
            a = 32'hFFFFFFFF;
            b = 32'd7;
            op = DIV_DIVU;
            start = 1'b1;

            @(posedge clk); #1;
            start = 1'b0;

            repeat (5) @(posedge clk); #1;
            flush = 1'b1;

            @(posedge clk); #1;
            flush = 1'b0;

            test_cnt++;
            if (busy) begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - busy still high after flush <-- ERROR",
                    test_cnt, clk_cnt, "buffer flush deasserts busy"
                );
                err_cnt++;
            end else begin
                $display(
                    "Test %3d @ cycle %4d: %-36s - OK",
                    test_cnt, clk_cnt, "buffer flush deasserts busy"
                );
            end
        end

        done = 1'b1;
    end

    begin
        repeat (TIMEOUT_CLKS) @(posedge clk);
        if (!done) begin
            $display("Test suite timed out after %0d cycles", TIMEOUT_CLKS);
            `FAILED;
        end
    end
    join_any;
    disable run_f;

    repeat (5) @(posedge clk);

    $display("Tests run: %0d", test_cnt);
    $display("Cycles:    %0d", clk_cnt);

    if (err_cnt == 0) begin
        $display(msg_pass);
    end else begin
        $display("Number of errors: %0d / %0d", err_cnt, test_cnt);
        `FAILED;
    end

    $finish();
end

endmodule
