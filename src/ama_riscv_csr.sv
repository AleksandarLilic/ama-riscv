`include "ama_riscv_defines.svh"

module ama_riscv_csr #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
)(
    input  logic clk,
    input  logic rst,
    input  csr_ctrl_t ctrl,
    input  arch_width_t in,
    input  logic [4:0] imm5,
    input  csr_addr_t addr,
    input  logic inst_to_be_retired,
    input  perf_event_t perf_events,
    output arch_width_t out
);

//------------------------------------------------------------------------------
// local params, helpers
localparam unsigned CLOCKS_PER_US = (CLOCK_FREQ / 1_000_000);
localparam unsigned CNT_WIDTH = $clog2(CLOCKS_PER_US);

//localparam unsigned MHPMEVENT_PAD_WIDTH =
//    ((ARCH_WIDTH - MHPMEVENTS) != 0) ? (ARCH_WIDTH - MHPMEVENTS) : ARCH_WIDTH;
//localparam logic [MHPMEVENT_PAD_WIDTH-1:0] MHPMEVENT_PAD = 'h0;
localparam unsigned MHPM_MASK_BITS = $clog2(MHPMCOUNTERS + MHPM_IDX_L);

function automatic logic get_event(
    input perf_event_t pe, input mhpmevent_t ev);
    case (ev)
        MHPMEVENT_BAD_SPEC: get_event = pe.bad_spec;
        MHPMEVENT_STALL_BE : get_event = pe.stall_be;
        MHPMEVENT_STALL_L1D : get_event = pe.stall_l1d;
        MHPMEVENT_STALL_L1D_R : get_event = pe.stall_l1d_r;
        MHPMEVENT_STALL_L1D_W : get_event = pe.stall_l1d_w;
        MHPMEVENT_STALL_FE : get_event = pe.stall_fe;
        MHPMEVENT_STALL_L1I : get_event = pe.stall_l1i;
        MHPMEVENT_STALL_SIMD : get_event = pe.stall_simd;
        MHPMEVENT_STALL_LOAD : get_event = pe.stall_load;
        MHPMEVENT_STALL_DIV : get_event = pe.stall_div;
        MHPMEVENT_RET_CTRL_FLOW : get_event = pe.ret_ctrl_flow;
        MHPMEVENT_RET_CTRL_FLOW_J : get_event = pe.ret_ctrl_flow_j;
        MHPMEVENT_RET_CTRL_FLOW_JR : get_event = pe.ret_ctrl_flow_jr;
        MHPMEVENT_RET_CTRL_FLOW_BR : get_event = pe.ret_ctrl_flow_br;
        MHPMEVENT_RET_MEM : get_event = pe.ret_mem;
        MHPMEVENT_RET_MEM_LOAD : get_event = pe.ret_mem_load;
        MHPMEVENT_RET_MEM_STORE : get_event = pe.ret_mem_store;
        MHPMEVENT_RET_SIMD : get_event = pe.ret_simd;
        MHPMEVENT_RET_SIMD_ARITH : get_event = pe.ret_simd_arith;
        MHPMEVENT_RET_SIMD_DATA_FMT : get_event = pe.ret_simd_data_fmt;
        MHPMEVENT_BP_MISS: get_event = pe.bp_miss;
        MHPMEVENT_L1I_REF : get_event = pe.l1i_ref;
        MHPMEVENT_L1I_MISS : get_event = pe.l1i_miss;
        MHPMEVENT_L1I_SPEC_MISS : get_event = pe.l1i_spec_miss;
        MHPMEVENT_L1I_SPEC_MISS_BAD : get_event = pe.l1i_spec_miss_bad;
        MHPMEVENT_L1D_REF : get_event = pe.l1d_ref;
        MHPMEVENT_L1D_REF_R : get_event = pe.l1d_ref_r;
        MHPMEVENT_L1D_REF_W : get_event = pe.l1d_ref_w;
        MHPMEVENT_L1D_MISS : get_event = pe.l1d_miss;
        MHPMEVENT_L1D_MISS_R : get_event = pe.l1d_miss_r;
        MHPMEVENT_L1D_MISS_W : get_event = pe.l1d_miss_w;
        MHPMEVENT_L1D_WRITEBACK : get_event = pe.l1d_writeback;
        default: get_event = 1'b0;
    endcase
endfunction

//------------------------------------------------------------------------------
// implementation
csr_t csr; // regs
csr_addr_t addr_en;
arch_width_t imm, wr_data_src, wr_data;
assign imm = {27'h0, imm5}; // zero-extend
assign wr_data_src = ctrl.ui ? imm : in;
assign addr_en = csr_addr_t'(addr & {12{ctrl.en}});

logic [MHPM_MASK_BITS-1:0] mhpm_addr_c;
assign mhpm_addr_c = (addr_en[MHPM_MASK_BITS-1:0]);
logic [MHPM_MASK_BITS-1:0] mhpm_addr_e;
assign mhpm_addr_e = (addr_en[MHPM_MASK_BITS-1:0]);

//------------------------------------------------------------------------------
// csr read
always_comb begin
    out = 'h0;
    if (ctrl.re) begin
        case (addr_en)
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
            CSR_MHPMCOUNTER8:
                out = csr.mhpmcounter[mhpm_addr_c].f.lo;
            CSR_MHPMCOUNTER3H,
            CSR_MHPMCOUNTER4H,
            CSR_MHPMCOUNTER5H,
            CSR_MHPMCOUNTER6H,
            CSR_MHPMCOUNTER7H,
            CSR_MHPMCOUNTER8H:
                out = {MHPMCOUNTER_PAD, csr.mhpmcounter[mhpm_addr_c].f.hi};
            CSR_MHPMEVENT3,
            CSR_MHPMEVENT4,
            CSR_MHPMEVENT5,
            CSR_MHPMEVENT6,
            CSR_MHPMEVENT7,
            CSR_MHPMEVENT8:
                //out = {MHPMEVENT_PAD, csr.mhpmevent[mhpm_addr_e]};
                out = csr.mhpmevent[mhpm_addr_e];
            default: ;
        endcase
    end
end

//------------------------------------------------------------------------------
// csr write
always_comb begin
    case (ctrl.op)
        CSR_OP_RW: wr_data = wr_data_src;
        CSR_OP_RS: wr_data = (out | wr_data_src);
        CSR_OP_RC: wr_data = (out & ~wr_data_src);
        default: wr_data = 'h0;
    endcase
end

//------------------------------------------------------------------------------
mhpmevent_t wr_mhpmevent;
assign wr_mhpmevent = mhpmevent_t'(wr_data[MHPMEVENTS-1:0]);
// generic
always_ff @(posedge clk) begin
    if (rst) begin
        csr.tohost <= 'h0;
        csr.mscratch <= 'h0;
        `IT_I(MHPM_IDX_L, (MHPMCOUNTERS + MHPM_IDX_L)) begin
            csr.mhpmevent[i] <= MHPMEVENT_NONE;
        end
    end else if (ctrl.we) begin
        case (addr_en)
            CSR_TOHOST: csr.tohost <= wr_data;
            CSR_MSCRATCH: csr.mscratch <= wr_data;
            CSR_MHPMEVENT3,
            CSR_MHPMEVENT4,
            CSR_MHPMEVENT5,
            CSR_MHPMEVENT6,
            CSR_MHPMEVENT7,
            CSR_MHPMEVENT8: csr.mhpmevent[mhpm_addr_e] <= wr_mhpmevent;
            default: ;
        endcase
    end
end

//------------------------------------------------------------------------------
// dedicated counters

// mcycle
logic [1:0] am_mcycle;
assign am_mcycle = {(addr_en == CSR_MCYCLEH), (addr_en == CSR_MCYCLE)};
always_ff @(posedge clk) begin
    if (rst) begin
        csr.mcycle <= 'h0;
    end else if (ctrl.we && (|am_mcycle)) begin
        if (am_mcycle[0]) csr.mcycle.r[CSR_LOW] <= wr_data;
        else csr.mcycle.r[CSR_HIGH] <= wr_data;
    end else begin
        csr.mcycle <= (csr.mcycle + 'h1);
    end
end

// minstret
logic [1:0] am_minstret;
assign am_minstret = {(addr_en == CSR_MINSTRETH), (addr_en == CSR_MINSTRET)};
always_ff @(posedge clk) begin
    if (rst) begin
        csr.minstret <= 'h0;
    end else if (ctrl.we && (|am_minstret)) begin
        if (am_minstret[0]) csr.minstret.r[CSR_LOW] <= wr_data;
        else csr.minstret.r[CSR_HIGH] <= wr_data;
    end else if (inst_to_be_retired) begin
        csr.minstret <= (csr.minstret + 64'h1);
    end
end

// mtime
logic tick_us;
logic [CNT_WIDTH-1:0] cnt_us; // 1 microsecond cnt
assign tick_us = (cnt_us == CNT_WIDTH'(CLOCKS_PER_US - 1));
`DFF_CI_RI_RVI_CLR_CLRVI(tick_us, (cnt_us + 'h1), cnt_us)
`DFF_CI_RI_RVI_EN(tick_us, (csr.mtime + 64'h1), csr.mtime)

//------------------------------------------------------------------------------
// hardware performance monitors
csr_addr_t am_l[`MHPM_RANGE], am_h[`MHPM_RANGE];
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

logic [1:0] am_mhpmcounter[`MHPM_RANGE];
logic event_val [`MHPM_RANGE];
genvar i;
generate
`IT_I_NT(MHPM_IDX_L, (MHPMCOUNTERS + MHPM_IDX_L)) begin: gen_mhpm_write
    assign am_mhpmcounter[i] = {(addr_en == am_h[i]), (addr_en == am_l[i])};
    assign event_val[i] = get_event(perf_events, csr.mhpmevent[i]);
    always_ff @(posedge clk) begin
        if (rst) begin
            csr.mhpmcounter[i] <= 'h0;
        end else if (ctrl.we && (|am_mhpmcounter[i])) begin
            if (am_mhpmcounter[i][0]) begin
                csr.mhpmcounter[i].f.lo <= wr_data;
            end else begin
                csr.mhpmcounter[i].f.hi <= wr_data[MHPMCOUNTER_PAD_WIDTH-1:0];
            end
        end else begin
            csr.mhpmcounter[i] <= (
                csr.mhpmcounter[i] + MHPMCOUNTER_WIDTH'(event_val[i])
            );
        end
    end
end
endgenerate

endmodule
