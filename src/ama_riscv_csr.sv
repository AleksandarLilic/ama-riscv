`include "ama_riscv_defines.svh"

module ama_riscv_csr (
    input  logic clk,
    input  logic rst,
    input  csr_ctrl_t ctrl,
    input  arch_width_t in,
    input  logic [4:0] imm5,
    input  csr_addr_t addr,
    input  perf_event_t perf_events,
    input  logic minstret_wr_skip,
    input  csr_dw_t mtime,
    output arch_width_t out,
    // trap controller interface
    input  csr_trap_wr_t trap_wr,
    output csr_trap_status_t trap_status,
    output arch_width_t mtvec, // trap target PC
    output arch_width_t mepc, // mret target PC
    // mip sources
    input  logic mtip,
    input  logic meip
);

//------------------------------------------------------------------------------

//localparam unsigned MHPMEVENT_PAD_WIDTH =
//    ((ARCH_WIDTH - MHPMEVENTS) != 0) ? (ARCH_WIDTH - MHPMEVENTS) : ARCH_WIDTH;
//localparam logic [MHPMEVENT_PAD_WIDTH-1:0] MHPMEVENT_PAD = 'h0;
localparam unsigned MHPM_MASK_BITS = $clog2(MHPMCOUNTERS + MHPM_IDX_L);

/* verilator lint_off UNUSEDSIGNAL */
function automatic logic get_event(input perf_event_t pe, input mhpmevent_t ev);
    // ret_inst not used from pe
    case (ev)
        MHPMEVENT_BAD_SPEC: get_event = pe.bad_spec;
        MHPMEVENT_STALL_BE : get_event = pe.stall_be;
        MHPMEVENT_STALL_L1D : get_event = pe.stall_l1d;
        MHPMEVENT_STALL_L1D_R : get_event = pe.stall_l1d_r;
        MHPMEVENT_STALL_L1D_W : get_event = pe.stall_l1d_w;
        MHPMEVENT_STALL_FE : get_event = pe.stall_fe;
        MHPMEVENT_STALL_L1I : get_event = pe.stall_l1i;
        MHPMEVENT_STALL_SIMD : get_event = pe.stall_simd;
        MHPMEVENT_STALL_DIV : get_event = pe.stall_div;
        MHPMEVENT_STALL_LOAD : get_event = pe.stall_load;
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
/* verilator lint_on UNUSEDSIGNAL */

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
// trap CSRs: source-driven mip (software-RO) + exports to trap_ctrl / fe_ctrl
arch_width_t csr_mip;
assign csr_mip = (
    (arch_width_t'(meip) << MIP_MEIP_BIT) |
    (arch_width_t'(mtip) << MIP_MTIP_BIT)
);

assign trap_status.mstatus_mie = csr.mstatus[MSTATUS_MIE_BIT];
assign trap_status.mie = csr.mie;
assign trap_status.mip = csr_mip;
assign mtvec = csr.mtvec;
assign mepc = csr.mepc;

//------------------------------------------------------------------------------
// csr read
always_comb begin
    out = 'h0;
    if (ctrl.re) begin
        case (addr_en)
            CSR_TOHOST: out = csr.tohost;
            CSR_CYCLE,
            CSR_MCYCLE: out = csr.mcycle.r[CSR_LOW];
            CSR_CYCLEH,
            CSR_MCYCLEH: out = csr.mcycle.r[CSR_HIGH];
            CSR_INSTRET,
            CSR_MINSTRET: out = csr.minstret.r[CSR_LOW];
            CSR_INSTRETH,
            CSR_MINSTRETH: out = csr.minstret.r[CSR_HIGH];
            CSR_MSCRATCH: out = csr.mscratch;
            CSR_TIME: out = mtime.r[CSR_LOW];
            CSR_TIMEH: out = mtime.r[CSR_HIGH];
            CSR_HPMCOUNTER3,
            CSR_HPMCOUNTER4,
            CSR_HPMCOUNTER5,
            CSR_HPMCOUNTER6,
            CSR_HPMCOUNTER7,
            CSR_HPMCOUNTER8,
            CSR_MHPMCOUNTER3,
            CSR_MHPMCOUNTER4,
            CSR_MHPMCOUNTER5,
            CSR_MHPMCOUNTER6,
            CSR_MHPMCOUNTER7,
            CSR_MHPMCOUNTER8:
                out = csr.mhpmcounter[mhpm_addr_c].f.lo;
            CSR_HPMCOUNTER3H,
            CSR_HPMCOUNTER4H,
            CSR_HPMCOUNTER5H,
            CSR_HPMCOUNTER6H,
            CSR_HPMCOUNTER7H,
            CSR_HPMCOUNTER8H,
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
            // trap CSRs
            CSR_MSTATUS: out = csr.mstatus;
            CSR_MIE: out = csr.mie;
            CSR_MIP: out = csr_mip;
            CSR_MTVEC: out = csr.mtvec;
            CSR_MEPC: out = csr.mepc;
            CSR_MCAUSE: out = csr.mcause;
            CSR_MTVAL: out = csr.mtval;
            // read-only ID CSRs
            CSR_MISA: out = MISA_VAL;
            // unimplemented machine info CSRs, reads zero by default
            //CSR_MVENDORID: out = MVENDORID_VAL;
            //CSR_MARCHID: out = MARCHID_VAL;
            //CSR_MIMPID: out = MIMPID_VAL;
            //CSR_MHARTID: out = MHARTID_VAL;
            //CSR_MCONFIGPTR: out = MCONFIGPTR_VAL;
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
// trap CSRs (per-CSR write, trap entry/ret has priority over a csr* write)
// at the entry/ret cycle the trapping inst is a bubble at WBK with everything
// older drained, so there is no concurrent csr* write to arbitrate

// mstatus: WARL (MIE/MPIE writable, MPP hardwired M); stack on entry/ret
always_ff @(posedge clk) begin
    if (rst) begin
        csr.mstatus <= MSTATUS_MPP_FIXED;
    end else if (trap_wr.entry) begin
        csr.mstatus[MSTATUS_MPIE_BIT] <= csr.mstatus[MSTATUS_MIE_BIT];
        csr.mstatus[MSTATUS_MIE_BIT] <= 1'b0;
    end else if (trap_wr.ret) begin
        csr.mstatus[MSTATUS_MPIE_BIT] <= 1'b1;
        csr.mstatus[MSTATUS_MIE_BIT] <= csr.mstatus[MSTATUS_MPIE_BIT];
    end else if (ctrl.we && (addr_en == CSR_MSTATUS)) begin
        csr.mstatus <= ((wr_data & MSTATUS_WMASK) | MSTATUS_MPP_FIXED);
    end
end

// mepc: trap entry writes pc_dec (word-aligned), else WARL csr* write
always_ff @(posedge clk) begin
    if (rst) csr.mepc <= 'h0;
    else if (trap_wr.entry) csr.mepc <= (trap_wr.trap_info.mepc & PC_ALIGN_MASK);
    else if (ctrl.we && (addr_en == CSR_MEPC)) csr.mepc <= (wr_data & PC_ALIGN_MASK);
end

// mcause: trap entry writes cause, else csr* write
always_ff @(posedge clk) begin
    if (rst) csr.mcause <= 'h0;
    else if (trap_wr.entry) csr.mcause <= trap_wr.trap_info.mcause;
    else if (ctrl.we && (addr_en == CSR_MCAUSE)) csr.mcause <= wr_data;
end

// mtval: trap entry writes tval, else csr* write
always_ff @(posedge clk) begin
    if (rst) csr.mtval <= 'h0;
    else if (trap_wr.entry) csr.mtval <= trap_wr.trap_info.mtval;
    else if (ctrl.we && (addr_en == CSR_MTVAL)) csr.mtval <= wr_data;
end

// mtvec: csr* write only, WARL (direct mode => low 2 bits 0)
always_ff @(posedge clk) begin
    if (rst) csr.mtvec <= 'h0;
    else if (ctrl.we && (addr_en == CSR_MTVEC)) csr.mtvec <= (wr_data & PC_ALIGN_MASK);
end

// mie: csr* write only, WARL (MTIE/MEIE writable)
always_ff @(posedge clk) begin
    if (rst) csr.mie <= 'h0;
    else if (ctrl.we && (addr_en == CSR_MIE)) csr.mie <= (wr_data & MIE_WMASK);
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
    end else if (perf_events.ret_inst && !minstret_wr_skip) begin
        csr.minstret <= (csr.minstret + 64'h1);
    end
end

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
