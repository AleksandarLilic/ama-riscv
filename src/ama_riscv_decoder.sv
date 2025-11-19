`include "ama_riscv_defines.svh"

module ama_riscv_decoder (
    input  logic clk,
    input  logic rst,
    input  arch_width_t inst_dec,
    output decoder_t decoded,
    output fe_ctrl_t fe_ctrl
);

rf_addr_t rs1_addr, rd_addr;
assign rs1_addr = get_rs1(inst_dec, 1'b1);
assign rd_addr = get_rd(inst_dec, 1'b1);
logic rs1_nz, rd_nz;
assign rs1_nz = (rs1_addr == RF_X0_ZERO);
assign rd_nz = (rd_addr != RF_X0_ZERO);

opc7_t opc7;
logic [2:0] fn3;
logic fn7_b6, fn7_b5, fn7_b0;
assign opc7 = get_opc7(inst_dec);
assign fn3 = get_fn3(inst_dec);
assign fn7_b6 = get_fn7_b6(inst_dec);
assign fn7_b5 = get_fn7_b5(inst_dec);
assign fn7_b0 = get_fn7_b0(inst_dec);

// shorthands
decoder_t d;
fe_ctrl_t fc;
assign decoded = d;
assign fe_ctrl = fc;

always_comb begin
    d = `DECODER_RST_VAL;
    fc = `FE_CTRL_RST_VAL;

    // decoder assumes frontend can always progress (pc_sel/pc_we)
    // fe_ctrl module overwrites if/when it can't
    case (opc7)
        OPC7_R_TYPE: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.itype.mult = fn7_b0;
            d.alu_op = alu_op_t'({fn7_b5, fn3});
            d.mult_op = mult_op_t'({1'b0, fn3[1:0]});
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.alu_b_sel = ALU_B_SEL_RS2;
            d.ewb_sel = EWB_SEL_ALU;
            d.wb_sel = d.itype.mult ? WB_SEL_SIMD : WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_I_TYPE: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.alu_op = (fn3[1:0] == 2'b01) ? // shift : immediate
                alu_op_t'({fn7_b5, fn3}) : alu_op_t'({1'b0, fn3});
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_I_TYPE;
            d.ewb_sel = EWB_SEL_ALU;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_LOAD: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.itype.load = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_I_TYPE;
            d.dmem_en = 1'b1;
            d.wb_sel = WB_SEL_DMEM;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_STORE: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.itype.store = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_S_TYPE;
            d.dmem_en = 1'b1;
            d.has_reg = '{rd: 1'b0, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_BRANCH: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.itype.branch = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_PC;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_B_TYPE;
            d.bc_uns = fn3[1];
            d.has_reg = '{rd: 1'b0, rs1: 1'b1, rs2: 1'b1};
        end

        OPC7_JALR: begin
            fc.pc_sel = PC_SEL_ALU;
            fc.pc_we = 1'b1;
            d.itype.jump = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_I_TYPE;
            d.ewb_sel = EWB_SEL_PC_INC4;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b0};
        end

        OPC7_JAL: begin
            fc.pc_sel = PC_SEL_ALU;
            fc.pc_we = 1'b1;
            d.itype.jump = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_PC;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_J_TYPE;
            d.ewb_sel = EWB_SEL_PC_INC4;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_LUI: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.alu_op = ALU_OP_PASS_B;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_U_TYPE;
            d.ewb_sel = EWB_SEL_ALU;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_AUIPC: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            d.alu_op = ALU_OP_ADD;
            d.alu_a_sel = ALU_A_SEL_PC;
            d.alu_b_sel = ALU_B_SEL_IMM;
            d.ig_sel = IG_U_TYPE;
            d.ewb_sel = EWB_SEL_ALU;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: 1'b0, rs2: 1'b0};
        end

        OPC7_CUSTOM: begin
            // [SIMD, UNPAK]
            unique case (custom_isa_t'(fn3[0]))
                CUSTOM_SIMD_DOT: begin
                    fc.pc_sel = PC_SEL_INC4;
                    fc.pc_we = 1'b1;
                    d.itype.mult = 1'b1;
                    d.mult_op = mult_op_t'({1'b1, fn7_b6, fn7_b0});
                    d.alu_a_sel = ALU_A_SEL_RS1;
                    d.alu_b_sel = ALU_B_SEL_RS2;
                    d.wb_sel = WB_SEL_SIMD;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b1};
                end
                CUSTOM_SIMD_UNPK: begin
                    fc.pc_sel = PC_SEL_INC4;
                    fc.pc_we = 1'b1;
                    d.itype.unpk = 1'b1;
                    d.unpk_op = unpk_op_t'({fn7_b6, fn7_b5, fn7_b0});
                    d.alu_a_sel = ALU_A_SEL_RS1;
                    d.ewb_sel = EWB_SEL_UNPK;
                    d.wb_sel = WB_SEL_EWB;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1'b1, rs1: 1'b1, rs2: 1'b1};
                    d.has_reg_p = 1'b1;
                end
            endcase
        end

        OPC7_SYSTEM: begin
            fc.pc_sel = PC_SEL_INC4;
            fc.pc_we = 1'b1;
            // FIXME: rw/rwi should not read CSR on rd=x0;
            // no impact w/ current CSRs
            d.csr_ctrl.en = 1'b1;
            d.csr_ctrl.re = 1'b1;
            d.csr_ctrl.we = !((fn3[1:0] != CSR_OP_RW) && rs1_nz);
            d.csr_ctrl.ui = fn3[2];
            d.csr_ctrl.op = csr_op_t'(fn3[1:0]);
            d.alu_a_sel = ALU_A_SEL_RS1;
            d.ewb_sel = EWB_SEL_CSR;
            d.wb_sel = WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1'b1, rs1: !fn3[2], rs2: 1'b0};
        end

        default: begin
            d = `DECODER_RST_VAL;
            fc = `FE_CTRL_RST_VAL;
        end

    endcase
end

endmodule
