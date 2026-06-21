`include "ama_riscv_fpga_defines.svh"
`include "ama_riscv_defines.svh"

module ama_riscv_fpga #(
    parameter UART_BR = BR_115200
)(
    input  CLK_BOARD,
    input  RST_BOARD,
    output [3:0] LEDS,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

//------------------------------------------------------------------------------
// clocks and reset

localparam CPU_TARGET_FREQ_MHZ = `CPU_TARGET_FREQ_MHZ;
if (CPU_TARGET_FREQ_MHZ == 0) begin: check_cpu_target_freq_mhz
    $error("CPU_TARGET_FREQ_MHZ = 0");
end

localparam longint CLOCK_FREQ = (CPU_TARGET_FREQ_MHZ * 1_000_000);

logic clk, rst;
ama_riscv_fpga_clk_gen fpga_clk_gen_i (.CLK_BOARD, .RST_BOARD, .clk, .rst);

//------------------------------------------------------------------------------
// CPU

logic inst_retired;
ama_riscv_top # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .UART_BR (UART_BR)
) ama_riscv_top_i (
    .clk,
    .rst,
    .uart_serial_in (FPGA_SERIAL_RX),
    .uart_serial_out (FPGA_SERIAL_TX),
    .inst_retired
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
always @(posedge CLK_BOARD) begin
    if (rst) boot_sig <= 1'b0;
    else boot_sig <= 1'b1;
end

`ifdef BOARD_CMOD_A7
`define LEDS_OFF 2'b11
`else
`define LEDS_OFF 2'b00
`endif

assign LEDS = {`LEDS_OFF, instret_sig, boot_sig};

endmodule
