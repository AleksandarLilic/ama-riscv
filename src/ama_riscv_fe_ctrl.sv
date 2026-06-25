`include "ama_riscv_defines.svh"

module ama_riscv_fe_ctrl (
    input  logic clk,
    input  logic rst,
    rv_ctrl_if.TX imem_req,
    rv_ctrl_if.RX imem_rsp,
    input  arch_width_t pc_dec,
    input  arch_width_t pc_mem,
    input  logic branch_in_dec,
    input  logic branch_in_mem,
    input  logic jalr_in_dec,
    input  logic jalr_in_exe,
    input  logic jalr_in_mem,
    `ifdef USE_BP
    input  branch_t bp_pred,
    `endif
    input  branch_t branch_resolution,
    input  logic dc_stalled,
    input  logic div_stalled,
    /* verilator lint_off UNUSEDSIGNAL */
    input  hazard_t hazard,
    /* verilator lint_on UNUSEDSIGNAL */
    input  fe_ctrl_t decoded_fe_ctrl,
    // trap controller
    input  trap_ctrl_t trap_ctrl,
    `ifdef USE_BP
    output arch_width_t pc_cp,
    `endif
    output logic stall_act_flow,
    output spec_exec_t spec,
    output fe_ctrl_t fe_ctrl
);

//------------------------------------------------------------------------------
// types
typedef enum logic [2:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_FE_IC,
    STALL_BE
} stall_state_t;

/*
typedef enum logic [1:0] {
    STALL_NONE = 2'b00,
    STALL_BRANCH = 2'b01,
    STALL_JUMP = 2'b10
} stall_inst_type_t;

typedef struct packed {
    stall_inst_type_t stype;
    arch_width_t pc;
} stalled_entry_t;
*/

typedef struct packed {
    logic flow;
    logic icache;
    logic be;
    logic dcache;
    logic div;
    logic hazard;
} stall_sources_t;

typedef enum logic {
    NS_E, // non-speculative execution
    SPEC_E
} exec_state_t;

typedef struct packed {
    logic valid;
    arch_width_t pc;
    branch_t b_tnt;
} spec_entry_t;

//------------------------------------------------------------------------------
// STALL control
logic flow_update;
logic branch_taken;
logic save_stall_entry, clear_stall_entry;
arch_width_t stalled_pc;
stall_sources_t stall_act, stall_res;

// redirect / stale-miss overlay (spec.wrong = 0 without 'USE_BP')
logic redirect_req;
// trap_ctrl.wfi_resume refetches pc_fet_last (== pc_wfi+4)
// via the PC_SEL_PC redirect path
assign redirect_req = (
    spec.wrong ||
    trap_ctrl.trap_redirect || trap_ctrl.mret_redirect || trap_ctrl.wfi_resume
);

assign branch_taken = (branch_in_mem && (branch_resolution == B_T));
`ifdef USE_BP
assign flow_update = jalr_in_mem;
assign stall_act.flow = ((
    (jalr_in_dec && !trap_ctrl.pending) || jalr_in_exe)
);
logic bp_hit, bp_miss, bp_taken;
assign bp_taken = (bp_pred == B_T);
`else
assign flow_update = (branch_taken || jalr_in_mem);
assign stall_act.flow = (
    (((branch_in_dec || jalr_in_dec) && !trap_ctrl.pending) || jalr_in_exe)
);
assign spec = '{1'b0, 1'b0, 1'b0};
`endif

assign stall_act_flow = stall_act.flow;

assign stall_act.icache = !imem_req.ready;
assign stall_act.dcache = dc_stalled;
assign stall_act.hazard = (/* hazard.to_dec || */hazard.to_exe);
assign stall_act.div = div_stalled;
assign stall_act.be = (stall_act.dcache || stall_act.hazard || stall_act.div);

assign stall_res.flow = ((stalled_pc == pc_mem) && (pc_mem != 'h0));
assign stall_res.icache = imem_req.ready;
assign stall_res.dcache = !dc_stalled;
assign stall_res.hazard = !(/* hazard.to_dec || */ hazard.to_exe);
assign stall_res.div = !div_stalled;
assign stall_res.be = (stall_res.dcache && stall_res.hazard && stall_res.div);

logic stall_res_flow_d;
`DFF_CI_RI_RVI(stall_res.flow, stall_res_flow_d)

// stall FSM
stall_state_t state, nx_state;

// state transition
`DFF_CI_RI_RV(RST, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    save_stall_entry = 1'b0;
    clear_stall_entry = 1'b0;

    case (state)
        RST: begin
            if (stall_res.icache) begin
                // wait for icache to become ready to make first request
                nx_state = STALL_FE_IC; // cold caches at boot
            end
        end

        STEADY: begin
            clear_stall_entry = 1'b1; // save takes priority if both are active
            if (stall_act.be) begin
                nx_state = STALL_BE;
            end else if (stall_act.flow) begin
                save_stall_entry = 1'b1;
                nx_state = STALL_FLOW;
            end else if (stall_act.icache) begin
                nx_state = STALL_FE_IC;
            end
            `ifdef USE_BP
            if (spec.wrong) nx_state = STEADY;
            `endif
        end

        STALL_FLOW: begin
            `ifdef USE_BP
            if (spec.wrong) begin
                nx_state = STEADY;
            end else
            `endif
            if (stall_res.flow) begin
                // flow change resolved
                if (stall_act.icache) nx_state = STALL_FE_IC;
                else if (stall_act.be) nx_state = STALL_BE;
                else nx_state = STEADY;
            end
        end

        STALL_FE_IC: begin
            if (stall_res.icache) begin // imem returned inst
                // stall again, now if inst is flow change, else proceed forward
                if (stall_act.be) begin
                    nx_state = STALL_BE;
                end else if (stall_act.flow) begin
                    save_stall_entry = 1'b1;
                    nx_state = STALL_FLOW;
                end else begin
                    nx_state = STEADY;
                end
            end
            `ifdef USE_BP
            if (spec.wrong) nx_state = STEADY;
            `endif
        end

        STALL_BE: begin
            if (stall_res.be) begin
                // once backend resolves its stall, continue as per usual
                if (stall_act.flow) begin
                    save_stall_entry = 1'b1;
                    nx_state = STALL_FLOW;
                end else if (stall_act.icache) begin
                    nx_state = STALL_FE_IC;
                end else begin
                    nx_state = STEADY;
                end
            end
            `ifdef USE_BP
            if (spec.wrong) nx_state = STEADY;
            `endif
        end

        default: ;

    endcase
end

always_ff @(posedge clk) begin
    if (rst) stalled_pc <= 'h0;
    else if (save_stall_entry) stalled_pc <= pc_dec;
    else if (clear_stall_entry) stalled_pc <= 'h0;
end

function automatic void spec_fetch_wrong_spec();
    // current inst inst is branch, fingers crossed
    fe_ctrl.pc_sel = bp_taken ? PC_SEL_JAL_BP : PC_SEL_INC4;
    fe_ctrl.pc_we = 1'b1;
    fe_ctrl.bubble_dec = 1'b0;
    imem_req.valid = 1'b1;
    imem_rsp.ready = 1'b1;
endfunction

logic stale_ic_miss, nx_stale_ic_miss;
// outputs
/* verilator lint_off UNUSEDSIGNAL */
fe_ctrl_t decoded_fe_ctrl_d; // bubble_dec, use_cp unused
/* verilator lint_on UNUSEDSIGNAL */
always_comb begin
    fe_ctrl.pc_sel = decoded_fe_ctrl_d.pc_sel;
    fe_ctrl.pc_we = decoded_fe_ctrl_d.pc_we;
    fe_ctrl.bubble_dec = 1'b0;
    fe_ctrl.bubble_exe = 1'b0;
    fe_ctrl.use_cp = 1'b0;
    imem_req.valid = 1'b0;
    imem_rsp.ready = 1'b0;
    nx_stale_ic_miss = stale_ic_miss;

    unique case (state)
        RST: begin
            // reset vector on boot, cold icache
            fe_ctrl.pc_sel = PC_SEL_PC;
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.bubble_dec = 1'b1;
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;
        end

        STEADY: begin
            // pass decoder outputs by default
            fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
            fe_ctrl.pc_we = decoded_fe_ctrl.pc_we;
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;

            // override if in stall
            if (stall_act.be) begin
                // backend stalls, don't make any more requests
                fe_ctrl.pc_we = 1'b0;
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_act.flow) begin
                // current inst is stalling, bubble in next cycle
                fe_ctrl.pc_we = 1'b0;
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_act.icache) begin
                // imem has no reponse in this cycle, bubble right away
                fe_ctrl.pc_sel = PC_SEL_PC;
                fe_ctrl.pc_we = 1'b0;
                fe_ctrl.bubble_dec = 1'b1;
                imem_req.valid = 1'b0;

            `ifdef USE_BP
            end else if (spec.enter) begin
                spec_fetch_wrong_spec();
            `endif

            end
        end

        STALL_FLOW: begin
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            fe_ctrl.pc_we = 1'b0;
            if (stall_res.flow) begin
                // flow change resolved
                fe_ctrl.pc_sel = flow_update ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                imem_req.valid = 1'b1;
                //imem_req.valid = !stall_src_dmem;
                imem_rsp.ready = 1'b1;
            end
        end

        STALL_FE_IC: begin
            fe_ctrl.pc_sel = PC_SEL_PC;
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b1;

            if (imem_rsp.valid) begin
                if (stall_act.be) begin
                    // backend stalls, don't make any more requests
                    fe_ctrl.pc_we = 1'b0;
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;
                end else if (stall_act.flow) begin
                    // current inst is stalling, bubble in next cycle
                    fe_ctrl.pc_we = 1'b0;
                    fe_ctrl.bubble_dec = 1'b0;
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;

                `ifdef USE_BP
                end else if (spec.enter) begin
                    spec_fetch_wrong_spec();
                `endif

                end else begin
                    // no stall, no spec exec, proceed
                    fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.bubble_dec = 1'b0;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end
            end
        end

        STALL_BE: begin
            // when be stalls, fe keeps current state, no new requests
            fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.bubble_dec = 1'b0;
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b0;
            if (stall_res.be) begin
                if (stall_act.icache) begin
                    fe_ctrl.pc_sel = PC_SEL_PC;
                    fe_ctrl.pc_we = 1'b0;
                    fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b1;
                end else if (stall_act.flow) begin // stall in decode now
                    fe_ctrl.pc_we = 1'b0;
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;
                end else if (stall_res.flow && !stall_res_flow_d) begin
                    // flow change resolved just now
                    fe_ctrl.pc_sel = flow_update ? PC_SEL_ALU : PC_SEL_INC4;

                `ifdef USE_BP
                end else if (spec.enter) begin
                    spec_fetch_wrong_spec();
                `endif

                end else begin
                    fe_ctrl.pc_we = 1'b1;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end
            end
        end

        default: ;

    endcase

    //--------------------------------------------------------------------------
    // redirect/stale-miss overlay - top priority
    // steers the front-end on a control-flow change
    // (branch wrong-path flush, or trap/mret entry/return)
    // the icache respects every request once issued, so a redirect that lands
    // while a fetch miss is in flight cannot fetch now and the in-flight
    // response is stale:
    // capture the target into pc_fet_last, defer, sink the doomed response when
    // it arrives, then issue the target
    // the doomed (in-flight) response is discarded by bubble_dec when it lands
    if (stale_ic_miss) begin
        // deferred redirect: target already latched in pc_fet_last
        fe_ctrl.pc_sel = PC_SEL_PC; // pc_sel_pc_src == pc_fet_last (target)
        fe_ctrl.bubble_dec = 1'b1;
        if (!stall_act.icache) begin
            // icache ready again (doomed miss completed): issue the target
            // its response is bubbled this cycle and the target is fetched next
            fe_ctrl.pc_we = 1'b1;
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;
            nx_stale_ic_miss = 1'b0;
        end else begin
            // still waiting for the doomed miss to complete
            fe_ctrl.pc_we = 1'b0;
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b0;
        end
    end else if (redirect_req) begin
        // capture the redirect target + flush
        fe_ctrl.pc_we = 1'b1; // flop target into pc_fet_last
        fe_ctrl.bubble_dec = 1'b1;
        `ifdef USE_BP
        if (spec.wrong) begin
            // wrong-path flush: also drop EXE and restore the checkpoint PC
            fe_ctrl.pc_sel = branch_taken ? PC_SEL_ALU : PC_SEL_INC4;
            fe_ctrl.bubble_exe = 1'b1;
            fe_ctrl.use_cp = 1'b1;
        end else
        `endif
        begin
            // trap/mret: mtvec/mepc via the core PC front mux on PC_SEL_PC
            fe_ctrl.pc_sel = PC_SEL_PC;
        end

        if (stall_act.icache) begin
            // miss in flight: defer, capture target only
            // the doomed response is discarded later via the stale_ic_miss path
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b0;
            nx_stale_ic_miss = 1'b1;
        end else begin
            // icache idle (or responding with stale): issue the target now
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;
        end
    end else if (trap_ctrl.pending) begin
        // chase (TRAP_PENDING/RESTORE_PENDING) or wfi park (WFI):
        // stall the front-end for the whole window so younger (doomed) insts
        // behind the carrier are bubbled, and no new fetch is issued
        // exception: on the wfi wake (trap_ctrl.wfi_launch)
        // drop the bubble for one cycle
        // so the injected trap tag rides DEC->EXE (it would die on a bubble)
        fe_ctrl.pc_we = 1'b0;
        fe_ctrl.bubble_dec = !trap_ctrl.wfi_launch;
        imem_req.valid = 1'b0;
        imem_rsp.ready = 1'b0;
    end
end

`DFF_CI_RI_RVI(nx_stale_ic_miss, stale_ic_miss)

`DFF_CI_RI_RV(`FE_CTRL_INIT_VAL, decoded_fe_ctrl, decoded_fe_ctrl_d)

`ifdef USE_BP
//------------------------------------------------------------------------------
// SPECULATIVE EXEC control
spec_entry_t spec_entry[2];
logic se_ptr_h, se_ptr_t; // head and tail pointers for speculative entry
logic branch_queued;
exec_state_t state_e, nx_state_e;

logic save_spec_entry, clear_spec_entry;
assign spec.enter = (
    branch_in_dec && (!(stall_act.be || spec.wrong || trap_ctrl.pending))
);
assign spec.resolve = (
    spec_entry[se_ptr_t].valid &&
    (spec_entry[se_ptr_t].pc == pc_mem) &&
    (pc_mem != 'h0)
);
assign bp_hit = (
    spec.resolve && (spec_entry[se_ptr_t].b_tnt == branch_resolution)
);
assign bp_miss = (spec.resolve && !bp_hit);
assign spec.wrong = bp_miss;
assign spec.exec_n = (nx_state_e == SPEC_E);
assign spec.active = (state_e == SPEC_E);

//------------------------------------------------------------------------------
// state transition
`DFF_CI_RI_RV(NS_E, nx_state_e, state_e)

// next state
always_comb begin
    nx_state_e = state_e;
    save_spec_entry = 1'b0;
    clear_spec_entry = 1'b0;

    unique case (state_e)
        NS_E: begin
            if (spec.enter) begin
                nx_state_e = SPEC_E;
                save_spec_entry = 1'b1;
            end
        end

        SPEC_E: begin
            if (spec.enter) begin // branch again
                save_spec_entry = 1'b1;
            end
            if (spec.resolve) begin
                clear_spec_entry = 1'b1;
                if (spec.wrong) begin // missed, whantever you have is wrong
                    nx_state_e = NS_E;
                end else begin // on correct path
                    if (spec.enter) begin // branch in dec again
                        nx_state_e = SPEC_E;
                        save_spec_entry = 1'b1;
                    end else if (!branch_queued) begin
                        // next inst is not branch, and not double branched
                        nx_state_e = NS_E;
                    end
                end
            end
        end

    endcase
end

// speculative entries fifo
always_ff @(posedge clk) begin
    if (rst) begin
        spec_entry <= {'h0, 'h0};
        se_ptr_h <= 1'b0;
        se_ptr_t <= 1'b0;
    end else if (spec.wrong) begin // missed, whantever you have is wrong
        spec_entry <= {'h0, 'h0};
        se_ptr_h <= 1'b0;
        se_ptr_t <= 1'b0;
    end else begin
        if (save_spec_entry) begin
            se_ptr_h <= (!se_ptr_h);
            spec_entry[se_ptr_h] <= '{valid: 1'b1, pc: pc_dec, b_tnt: bp_pred};
        end
        if (clear_spec_entry) begin
            se_ptr_t <= (!se_ptr_t);
            // written by new spec_entry if both ptrs match - 3rd consec. branch
            if (!((se_ptr_t == se_ptr_h) && save_spec_entry)) begin
                spec_entry[se_ptr_t] <= 'h0;
            end
        end
    end
end

assign branch_queued = (spec_entry[se_ptr_h].pc != 'h0);
assign pc_cp = spec_entry[se_ptr_t].pc;

`ifndef SYNT
// asserts
always_comb begin
    `IT(2) begin
        if (spec_entry[i].valid) begin
            assert (spec_entry[i].pc !== 'h0)
            else $fatal(1,
                "FE CTRL: saved pc=0 as speculative entry idx %0d", i
            );
        end
    end
end
`endif

`endif

endmodule
