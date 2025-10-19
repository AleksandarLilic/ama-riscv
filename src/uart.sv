`include "ama_riscv_defines.svh"

module uart #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     send_req,
    rv_if.TX     recv_rsp,
    input  logic serial_in,
    output logic serial_out
);

logic serial_in_d;
logic serial_out_tx;

// flop the in/out
`DFF_CI_RI_RVI(serial_in, serial_in_d);
`DFF_CI_RI_RVI(serial_out_tx, serial_out);

uart_tx #(
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_tx_i (
    .clk (clk),
    .rst (rst),
    .send_req (send_req),
    .serial_out (serial_out_tx)
);

uart_rx #(
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_rx_i (
    .clk (clk),
    .rst (rst),
    .recv_rsp (recv_rsp),
    .serial_in (serial_in_d)
);

endmodule
