`include "ama_riscv_defines.svh"

`define SYNT
`define FPGA

`ifndef CPU_TARGET_FREQ_MHZ
`define CPU_TARGET_FREQ_MHZ 50
`endif

module ama_riscv_fpga #(
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

// arty-7 100 MHz on-board osc
localparam CLOCK_FREQ_ARTY_7 = 100; //  MHz
localparam real CLOCK_PERIOD_ARTY_7 = (1000.0 / CLOCK_FREQ_ARTY_7); // 10 ns
// PLL config
localparam longint CLKIN1 = (CLOCK_FREQ_ARTY_7 * 1_000_000); // Hz
localparam DIVCLK_DIVIDE = 1;

localparam CPU_TARGET_FREQ_MHZ = `CPU_TARGET_FREQ_MHZ;
if (CPU_TARGET_FREQ_MHZ == 0) begin: check_cpu_target_freq_mhz
    $error("CPU_TARGET_FREQ_MHZ = 0");
end

// PLL config per target freq; vco = CLKIN1 * CLKFBOUT_MULT / DIVCLK_DIVIDE
localparam CLKFBOUT_MULT =
    (CPU_TARGET_FREQ_MHZ == 50)  ? 15 : // vco 1500
    (CPU_TARGET_FREQ_MHZ == 55)  ? 11 : // vco 1100
    (CPU_TARGET_FREQ_MHZ == 60)  ? 15 : // vco 1500
    (CPU_TARGET_FREQ_MHZ == 65)  ? 13 : // vco 1300
    (CPU_TARGET_FREQ_MHZ == 70)  ? 14 : // vco 1400
    (CPU_TARGET_FREQ_MHZ == 75)  ? 15 : // vco 1500
    (CPU_TARGET_FREQ_MHZ == 80)  ? 12 : // vco 1200
    (CPU_TARGET_FREQ_MHZ == 90)  ?  9 : // vco 900
    (CPU_TARGET_FREQ_MHZ == 100) ? 15 : // vco 1500
    0; // unsupported -> caught by check below

localparam CLKOUT0_DIVIDE =
    (CPU_TARGET_FREQ_MHZ == 50)  ? 30 :
    (CPU_TARGET_FREQ_MHZ == 55)  ? 20 :
    (CPU_TARGET_FREQ_MHZ == 60)  ? 25 :
    (CPU_TARGET_FREQ_MHZ == 65)  ? 20 :
    (CPU_TARGET_FREQ_MHZ == 70)  ? 20 :
    (CPU_TARGET_FREQ_MHZ == 75)  ? 20 :
    (CPU_TARGET_FREQ_MHZ == 80)  ? 15 :
    (CPU_TARGET_FREQ_MHZ == 90)  ? 10 :
    (CPU_TARGET_FREQ_MHZ == 100) ? 15 :
    0;

if (CLKFBOUT_MULT == 0) begin: check_target_freq
    $error("unsupported CPU_TARGET_FREQ_MHZ");
end

localparam longint CLOCK_FREQ = (
    //CLKIN1 * (CLKFBOUT_MULT / (DIVCLK_DIVIDE * CLKOUT0_DIVIDE))
    (CLKIN1 * CLKFBOUT_MULT) / DIVCLK_DIVIDE / CLKOUT0_DIVIDE
);

if (CLOCK_FREQ == 0) begin: check_clock_freq
    $error("CLOCK_FREQ = 0");
end

logic clk_gen, clk_gen_b;
logic clk_gen_fb_out, clk_gen_fb_out_b;
logic clk_gen_pll_lock;

// 50 MHz config
PLLE2_ADV #(
    .BANDWIDTH ("OPTIMIZED"),
    .COMPENSATION ("BUF_IN"), // ZHOLD is default
    .STARTUP_WAIT ("FALSE"),
    .DIVCLK_DIVIDE (DIVCLK_DIVIDE),
    .CLKFBOUT_MULT (CLKFBOUT_MULT),
    .CLKOUT0_DIVIDE (CLKOUT0_DIVIDE),
    .CLKFBOUT_PHASE (0.000),
    .CLKOUT0_PHASE (0.000),
    .CLKOUT0_DUTY_CYCLE (0.500), // 50%
    .CLKIN1_PERIOD (CLOCK_PERIOD_ARTY_7)
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
    else if (instret_cnt == 'h0) instret_sig <= ~instret_sig;
end

logic boot_sig;
always @(posedge CLK100MHZ) begin
    if (rst) boot_sig <= 1'b0;
    else boot_sig <= 1'b1;
end

assign LEDS = {2'h0, instret_sig, boot_sig};

endmodule
