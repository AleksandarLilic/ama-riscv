//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Synchronizer RTL
// File:            synchronizer.v
// Date created:    2021-05-31
// Author:          Aleksandar Lilic
// Description:     Simple sync module with two 1-bit FFs in series
//
// Version history:
//      2021-05-31  AL  0.1.0 - Initial
//      2021-05-31  AL  1.0.0 - Release
//-----------------------------------------------------------------------------

module synchronizer #(
    parameter WIDTH = 1
)(
    input  logic             clk,
    input  logic             rst,
    input  logic [WIDTH-1:0] async_signal,
    output logic [WIDTH-1:0] sync_signal
);

//-----------------------------------------------------------------------------
// Signals
logic [WIDTH-1:0] async_signal_d1;
logic [WIDTH-1:0] async_signal_d2;

//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        async_signal_d1 <= {WIDTH{1'b0}};
        async_signal_d2 <= {WIDTH{1'b0}};
    end
    else begin
        async_signal_d1 <= async_signal;
        async_signal_d2 <= async_signal_d1;
    end
end

assign sync_signal = async_signal_d2;

endmodule
