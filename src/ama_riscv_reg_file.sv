`include "ama_riscv_defines.svh"

module ama_riscv_reg_file #(
    parameter unsigned BANKED = 0
)(
    input  logic clk,
    input  rf_we_t we,
    input  rf_addr_t addr_a,
    input  rf_addr_t addr_b,
    input  rf_addr_t addr_c,
    input  rf_addr_t addr_d,
    input  arch_width_t data_d,
    input  arch_width_t data_dp,
    output arch_width_t data_a,
    output arch_width_t data_b,
    output arch_width_t data_c
);

`ifndef SYNT
// for tb views only, always flat
arch_width_t rf_v [0:RF_NUM-1];
`endif

if (BANKED == 0) begin: gen_flat_rf
arch_width_t rf [1:RF_NUM-1];

// synchronous register write with optional paired register
rf_addr_t addr_dp;
assign addr_dp = get_rdp(addr_d);

logic rd_we, rdp_we;
assign rd_we = (we.rd && (addr_d != RF_X0_ZERO));
assign rdp_we = (we.rdp && (addr_dp != RF_X0_ZERO));

always @ (posedge clk) begin
    if (rd_we) begin
        rf[addr_d] <= data_d;
        if (rdp_we) rf[addr_dp] <= data_dp;
    end
end

// asynchronous register read
always_comb begin
    // A
    if (addr_a == RF_X0_ZERO) data_a = 'h0;
    else data_a = rf[addr_a];
    // B
    if (addr_b == RF_X0_ZERO) data_b = 'h0;
    else data_b = rf[addr_b];
    // C
    if (addr_c == RF_X0_ZERO) data_c = 'h0;
    else data_c = rf[addr_c];
end

`ifndef SYNT
always_comb begin
    `IT_I(1, RF_NUM) rf_v[i] = rf[i];
end
`endif

end else begin: gen_banked_rf

//  - even regs: x0, x2, x4, ... x30  (index = reg[4:1])
//  - odd  regs: x1, x3, x5, ... x31  (index = reg[4:1])
// x0 allocated but never used
arch_width_t rf_even [0:15];
arch_width_t rf_odd [0:15];

logic [3:0] idx_d;
assign idx_d = addr_d[4:1];
logic addr_d_even, addr_d_odd;
assign addr_d_even = (addr_d[0] == 1'b0);
assign addr_d_odd = (addr_d[0] == 1'b1);

logic rd_we;
assign rd_we = (we.rd && (addr_d != RF_X0_ZERO));

logic rdp_we;
assign rdp_we = (
    we.rdp && addr_d_even && (addr_d != RF_X0_ZERO) && (addr_d != RF_X31_T6)
);

// even bank writes:
//  - single write when rd is even
//  - paired write always writes rd (which is even by construction)
always_ff @(posedge clk) begin
    if (rdp_we) rf_even[idx_d] <= data_d;
    else if (rd_we && addr_d_even) rf_even[idx_d] <= data_d;
end

// odd bank writes:
//  - single write when rd is odd
//  - paired write writes rdp (= rd+1), which is odd
always_ff @(posedge clk) begin
    if (rdp_we) rf_odd[idx_d] <= data_dp;
    else if (rd_we && addr_d_odd) rf_odd[idx_d] <= data_d;
end

// asynchronous register read
always_comb begin
    // A
    if (addr_a == RF_X0_ZERO) data_a = 'h0;
    else if (addr_a[0] == 1'b0) data_a = rf_even[addr_a[4:1]];
    else data_a = rf_odd[addr_a[4:1]];
    // B
    if (addr_b == RF_X0_ZERO) data_b = 'h0;
    else if (addr_b[0] == 1'b0) data_b = rf_even[addr_b[4:1]];
    else data_b = rf_odd[addr_b[4:1]];
    // C
    if (addr_c == RF_X0_ZERO) data_c = 'h0;
    else if (addr_c[0] == 1'b0) data_c = rf_even[addr_c[4:1]];
    else data_c = rf_odd[addr_c[4:1]];
end

`ifndef SYNT
always_comb begin
    for (int i = 0; i < (RF_NUM); i += 2) begin
        rf_v[i] = rf_even[i/2];
        rf_v[i+1] = rf_odd[i/2];
    end
end
`endif

end

// asserts
`ifndef SYNT
always_comb begin
    if (we.rdp) begin
        assert (addr_d != RF_X31_T6)
            else $fatal(1, "rd=x31, illegal for rdp write");
        assert (addr_d[0] == 1'b0)
            else $fatal(1, "paired write illegal: rd is odd");
    end
end
`endif

endmodule
