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
    input  logic        branch_inst_exe,
    input  logic        jump_inst_exe,
    input  logic        branch_taken,
    input  logic        dc_stalled,
    input  logic        load_hazard_stall,
    input  fe_ctrl_t    decoded_fe_ctrl,
    output fe_ctrl_t    fe_ctrl,
    output logic        move_past_dec_stall
);

typedef enum logic [2:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_IMEM,
    STALL_DC
    // SPECULATIVE_EXEC, once BP is implemented, pc_sel is resolved differently
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
    logic dcache;
} stall_sources_t;

logic flow_changed;
assign flow_changed = (branch_taken && branch_inst_exe) || jump_inst_exe;

stalled_entry_t stalled_entry, stalled_entry_d;
stall_sources_t stall_act, stall_res;
assign stall_act.flow = branch_inst_dec || jump_inst_dec;
assign stall_act.icache = !imem_req.ready;
assign stall_act.dcache = dc_stalled;
assign stall_res.flow =
    ((stalled_entry.pc == pc_exe) && (pc_exe != 'h0) && (!load_hazard_stall));
assign stall_res.icache = imem_req.ready;
assign stall_res.dcache = !dc_stalled;
`DFF_CI_RI_RV('{stype: STALL_NONE, pc: 'h0}, stalled_entry, stalled_entry_d)

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
    stalled_entry = stalled_entry_d;

    case (state)
        RST: begin
            if (stall_res.icache) begin
                // wait for icache to become ready to make first request
                nx_state = STALL_IMEM; // cold caches at boot
            end
        end

        STEADY: begin
            stalled_entry = '{stype: STALL_NONE, pc: 'h0};
            if (stall_act.flow) begin
                stalled_entry = '{stype: stype_dec, pc: pc_dec};
                nx_state = STALL_FLOW;
            end else if (stall_act.dcache) begin
                nx_state = STALL_DC;
            end else if (stall_act.icache) begin
                nx_state = STALL_IMEM;
            end
        end

        STALL_FLOW: begin
            if (stall_res.flow) begin
                // flow change resolved
                if (stall_act.icache) nx_state = STALL_IMEM;
                else if (stall_act.dcache) nx_state = STALL_DC;
                else nx_state = STEADY;
            end
        end

        STALL_IMEM: begin
            if (stall_res.icache) begin // imem returned inst
                // stall again, now if inst is flow change, else proceed forward
                if (stall_act.flow) begin
                    stalled_entry = '{stype: stype_dec, pc: pc_dec};
                    nx_state = STALL_FLOW;
                end else if (stall_act.dcache) begin
                    nx_state = STALL_DC;
                end else begin
                    nx_state = STEADY;
                end
            end
        end

        STALL_DC: begin
            if (stall_res.dcache) begin
                // once backend resolves its stall, continue as per usual
                if (stall_act.flow) begin
                    stalled_entry = '{stype: stype_dec, pc: pc_dec};
                    nx_state = STALL_FLOW;
                end else if (stall_act.icache) begin
                    nx_state = STALL_IMEM;
                end else begin
                    nx_state = STEADY;
                end
            end
        end

        default: ;

    endcase
end

// outputs
fe_ctrl_t decoded_fe_ctrl_d;
always_comb begin
    fe_ctrl.pc_sel = decoded_fe_ctrl_d.pc_sel;
    fe_ctrl.pc_we = decoded_fe_ctrl_d.pc_we;
    fe_ctrl.bubble_dec = 1'b0;
    imem_req.valid = 1'b0;
    imem_rsp.ready = 1'b0;
    move_past_dec_stall = 1'b0;

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
            if (stall_act.flow) begin
                // current inst is stalling, bubble in next cycle
                fe_ctrl.pc_we = 1'b0; // ... (1) overwritten for now
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_act.dcache) begin
                // backend stalls, don't make any more requests
                fe_ctrl.pc_we = 1'b0;
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_act.icache) begin
                // imem has no reponse in this cycle, bubble right away
                fe_ctrl.pc_sel = PC_SEL_PC;
                fe_ctrl.pc_we = 1'b0;
                fe_ctrl.bubble_dec = 1'b1;
                imem_req.valid = 1'b0;
            end
        end

        STALL_FLOW: begin
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            fe_ctrl.pc_we = 1'b0;
            if (stall_res.flow) begin
                // flow change resolved
                fe_ctrl.pc_sel = flow_changed ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                imem_req.valid = 1'b1;
                //imem_req.valid = !stall_src_dmem;
                imem_rsp.ready = 1'b1;
            end

        end

        STALL_IMEM: begin
            fe_ctrl.pc_sel = PC_SEL_PC;
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b1;

            if (imem_rsp.valid) begin
                fe_ctrl.bubble_dec = 1'b0;
                if (stall_act.flow) begin
                    // current inst is stalling, bubble in next cycle
                    fe_ctrl.pc_we = 1'b0; // ... (1) overwritten for now
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;
                end else begin
                    // no stall, proceed
                    fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
                    fe_ctrl.pc_we = 1'b1;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                    if (stall_act.dcache) move_past_dec_stall = 1'b1;
                end
            end
        end

        STALL_DC: begin
            // when dc stalls, fe keeps current state, no new requests
            fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.bubble_dec = 1'b0;
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b0;
            if (stall_res.dcache) begin
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
                end else begin
                    fe_ctrl.pc_we = 1'b1;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end
            end
        end

        default: ;

    endcase
end

`DFF_CI_RI_RV(`FE_CTRL_RST_VAL, decoded_fe_ctrl, decoded_fe_ctrl_d)

endmodule
