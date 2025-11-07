`include "ama_riscv_defines.svh"

module ama_riscv_fe_ctrl (
    input  logic        clk,
    input  logic        rst,
    rv_if.TX            imem_req,
    rv_if.RX            imem_rsp,
    input  arch_width_t pc_dec,
    input  arch_width_t pc_exe,
    input  logic        branch_inst_dec,
    input  logic        jump_inst_dec,
    input  branch_t     bp_pred,
    input  logic        branch_inst_exe,
    input  logic        jump_inst_exe,
    input  branch_t     branch_resolution,
    input  logic        dc_stalled,
    input  hazard_be_t  hazard_be,
    input  fe_ctrl_t    decoded_fe_ctrl,
    output fe_ctrl_t    fe_ctrl,
    output logic        bp_hit,
    output arch_width_t pc_cp,
    output spec_exec_t  spec,
    output logic        move_past_dec_exe_dc_stall
);

// types
typedef enum logic [2:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_FE_IC,
    STALL_BE
} stall_state_t;

typedef enum logic [1:0] {
    STALL_NONE = 2'b00,
    STALL_BRANCH = 2'b01,
    STALL_JUMP = 2'b10
} stall_inst_type_t;

typedef struct packed {
    stall_inst_type_t stype;
    arch_width_t pc;
} stalled_entry_t;

typedef struct packed {
    logic flow;
    logic icache;
    logic be;
    logic dcache;
    logic hazard;
} stall_sources_t;

typedef enum logic {
    NS_E, // non-speculative execution
    SPEC_E
} exec_state_t;

typedef struct packed {
    arch_width_t pc;
    branch_t b_tnt;
} spec_entry_t;

// STALL control
logic flow_changed;
logic branch_taken;
logic save_stall_entry, clear_stall_entry;
stalled_entry_t stalled_entry;
stall_sources_t stall_act, stall_res;

assign branch_taken = branch_inst_exe && (branch_resolution == B_T);
`ifdef USE_BP
assign flow_changed = jump_inst_exe;
assign stall_act.flow = jump_inst_dec;
`else
assign flow_changed = branch_taken || jump_inst_exe;
assign stall_act.flow = branch_inst_dec || jump_inst_dec;
assign spec = '{1'b0, 1'b0, 1'b0};
`endif

assign stall_act.icache = !imem_req.ready;
assign stall_act.dcache = dc_stalled;
assign stall_act.hazard = (hazard_be.to_dec || hazard_be.to_exe);
assign stall_act.be = (stall_act.dcache || stall_act.hazard);

assign stall_res.flow =
    ((stalled_entry.pc == pc_exe) && (pc_exe != 'h0) && (!hazard_be.to_exe));
assign stall_res.icache = imem_req.ready;
assign stall_res.dcache = !dc_stalled;
assign stall_res.hazard = !(hazard_be.to_dec || hazard_be.to_exe);
assign stall_res.be = (stall_res.dcache && stall_res.hazard);

logic stall_res_flow_d;
`DFF_CI_RI_RVI(stall_res.flow, stall_res_flow_d)

stall_inst_type_t stype_dec;
assign stype_dec = branch_inst_dec ? STALL_BRANCH : STALL_JUMP;

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
            // whatever you are doing, drop it, it's wrong
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
            // whatever you are doing, drop it, it's wrong
            if (spec.wrong) nx_state = STEADY;
            `endif
        end

        default: ;

    endcase
end

always_ff @(posedge clk) begin
    if (rst) stalled_entry = '{stype: STALL_NONE, pc: 'h0};
    else if (save_stall_entry) stalled_entry = '{stype: stype_dec, pc: pc_dec};
    else if (clear_stall_entry) stalled_entry = '{stype: STALL_NONE, pc: 'h0};
end

// outputs
fe_ctrl_t decoded_fe_ctrl_d;
always_comb begin
    fe_ctrl.pc_sel = decoded_fe_ctrl_d.pc_sel;
    fe_ctrl.pc_we = decoded_fe_ctrl_d.pc_we;
    fe_ctrl.bubble_dec = 1'b0;
    fe_ctrl.use_cp = 1'b0;
    imem_req.valid = 1'b0;
    imem_rsp.ready = 1'b0;
    move_past_dec_exe_dc_stall = 1'b0;

    case (state)
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
                // enter speculative only if not blocked by others
                fe_ctrl.pc_sel = (bp_pred == B_T) ? PC_SEL_BP : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                fe_ctrl.bubble_dec = 1'b0;
                imem_req.valid = 1'b1;
                imem_rsp.ready = 1'b1;
            `endif

            end

            `ifdef USE_BP
            if (spec.wrong) begin
                fe_ctrl.pc_sel = branch_taken ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                fe_ctrl.bubble_dec = 1'b1;
                fe_ctrl.use_cp = 1'b1;
                imem_req.valid = 1'b1;
                imem_rsp.ready = 1'b1;
            end
            `endif
        end

        STALL_FLOW: begin
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            fe_ctrl.pc_we = 1'b0;
            `ifdef USE_BP
            if (spec.wrong) begin
                fe_ctrl.pc_sel = branch_taken ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                fe_ctrl.bubble_dec = 1'b1;
                fe_ctrl.use_cp = 1'b1;
                imem_req.valid = 1'b1;
                imem_rsp.ready = 1'b1;
            end else
            `endif
            if (stall_res.flow) begin
                // flow change resolved
                fe_ctrl.pc_sel = flow_changed ? PC_SEL_ALU : PC_SEL_INC4;
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
                    // current inst inst is branch, fingers crossed
                    fe_ctrl.pc_sel = (bp_pred == B_T) ? PC_SEL_BP : PC_SEL_INC4;
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.bubble_dec = 1'b0;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                `endif

                end else begin
                    // no stall, no spec exec, proceed
                    fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.bubble_dec = 1'b0;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                    if (stall_act.dcache) move_past_dec_exe_dc_stall = 1'b1;
                end
            end

            `ifdef USE_BP
            // whatever you are doing, drop it, it's wrong
            if (spec.wrong) begin
                fe_ctrl.pc_sel = branch_taken ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                fe_ctrl.bubble_dec = 1'b1;
                fe_ctrl.use_cp = 1'b1;
                imem_req.valid = 1'b1;
                imem_rsp.ready = 1'b1;
            end
            `endif
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
                    fe_ctrl.pc_sel = flow_changed ? PC_SEL_ALU : PC_SEL_INC4;

                `ifdef USE_BP
                end else if (spec.enter) begin
                    // current inst inst is branch, fingers crossed
                    fe_ctrl.pc_sel = (bp_pred == B_T) ? PC_SEL_BP : PC_SEL_INC4;
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.bubble_dec = 1'b0;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                `endif

                end else begin
                    fe_ctrl.pc_we = 1'b1;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end

                `ifdef USE_BP
                // whatever you are doing, drop it, it's wrong
                if (spec.wrong) begin
                    fe_ctrl.pc_sel = branch_taken ? PC_SEL_ALU : PC_SEL_INC4;
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.bubble_dec = 1'b1;
                    fe_ctrl.use_cp = 1'b1;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end
                `endif
            end
        end

        default: ;

    endcase
end

`DFF_CI_RI_RV(`FE_CTRL_RST_VAL, decoded_fe_ctrl, decoded_fe_ctrl_d)

`ifdef USE_BP
// SPECULATIVE EXEC control
spec_entry_t spec_entry, spec_entry_d;

logic save_spec_entry, clear_spec_entry;
assign spec.enter = (
    branch_inst_dec /* && (!(stall_act.dcache || stall_act.hazard)) */);
assign spec.resolve =
    ((spec_entry.pc == pc_exe) && (pc_exe != 'h0) && (!hazard_be.to_exe));
assign bp_hit = spec.resolve && (spec_entry.b_tnt == branch_resolution);

// speculative execution FSM
exec_state_t state_e, nx_state_e;

// state transition
`DFF_CI_RI_RV(NS_E, nx_state_e, state_e)

// next state
always_comb begin
    nx_state_e = state_e;
    save_spec_entry = 1'b0;
    clear_spec_entry = 1'b0;
    spec.wrong = 1'b0;

    case (state_e)
        NS_E: begin
            if (spec.enter) begin
                nx_state_e = SPEC_E;
                save_spec_entry = 1'b1;
            end
        end
        SPEC_E: begin
            if (spec.resolve) begin
                clear_spec_entry = 1'b1;
                if (!bp_hit) begin // missed, whantever you have is wrong
                    nx_state_e = NS_E;
                    spec.wrong = !bp_hit;
                end else begin // on correct path
                    if (spec.enter) begin // branch in dec again
                        nx_state_e = SPEC_E;
                        save_spec_entry = 1'b1;
                    end else begin // next inst is not branch
                        nx_state_e = NS_E;
                    end
                end
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    if (rst) spec_entry = '{pc: 'h0, b_tnt: B_NT};
    else if (save_spec_entry) spec_entry = '{pc: pc_dec, b_tnt: bp_pred};
    else if (clear_spec_entry) spec_entry = '{pc: 'h0, b_tnt: B_NT};
end
assign pc_cp = spec_entry.pc;
`endif

endmodule
