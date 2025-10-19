// Description:
// Module instantiates 2 UART sub-modules and connects them via RX/TX lines.
// Data Flow:
//    Testbench -> DUT_uart_i -> Serial line -> DUT_uart_j -> Testbench
// Testbench drives some data to TX and than compares it with the RX side

`timescale 1ns/1ps

`define CLK_PERIOD 8
`define CLOCK_FREQ 125_000_000
`define BAUD_RATE 115_200
`define SIM_TIME `CLOCK_FREQ*0.0009 // 900us

`define FAILED \
    $display(msg_fail); \
    $finish();

module uart_tb();

logic done = 0;
logic [7:0] payload;
integer i;

// I/O
logic clk = 0;
logic rst;
logic FPGA_SERIAL_RX;
logic FPGA_SERIAL_TX;

rv_if #(.DW(8)) send_req_ch ();
rv_if #(.DW(8)) recv_rsp_ch ();
// unused dummy channels, but can't compile w/o port connection on DUT instances
rv_if #(.DW(8)) dummy_send_req_ch ();
rv_if #(.DW(8)) dummy_recv_rsp_ch ();

// DUT instances
uart # (
    .CLOCK_FREQ (`CLOCK_FREQ),
    .BAUD_RATE (`BAUD_RATE)
) DUT_uart_i (
    .clk (clk),
    .rst (rst),
    .send_req (send_req_ch.RX),
    .recv_rsp (dummy_recv_rsp_ch.TX),
    .serial_in (FPGA_SERIAL_RX),
    .serial_out (FPGA_SERIAL_TX)
);

uart # (
    .CLOCK_FREQ (`CLOCK_FREQ),
    .BAUD_RATE (`BAUD_RATE)
) DUT_uart_j (
    .clk (clk),
    .rst (rst),
    .send_req (dummy_send_req_ch.RX),
    .recv_rsp (recv_rsp_ch.TX),
    // NOTE: lines are cross connected from first UART
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
// Test
initial begin
    rst = 1'b0;
    send_req_ch.data = 8'd0;
    send_req_ch.valid = 1'b0;
    recv_rsp_ch.ready = 1'b0;
    repeat (2) @(posedge clk); #1;

    // Reset the UARTs
    rst = 1'b1;
    @(posedge clk); #1;
    rst = 1'b0;

    fork
    begin
        for (i = 0; i < 10; i = i + 1) begin
            // Wait until the DUT_uart_i transmitter is ready
            while (send_req_ch.ready == 1'b0) begin
                @(posedge clk); #1;
            end

            // Send char to DUT_uart_i transmitter
            payload = 8'h41 + i; // 0x41 = A
            send_req_ch.data = payload;
            send_req_ch.valid = 1'b1;
            @(posedge clk);
            #1;
            send_req_ch.valid = 1'b0;

            // Wait for DUT_uart_j receiver to indicate it has valid data
            while (recv_rsp_ch.valid == 1'b0) begin
                @(posedge clk);
                #1;
            end

            $display(
                "Status val-%0d @ time t=%12t: DUT_uart_j got data: %h, expected: %h",
                i, $time, recv_rsp_ch.data, payload
            );

            // Check that the data is correct
            if (recv_rsp_ch.data !== payload) begin
                $display(
                    "Failure 1-%0d @ time t=%12t: DUT_uart_j got data: %h, but expected: %h",
                    i, $time, recv_rsp_ch.data, payload
                );
                `FAILED;
            end

            // wait a few cycles
            repeat(1*i) begin
                @(posedge clk);
                #1;
            end

            // Consume data
            recv_rsp_ch.ready = 1'b1;
            @(posedge clk);
            #1;
            recv_rsp_ch.ready = 1'b0;
            @(posedge clk);
            #1;

            // Check if no longer valid
            if (recv_rsp_ch.valid == 1'b1) begin
                $display(
                    "Failure r/v-%0d @ time t=%12t: DUT_uart_j didn't clear recv_rsp_ch.valid when recv_rsp_ch.ready was asserted",
                    i, $time
                );
                `FAILED;
            end
        end

        // Data should not change though
        repeat (10) @(posedge clk); #1;
        if (recv_rsp_ch.data !== payload) begin
            $display(
                "Failure 2 @ time t=%12t: DUT_uart_j got correct data, but it didn't hold recv_rsp_ch.data until recv_rsp_ch.ready was asserted",
                $time
            );
            `FAILED;
        end

        // DUT_uart_i transmitter should be idle
        // FPGA_SERIAL_TX line should be idle
        if (FPGA_SERIAL_TX !== 1'b1) begin
            $display(
                "Failure 3 @ time t=%12t: FPGA_SERIAL_TX was not high when the DUT_uart_i transmitter should be idle",
                $time
            );
            `FAILED;
        end

        // If recv_rsp_ch.ready is asserted to the DUT_uart_j receiver,
        // it should pull its recv_rsp_ch.valid signal low
        recv_rsp_ch.ready = 1'b1;
        @(posedge clk);
        #1;
        recv_rsp_ch.ready = 1'b0;
        @(posedge clk);
        #1;

        if (recv_rsp_ch.valid == 1'b1) begin
            $display(
                "Failure 4 @ time t=%12t: DUT_uart_j didn't clear recv_rsp_ch.valid when recv_rsp_ch.ready was asserted",
                $time
            );
            `FAILED;
        end
        done = 1;
    end

    // Catch time-out:
    begin
        repeat (`SIM_TIME) @(posedge clk);
        if (!done) begin
            $display("Test timed out");
            `FAILED;
        end
    end
    join

    repeat (20) @(posedge clk);
    $display(msg_pass);
    $finish();
end

endmodule
