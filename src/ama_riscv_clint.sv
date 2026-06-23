`include "ama_riscv_defines.svh"

module ama_riscv_clint #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
) (
    input  logic clk,
    input  logic rst,
    clint_if.RX mmio,
    output logic mtip
);

//------------------------------------------------------------------------------
// local params, helpers
localparam unsigned CLOCKS_PER_US = (CLOCK_FREQ / 1_000_000);
localparam unsigned CNT_WIDTH = $clog2(CLOCKS_PER_US);

// word index into the CLINT register file (= dmem_addr[4:2])
localparam logic [2:0] CL_MTIMECMP_LO = 3'd2;
localparam logic [2:0] CL_MTIMECMP_HI = 3'd3;
localparam logic [2:0] CL_MTIME_LO = 3'd4;
localparam logic [2:0] CL_MTIME_HI = 3'd5;

//------------------------------------------------------------------------------
// MMIO write decode
// (msip not implemented)
logic wr;
assign wr = (mmio.ctrl.en && mmio.ctrl.we);
logic wr_mtimecmp_lo, wr_mtimecmp_hi, wr_mtime_lo, wr_mtime_hi;
assign wr_mtimecmp_lo = (wr && (mmio.ctrl.addr == CL_MTIMECMP_LO));
assign wr_mtimecmp_hi = (wr && (mmio.ctrl.addr == CL_MTIMECMP_HI));
assign wr_mtime_lo = (wr && (mmio.ctrl.addr == CL_MTIME_LO));
assign wr_mtime_hi = (wr && (mmio.ctrl.addr == CL_MTIME_HI));

// mtime
// MMIO write wins over the us-tick that cycle
logic tick_us;
logic [CNT_WIDTH-1:0] cnt_us; // 1 microsecond cnt
assign tick_us = (cnt_us == CNT_WIDTH'(CLOCKS_PER_US - 1));
`DFF_CI_RI_RVI_CLR_CLRVI(tick_us, (cnt_us + 'h1), cnt_us)

csr_dw_t mtime;
always_ff @(posedge clk) begin
    if (rst) begin
        mtime <= '0;
    end else begin
        if (tick_us) mtime <= (mtime + 64'h1);
        if (wr_mtime_lo) mtime.r[CSR_LOW] <= mmio.wdata;
        if (wr_mtime_hi) mtime.r[CSR_HIGH] <= mmio.wdata;
    end
end
assign mmio.mtime = mtime;

// mtimecmp
csr_dw_t mtimecmp;
always_ff @(posedge clk) begin
    if (rst) begin
        mtimecmp <= {ARCH_WIDTH_D{1'b1}};
    end else begin
        if (wr_mtimecmp_lo) mtimecmp.r[CSR_LOW] <= mmio.wdata;
        if (wr_mtimecmp_hi) mtimecmp.r[CSR_HIGH] <= mmio.wdata;
    end
end

// timer interrupt
assign mtip = (mtime.rdw >= mtimecmp.rdw);

//------------------------------------------------------------------------------
// MMIO read: registered, lands in WBK
arch_width_t rdata_nx;
always_comb begin
    unique case (mmio.ctrl.addr)
        CL_MTIMECMP_LO: rdata_nx = mtimecmp.r[CSR_LOW];
        CL_MTIMECMP_HI: rdata_nx = mtimecmp.r[CSR_HIGH];
        CL_MTIME_LO: rdata_nx = mtime.r[CSR_LOW];
        CL_MTIME_HI: rdata_nx = mtime.r[CSR_HIGH];
        default: rdata_nx = 'h0; // msip
    endcase
end
`DFF_CI_RI_RVI_EN(mmio.ctrl.en, rdata_nx, mmio.rdata)

endmodule
