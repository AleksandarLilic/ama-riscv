`include "ama_riscv_defines.svh"

module ama_riscv_mem (
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_imem,
    rv_if.TX     rsp_imem
    /* rv_if.RX     req_dmem_r,
    rv_if.TX     rsp_dmem_r,
    rv_if.RX     req_dmem_w_addr,
    rv_if.RX     req_dmem_w_data */
);

localparam unsigned DEPTH = 4096; // 64K with 128-bit bus
logic [MEM_DATA_BUS-1:0] mem [DEPTH-1:0];

`DFF_CI_RI_RVI(1'b1, req_imem.ready) // always ready for new request out of rst

// imem read
always_ff @(posedge clk) begin
    if (req_imem.valid) begin
        rsp_imem.data <= mem[req_imem.data];
        rsp_imem.valid <= 1'b1;
    end else begin
        // don't change rsp_imem.data bus
        rsp_imem.valid <= 1'b0;
    end
end

/* // dmem read
always_ff @(posedge clk) begin
    if (req_dmem_r.valid) begin
        rsp_dmem_r.data <= mem[req_dmem_r.data];
        rsp_dmem_r.valid <= 1'b1;
    end else begin
        // don't change rsp_dmem_r.data bus
        rsp_dmem_r.valid <= 1'b0;
    end
end */

endmodule
