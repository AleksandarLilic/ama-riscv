// Description:
// Instantiates uart_fpga (DUT) and a uart (off_chip_uart) connected via
// cross-connected serial lines. The off-chip UART sends characters to the
// DUT, which performs case-flipping on ASCII letters and echoes them back.
// The testbench verifies each echoed character against the expected value.
// Data Flow:
//    Testbench -> off_chip_uart -> FPGA_SERIAL_RX -> DUT (uart_fpga)
//    Testbench <- off_chip_uart <- FPGA_SERIAL_TX <- DUT (uart_fpga)

`timescale 1ns/1ps

// redefine these two during build if needed
`define CLK_PERIOD 10 // ns - 100 MHz
`define BAUD_RATE 115_200

parameter unsigned CLOCK_FREQ   = (1000 / `CLK_PERIOD) * 1_000_000; // Hz
parameter unsigned BITS_PER_SYM = (1 + 8 + 1); // 8N1: start + 8 data + stop
parameter unsigned CLKS_PER_BIT = (CLOCK_FREQ / `BAUD_RATE);
parameter unsigned CLKS_PER_SYM = (CLKS_PER_BIT * BITS_PER_SYM);
parameter unsigned SYMBOLS_TO_SEND = 50;
// each symbol needs one send + one echo receive (two serial transfers)
parameter unsigned TIMEOUT_CLKS = CLKS_PER_SYM * 2 * SYMBOLS_TO_SEND + 1000;

`define FAILED \
    $display(msg_fail); \
    $finish();

`define TB uart_fpga_tb

module `TB();

logic done = 0;
logic [7:0] payload;
logic [7:0] expected;
integer i;
integer err_cnt;

// I/O
logic clk = 0;
logic rst;
logic FPGA_SERIAL_RX;
logic FPGA_SERIAL_TX;
logic [5:0] leds;

// Off-chip UART rv_if channels
rv_if #(.DW(8)) off_chip_send_req_ch ();
rv_if #(.DW(8)) off_chip_recv_rsp_ch ();

// DUT: uart_fpga (on-chip, Arty A7-100, 100 MHz)
uart_fpga # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (`BAUD_RATE)
) DUT (
    .CLK100MHZ (clk),
    .BUTTONS ({3'd0, rst}),
    .SWITCHES (4'd0),
    .LEDS (leds),
    .FPGA_SERIAL_RX (FPGA_SERIAL_RX),
    .FPGA_SERIAL_TX (FPGA_SERIAL_TX)
);

// Off-chip UART: simulates the host/workstation
uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (`BAUD_RATE)
) off_chip_uart (
    .clk (clk),
    .rst (rst),
    .send_req (off_chip_send_req_ch.RX),
    .recv_rsp (off_chip_recv_rsp_ch.TX),
    // lines are cross-connected: off-chip TX -> DUT RX, DUT TX -> off-chip RX
    .serial_in (FPGA_SERIAL_TX),
    .serial_out (FPGA_SERIAL_RX)
);

// clk gen
always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    $timeformat(-6, 1, " us", 9);
end

string msg_pass = "==== PASS ====";
string msg_fail = "==== FAIL ====";

// Case-flip helper: mirrors the DUT loopback logic
function automatic logic [7:0] case_flip(input logic [7:0] c);
    if (c >= 8'd65 && c <= 8'd90) return c + 8'd32; // A-Z -> a-z
    else if (c >= 8'd97 && c <= 8'd122) return c - 8'd32; // a-z -> A-Z
    else return c;
endfunction

// Test
initial begin
    err_cnt = 0;
    rst = 1'b0;
    off_chip_send_req_ch.data = 8'd0;
    off_chip_send_req_ch.valid = 1'b0;
    off_chip_recv_rsp_ch.ready = 1'b0;

    repeat (4) @(posedge clk);
    #1;

    // Reset
    rst = 1'b1;
    @(posedge clk);
    #1;
    rst = 1'b0;

    // idle for a bit
    repeat (50) @(posedge clk);
    #1;

    fork
    begin
        for (i = 0; i < SYMBOLS_TO_SEND; i = i + 1) begin
            payload = 8'h41 + i; // start at 'A'
            expected = case_flip(payload);

            // Wait until off-chip UART transmitter is ready
            while (off_chip_send_req_ch.ready == 1'b0) begin
                @(posedge clk); #1;
            end

            // Send character
            off_chip_send_req_ch.data = payload;
            off_chip_send_req_ch.valid = 1'b1;
            @(posedge clk);
            #1;
            off_chip_send_req_ch.valid = 1'b0;

            // Wait for echoed (case-flipped) data to arrive at off-chip RX
            while (off_chip_recv_rsp_ch.valid == 1'b0) begin
                @(posedge clk); #1;
            end

            $write("Symbol %2d @ t=%12t: ", i, $time );
            $display(
                "sent %h (%s)  received %h (%s)  expected %h (%s)%s",
                payload, payload,
                off_chip_recv_rsp_ch.data, off_chip_recv_rsp_ch.data,
                expected, expected,
                (off_chip_recv_rsp_ch.data !== expected) ? "  <-- ERROR" : ""
            );

            if (off_chip_recv_rsp_ch.data !== expected) begin
                err_cnt = err_cnt + 1;
            end

            // Consume received data
            off_chip_recv_rsp_ch.ready = 1'b1;
            @(posedge clk);
            #1;
            off_chip_recv_rsp_ch.ready = 1'b0;
            @(posedge clk);
            #1;
        end
        done = 1;
    end

    // Catch time-out
    begin
        repeat (TIMEOUT_CLKS) @(posedge clk);
        if (!done) begin
            $display("Test timed out");
            `FAILED;
        end
    end
    join

    repeat (20) @(posedge clk);
    $display("Test done");
    if (err_cnt == 0) begin
        $display(msg_pass);
    end else begin
        $display("Number of errors: %0d / %0d", err_cnt, SYMBOLS_TO_SEND);
        `FAILED;
    end
    $finish();
end

endmodule
