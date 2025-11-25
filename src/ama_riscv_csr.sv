`include "ama_riscv_defines.svh"

module ama_riscv_csr #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
)(
    input  logic clk,
    input  logic rst,
    input  csr_ctrl_t ctrl,
    input  arch_width_t in,
    input  arch_width_t inst_exe,
    input  logic inst_to_be_retired,
    input  perf_event_t perf_event,
    output arch_width_t out
);

// local params, helpers
localparam unsigned CLOCKS_PER_US = (CLOCK_FREQ / 1_000_000);
localparam unsigned CNT_WIDTH = $clog2(CLOCKS_PER_US);

localparam unsigned MHPMEVENT_PAD_WIDTH = (ARCH_WIDTH - MHPMEVENTS);
localparam logic [MHPMEVENT_PAD_WIDTH-1:0] MHPMEVENT_PAD = 'h0;
localparam unsigned MHPMCOUNTER_MASK_BITS = $clog2(MHPMCOUNTERS + MHPM_OFFSET);
localparam unsigned MHPMEVENT_MASK_BITS = $clog2(MHPMEVENTS + MHPM_OFFSET);

`define RANGE_C MHPM_OFFSET:MHPMCOUNTERS+MHPM_OFFSET-1
`define RANGE_E MHPM_OFFSET:MHPMEVENTS+MHPM_OFFSET-1

function automatic logic get_event(
    input perf_event_t pe, input logic [MHPMEVENTS-1:0] mhpmevent);
    get_event = 1'b0;
    case (mhpmevent)
        MHPMEVENT_BAD_SPEC: get_event = pe.bad_spec;
        MHPMEVENT_BE: get_event = pe.be;
        MHPMEVENT_BE_DC: get_event = pe.be_dc;
        MHPMEVENT_FE: get_event = pe.fe;
        MHPMEVENT_FE_IC: get_event = pe.fe_ic;
        MHPMEVENT_RET_SIMD: get_event = pe.ret_simd;
    endcase
endfunction

// implementation
csr_t csr; // regs
csr_addr_t addr;
logic [4:0] imm5;
arch_width_t imm, wr_data_src, wr_data;
assign imm5 = inst_exe[19:15];
assign imm = {27'h0, imm5}; // zero-extend
assign wr_data_src = ctrl.ui ? imm : in;
assign addr = csr_addr_t'(inst_exe[31:20] & {12{ctrl.en}});

csr_dw_t mhpmcounter[`RANGE_C];
logic [MHPMCOUNTER_MASK_BITS-1:0] mhpm_addr_c;
assign mhpm_addr_c = (addr[MHPMCOUNTER_MASK_BITS-1:0]);

mhpmevent_t mhpmevent[`RANGE_E];
logic [MHPMEVENT_MASK_BITS-1:0] mhpm_addr_e;
assign mhpm_addr_e = (addr[MHPMEVENT_MASK_BITS-1:0]);

// csr read
always_comb begin
    out = 'h0;
    if (ctrl.re) begin
        case (addr)
            CSR_TOHOST: out = csr.tohost;
            CSR_MCYCLE: out = csr.mcycle.r[CSR_LOW];
            CSR_MCYCLEH: out = csr.mcycle.r[CSR_HIGH];
            CSR_MINSTRET: out = csr.minstret.r[CSR_LOW];
            CSR_MINSTRETH: out = csr.minstret.r[CSR_HIGH];
            CSR_MSCRATCH: out = csr.mscratch;
            CSR_TIME: out = csr.mtime.r[CSR_LOW];
            CSR_TIMEH: out = csr.mtime.r[CSR_HIGH];
            CSR_MHPMCOUNTER3,
            CSR_MHPMCOUNTER4,
            CSR_MHPMCOUNTER5,
            CSR_MHPMCOUNTER6,
            CSR_MHPMCOUNTER7,
            CSR_MHPMCOUNTER8: out = mhpmcounter[mhpm_addr_c].r[CSR_LOW];
            CSR_MHPMCOUNTER3H,
            CSR_MHPMCOUNTER4H,
            CSR_MHPMCOUNTER5H,
            CSR_MHPMCOUNTER6H,
            CSR_MHPMCOUNTER7H,
            CSR_MHPMCOUNTER8H: out = mhpmcounter[mhpm_addr_c].r[CSR_HIGH];
            CSR_MHPMEVENT3,
            CSR_MHPMEVENT4,
            CSR_MHPMEVENT5,
            CSR_MHPMEVENT6,
            CSR_MHPMEVENT7,
            CSR_MHPMEVENT8: out = {MHPMEVENT_PAD, mhpmevent[mhpm_addr_e]};
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    wr_data = 'h0;
    case (ctrl.op)
        CSR_OP_RW: wr_data = wr_data_src;
        CSR_OP_RS: wr_data = out | wr_data_src;
        CSR_OP_RC: wr_data = out & ~wr_data_src;
    endcase
end

mhpmevent_t wr_mhpmevent;
assign wr_mhpmevent = mhpmevent_t'(wr_data[MHPMEVENTS-1:0]);
// generic
always_ff @(posedge clk) begin
    if (rst) begin
        csr.tohost <= 'h0;
        csr.mscratch <= 'h0;
        `IT2(MHPM_OFFSET, (MHPMCOUNTERS + MHPM_OFFSET)) begin
            mhpmevent[i] <= MHPMEVENT_NONE;
        end
    end else if (ctrl.we) begin
        case (addr)
            CSR_TOHOST: csr.tohost <= wr_data;
            CSR_MSCRATCH: csr.mscratch <= wr_data;
            CSR_MHPMEVENT3,
            CSR_MHPMEVENT4,
            CSR_MHPMEVENT5,
            CSR_MHPMEVENT6,
            CSR_MHPMEVENT7,
            CSR_MHPMEVENT8: mhpmevent[mhpm_addr_e] <= wr_mhpmevent;
            default: ;
        endcase
    end
end


// mcycle
logic [1:0] am_mcycle;
assign am_mcycle = {(addr == CSR_MCYCLEH), (addr == CSR_MCYCLE)};
always_ff @(posedge clk) begin
    if (rst) begin
        csr.mcycle <= 'h0;
    end else if (ctrl.we && (|am_mcycle)) begin
        if (am_mcycle[0]) csr.mcycle.r[CSR_LOW] <= wr_data;
        else csr.mcycle.r[CSR_HIGH] <= wr_data;
    end else begin
        csr.mcycle <= csr.mcycle + 'h1;
    end
end

// minstret
logic [1:0] am_minstret;
assign am_minstret = {(addr == CSR_MINSTRETH), (addr == CSR_MINSTRET)};
always_ff @(posedge clk) begin
    if (rst) begin
        csr.minstret <= 'h0;
    end else if (ctrl.we && (|am_minstret)) begin
        if (am_minstret[0]) csr.minstret.r[CSR_LOW] <= wr_data;
        else csr.minstret.r[CSR_HIGH] <= wr_data;
    end else if (inst_to_be_retired) begin
        csr.minstret <= csr.minstret + 64'h1;
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

`DFF_CI_RI_RVI_EN(tick_us, (csr.mtime + 64'h1), csr.mtime)

// hardware performance monitors
csr_addr_t am_l[`RANGE_C], am_h[`RANGE_C];
assign am_l = {
    CSR_MHPMCOUNTER3,
    CSR_MHPMCOUNTER4,
    CSR_MHPMCOUNTER5,
    CSR_MHPMCOUNTER6,
    CSR_MHPMCOUNTER7,
    CSR_MHPMCOUNTER8
};
assign am_h = {
    CSR_MHPMCOUNTER3H,
    CSR_MHPMCOUNTER4H,
    CSR_MHPMCOUNTER5H,
    CSR_MHPMCOUNTER6H,
    CSR_MHPMCOUNTER7H,
    CSR_MHPMCOUNTER8H
};

logic [1:0] am_mhpmcounter[`RANGE_C];
genvar i;
generate
    `IT2_NT(MHPM_OFFSET, (MHPMCOUNTERS + MHPM_OFFSET)) begin: gen_mhpm_write
        assign am_mhpmcounter[i] = {(addr == am_h[i]), (addr == am_l[i])};
        always_ff @(posedge clk) begin
            if (rst) begin
                mhpmcounter[i] <= 'h0;
            end else if (ctrl.we && (|am_mhpmcounter[i])) begin
                if (am_mhpmcounter[i][0]) mhpmcounter[i].r[CSR_LOW] <= wr_data;
                else mhpmcounter[i].r[CSR_HIGH] <= wr_data;
            end else if (get_event(perf_event, mhpmevent[i])) begin
                mhpmcounter[i] <= mhpmcounter[i] + 64'h1;
            end
        end
    end
endgenerate

endmodule
