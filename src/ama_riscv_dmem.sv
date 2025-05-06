`include "ama_riscv_defines.svh"

module ama_riscv_dmem (
    input  logic        clk,
    input  logic        en,
    input  logic [ 3:0] we,
    input  logic [13:0] addr,
    input  logic [31:0] din,
    output logic [31:0] dout
);

logic [31:0] mem [0:`MEM_SIZE-1];

// dmem read
always_ff @(posedge clk) begin
    if (en) dout <= mem[addr];
end

// dmem write with byte enable
always_ff @(posedge clk) begin
    for (int i = 0; i < 4; i = i+1) begin
        if (we[i] && en) mem[addr][i*8 +: 8] <= din[i*8 +: 8];
    end
end

endmodule
