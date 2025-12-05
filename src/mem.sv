`include "ama_riscv_defines.svh"

module mem #(
    parameter unsigned DW = 128,
    parameter unsigned AW = 16
)(
    input  logic clk,
    input  logic en,
    input  logic [(DW>>3)-1:0] we,
    input  logic [AW-1:0] addr,
    input  logic [DW-1:0] din,
    output logic [DW-1:0] dout
);

localparam unsigned WORDS = (1 << AW);

`ifdef FPGA_SYNT
//(* dont_touch = "true" *)
(* ram_style = "block" *)
`endif
logic [DW-1:0] m [WORDS-1:0];

// read
always_ff @(posedge clk) begin
    if (en) dout <= m[addr];
end

// byte enable write
always_ff @(posedge clk) begin
    `IT((DW>>3)) if (en && we[i]) m[addr][i*8 +: 8] <= din[i*8 +: 8];
end

endmodule
