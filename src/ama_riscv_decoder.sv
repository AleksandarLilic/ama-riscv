`include "ama_riscv_defines.svh"

module ama_riscv_decoder (
    input  logic        clk,
    input  logic        rst,
    pipeline_if.IN      inst,
    rv_if.TX            imem_req,
    rv_if.RX            imem_rsp,
    input  logic        bc_a_eq_b,
    input  logic        bc_a_lt_b,
    output logic        bubble_dec,
    pipeline_if.OUT     clear,
    output logic [ 1:0] pc_sel,
    output logic        pc_we,
    output logic        load_inst,
    output logic        store_inst,
    output logic        branch_inst,
    output csr_ctrl_t   csr_ctrl,
    output logic [ 3:0] alu_op_sel,
    output logic        alu_a_sel,
    output logic        alu_b_sel,
    output logic [ 2:0] ig_sel,
    output logic        bc_uns,
    output logic        dmem_en,
    output logic        load_sm_en,
    output logic [ 1:0] wb_sel,
    output logic        rd_we
);

typedef enum logic [1:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_IMEM
} stall_state_t;

logic [11:0] csr_addr;
assign csr_addr = inst.p.dec[31:20];

logic [ 4:0] rs1_addr_dec;
logic [ 4:0] rd_addr_dec;
assign rs1_addr_dec = inst.p.dec[19:15];
assign rd_addr_dec = inst.p.dec[11:7];

logic [ 6:0] opc7_dec;
logic [ 2:0] fn3_dec;
logic [ 6:0] fn7_dec;
assign opc7_dec = inst.p.dec[6:0];
assign fn3_dec = inst.p.dec[14:12];
assign fn7_dec = inst.p.dec[31:25];

logic [ 6:0] opc7_exe;
logic [ 2:0] fn3_exe;
logic [ 6:0] fn7_exe;
assign opc7_exe = inst.p.exe[6:0];
assign fn3_exe = inst.p.exe[14:12];
assign fn7_exe = inst.p.exe[31:25];

// decoder outputs
logic [ 1:0] pc_sel_r;
logic        pc_we_r;
logic        load_inst_r;
logic        store_inst_r;
logic        branch_inst_r;
logic        jump_inst_r;
csr_ctrl_t   csr_ctrl_r;
logic [ 3:0] alu_op_sel_r;
logic        alu_a_sel_r;
logic        alu_b_sel_r;
logic [ 2:0] ig_sel_r;
logic        bc_uns_r;
logic        dmem_en_r;
logic        load_sm_en_r;
logic [ 1:0] wb_sel_r;
logic        rd_we_r;

// saved outputs
logic [ 1:0] pc_sel_d;
logic        pc_we_d;
logic        load_inst_d;
logic        store_inst_d;
logic        branch_inst_d;
logic        jump_inst_d;
logic [ 3:0] alu_op_sel_d;
logic        alu_a_sel_d;
logic        alu_b_sel_d;
logic [ 2:0] ig_sel_d;
logic        bc_uns_d;
logic        dmem_en_d;
logic        load_sm_en_d;
logic [ 1:0] wb_sel_d;
logic        rd_we_d;

logic rd_nz;
assign rd_nz = (rd_addr_dec != `RF_X0_ZERO);

logic rs1_nz;
assign rs1_nz = (rs1_addr_dec == `RF_X0_ZERO);

// Reset sequence
logic [ 2:0] reset_seq;
`DFF_CI_RI_RV(3'b111, {reset_seq[1:0],1'b0}, reset_seq)

logic rst_seq_dec;
logic rst_seq_exe;
logic rst_seq_mem;
assign rst_seq_dec = reset_seq[0]; // clear 1 clk after rst ends
assign rst_seq_exe = reset_seq[1]; // 2 clks
assign rst_seq_mem = reset_seq[2]; // 3 clks

// Pipeline FFs clear
assign clear.p = {1'b0, rst_seq_dec, rst_seq_exe, rst_seq_mem, 1'b0};

// TODO: decoder should be implemented with SV struct for cleaner code
// Decoder
always_comb begin
    pc_sel_r = pc_sel_d;
    pc_we_r = pc_we_d;
    load_inst_r = load_inst_d;
    store_inst_r = store_inst_d;
    branch_inst_r = branch_inst_d;
    jump_inst_r = jump_inst_d;
    csr_ctrl_r = {1'b0, 1'b0, 1'b0, 2'b00};
    alu_op_sel_r = alu_op_sel_d;
    alu_a_sel_r = alu_a_sel_d;
    alu_b_sel_r = alu_b_sel_d;
    ig_sel_r = ig_sel_d;
    bc_uns_r = bc_uns_d;
    dmem_en_r = dmem_en_d;
    load_sm_en_r = load_sm_en_d;
    wb_sel_r = wb_sel_d;
    rd_we_r = rd_we_d;

    case (opc7_dec)
        `OPC7_R_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = {fn7_dec[5],fn3_dec};
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_RS2;
            ig_sel_r      = `IG_DISABLED;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            wb_sel_r      = `WB_SEL_ALU;
            rd_we_r       = rd_nz;
        end

        `OPC7_I_TYPE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = (fn3_dec[1:0] == 2'b01) ?
                                {fn7_dec[5], fn3_dec} : // shift
                                {1'b0, fn3_dec}; // imm
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            wb_sel_r      = `WB_SEL_ALU;
            rd_we_r       = rd_nz;
        end

        `OPC7_LOAD: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b1;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b1;
            load_sm_en_r  = 1'b1;
            wb_sel_r      = `WB_SEL_DMEM;
            rd_we_r       = rd_nz;
        end

        `OPC7_STORE: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b1;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_S_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b1;
            load_sm_en_r  = 1'b0;
            // wb_sel_r      = *;
            rd_we_r       = 1'b0;
        end

        `OPC7_BRANCH: begin
            pc_sel_r      = `PC_SEL_INC4;   // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b1;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_B_TYPE;
            bc_uns_r      = fn3_dec[1];
            dmem_en_r     = 1'b0;
            load_sm_en_r  = 1'b0;
            // wb_sel_r      = *;
            rd_we_r       = 1'b0;
        end

        `OPC7_JALR: begin
            pc_sel_r      = `PC_SEL_ALU;    // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_I_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_INC4;
            rd_we_r       = rd_nz;
        end

        `OPC7_JAL: begin
            pc_sel_r      = `PC_SEL_ALU;    // to change to branch predictor
            pc_we_r       = 1'b1;           // assumes branch predictor ... (1)
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b1;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_J_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_INC4;
            rd_we_r       = rd_nz;
        end

        `OPC7_LUI: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_PASS_B;
            // alu_a_sel_r   = *;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_U_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_ALU;
            rd_we_r       = rd_nz;
        end

        `OPC7_AUIPC: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            alu_op_sel_r  = `ALU_ADD;
            alu_a_sel_r   = `ALU_A_SEL_PC;
            alu_b_sel_r   = `ALU_B_SEL_IMM;
            ig_sel_r      = `IG_U_TYPE;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_ALU;
            rd_we_r       = rd_nz;
        end

        `OPC7_SYSTEM: begin
            pc_sel_r      = `PC_SEL_INC4;
            pc_we_r       = 1'b1;
            load_inst_r   = 1'b0;
            store_inst_r  = 1'b0;
            branch_inst_r = 1'b0;
            jump_inst_r   = 1'b0;
            csr_ctrl_r.en = !((fn3_dec[1:0] == `CSR_OP_SEL_ASSIGN) && rs1_nz);
            csr_ctrl_r.we = !((fn3_dec[1:0] != `CSR_OP_SEL_ASSIGN) && rs1_nz);
            csr_ctrl_r.ui = fn3_dec[2];
            csr_ctrl_r.op_sel = fn3_dec[1:0];
            // alu_op_sel_r  = *;
            alu_a_sel_r   = `ALU_A_SEL_RS1;
            // alu_b_sel_r   = *;
            // ig_sel_r      = *;
            // bc_uns_r      = *;
            dmem_en_r     = 1'b0;
            // load_sm_en_r  = *;
            wb_sel_r      = `WB_SEL_CSR;
            rd_we_r       = rd_nz;
        end
        default ;
    endcase
end

// Branch Resolution
logic        branch_taken;
logic        branch_inst_exe;
logic [ 1:0] fn3_exe_branch;
assign fn3_exe_branch = {fn3_exe[2], fn3_exe[0]}; // branch conditions

`DFF_CI_RI_RVI(branch_inst_r, branch_inst_exe)

always_comb begin
    case (fn3_exe_branch)
        `BR_SEL_BEQ: branch_taken = bc_a_eq_b;
        `BR_SEL_BNE: branch_taken = !bc_a_eq_b;
        `BR_SEL_BLT: branch_taken = bc_a_lt_b;
        `BR_SEL_BGE: branch_taken = bc_a_eq_b || !bc_a_lt_b;
        default: branch_taken = 1'b0;
    endcase
end

// Jumps
logic jump_inst_exe;
`DFF_CI_RI_RVI(jump_inst_r, jump_inst_exe)

// Flow changed
logic flow_changed;
assign flow_changed = (branch_taken && branch_inst_exe) || jump_inst_exe;

// Stall
logic stall_src_flow_change;
assign stall_src_flow_change = branch_inst_r || jump_inst_r;
logic stall_src_imem;
assign stall_src_imem = !imem_rsp.valid;

// stall FSM
stall_state_t state, nx_state;

always_ff @(posedge clk) begin
    if (rst) state <= RST;
    else state <= nx_state;
end

// next state
always_comb begin
    nx_state = state;
    case (state)
        RST: begin
            `ifdef IMEM_DELAY
            nx_state = STALL_IMEM; // mem needs fixed number of cycles for rsp
            `else
            nx_state = STEADY;
            `endif
        end

        STEADY: begin
            if (stall_src_flow_change) nx_state = STALL_FLOW;
            else if (stall_src_imem) nx_state = STALL_IMEM;
        end

        STALL_FLOW: begin
            if (stall_src_imem) nx_state = STALL_IMEM;
            else nx_state = STEADY; // resolved in EXE, 1 clk currently
        end

        STALL_IMEM: begin
            if (imem_req.ready) begin
                if (stall_src_flow_change) nx_state = STALL_FLOW;
                else nx_state = STEADY;
            end
        end
    endcase
end

// outputs
always_comb begin
    pc_sel = pc_sel_d;
    pc_we = pc_we_d;
    imem_req.valid = 1'b0;
    imem_rsp.ready = 1'b0;
    bubble_dec = 1'b0;

    case (state)
        RST: begin
            pc_sel = `PC_SEL_PC;
            `ifdef IMEM_DELAY
            bubble_dec = 1'b1;
            pc_we = 1'b0;
            `else
            bubble_dec = 1'b0;
            pc_we = 1'b1;
            `endif
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;
        end

        STEADY: begin
            // pass decoder outputs by default
            pc_sel = pc_sel_r;
            pc_we = pc_we_r;
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;

            // override if in stall
            if (stall_src_flow_change) begin
                pc_we = 1'b0; // ... (1) overwritten for now
                imem_req.valid = 1'b0;
                imem_rsp.ready = 1'b0;
            end else if (stall_src_imem) begin
                pc_we = 1'b0;
                imem_req.valid = 1'b0;
                bubble_dec = 1'b1;
            end
        end

        STALL_FLOW: begin
            pc_sel = flow_changed ? `PC_SEL_ALU : pc_sel_r;
            pc_we = 1'b1;
            imem_req.valid = 1'b1;
            imem_rsp.ready = 1'b1;
            bubble_dec = 1'b1;
        end

        STALL_IMEM: begin
            pc_we = 1'b0;
            pc_sel = pc_sel_d;
            imem_req.valid = 1'b0;
            imem_rsp.ready = 1'b1;
            bubble_dec = 1'b1;

            if (imem_rsp.valid) begin // imem returned inst
                // stall if inst is flow change, else proceed forward
                if (stall_src_flow_change) begin
                    pc_we = 1'b0; // ... (1) overwritten for now
                    imem_req.valid = 1'b0;
                    imem_rsp.ready = 1'b0;
                    bubble_dec = 1'b0;
                end else begin
                    pc_we = 1'b1;
                    pc_sel = pc_sel_r;
                    imem_req.valid = 1'b1;
                    imem_rsp.ready = 1'b1;
                    bubble_dec = 1'b0;
                end
            end
        end
    endcase
end

// Output assignment
assign load_inst = load_inst_r;
assign store_inst = store_inst_r;
assign branch_inst = branch_inst_r;
assign csr_ctrl = csr_ctrl_r;
assign alu_op_sel = alu_op_sel_r;
assign alu_a_sel = alu_a_sel_r;
assign alu_b_sel = alu_b_sel_r;
assign ig_sel = ig_sel_r;
assign bc_uns = bc_uns_r;
assign dmem_en = dmem_en_r;
assign load_sm_en = load_sm_en_r;
assign wb_sel = wb_sel_r;
assign rd_we = rd_we_r;

// Store values
`DFF_CI_RI_RV(`PC_SEL_PC, pc_sel, pc_sel_d)
`DFF_CI_RI_RVI(pc_we, pc_we_d)
`DFF_CI_RI_RVI(load_inst, load_inst_d)
`DFF_CI_RI_RVI(store_inst, store_inst_d)
`DFF_CI_RI_RVI(branch_inst_r, branch_inst_d)
`DFF_CI_RI_RVI(jump_inst_r, jump_inst_d)
`DFF_CI_RI_RV(`ALU_ADD, alu_op_sel, alu_op_sel_d)
`DFF_CI_RI_RV(`ALU_A_SEL_RS1, alu_a_sel, alu_a_sel_d)
`DFF_CI_RI_RV(`ALU_B_SEL_RS2, alu_b_sel, alu_b_sel_d)
`DFF_CI_RI_RV(`IG_DISABLED, ig_sel, ig_sel_d)
`DFF_CI_RI_RVI(bc_uns, bc_uns_d)
`DFF_CI_RI_RVI(dmem_en, dmem_en_d)
`DFF_CI_RI_RVI(load_sm_en, load_sm_en_d)
`DFF_CI_RI_RV(`WB_SEL_DMEM, wb_sel, wb_sel_d)
`DFF_CI_RI_RVI(rd_we, rd_we_d)

endmodule
