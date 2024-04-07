module ama_riscv_imem (
    input  wire        clk,
    input  wire [13:0] addrb,
    output reg  [31:0] doutb
);

reg  [31:0] mem[16384-1:0];
    
// imem read
always @(posedge clk) begin
    doutb <= mem[addrb];
end

endmodule
