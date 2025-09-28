`include "ama_riscv_defines.svh"

module ama_riscv_dmem (
    input  logic        clk,
    input  logic [ 3:0] we,
    rv_if_d2.RX req,
    rv_if.TX    rsp
);

logic [31:0] mem [0:MEM_SIZE_W-1];
// ignores r/v handshake as it can always respond in 1 cycle
// rv_if used for simplicity

// dmem read
assign req.ready = 1'b1; // always ready
always_ff @(posedge clk) begin
    if (req.valid) begin
        rsp.data <= mem[req.data1];
        rsp.valid <= 1'b1;
    end else begin
        // don't change rsp.data bus
        rsp.valid <= 1'b0;
    end
end

// dmem write with byte enable
always_ff @(posedge clk) begin
    for (int i = 0; i < 4; i = i + 1) begin
        if (we[i] && req.valid) mem[req.data1][i*8 +: 8] <= req.data2[i*8 +: 8];
    end
end

endmodule
