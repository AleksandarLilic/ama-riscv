`include "ama_riscv_defines.svh"

module ama_riscv_csr #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
)(
    input  logic clk,
    input  logic rst,
    input  csr_ctrl_t csr_ctrl,
    input  arch_width_t in,
    input  arch_width_t inst_exe,
    input  logic inst_to_be_retired,
    output arch_width_t csr_out
);

localparam unsigned CLOCKS_PER_US = CLOCK_FREQ / 1_000_000;
localparam unsigned CNT_WIDTH = $clog2(CLOCKS_PER_US);

csr_t csr; // regs
csr_addr_t csr_addr;
logic [4:0] csr_imm5;
arch_width_t csr_din_imm, csr_wr_data_source, csr_wr_data;
assign csr_imm5 = inst_exe[19:15];
assign csr_din_imm = {27'h0, csr_imm5}; // zero-extend
assign csr_wr_data_source = csr_ctrl.ui ? csr_din_imm : in;
assign csr_addr = csr_addr_t'(inst_exe[31:20] & {12{csr_ctrl.en}});

// csr read
always_comb begin
    csr_out = 'h0;
    if (csr_ctrl.re) begin
        case (csr_addr)
            CSR_TOHOST: csr_out = csr.tohost;
            CSR_MCYCLE: csr_out = csr.mcycle.r[CSR_LOW];
            CSR_MCYCLEH: csr_out = csr.mcycle.r[CSR_HIGH];
            CSR_MINSTRET: csr_out = csr.minstret.r[CSR_LOW];
            CSR_MINSTRETH: csr_out = csr.minstret.r[CSR_HIGH];
            CSR_MSCRATCH: csr_out = csr.mscratch;
            CSR_TIME: csr_out = csr.mtime.r[CSR_LOW];
            CSR_TIMEH: csr_out = csr.mtime.r[CSR_HIGH];
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    csr_wr_data = 'h0;
    case (csr_ctrl.op)
        CSR_OP_RW: csr_wr_data = csr_wr_data_source;
        CSR_OP_RS: csr_wr_data = csr_out | csr_wr_data_source;
        CSR_OP_RC: csr_wr_data = csr_out & ~csr_wr_data_source;
    endcase
end

// tohost/mscratch
always_ff @(posedge clk) begin
    if (rst) begin
        csr.tohost <= 'h0;
        csr.mscratch <= 'h0;
    end else if (csr_ctrl.we) begin
        case (csr_addr)
            CSR_TOHOST: csr.tohost <= csr_wr_data;
            CSR_MSCRATCH: csr.mscratch <= csr_wr_data;
            default: ;
        endcase
    end
end

// mcycle
logic csr_addr_match_mcycle, csr_addr_match_mcycle_l;
assign csr_addr_match_mcycle_l = (csr_addr == CSR_MCYCLE);
assign csr_addr_match_mcycle =
    csr_addr_match_mcycle_l || (csr_addr == CSR_MCYCLEH);

always_ff @(posedge clk) begin
    if (rst) begin
        csr.mcycle <= 'h0;
    end else if (csr_ctrl.we && csr_addr_match_mcycle) begin
        if (csr_addr_match_mcycle_l) csr.mcycle.r[CSR_LOW] <= csr_wr_data;
        else csr.mcycle.r[CSR_HIGH] <= csr_wr_data;
    end else begin
        csr.mcycle <= csr.mcycle + 'h1;
    end
end

// minstret
logic csr_addr_match_minstret, csr_addr_match_minstret_l;
assign csr_addr_match_minstret_l = (csr_addr == CSR_MINSTRET);
assign csr_addr_match_minstret =
    csr_addr_match_minstret_l || (csr_addr == CSR_MINSTRETH);

always_ff @(posedge clk) begin
    if (rst) begin
        csr.minstret <= 'h0;
    end else if (csr_ctrl.we && csr_addr_match_minstret) begin
        if (csr_addr_match_minstret_l) csr.minstret.r[CSR_LOW] <= csr_wr_data;
        else csr.minstret.r[CSR_HIGH] <= csr_wr_data;
    end else begin
        csr.minstret <= csr.minstret + {63'h0, inst_to_be_retired};
    end
end

// mtime
logic tick_us;
logic [CNT_WIDTH-1:0] cnt_us; // 1 microsecond cnt
always_ff @(posedge clk) begin
    if (rst) begin
        cnt_us <= 'h0;
        tick_us <= 1'b0;
    end else if (cnt_us == CNT_WIDTH'(CLOCKS_PER_US - 1)) begin
        cnt_us <= 'h0;
        tick_us <= 1'b1;
    end else begin
        cnt_us <= cnt_us + 'h1;
        tick_us <= 1'b0;
    end
end

`DFF_CI_RI_RVI((csr.mtime + {63'h0, tick_us}), csr.mtime)

endmodule
