`include "ama_riscv_defines.svh"

module ama_riscv_trap_ctrl (
    input  logic clk,
    input  logic rst,
    // DEC-stage decode
    input  exception_t xcpt,
    input  logic mret_dec,
    input  logic dec_valid,
    input  logic dec_en,
    input  arch_width_t pc_dec, // pc -> mepc
    input  arch_width_t inst_dec, // inst -> mtval on illegal
    /* verilator lint_off UNUSEDSIGNAL */
    input  spec_exec_t spec,
    /* verilator lint_on UNUSEDSIGNAL */
    input  trap_tag_t trap_tag_wbk, // tagged inst reaching WBK
    input  csr_trap_status_t csr_status,
    // outputs
    output trap_tag_t trap_tag_dec,
    output logic pending,
    output csr_trap_wr_t csr_trap_wr,
    // fe/pc redirection
    output logic trap_redirect,
    output logic mret_redirect
);

// custom types
typedef enum logic [2:0] {
    IDLE,
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

//------------------------------------------------------------------------------
// recognize a trap on a clean, advancing DEC cycle while IDLE
// en-gated so the 1-cycle trap_tag_dec.pending pulse moves with pipe DEC->EXE
// exceptions are taken regardless of speculation
// (spec_wrong flush cancels wrong paths)
// exception has priority over irq on the same cycle.
catch_t catch;
assign catch.active =
    (dec_valid && dec_en && (state == IDLE) && (xcpt.pend || irq.pend));
assign catch.cause = xcpt.pend ? xcpt.cause : irq.cause;
assign catch.mtval =
    (xcpt.pend && (xcpt.cause == MCAUSE_ILLEGAL_INST)) ? inst_dec : 'h0;

// mret recognized while a handler is running
logic mret_catch;
assign mret_catch = ((state == TRAPPED) && mret_dec && dec_en);

//------------------------------------------------------------------------------
// trap info holding reg (flopped at recognition, held until next trap)
trap_info_t trap_info;
`DFF_CI_RI_RVI_EN(
    catch.active,
    '{mcause: catch.cause, mtval: catch.mtval, mepc: pc_dec},
    trap_info
)

//------------------------------------------------------------------------------
// FSM
`DFF_CI_RI_RV(IDLE, nx_state, state)

always_comb begin
    nx_state = state;
    case (state)
        IDLE: begin
            if (catch.active) nx_state = TRAP_PENDING;
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
assign trap_tag_dec.trapped = catch.active;
assign trap_tag_dec.mret = mret_catch;
// chase younger with bubbles (request to fe_ctrl)
// the carrier itself is NOT bubbled
assign pending = ((state == TRAP_PENDING) || (state == RESTORE_PENDING));
assign trap_redirect = (state == TRAP_WRITE);
assign mret_redirect = (state == RESTORE_WRITE);

assign csr_trap_wr = '{
    entry: (state == TRAP_WRITE),
    ret: (state == RESTORE_WRITE),
    trap_info: trap_info
};

endmodule
