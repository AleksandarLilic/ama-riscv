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
//      2021-10-28  AL  0.1.1 - Fix IMEM ports
//
//-----------------------------------------------------------------------------

module ama_riscv_imem (
    input   wire        clk    ,
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
// Load IMEM for FPGA runs
// `ifdef SYNTHESIS
    initial begin
        $readmemh("/home/aleksandar/Documents/xilinx/ama-riscv/sw/uart_test/uart_test.hex", mem); 
    end
// `endif


endmodule
