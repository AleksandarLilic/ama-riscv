module ama_riscv_imem (
    input  logic        clk,
    input  logic [13:0] addrb,
    output logic [31:0] doutb
);

logic [31:0] mem[16384-1:0];
always_ff @(posedge clk) doutb <= mem[addrb]; // imem read

endmodule
