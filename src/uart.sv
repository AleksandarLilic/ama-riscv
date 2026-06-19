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
`DFF_CI_RI_RV(1'b1, serial_in, serial_in_d);
`DFF_CI_RI_RV(1'b1, serial_out_tx, serial_out);

// use of shortcut allowed only if not synthesizing
`ifndef SYNT
`ifdef UART_SHORTCUT
`define USE_UART_SHORTCUT
`endif
`endif

`ifdef USE_UART_SHORTCUT
assign send_req.ready = 1'b1;
initial begin
    @(posedge clk);
    `LOG_W(
        "UART_SHORTCUT is used, execution clock cycles will be innacurate", 1);
end
`else
uart_tx #(
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_tx_i (
    .clk (clk),
    .rst (rst),
    .send_req (send_req),
    .serial_out (serial_out_tx)
);
`endif

`ifndef SYNT
`ifdef LOG_UART
initial begin
    forever begin
        @(posedge clk);
        #1;
        if (send_req.valid) begin
            `TB.uart_out = {`TB.uart_out, string'(send_req.data)};
        end
    end
end
`endif
`endif

// uart_rx has no backpressure
// buffer here instead, so the data is available for at least 1 symbol time
rv_if #(.DW(8)) recv_rsp_raw ();

logic recv_rsp_raw_valid_d;
`DFF_CI_RI_RVI(recv_rsp_raw.valid, recv_rsp_raw_valid_d)

assign recv_rsp_raw.ready = !recv_rsp.valid;
logic take_new_data;
assign take_new_data = (
    // only when new data arrives and current one has been read
    recv_rsp_raw.valid && !recv_rsp_raw_valid_d && recv_rsp_raw.ready
);

always_ff @(posedge clk) begin
    if (rst) begin
        recv_rsp.data <= 8'h0;
        recv_rsp.valid <= 1'b0;
    end else if (take_new_data) begin
        recv_rsp.data <= recv_rsp_raw.data;
        recv_rsp.valid <= 1'b1;
    end else if (recv_rsp.ready) begin
        recv_rsp.valid <= 1'b0;
    end
end

uart_rx #(
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_rx_i (
    .clk (clk),
    .rst (rst),
    .recv_rsp (recv_rsp_raw.TX),
    .serial_in (serial_in_d)
);

endmodule
