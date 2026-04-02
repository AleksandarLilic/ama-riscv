`include "ama_riscv_defines.svh"

`define SYNT
`define FPGA

module ama_riscv_fpga #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter UART_BR = BR_115200
)(
    input  CLK100MHZ,
    input  RST,
    output [3:0] LEDS,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

//------------------------------------------------------------------------------
// PLL

logic clk_gen;
logic clk_gen_b;
logic clk_gen_fb_out;
logic clk_gen_fb_out_b;

// 50MHz config
PLLE2_ADV #(
    .BANDWIDTH ("OPTIMIZED"),
    .COMPENSATION ("BUF_IN"), // ZHOLD is default
    .STARTUP_WAIT ("FALSE"),
    .DIVCLK_DIVIDE (5), // config f1
    .CLKFBOUT_MULT (50), // config f2
    .CLKOUT0_DIVIDE (20), // config f3
    .CLKFBOUT_PHASE (0.000),
    .CLKOUT0_PHASE (0.000),
    .CLKOUT0_DUTY_CYCLE (0.500), // 50%
    .CLKIN1_PERIOD (10.000) // 100MHz on-board osc
) plle2_adv_i (
    // input clock and control
    .CLKFBIN (clk_gen_fb_out_b),
    .CLKIN1 (CLK100MHZ),
    .CLKIN2 (1'b0),
    .CLKINSEL (1'b1),
    // control and status signals
    .LOCKED (clk_gen_pll_lock), // output
    .PWRDWN (1'b0), // input
    .RST (1'b0), // input
    // outputs
    .CLKFBOUT (clk_gen_fb_out),
    .CLKOUT0 (clk_gen)
);

BUFG clk_gen_buf (.I (clk_gen), .O (clk_gen_b));
BUFG clk_gen_fb_buf (.I (clk_gen_fb_out), .O (clk_gen_fb_out_b));

logic clk, rst;
assign clk = clk_gen_b;
assign rst = (RST || ~clk_gen_pll_lock);

//------------------------------------------------------------------------------
// CPU

logic inst_retired;

ama_riscv_top # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .UART_BR (UART_BR)
) ama_riscv_top_i (
    .clk (clk),
    .rst (rst),
    .uart_serial_in (FPGA_SERIAL_RX),
    .uart_serial_out (FPGA_SERIAL_TX),
    .inst_retired (inst_retired)
);

//------------------------------------------------------------------------------
// board indication

logic [25:0] instret_cnt; // 64M
`DFF_CI_RI_RVI_EN(inst_retired, (instret_cnt + 26'd1), instret_cnt);

logic instret_sig;
always_ff @(posedge clk) begin
    if (rst) instret_sig <= 'h0;
    else if (instret_cnt == {26{1'b1}}) instret_sig <= ~instret_sig;
end

logic boot_sig;
always @(posedge CLK100MHZ) begin
    if (rst) boot_sig <= 1'b0;
    else boot_sig <= 1'b1;
end

assign LEDS = {2'h0, instret_sig, boot_sig};

endmodule
