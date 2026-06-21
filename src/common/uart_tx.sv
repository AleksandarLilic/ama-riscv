`include "ama_riscv_defines.svh"

module uart_tx #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     send_req,
    output logic serial_out
);

localparam unsigned SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;
localparam unsigned CLOCK_COUNTER_WIDTH = $clog2(SYMBOL_EDGE_TIME);
localparam unsigned START_BIT = 1'b0;
localparam unsigned STOP_BIT = 1'b1;
localparam unsigned IDLE_BIT = 1'b1;

typedef logic [CLOCK_COUNTER_WIDTH-1:0] cnt_t;
localparam cnt_t SYMBOL_EDGE_TIME_M = cnt_t'(SYMBOL_EDGE_TIME - 1);

logic        symbol_edge;
logic        start;
logic        tx_running;
logic  [8:0] buffer;
logic  [3:0] bit_counter;
cnt_t clock_counter;

// Goes high (pulse) when it is time to start receiving a new character
assign start = send_req.valid && !tx_running;

// Counts down from 10 bits for every character
// START_BIT sent immediately in buffer always block
always_ff @(posedge clk) begin
    if (rst) bit_counter <= 0;
    else if (start) bit_counter <= 10;
    else if (symbol_edge && tx_running) bit_counter <= bit_counter - 1;
end

// Goes high while transmitting a character
assign tx_running = bit_counter != 4'd0;

// Counts cycles until a single symbol is done
always_ff @(posedge clk) begin
    if (rst) clock_counter <= 'h0;
    else if (start || symbol_edge) clock_counter <= 'h0;
    else clock_counter <= clock_counter + 1;
end

// Goes high at every symbol edge
assign symbol_edge = (clock_counter == SYMBOL_EDGE_TIME_M);

// Buffer
always_ff @(posedge clk) begin
    if (rst) begin
        buffer <= {9{IDLE_BIT}};
        serial_out <= IDLE_BIT;
    end else if (start) begin
        buffer <= {STOP_BIT, send_req.data};
        serial_out <=  START_BIT;
    end else if (symbol_edge && tx_running) begin
        buffer <= {IDLE_BIT, buffer[8:1]};
        serial_out <= buffer[0];
    end
end

// ready/valid
assign send_req.ready = !tx_running;

endmodule
