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

        // add/sub (wrap)
        run_test("add16 safe", SIMD_ARITH_OP_ADD16,
                 {16'sd1000, 16'sd500}, {16'sd300, 16'sd200},
                 32'd0, {16'sd1300, 16'sd700}
        );
        run_test("add16 wrap", SIMD_ARITH_OP_ADD16,
                 {16'h7FFF, 16'h8000}, {16'sd1, 16'hFFFF},
                 32'd0, {16'h8000, 16'h7FFF}
        );
        run_test("add8 safe", SIMD_ARITH_OP_ADD8,
                 {8'sd20, 8'sd10, 8'sd5, 8'sd2}, {8'sd3, 8'sd7, 8'sd8, 8'sd15},
                 32'd0, {8'sd23, 8'sd17, 8'sd13, 8'sd17}
        );
        run_test("add8 wrap", SIMD_ARITH_OP_ADD8,
                 {8'h7F, 8'h80, 8'sd1, 8'sd2}, {8'sd1, 8'hFF, 8'sd3, 8'sd4},
                 32'd0, {8'h80, 8'h7F, 8'sd4, 8'sd6}
        );
        run_test("sub16 safe", SIMD_ARITH_OP_SUB16,
                 {16'sd1000, 16'sd500}, {16'sd200, 16'sd100},
                 32'd0, {16'sd800, 16'sd400}
        );
        run_test("sub16 wrap", SIMD_ARITH_OP_SUB16,
                 {16'h8000, 16'h7FFF}, {16'sd1, 16'hFFFF},
                 32'd0, {16'h7FFF, 16'h8000}
        );
        run_test("sub8 safe", SIMD_ARITH_OP_SUB8,
                 {8'sd40, 8'sd30, 8'sd20, 8'sd10}, {8'sd2, 8'sd7, 8'sd3, 8'sd5},
                 32'd0, {8'sd38, 8'sd23, 8'sd17, 8'sd5}
        );
        run_test("sub8 wrap", SIMD_ARITH_OP_SUB8,
                 {8'h80, 8'h7F, 8'sd3, 8'sd1}, {8'sd1, 8'hFF, 8'sd1, 8'sd1},
                 32'd0, {8'h7F, 8'h80, 8'sd2, 8'sd0}
        );
        // qadd/qsub (signed sat)
        run_test("qadd16 safe", SIMD_ARITH_OP_QADD16,
                 {16'sd1000, 16'sd500}, {16'sd200, 16'sd300},
                 32'd0, {16'sd1200, 16'sd800}
        );
        run_test("qadd16 sat", SIMD_ARITH_OP_QADD16,
                 {16'sd30000, -16'sd30000}, {16'sd10000, -16'sd10000},
                 32'd0, {16'h7FFF, 16'h8000}
        );
        run_test("qadd8 safe", SIMD_ARITH_OP_QADD8,
                 {8'sd20, 8'sd10, 8'sd5, 8'sd2}, {8'sd2, 8'sd5, 8'sd10, 8'sd30},
                 32'd0, {8'sd22, 8'sd15, 8'sd15, 8'sd32}
        );
        run_test("qadd8 sat", SIMD_ARITH_OP_QADD8,
                 {8'sd100, 8'sd1, 8'sd1, 8'sd1}, {8'sd50, 8'sd1, 8'sd1, 8'sd1},
                 32'd0, {8'sd127, 8'sd2, 8'sd2, 8'sd2}
        );
        run_test("qsub16 safe", SIMD_ARITH_OP_QSUB16,
                 {16'sd1000, 16'sd500}, {16'sd200, 16'sd100},
                 32'd0, {16'sd800, 16'sd400}
        );
        run_test("qsub16 sat", SIMD_ARITH_OP_QSUB16,
                 {-16'sd30000, 16'sd30000}, {16'sd10000, -16'sd10000},
                 32'd0, {16'h8000, 16'h7FFF}
        );
        run_test("qsub8 safe", SIMD_ARITH_OP_QSUB8,
                 {8'sd40, 8'sd20, 8'sd10, 8'sd5}, {8'sd2, 8'sd5, 8'sd3, 8'sd1},
                 32'd0, {8'sd38, 8'sd15, 8'sd7, 8'sd4}
        );
        run_test("qsub8 sat", SIMD_ARITH_OP_QSUB8,
                 {-8'sd100, 8'sd1, 8'sd1, 8'sd1}, {8'sd50, 8'sd1, 8'sd1, 8'sd1},
                 32'd0, {8'h80, 8'h00, 8'h00, 8'h00}
        );
        // qadd/qsub (unsigned sat)
        run_test("qadd16u safe", SIMD_ARITH_OP_QADD16U,
                 {16'd1000, 16'd500}, {16'd200, 16'd300},
                 32'd0, {16'd1200, 16'd800}
        );
        run_test("qadd16u oflow", SIMD_ARITH_OP_QADD16U,
                 {16'd60000, 16'd1}, {16'd10000, 16'd1},
                 32'd0, {16'hFFFF, 16'd2}
        );
        run_test("qadd8u safe", SIMD_ARITH_OP_QADD8U,
                 {8'd50, 8'd30, 8'd10, 8'd5}, {8'd5, 8'd10, 8'd20, 8'd40},
                 32'd0, {8'd55, 8'd40, 8'd30, 8'd45}
        );
        run_test("qadd8u oflow", SIMD_ARITH_OP_QADD8U,
                 {8'd200, 8'd1, 8'd1, 8'd1}, {8'd100, 8'd1, 8'd1, 8'd1},
                 32'd0, {8'hFF, 8'd2, 8'd2, 8'd2}
        );
        run_test("qsub16u safe", SIMD_ARITH_OP_QSUB16U,
                 {16'd1000, 16'd500}, {16'd200, 16'd100},
                 32'd0, {16'd800, 16'd400}
        );
        run_test("qsub16u uflow", SIMD_ARITH_OP_QSUB16U,
                 {16'd100, 16'd500}, {16'd200, 16'd100},
                 32'd0, {16'd0, 16'd400}
        );
        run_test("qsub8u safe", SIMD_ARITH_OP_QSUB8U,
                 {8'd50, 8'd30, 8'd20, 8'd10}, {8'd5, 8'd10, 8'd3, 8'd2},
                 32'd0, {8'd45, 8'd20, 8'd17, 8'd8}
        );
        run_test("qsub8u uflow", SIMD_ARITH_OP_QSUB8U,
                 {8'd5, 8'd200, 8'd10, 8'd5}, {8'd9, 8'd50, 8'd3, 8'd9},
                 32'd0, {8'd0, 8'd150, 8'd7, 8'd0}
        );
        // min/max (signed)
        run_test("min16 safe", SIMD_ARITH_OP_MIN16,
                 {16'sd1000, 16'sd500}, {16'sd800, 16'sd600},
                 32'd0, {16'sd800, 16'sd500}
        );
        run_test("min16 mixed", SIMD_ARITH_OP_MIN16,
                 {16'sd100, -16'sd200}, {-16'sd50, 16'sd300},
                 32'd0, {-16'sd50, -16'sd200}
        );
        run_test("min8 safe", SIMD_ARITH_OP_MIN8,
                 {8'sd10, 8'sd20, 8'sd5, 8'sd15}, {8'sd8, 8'sd25, 8'sd3, 8'sd12},
                 32'd0, {8'sd8, 8'sd20, 8'sd3, 8'sd12}
        );
        run_test("min8 mixed", SIMD_ARITH_OP_MIN8,
                 {8'sd5, -8'sd1, 8'sd7, -8'sd9}, {8'sd2, 8'sd3, 8'sd7, 8'sd4},
                 32'd0, {8'sd2, -8'sd1, 8'sd7, -8'sd9}
        );
        run_test("max16 safe", SIMD_ARITH_OP_MAX16,
                 {16'sd1000, 16'sd500}, {16'sd800, 16'sd600},
                 32'd0, {16'sd1000, 16'sd600}
        );
        run_test("max16 mixed", SIMD_ARITH_OP_MAX16,
                 {16'sd100, -16'sd200}, {-16'sd50, 16'sd300},
                 32'd0, {16'sd100, 16'sd300}
        );
        run_test("max8 safe", SIMD_ARITH_OP_MAX8,
                 {8'sd10, 8'sd20, 8'sd5, 8'sd15}, {8'sd8, 8'sd25, 8'sd3, 8'sd12},
                 32'd0, {8'sd10, 8'sd25, 8'sd5, 8'sd15}
        );
        run_test("max8 mixed", SIMD_ARITH_OP_MAX8,
                 {8'sd5, -8'sd1, 8'sd7, -8'sd9}, {8'sd2, 8'sd3, 8'sd7, 8'sd4},
                 32'd0, {8'sd5, 8'sd3, 8'sd7, 8'sd4}
        );
        // min/max (unsigned)
        run_test("min16u safe", SIMD_ARITH_OP_MIN16U,
                 {16'd1000, 16'd500}, {16'd800, 16'd600},
                 32'd0, {16'd800, 16'd500}
        );
        run_test("min16u large", SIMD_ARITH_OP_MIN16U,
                 {16'd60000, 16'd1}, {16'd100, 16'd65535},
                 32'd0, {16'd100, 16'd1}
        );
        run_test("min8u safe", SIMD_ARITH_OP_MIN8U,
                 {8'd50, 8'd30, 8'd20, 8'd10}, {8'd40, 8'd35, 8'd15, 8'd12},
                 32'd0, {8'd40, 8'd30, 8'd15, 8'd10}
        );
        run_test("min8u large", SIMD_ARITH_OP_MIN8U,
                 {8'd200, 8'd1, 8'd128, 8'd1}, {8'd10, 8'd200, 8'd127, 8'd255},
                 32'd0, {8'd10, 8'd1, 8'd127, 8'd1}
        );
        run_test("max16u safe", SIMD_ARITH_OP_MAX16U,
                 {16'd1000, 16'd500}, {16'd800, 16'd600},
                 32'd0, {16'd1000, 16'd600}
        );
        run_test("max16u large", SIMD_ARITH_OP_MAX16U,
                 {16'd60000, 16'd1}, {16'd100, 16'd65535},
                 32'd0, {16'd60000, 16'd65535}
        );
        run_test("max8u safe", SIMD_ARITH_OP_MAX8U,
                 {8'd50, 8'd30, 8'd20, 8'd10}, {8'd40, 8'd35, 8'd15, 8'd12},
                 32'd0, {8'd50, 8'd35, 8'd20, 8'd12}
        );
        run_test("max8u large", SIMD_ARITH_OP_MAX8U,
                 {8'd200, 8'd1, 8'd128, 8'd1}, {8'd10, 8'd200, 8'd127, 8'd255},
                 32'd0, {8'd200, 8'd200, 8'd128, 8'd255}
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
