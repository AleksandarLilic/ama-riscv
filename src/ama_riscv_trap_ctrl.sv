`include "ama_riscv_defines.svh"

module ama_riscv_trap_ctrl (
    input  logic clk,
    input  logic rst,
    // DEC-stage decode
    input  exception_t xcpt,
    input  logic mret_dec,
    input  logic wfi_dec,
    input  logic dec_valid,
    input  logic dec_en,
    input  arch_width_t pc_dec, // pc -> mepc
    input  arch_width_t pc_inc4, // pc+4 -> mepc on wfi wake
    input  arch_width_t inst_dec, // inst -> mtval on illegal
    /* verilator lint_off UNUSEDSIGNAL */
    input  spec_exec_t spec,
    /* verilator lint_on UNUSEDSIGNAL */
    input  trap_tag_t trap_tag_wbk, // tagged inst reaching WBK
    input  csr_trap_status_t csr_status,
    // outputs
    output csr_trap_wr_t csr_trap_wr,
    output trap_tag_t trap_tag_dec,
    output trap_ctrl_t ctrl
);

// custom types
typedef enum logic [2:0] {
    IDLE,
    WFI,
    TRAP_PENDING,
    TRAP_WRITE,
    TRAPPED,
    RESTORE_PENDING,
    RESTORE_WRITE
} state_t;

typedef struct packed {
    logic meip;
    logic mtip;
    logic pend;
    logic indiv;
    mcause_t cause;
} irq_t;

typedef struct packed {
    logic active;
    mcause_t cause;
    arch_width_t mtval;
} catch_t;

state_t state, nx_state;

//------------------------------------------------------------------------------
// interrupt recognition, priority MEI > MTI, blocked during speculation
irq_t irq;
assign irq.meip = (csr_status.mie[MIP_MEIP_BIT] & csr_status.mip[MIP_MEIP_BIT]);
assign irq.mtip = (csr_status.mie[MIP_MTIP_BIT] & csr_status.mip[MIP_MTIP_BIT]);
assign irq.cause = irq.meip ? MCAUSE_MACHINE_EXT_INT : MCAUSE_MACHINE_TIMER_INT;
assign irq.pend = (
    csr_status.mstatus_mie & (irq.meip | irq.mtip) & (!spec.active)
);
// wfi wake honors individual enables (mie&mip per bit), not global mstatus.MIE
assign irq.indiv = (irq.meip | irq.mtip);

//------------------------------------------------------------------------------
// recognize a trap on a clean, advancing DEC cycle while IDLE
// en-gated so the 1-cycle trap_tag_dec.pending pulse moves with pipe DEC->EXE
// exceptions are taken regardless of speculation
// (spec_wrong flush cancels wrong paths)
// exception has priority over irq on the same cycle.
// a wfi in DEC is NOT a trap victim (it parks instead) -> excluded here so an
// already-pending interrupt at the wfi cycle yields mepc=pc_wfi+4, not pc_wfi.
catch_t catch;
assign catch.active = (
    dec_valid && dec_en && !wfi_dec && (state == IDLE) &&
    (xcpt.pend || irq.pend)
);
assign catch.cause = xcpt.pend ? xcpt.cause : irq.cause;
assign catch.mtval =
    (xcpt.pend && (xcpt.cause == MCAUSE_ILLEGAL_INST)) ? inst_dec : 'h0;

// enter the wfi park on a clean DEC advance while IDLE
logic wfi_catch;
assign wfi_catch = (dec_valid && dec_en && (state == IDLE) && wfi_dec);

// wake-and-trap: leave WFI to TRAP_PENDING; the carrier tag rides this cycle
assign ctrl.wfi_launch = ((state == WFI) && !spec.wrong && irq.pend);

// wake-no-trap (MIE=0): leave WFI to IDLE
// refetch pc_wfi+4 (held in pc_fet_last) via a redirect,
// since the parked front-end would otherwise resume at pc_wfi+8
assign ctrl.wfi_resume = (
    (state == WFI) && !spec.wrong && !irq.pend && irq.indiv && !spec.active
);

// mret recognized while a handler is running
logic mret_catch;
assign mret_catch = ((state == TRAPPED) && mret_dec && dec_en);

//------------------------------------------------------------------------------
// mepc source for the wfi wake: pc+4, captured at the IDLE->WFI entry cycle
// (pc.dec == pc_fet_last there, so pc_inc4 == pc_wfi+4); held across the park
arch_width_t wfi_mepc;
`DFF_CI_RI_RVI_EN(wfi_catch, pc_inc4, wfi_mepc)

//------------------------------------------------------------------------------
// trap info holding reg (flopped at recognition, held until next trap)
// mepc muxes pc_dec (normal catch) vs the held pc_wfi+4 (wfi wake)
trap_info_t trap_info;
`DFF_CI_RI_RVI_EN(
    (catch.active || ctrl.wfi_launch),
    '{
        mcause: ctrl.wfi_launch ? irq.cause : catch.cause,
        mtval: ctrl.wfi_launch ? '0 : catch.mtval,
        mepc: ctrl.wfi_launch ? wfi_mepc : pc_dec
    },
    trap_info
)

//------------------------------------------------------------------------------
// FSM
`DFF_CI_RI_RV(IDLE, nx_state, state)

always_comb begin
    nx_state = state;
    case (state)
        IDLE: begin
            if (wfi_catch) nx_state = WFI; // wfi parks; priority over the catch
            else if (catch.active) nx_state = TRAP_PENDING;
        end
        WFI: begin
            // wake honors individual mie&mip (not global MIE); MIE selects exit
            if (spec.wrong) nx_state = IDLE; // wrong-path wfi, cancel
            else if (irq.pend) nx_state = TRAP_PENDING; // wake + trap (MIE set)
            else if (irq.indiv && !spec.active) nx_state = IDLE; // no-trap wake
        end
        TRAP_PENDING: begin
            if (spec.wrong) nx_state = IDLE; // cancel wrong-path (xcpt only)
            else if (trap_tag_wbk.trapped) nx_state = TRAP_WRITE;
        end
        TRAP_WRITE: begin
            nx_state = TRAPPED;
        end
        TRAPPED: begin
            if (mret_catch) nx_state = RESTORE_PENDING;
        end
        RESTORE_PENDING: begin
            if (trap_tag_wbk.mret) nx_state = RESTORE_WRITE;
        end
        RESTORE_WRITE: begin
            nx_state = IDLE;
        end
        default: begin
            nx_state = IDLE;
        end
    endcase
end

//------------------------------------------------------------------------------
// outputs
// tags are injected at DEC and ride WITH the inst via the core STAGE pipe
// wfi wake injects the tag onto an inert NOP carrier (wfi_launch)
assign trap_tag_dec.trapped = (catch.active || ctrl.wfi_launch);
assign trap_tag_dec.mret = mret_catch;
// chase younger with bubbles (request to fe_ctrl); WFI parks the front-end too.
// the carrier itself is NOT bubbled; on the wfi_launch cycle fe_ctrl drops the
// bubble (despite pending) so the wake tag can ride DEC->EXE
assign ctrl.pending = (
    (state == TRAP_PENDING) || (state == RESTORE_PENDING) || (state == WFI)
);
assign ctrl.trap_redirect = (state == TRAP_WRITE);
assign ctrl.mret_redirect = (state == RESTORE_WRITE);

assign csr_trap_wr = '{
    entry: (state == TRAP_WRITE),
    ret: (state == RESTORE_WRITE),
    trap_info: trap_info
};

endmodule
