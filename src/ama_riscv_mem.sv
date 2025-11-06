`include "ama_riscv_defines.svh"
`ifndef SYNT
`include "ama_riscv_tb_defines.svh"
`endif

module ama_riscv_mem (
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_imem,
    rv_if.TX     rsp_imem,
    rv_if.RX     req_dmem_r,
    rv_if_da.RX  req_dmem_w,
    rv_if.TX     rsp_dmem
);

`ifdef FPGA_SYNT
//(* dont_touch = "true" *)
(* ram_style = "block" *)
`endif
logic [MEM_DATA_BUS-1:0] mem [MEM_SIZE_Q-1:0];

`ifdef FPGA_SYNT
// preload for FPGA emulation
initial begin
    $readmemh(`TO_STRING(`FPGA_HEX_PATH), mem, 0, MEM_SIZE_Q-1);
end
`endif

// imem read
`DFF_CI_RI_RVI(1'b1, req_imem.ready) // always ready for new request out of rst
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
        rsp_dmem.valid <= 1'b0;
        // don't change rsp_dmem.data bus at the end of transfer
        //rsp_dmem.data <= 'h0;
    end
end

`ifndef SYNT
    task randomize_mem;
    for (int i = 0; i < MEM_SIZE_Q; i++) begin
        for (int j = 0; j < (MEM_DATA_BUS-1); j++) mem[i][j] = $random;
    end
    endtask

    task pattern_mem;
    for (int i = 0; i < MEM_SIZE_Q; i++) begin
        mem[i] = 'ha5a5a5a5_a5a5a5a5_a5a5a5a5_a5a5a5a5; // match isa sim
    end
    endtask

    initial begin
        //randomize_mem;
        pattern_mem;
    end
`endif

// dmem write
`DFF_CI_RI_RVI(1'b1, req_dmem_w.ready)
always_ff @(posedge clk) begin
    if (req_dmem_w.valid) begin
        //`LOG_D($sformatf("DMEM write: addr=0x%08h, wdata=0x%32h", req_dmem_w.addr, req_dmem_w.wdata));
        mem[req_dmem_w.addr] <= req_dmem_w.wdata;
    end
end

/*
// readback for debug
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
 */
endmodule
