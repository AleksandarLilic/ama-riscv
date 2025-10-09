`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"

module ama_riscv_mem (
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_imem,
    rv_if.TX     rsp_imem,
    rv_if.RX     req_dmem_r,
    rv_if_da.RX  req_dmem_w,
    rv_if.TX     rsp_dmem
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

// dmem read
`DFF_CI_RI_RVI(1'b1, req_dmem_r.ready)
always_ff @(posedge clk) begin
    if (req_dmem_r.valid) begin
        rsp_dmem.data <= mem[req_dmem_r.data];
        rsp_dmem.valid <= 1'b1;
    end else begin
        // don't change rsp_dmem.data bus
        rsp_dmem.valid <= 1'b0;
        rsp_dmem.data <= 'h0; // FIXME: remove
    end
end

// dmem write
`DFF_CI_RI_RVI(1'b1, req_dmem_w.ready)
always_ff @(posedge clk) begin
    if (req_dmem_w.valid) begin
        `LOG_D($sformatf("DMEM write: addr=0x%08h, wdata=0x%32h", req_dmem_w.addr, req_dmem_w.wdata));
        mem[req_dmem_w.addr] <= req_dmem_w.wdata;

    end
end

logic [MEM_ADDR_BUS-1:0] hold_addr;
initial begin
    forever @(posedge clk) begin
        if (req_dmem_w.valid) begin
            hold_addr = req_dmem_w.addr;
            #1; // wait for write to complete
            `LOG_D($sformatf("DMEM readback: addr=0x%08h, rdata=0x%32h", hold_addr, mem[hold_addr]));
        end
    end
end

endmodule
