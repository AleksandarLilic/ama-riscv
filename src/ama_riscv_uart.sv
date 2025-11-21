`include "ama_riscv_defines.svh"

module ama_riscv_uart #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst,
    uart_if.RX   uart_ch,
    input  logic serial_in,
    output logic serial_out
);

rv_if #(.DW(8)) send_req_ch ();
rv_if #(.DW(8)) recv_rsp_ch ();

// uart sync write
always_ff @(posedge clk) begin
    if (rst) begin
        send_req_ch.data <= 'h0;
        send_req_ch.valid <= 'b0;
    end else begin
        if (uart_ch.ctrl.we) begin
            case (uart_ch.ctrl.addr)
                UART_TX: begin
                    send_req_ch.data <= uart_ch.send;
                    send_req_ch.valid <= 1'b1;
                end
                default: ;
            endcase
        end else begin
            send_req_ch.data <= 'h0;
            send_req_ch.valid <= 'b0;
        end
    end
end

// uart sync read
uart_rv_ctrl_t uart_rv_ctrl_in, uart_rv_ctrl;
assign uart_rv_ctrl_in = '{
    rx_valid: recv_rsp_ch.valid,
    tx_ready: send_req_ch.ready
};
`DFF_CI_RI_RV('{0, 0}, uart_rv_ctrl_in, uart_rv_ctrl)

arch_width_t read;
assign read = uart_ch.ctrl.load_signed ?
    {{24{recv_rsp_ch.data[7]}}, recv_rsp_ch.data} :
    {24'd0, recv_rsp_ch.data};

always_ff @(posedge clk) begin
    if (rst) begin
        uart_ch.recv <= 'h0;
        recv_rsp_ch.ready <= 1'b0;
    end else if (uart_ch.ctrl.en) begin
        case (uart_ch.ctrl.addr)
            UART_CTRL: begin
                uart_ch.recv <= {30'd0, uart_rv_ctrl};
                recv_rsp_ch.ready <= 1'b1;
            end
            UART_RX: begin
                uart_ch.recv <= read;
                recv_rsp_ch.ready <= 1'b1;
            end
            default: begin
                uart_ch.recv <= 32'd0;
                recv_rsp_ch.ready <= 1'b0;
            end
        endcase
    end else begin
        uart_ch.recv <= 'h0;
        recv_rsp_ch.ready <= 1'b0;
    end
end

uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_i (
    .clk (clk),
    .rst (rst),
    .send_req (send_req_ch.RX),
    .recv_rsp (recv_rsp_ch.TX),
    .serial_in (serial_in),
    .serial_out (serial_out)
);

endmodule
