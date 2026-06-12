`include "ama_riscv_fpga_defines.svh"
`include "ama_riscv_defines.svh"

module ama_riscv_fpga_clk_gen (
    input  CLK_BOARD,
    input  RST_BOARD,
    output clk,
    output rst
);

localparam CPU_TARGET_FREQ_MHZ = `CPU_TARGET_FREQ_MHZ;
if (CPU_TARGET_FREQ_MHZ == 0) begin: check_cpu_target_freq_mhz
    $error("CPU_TARGET_FREQ_MHZ = 0");
end

logic clk_gen, clk_gen_b;
logic clk_gen_fb_out, clk_gen_fb_out_b;
logic clk_gen_pll_lock;

`ifdef BOARD_ARTY_A7

// arty-7 100 MHz on-board osc
localparam CLOCK_FREQ_IN = 100; // MHz
localparam real CLOCK_PERIOD_IN = (1000.0 / CLOCK_FREQ_IN); // 10 ns
localparam longint CLKIN1 = (CLOCK_FREQ_IN * 1_000_000); // Hz
localparam DIVCLK_DIVIDE = 1;

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
    $error("unsupported CPU_TARGET_FREQ_MHZ for BOARD_ARTY_A7");
end

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
    .CLKIN1_PERIOD (CLOCK_PERIOD_IN)
) plle2_adv_i (
    // input clock and control
    .CLKFBIN (clk_gen_fb_out_b),
    .CLKIN1 (CLK_BOARD),
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

`elsif BOARD_CMOD_A7

// cmod a7 12 MHz on-board osc
localparam CLOCK_FREQ_IN = 12; // MHz
localparam real CLOCK_PERIOD_IN = (1000.0 / CLOCK_FREQ_IN); // 83.333 ns
localparam longint CLKIN1 = (CLOCK_FREQ_IN * 1_000_000); // Hz
localparam DIVCLK_DIVIDE = 1;

// MMCM config per target freq; vco = CLKIN1 * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
localparam real CLKFBOUT_MULT_F =
    (CPU_TARGET_FREQ_MHZ == 50) ? 54.0 : // vco 647.99
    (CPU_TARGET_FREQ_MHZ == 55) ? 55.0 : // vco 659.99
    (CPU_TARGET_FREQ_MHZ == 60) ? 60.0 : // vco 719.99
    0.0; // unsupported -> caught by check below

localparam real CLKOUT0_DIVIDE_F =
    (CPU_TARGET_FREQ_MHZ == 50) ? 13.0 :
    (CPU_TARGET_FREQ_MHZ == 55) ? 12.0 :
    (CPU_TARGET_FREQ_MHZ == 60) ? 12.0 :
    0.0;

if (CLKFBOUT_MULT_F == 0.0) begin: check_target_freq
    $error("unsupported CPU_TARGET_FREQ_MHZ for BOARD_CMOD_A7");
end

MMCME2_ADV #(
    .BANDWIDTH ("OPTIMIZED"),
    .CLKOUT4_CASCADE ("FALSE"),
    .COMPENSATION ("ZHOLD"),
    .STARTUP_WAIT ("FALSE"),
    .DIVCLK_DIVIDE (DIVCLK_DIVIDE),
    .CLKFBOUT_MULT_F (CLKFBOUT_MULT_F),
    .CLKFBOUT_PHASE (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F (CLKOUT0_DIVIDE_F),
    .CLKOUT0_PHASE (0.000),
    .CLKOUT0_DUTY_CYCLE (0.500), // 50%
    .CLKOUT0_USE_FINE_PS ("FALSE"),
    .CLKIN1_PERIOD (CLOCK_PERIOD_IN)
) mmcme2_adv_i (
    // outputs
    .CLKFBOUT (clk_gen_fb_out),
    .CLKFBOUTB (),
    .CLKOUT0 (clk_gen),
    .CLKOUT0B (),
    .CLKOUT1 (),
    .CLKOUT1B (),
    .CLKOUT2 (),
    .CLKOUT2B (),
    .CLKOUT3 (),
    .CLKOUT3B (),
    .CLKOUT4 (),
    .CLKOUT5 (),
    .CLKOUT6 (),
    // input clock and control
    .CLKFBIN (clk_gen_fb_out_b),
    .CLKIN1 (CLK_BOARD),
    .CLKIN2 (1'b0),
    .CLKINSEL (1'b1),
    // dynamic reconfiguration (unused)
    .DADDR (7'h0),
    .DCLK (1'b0),
    .DEN (1'b0),
    .DI (16'h0),
    .DO (),
    .DRDY (),
    .DWE (1'b0),
    // dynamic phase shift (unused)
    .PSCLK (1'b0),
    .PSEN (1'b0),
    .PSINCDEC (1'b0),
    .PSDONE (),
    // control and status signals
    .LOCKED (clk_gen_pll_lock), // output
    .CLKINSTOPPED (),
    .CLKFBSTOPPED (),
    .PWRDWN (1'b0), // input
    .RST (1'b0) // input
);

`else

if (1) begin: check_board
    $error("unsupported board: define BOARD_ARTY_A7 or BOARD_CMOD_A7");
end

`endif

// common for both, buffer the outputs
BUFG clk_gen_buf (.I (clk_gen), .O (clk_gen_b));
BUFG clk_gen_fb_buf (.I (clk_gen_fb_out), .O (clk_gen_fb_out_b));

assign clk = clk_gen_b;
assign rst = (RST_BOARD || ~clk_gen_pll_lock);

endmodule
