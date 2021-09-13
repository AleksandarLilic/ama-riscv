//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Data Memory
// File:            ama_riscv_dmem.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     Data Memory
//
// Version history:
//      2021-09-11  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------

module ama_riscv_dmem (
    input   wire        clk   ,
    input   wire        en    ,
    input   wire [ 3:0] we    ,
    input   wire [13:0] addr  ,
    input   wire [31:0] din   ,
    output  reg  [31:0] dout
);

//-----------------------------------------------------------------------------
// Signals
reg   [31:0] mem[16384-1:0];
    
//-----------------------------------------------------------------------------
// dmem read
always @(posedge clk) begin
    if (en)
        dout <= mem[addr];
end

//-----------------------------------------------------------------------------
// dmem write
genvar i;
generate for (i = 0; i < 4; i = i+1) begin
    always @(posedge clk) begin
        if (we[i] && en)
            mem[addr][i*8 +: 8] <= din[i*8 +: 8];
        end
    end 
endgenerate

endmodule
