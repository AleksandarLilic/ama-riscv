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

module uart_tb();

// I/O of off-chip and on-chip UART
logic        clk = 0;
logic        rst;
logic        FPGA_SERIAL_RX;
logic        FPGA_SERIAL_TX;
logic  [7:0] data_in;
logic        data_in_valid;
logic        data_in_ready;
logic  [7:0] data_out;
logic        data_out_valid;
logic        data_out_ready;
// Testbench variables
logic        done = 0;
logic  [7:0] payload;
integer     i;

// DUT instances
uart # (
    .CLOCK_FREQ     (`CLOCK_FREQ),
    .BAUD_RATE      (`BAUD_RATE)
) DUT_uart_i (
    .clk            (clk),
    .rst            (rst),
    // tx
    .data_in        (data_in),
    .data_in_valid  (data_in_valid), // ready/valid input
    .data_in_ready  (data_in_ready), // ready/valid output
    // rx not used
    .data_out       (),
    .data_out_valid (),
    .data_out_ready (),
    // phy
    .serial_in      (FPGA_SERIAL_RX),
    .serial_out     (FPGA_SERIAL_TX)
);

uart # (
    .CLOCK_FREQ     (`CLOCK_FREQ),
    .BAUD_RATE      (`BAUD_RATE)
) DUT_uart_j (
    .clk            (clk),
    .rst            (rst),
    // tx not used
    .data_in        (),
    .data_in_valid  (),
    .data_in_ready  (),
    // rx
    .data_out       (data_out),
    .data_out_valid (data_out_valid), // ready/valid output
    .data_out_ready (data_out_ready), // ready/valid input
    // phy
    // NOTE: lines are cross connected from first UART
    .serial_in      (FPGA_SERIAL_TX),
    .serial_out     (FPGA_SERIAL_RX)
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
    rst             = 1'b0;
    data_in         = 8'd0;
    data_in_valid   = 1'b0;
    data_out_ready  = 1'b0;
    repeat (2) @(posedge clk); #1;

    // Reset the UARTs
    rst = 1'b1;
    @(posedge clk); #1;
    rst = 1'b0;

    fork
    begin
        for (i = 0; i < 10; i = i + 1) begin
            // Wait until the DUT_uart_i transmitter is ready
            while (data_in_ready == 1'b0) begin
                @(posedge clk); #1;
            end

            // Send char to DUT_uart_i transmitter
            payload = 8'h11 + i;
            data_in = payload;
            data_in_valid = 1'b1;
            @(posedge clk);
            #1;
            data_in_valid = 1'b0;

            // Wait for DUT_uart_j receiver to indicate it has valid data
            while (data_out_valid == 1'b0) begin
                @(posedge clk);
                #1;
            end

            $display(
                "Status val-%0d @ time t=%12t: DUT_uart_j got data: %h, expected: %h",
                i, $time, data_out, payload
            );

            // Check that the data is correct
            if (data_out !== payload) begin
                $display(
                    "Failure 1-%0d @ time t=%12t: DUT_uart_j got data: %h, but expected: %h",
                    i, $time, data_out, payload
                );
            end

            // wait a few cycles
            repeat(1*i) begin
                @(posedge clk);
                #1;
            end

            // Consume data
            data_out_ready = 1'b1;
            @(posedge clk);
            #1;
            data_out_ready = 1'b0;
            @(posedge clk);
            #1;

            // Check if no longer valid
            if (data_out_valid == 1'b1) begin
                $display(
                    "Failure r/v-%0d @ time t=%12t: DUT_uart_j didn't clear data_out_valid when data_out_ready was asserted",
                    i, $time
                );
            end
        end

        // Data should not change though
        repeat (10) @(posedge clk); #1;
        if (data_out !== payload) begin
            $display(
                "Failure 2 @ time t=%12t: DUT_uart_j got correct data, but it didn't hold data_out until data_out_ready was asserted",
                $time
            );
        end

        // DUT_uart_i transmitter should be idle
        // FPGA_SERIAL_TX line should be idle
        if (FPGA_SERIAL_TX !== 1'b1) begin
            $display(
                "Failure 3 @ time t=%12t: FPGA_SERIAL_TX was not high when the DUT_uart_i transmitter should be idle",
                $time
            );
        end

        // If data_out_ready is asserted to the DUT_uart_j receiver,
        // it should pull its data_out_valid signal low
        data_out_ready = 1'b1;
        @(posedge clk);
        #1;
        data_out_ready = 1'b0;
        @(posedge clk);
        #1;

        if (data_out_valid == 1'b1) begin
            $display(
                "Failure 4 @ time t=%12t: DUT_uart_j didn't clear data_out_valid when data_out_ready was asserted",
                $time
            );
        end
        done = 1;
    end

    // Catch time-out:
    begin
        repeat (`SIM_TIME) @(posedge clk);
        if (!done) begin
            $display("Test timed out");
            $display(msg_fail);
            $finish();
        end
    end
    join

    repeat (20) @(posedge clk);
    $display(msg_pass);
    $finish();
end

endmodule
