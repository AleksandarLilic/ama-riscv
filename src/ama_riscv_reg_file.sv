`include "ama_riscv_defines.svh"

module ama_riscv_reg_file (
    input  logic clk,
    input  logic we,
    input  logic we_p,
    input  rf_addr_t addr_a,
    input  rf_addr_t addr_b,
    input  rf_addr_t addr_d,
    input  arch_width_t data_d,
    input  arch_width_t data_dp,
    output arch_width_t data_a,
    output arch_width_t data_b
);

arch_width_t rf [1:RF_NUM-1];

// synchronous register write with optional paired register
rf_addr_t addr_dp;
assign addr_dp = get_rdp(addr_d);

logic rd_we, rdp_we;
assign rd_we = (we && (addr_d != RF_X0_ZERO));
assign rdp_we = (we_p && (addr_dp != RF_X0_ZERO));

`ifndef SYNT
always_comb begin
    if (we_p) begin
        assert (addr_d != RF_X31_T6)
        else $fatal(1, "rd=x31, illegal for rdp write");
    end
end
`endif

always @ (posedge clk) begin
    if (rd_we) begin
        rf[addr_d] <= data_d;
        if (rdp_we) rf[addr_dp] <= data_dp;
    end
end

// asynchronous register read
always_comb begin
    if (addr_a == RF_X0_ZERO) data_a = 'h0;
    else data_a = rf[addr_a];
    if (addr_b == RF_X0_ZERO) data_b = 'h0;
    else data_b = rf[addr_b];
end

endmodule
