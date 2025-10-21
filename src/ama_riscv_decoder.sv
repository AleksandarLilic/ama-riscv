`include "ama_riscv_defines.svh"

module ama_riscv_decoder (
    input  logic        clk,
    input  logic        rst,
    pipeline_if.IN      inst,
    output decoder_t    decoded,
    output fe_ctrl_t    fe_ctrl
);

typedef enum logic [1:0] {
    RST,
    STEADY,
    STALL_FLOW,
    STALL_IMEM
} stall_state_t;

rf_addr_t rs1_addr_dec;
rf_addr_t rd_addr_dec;
assign rs1_addr_dec = get_rs1(inst.dec);
assign rd_addr_dec = get_rd(inst.dec);

opc7_t       opc7_dec;
logic [ 2:0] fn3_dec;
logic        fn7_dec_b5;
assign opc7_dec = get_opc7(inst.dec);
assign fn3_dec = get_fn3(inst.dec);
assign fn7_dec_b5 = get_fn7_b5(inst.dec);

logic rd_nz;
assign rd_nz = (rd_addr_dec != RF_X0_ZERO);
logic rs1_nz;
assign rs1_nz = (rs1_addr_dec == RF_X0_ZERO);

decoder_t decoded_d;
fe_ctrl_t fe_ctrl_d;
always_comb begin
    decoded = decoded_d;
    fe_ctrl = fe_ctrl_d;
    decoded.csr_ctrl = '{en: 1'b0, we: 1'b0, ui: 1'b0, op_sel: CSR_OP_SEL_NONE};

    case (opc7_dec)
        OPC7_R_TYPE: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = alu_op_t'({fn7_dec_b5, fn3_dec});
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            decoded.alu_b_sel   = ALU_B_SEL_RS2;
            decoded.ig_sel      = IG_DISABLED;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_ALU;
            decoded.rd_we       = rd_nz;
        end

        OPC7_I_TYPE: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  =
                (fn3_dec[1:0] == 2'b01) ?
                    alu_op_t'({fn7_dec_b5, fn3_dec}) : // shift
                    alu_op_t'({1'b0, fn3_dec}); // imm
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_I_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_ALU;
            decoded.rd_we       = rd_nz;
        end

        OPC7_LOAD: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b1;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_I_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b1;
            decoded.load_sm_en  = 1'b1;
            decoded.wb_sel      = WB_SEL_DMEM;
            decoded.rd_we       = rd_nz;
        end

        OPC7_STORE: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b1;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_S_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b1;
            decoded.load_sm_en  = 1'b0;
            // decoded.wb_sel      = *;
            decoded.rd_we       = 1'b0;
        end

        OPC7_BRANCH: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4; // to change to bp
            fe_ctrl.pc_we       = 1'b1;        // assumes bp ... (1)
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b1;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_PC;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_B_TYPE;
            decoded.bc_uns      = fn3_dec[1];
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            // wb_sel      = *;
            decoded.rd_we       = 1'b0;
        end

        OPC7_JALR: begin
            fe_ctrl.pc_sel      = PC_SEL_ALU;     // to change to bp
            fe_ctrl.pc_we       = 1'b1;           // assumes bp ... (1)
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b1;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_I_TYPE;
            // bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_INC4;
            decoded.rd_we       = rd_nz;
        end

        OPC7_JAL: begin
            fe_ctrl.pc_sel      = PC_SEL_ALU;     // to change to bp
            fe_ctrl.pc_we       = 1'b1;           // assumes bp ... (1)
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b1;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_PC;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_J_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_INC4;
            decoded.rd_we       = rd_nz;
        end

        OPC7_LUI: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = ALU_OP_PASS_B;
            // decoded.alu_a_sel   = *;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_U_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_ALU;
            decoded.rd_we       = rd_nz;
        end

        OPC7_AUIPC: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.alu_op_sel  = ALU_OP_ADD;
            decoded.alu_a_sel   = ALU_A_SEL_PC;
            decoded.alu_b_sel   = ALU_B_SEL_IMM;
            decoded.ig_sel      = IG_U_TYPE;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_ALU;
            decoded.rd_we       = rd_nz;
        end

        OPC7_SYSTEM: begin
            fe_ctrl.pc_sel      = PC_SEL_INC4;
            fe_ctrl.pc_we       = 1'b1;
            decoded.load_inst   = 1'b0;
            decoded.store_inst  = 1'b0;
            decoded.branch_inst = 1'b0;
            decoded.jump_inst   = 1'b0;
            decoded.csr_ctrl.en =
                !((fn3_dec[1:0] == CSR_OP_SEL_ASSIGN) && rs1_nz);
            decoded.csr_ctrl.we =
                !((fn3_dec[1:0] != CSR_OP_SEL_ASSIGN) && rs1_nz);
            decoded.csr_ctrl.ui = fn3_dec[2];
            decoded.csr_ctrl.op_sel = csr_op_sel_t'(fn3_dec[1:0]);
            // decoded.alu_op_sel  = *;
            decoded.alu_a_sel   = ALU_A_SEL_RS1;
            // decoded.alu_b_sel   = *;
            // decoded.ig_sel      = *;
            // decoded.bc_uns      = *;
            decoded.dmem_en     = 1'b0;
            decoded.load_sm_en  = 1'b0;
            decoded.wb_sel      = WB_SEL_CSR;
            decoded.rd_we       = rd_nz;
        end
        default ;
    endcase
end

`DFF_CI_RI_RV(`DECODER_RST_VAL, decoded, decoded_d)
`DFF_CI_RI_RV(`FE_CTRL_RST_VAL, fe_ctrl, fe_ctrl_d)

endmodule
