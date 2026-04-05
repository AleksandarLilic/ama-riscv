`timescale 1ns/1ps

`include "ama_riscv_defines.svh"
`include "ama_riscv_perf.svh"

`define TB ama_riscv_simd_tb

`define CLK_HALF_PERIOD 5 // ns

parameter unsigned CLK_PERIOD = (`CLK_HALF_PERIOD * 2);
parameter unsigned CLOCK_FREQ = (1_000 / CLK_PERIOD) * 1_000_000; // Hz
parameter unsigned TIMEOUT_CLKS = 500;

`define FAILED \
    $display(msg_fail); \
    $finish();

module `TB();

logic clk = 1'b0;
logic rst;
logic en;
logic done = 1'b0;

stage_ctrl_t ctrl_exe_mem;
simd_arith_op_t op;
simd_t a, b, p;
arch_width_t c_late;

int unsigned test_cnt = 0;
int unsigned err_cnt = 0;
longint unsigned clk_cnt = 0;

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

ama_riscv_simd DUT (
    .clk (clk),
    .rst (rst),
    .en (en),
    .ctrl_exe_mem (ctrl_exe_mem),
    .op (op),
    .a (a),
    .b (b),
    .c_late (c_late),
    .p (p)
);

always #(`CLK_HALF_PERIOD) clk = ~clk;

always @(posedge clk) clk_cnt <= (clk_cnt + 1);

always_comb begin
    ctrl_exe_mem.flush = 1'b0;
    ctrl_exe_mem.en = 1'b1;
    ctrl_exe_mem.bubble = 1'b0;
end

task automatic run_test(
    input string name,
    input simd_arith_op_t test_op,
    input arch_width_t test_a,
    input arch_width_t test_b,
    input arch_width_t test_c_late,
    input arch_width_t reference
);
    test_cnt = (test_cnt + 1);

    op = test_op;
    en = 1'b1;
    a = simd_t'(test_a);
    b = simd_t'(test_b);
    c_late = '0;

    @(posedge clk);
    #1;

    en = 1'b0;
    c_late = test_c_late;

    @(posedge clk);
    #1;

    $display(
        "Test %3d @ cycle %4d: %-16s op=%0h a=%h b=%h c_late=%h p=%h exp=%h%s",
        test_cnt,
        clk_cnt,
        name,
        test_op,
        test_a,
        test_b,
        test_c_late,
        p.w,
        reference,
        (p.w !== reference) ? "  <-- ERROR" : ""
    );

    if (p.w !== reference) err_cnt = (err_cnt + 1);

endtask

initial begin
    $timeformat(-9, 0, " ns", 20);

    rst = 1'b0;
    en = 1'b0;
    op = SIMD_ARITH_OP_MUL;
    a = '0;
    b = '0;
    c_late = '0;

    repeat (4) @(posedge clk);
    #1;

    rst = 1'b1;
    @(posedge clk);
    #1;
    rst = 1'b0;

    repeat (2) @(posedge clk);
    #1;

    fork: run_f
    begin
        //        name, op, a, b, c_late, ref
        run_test("mul", SIMD_ARITH_OP_MUL,
                 32'd12, 32'd7, 32'd0, 32'd84
        );
        run_test("mulh", SIMD_ARITH_OP_MULH,
                 32'hFFFF_FFFE, 32'd3, 32'd0, 32'hFFFF_FFFF
        );
        run_test("mulhsu", SIMD_ARITH_OP_MULHSU,
                 32'hFFFF_FFFE, 32'd3, 32'd0, 32'hFFFF_FFFF
        );
        run_test("mulhu", SIMD_ARITH_OP_MULHU,
                 32'hFFFF_FFFF, 32'd2, 32'd0, 32'h0000_0001
        );

        run_test("dot16", SIMD_ARITH_OP_DOT16,
                 {16'sd55, -16'sd1245}, {16'sd105, 16'sd17},
                 32'd10, -32'sd15380
        );
        run_test("dot16u", SIMD_ARITH_OP_DOT16U,
                 {16'd55, 16'd1245}, {16'd105, 16'd17},
                 32'd5, 32'd26945
        );
        run_test("dot8", SIMD_ARITH_OP_DOT8,
                 {8'sd0, 8'sd3, 8'sd1, 8'sd4}, {8'sd0, -8'sd17, 8'sd1, 8'sd1},
                 32'd2, -32'sd44
        );
        run_test("dot8u", SIMD_ARITH_OP_DOT8U,
                 {8'd55, 8'd3, 8'd1, 8'd88}, {8'd105, 8'd17, 8'd1, 8'd1},
                 32'd7, 32'd5922
        );
        run_test("dot4", SIMD_ARITH_OP_DOT4,
                 {4'sd1, 4'sd2, 4'sd3, 4'sd4, 4'sd1, 4'sd2, 4'sd3, 4'sd4},
                 {4'sd1, 4'sd1, 4'sd1, 4'sd1, 4'sd2, 4'sd2, 4'sd2, 4'sd2},
                 32'd3, 32'd33
        );
        run_test("dot4u", SIMD_ARITH_OP_DOT4U,
                 {4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8},
                 {4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1},
                 32'd4, 32'd40
        );
        run_test("dot2", SIMD_ARITH_OP_DOT2,
                 {2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1,
                  2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1},
                 {2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1,
                  2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1, 2'sd1},
                 32'd1, 32'd17
        );
        run_test("dot2u", SIMD_ARITH_OP_DOT2U,
                 {2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2,
                  2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2},
                 {2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1,
                  2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1},
                 32'd9, 32'd41
        );

        done = 1'b1;
    end

    begin
        repeat (TIMEOUT_CLKS) @(posedge clk);
        if (!done) begin
            $display("Test timed out");
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
