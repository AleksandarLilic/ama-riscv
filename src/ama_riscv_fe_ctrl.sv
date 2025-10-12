`include "ama_riscv_defines.svh"

module ama_riscv_fe_ctrl (
    input  logic        clk,
    input  logic        rst,
    rv_if.TX            imem_req,
    rv_if.RX            imem_rsp,
    input  logic [31:0] pc_dec,
    input  logic [31:0] pc_exe,
    input  logic        branch_inst_dec,
    input  logic        jump_inst_dec,
    input  logic        branch_inst_exe,
    input  logic        jump_inst_exe,
    input  logic        branch_taken,
    input  fe_ctrl_t    decoded_fe_ctrl,
    output fe_ctrl_t    fe_ctrl
);

typedef enum logic [1:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_IMEM
    // SPECULATIVE, once BP is implemented, pc_sel is resolved differently
} stall_state_t;

typedef enum logic [1:0] {
    STALL_NONE = 2'b00,
    STALL_BRANCH = 2'b01,
    STALL_JUMP = 2'b10
} stall_inst_type_t;

typedef struct packed {
    stall_inst_type_t stype;
    logic [31:0] pc;
} stalled_entry_t;

stalled_entry_t stalled_entry, stalled_entry_d;

stall_inst_type_t stype_dec;
assign stype_dec = branch_inst_dec ? STALL_BRANCH : STALL_JUMP;

logic flow_changed;
logic stall_src_flow_change;
logic stall_src_flow_change_resolved;
logic stall_src_imem;
assign flow_changed = (branch_taken && branch_inst_exe) || jump_inst_exe;
assign stall_src_flow_change = branch_inst_dec || jump_inst_dec;
assign stall_src_flow_change_resolved = (stalled_entry.pc == pc_exe);
assign stall_src_imem = !imem_req.ready;

// stall FSM
stall_state_t state, nx_state;

// state transition
`DFF_CI_RI_RV(RST, nx_state, state)
`DFF_CI_RI_RV('{stype: STALL_NONE, pc: 32'h0}, stalled_entry, stalled_entry_d)

// next state
always_comb begin
    nx_state = state;
    stalled_entry = stalled_entry_d;

    case (state)
        RST: begin
            `ifdef IMEM_DELAY
            nx_state = STALL_IMEM; // mem needs fixed number of cycles for rsp
            `else
            nx_state = STEADY;
            `endif
        end

        STEADY: begin
            stalled_entry = '{stype: STALL_NONE, pc: 32'h0};
            if (stall_src_flow_change) begin
                stalled_entry = '{stype: stype_dec, pc: pc_dec};
                nx_state = STALL_FLOW;
            end else if (stall_src_imem) begin
                nx_state = STALL_IMEM;
            end
        end

        STALL_FLOW: begin
            if (stall_src_flow_change_resolved) begin
                // flow change resolved
                if (stall_src_imem) nx_state = STALL_IMEM;
                else nx_state = STEADY;
            end
        end

        STALL_IMEM: begin
            if (imem_req.ready) begin // imem returned inst
                // stall again, now if inst is flow change, else proceed forward
                if (stall_src_flow_change) begin
                    stalled_entry = '{stype: stype_dec, pc: pc_dec};
                    nx_state = STALL_FLOW;
                end else begin
                    nx_state = STEADY;
                end
            end
        end
    endcase
end

// outputs
fe_ctrl_t decoded_fe_ctrl_d;
always_comb begin
    fe_ctrl.pc_sel = decoded_fe_ctrl_d.pc_sel;
    fe_ctrl.pc_we = decoded_fe_ctrl_d.pc_we;
    imem_req.valid = 1'b0;
    imem_rsp.ready = 1'b0;
    fe_ctrl.bubble_dec = 1'b0;

    case (state)
        RST: begin
            fe_ctrl.pc_sel = PC_SEL_PC;

            `ifdef IMEM_DELAY
            fe_ctrl.bubble_dec = 1'b1;
            fe_ctrl.pc_we = 1'b0;
            `else
            fe_ctrl.bubble_dec = 1'b0;
            fe_ctrl.pc_we = 1'b1;
            `endif

            // reset vector on boot
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
            if (stall_src_flow_change) begin
                // current inst is stalling, bubble in next cycle
                fe_ctrl.pc_we = 1'b0; // ... (1) overwritten for now
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_src_imem) begin
                // imem has no reponse in this cycle, bubble right away
                fe_ctrl.pc_we = 1'b0;
                imem_req.valid = 1'b0;
                fe_ctrl.bubble_dec = 1'b1;
                fe_ctrl.pc_sel = PC_SEL_PC;
            end
        end

        STALL_FLOW: begin
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall
            if (stall_src_flow_change_resolved) begin
                // flow change resolved
                fe_ctrl.pc_sel = flow_changed ? PC_SEL_ALU : PC_SEL_INC4;
                fe_ctrl.pc_we = 1'b1;
                imem_req.valid = 1'b1;
                imem_rsp.ready = 1'b1;
            end

        end

        STALL_IMEM: begin
            fe_ctrl.pc_we = 1'b0;
            fe_ctrl.pc_sel = PC_SEL_PC;
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b1;
            fe_ctrl.bubble_dec = 1'b1; // bubble as long as in stall

            if (imem_rsp.valid) begin
                fe_ctrl.bubble_dec = 1'b0;
                if (stall_src_flow_change) begin
                    // current inst is stalling, bubble in next cycle
                    fe_ctrl.pc_we = 1'b0; // ... (1) overwritten for now
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;
                end else begin
                    // no stall, proceed
                    fe_ctrl.pc_we = 1'b1;
                    fe_ctrl.pc_sel = decoded_fe_ctrl.pc_sel;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                end
            end
        end
    endcase
end

`DFF_CI_RI_RV(`FE_CTRL_RST_VAL, decoded_fe_ctrl, decoded_fe_ctrl_d)

endmodule
