`include "ama_riscv_defines.svh"

module ama_riscv_decoder (
    input  logic        clk,
    input  logic        rst,
    input  arch_width_t inst_dec,
    output decoder_t    decoded,
    output fe_ctrl_t    fe_ctrl
);

rf_addr_t rs1_addr_dec, rd_addr_dec;
assign rs1_addr_dec = get_rs1(inst_dec, 1'b1);
assign rd_addr_dec = get_rd(inst_dec, 1'b1);
logic rs1_nz, rd_nz;
assign rs1_nz = (rs1_addr_dec == RF_X0_ZERO);
assign rd_nz = (rd_addr_dec != RF_X0_ZERO);

opc7_t opc7_dec;
logic [2:0] fn3_dec;
logic fn7_dec_b5;
assign opc7_dec = get_opc7(inst_dec);
assign fn3_dec = get_fn3(inst_dec);
assign fn7_dec_b5 = get_fn7_b5(inst_dec);
assign fn7_dec_b0 = get_fn7_b0(inst_dec);

always_comb begin
    decoded = `DECODER_RST_VAL;
    fe_ctrl = `FE_CTRL_RST_VAL;

    // decoder assumes frontend can always progress (pc_sel/pc_we)
    // fe_ctrl module overwrites if it can't
    case (opc7_dec)
        OPC7_R_TYPE: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.mult = fn7_dec_b0;
            decoded.alu_op = alu_op_t'({fn7_dec_b5, fn3_dec});
            decoded.mult_op = mult_op_t'(fn3_dec[1:0]);
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.alu_b_sel = ALU_B_SEL_RS2;
            decoded.wb_sel = WB_SEL_ALU;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_I_TYPE: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.alu_op =
                (fn3_dec[1:0] == 2'b01) ?
                    alu_op_t'({fn7_dec_b5, fn3_dec}) : // shift
                    alu_op_t'({1'b0, fn3_dec}); // imm
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_I_TYPE;
            decoded.wb_sel = WB_SEL_ALU;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_LOAD: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.load = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_I_TYPE;
            decoded.dmem_en = 1'b1;
            decoded.wb_sel = WB_SEL_DMEM;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_STORE: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.store = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_S_TYPE;
            decoded.dmem_en = 1'b1;
            decoded.has_reg = '{rd: 1'b0, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_BRANCH: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.branch = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_PC;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_B_TYPE;
            decoded.bc_uns = fn3_dec[1];
            decoded.has_reg = '{rd: 1'b0, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_JALR: begin
            fe_ctrl.pc_sel = PC_SEL_ALU;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.jump = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_I_TYPE;
            decoded.wb_sel = WB_SEL_INC4;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_JAL: begin
            fe_ctrl.pc_sel = PC_SEL_ALU;
            fe_ctrl.pc_we = 1'b1;
            decoded.itype.jump = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_PC;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_J_TYPE;
            decoded.wb_sel = WB_SEL_INC4;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_LUI: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.alu_op = ALU_OP_PASS_B;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_U_TYPE;
            decoded.wb_sel = WB_SEL_ALU;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_AUIPC: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            decoded.alu_op = ALU_OP_ADD;
            decoded.alu_a_sel = ALU_A_SEL_PC;
            decoded.alu_b_sel = ALU_B_SEL_IMM;
            decoded.ig_sel = IG_U_TYPE;
            decoded.wb_sel = WB_SEL_ALU;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_SYSTEM: begin
            fe_ctrl.pc_sel = PC_SEL_INC4;
            fe_ctrl.pc_we = 1'b1;
            // FIXME: rw/rwi should not read CSR on rd=x0;
            // no impact w/ current CSRs
            decoded.csr_ctrl.en = 1'b1;
            decoded.csr_ctrl.re = 1'b1;
            decoded.csr_ctrl.we = !((fn3_dec[1:0] != CSR_OP_RW) && rs1_nz);
            decoded.csr_ctrl.ui = fn3_dec[2];
            decoded.csr_ctrl.op = csr_op_t'(fn3_dec[1:0]);
            decoded.alu_a_sel = ALU_A_SEL_RS1;
            decoded.wb_sel = WB_SEL_CSR;
            decoded.rd_we = rd_nz;
            decoded.has_reg = '{rd: 1'b1, rs1: !fn3_dec[2], rs2: 1'b0};
        end

        default: begin
            decoded = `DECODER_RST_VAL;
            fe_ctrl = `FE_CTRL_RST_VAL;
        end

    endcase
end

endmodule
