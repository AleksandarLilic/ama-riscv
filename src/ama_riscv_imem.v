//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Instruction Memory
// File:            ama_riscv_imem.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     Instruction Memory
//
// Version history:
//      2021-09-11  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------

module ama_riscv_imem (
    input   wire        clk    ,
    input   wire        ena    ,
    input   wire [ 3:0] wea    ,
    input   wire [13:0] addra  ,
    input   wire [31:0] dina   ,
    input   wire [13:0] addrb  ,
    output  reg  [31:0] doutb
);
//-----------------------------------------------------------------------------
// Signals
reg   [31:0] mem[16384-1:0];
    
//-----------------------------------------------------------------------------
// imem read
always @(posedge clk) begin
    doutb <= mem[addrb];
end

//-----------------------------------------------------------------------------
// imem write
genvar i;
generate for (i = 0; i < 4; i = i+1) begin
    always @(posedge clk) begin
        if (wea[i] && ena)
            mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
        end
    end 
endgenerate

endmodule
