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

// imem read port
`DFF_CI_RI_RVI(1'b1, req_imem.ready) // always ready for new request out of rst
`DFF_CI_RI_RVI(req_imem.valid, rsp_imem.valid)

// dmem r/w port
`DFF_CI_RI_RVI(1'b1, req_dmem_r.ready)
`DFF_CI_RI_RVI(1'b1, req_dmem_w.ready)
`DFF_CI_RI_RVI(req_dmem_r.valid, rsp_dmem.valid)

logic [MEM_ADDR_BUS-1:0] addr_dmem;
assign addr_dmem = req_dmem_w.valid ? req_dmem_w.addr : req_dmem_r.data;

`ifdef FPGA_SYNT

xpm_memory_tdpram #(
    .MEMORY_SIZE        (MEM_SIZE_Q * MEM_DATA_BUS),
    .MEMORY_PRIMITIVE   ("block"),
    .CLOCKING_MODE      ("common_clock"),
    .ECC_MODE           ("no_ecc"),
    .ADDR_WIDTH_A       (MEM_ADDR_BUS),
    .WRITE_DATA_WIDTH_A (MEM_DATA_BUS),
    .READ_DATA_WIDTH_A  (MEM_DATA_BUS),
    .BYTE_WRITE_WIDTH_A (MEM_DATA_BUS), // single-bit wea, no bwe needed
    .READ_LATENCY_A     (1),
    .WRITE_MODE_A       ("no_change"),
    .ADDR_WIDTH_B       (MEM_ADDR_BUS),
    .WRITE_DATA_WIDTH_B (MEM_DATA_BUS),
    .READ_DATA_WIDTH_B  (MEM_DATA_BUS),
    .BYTE_WRITE_WIDTH_B (MEM_DATA_BUS), // single-bit web
    .READ_LATENCY_B     (1),
    .WRITE_MODE_B       ("no_change"),
    .MEMORY_INIT_FILE   (`TO_STRING(`FPGA_HEX_PATH)),
    .USE_MEM_INIT       (1)
) u_mem (
    // port A - imem (read-only)
    .clka (clk),
    .rsta (1'b0),
    .ena (req_imem.valid),
    .regcea (1'b1),
    .wea (1'b0),
    .addra (req_imem.data),
    .dina ({MEM_DATA_BUS{1'b0}}),
    .douta (rsp_imem.data),
    .injectsbiterra (1'b0),
    .injectdbiterra (1'b0),
    .sbiterra (),
    .dbiterra (),
    // port B - dmem (read/write, mutually exclusive per assertion below)
    .clkb (clk),
    .rstb (1'b0),
    .enb (req_dmem_r.valid | req_dmem_w.valid),
    .regceb (1'b1),
    .web (req_dmem_w.valid),
    .addrb (addr_dmem),
    .dinb (req_dmem_w.wdata),
    .doutb (rsp_dmem.data),
    .injectsbiterrb (1'b0),
    .injectdbiterrb (1'b0),
    .sbiterrb (),
    .dbiterrb (),
    // global
    .sleep (1'b0)
);

`else // !FPGA_SYNT

logic [MEM_DATA_BUS-1:0] mem [MEM_SIZE_Q-1:0];

// imem read
always_ff @(posedge clk) begin
    if (req_imem.valid) rsp_imem.data <= mem[req_imem.data];
end

// dmem r/w
always_ff @(posedge clk) begin
    if (req_dmem_w.valid) mem[addr_dmem] <= req_dmem_w.wdata;
    else if (req_dmem_r.valid) rsp_dmem.data <= mem[addr_dmem];
end

`ifndef SYNT
always_ff @(posedge clk) begin
    assert(!(req_dmem_r.valid && req_dmem_w.valid))
        else $fatal(1, "D$ read+write same cycle");
end
`endif

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

`endif // FPGA_SYNT

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
