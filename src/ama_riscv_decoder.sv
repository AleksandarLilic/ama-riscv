`include "ama_riscv_defines.svh"

`ifndef SYNT
`include "ama_riscv_tb_defines.svh"

`define INST_WARN(x) \
    `LOG($sformatf( \
        "WARNING: decoder received unsupported %0s instruction: %8h at %8h", \
        x, inst_dec, `CORE.pc.dec) \
    )
`endif

module ama_riscv_decoder (
    input  arch_width_t inst_dec,
    output decoder_t decoded,
    output fe_ctrl_t fe_ctrl
);

rf_addr_t rs1_addr, rd_addr;
assign rs1_addr = get_rs1(inst_dec, 1'b1);
assign rd_addr = get_rd(inst_dec, 1'b1);
logic rs1_nz, rd_nz;
assign rs1_nz = (rs1_addr != RF_X0_ZERO);
assign rd_nz = (rd_addr != RF_X0_ZERO);

opc7_t opc7;
logic [2:0] fn3;
logic [6:0] fn7;
logic fn7_b5, fn7_b2, fn7_b0;
assign opc7 = get_opc7(inst_dec);
assign fn3 = get_fn3(inst_dec);
assign fn7 = get_fn7(inst_dec);
assign fn7_b0 = get_fn7_b0(inst_dec);
assign fn7_b2 = get_fn7_b2(inst_dec);
assign fn7_b5 = get_fn7_b5(inst_dec);

`ifndef SYNT
logic no_inst, unsupported_inst;
assign no_inst = (inst_dec == 'h0);
`endif

logic [2:0] fn7_simd_arith;
assign fn7_simd_arith = fn7[2:0];

simd_arith_op_t simd_arith_op_dec;
assign simd_arith_op_dec = simd_arith_op_t'({fn7_simd_arith, fn3});

// shorthands
decoder_t d;
fe_ctrl_t fc;
assign decoded = d;
assign fe_ctrl = fc;

always_comb begin
    d = `DECODER_INIT_VAL;
    fc = `FE_CTRL_INIT_VAL;
    `ifndef SYNT
    unsupported_inst = 'b0;
    `endif

    // decoder assumes frontend can always progress (pc_sel/pc_we)
    // fe_ctrl module overwrites if/when it can't
    case (opc7)
        OPC7_R_TYPE: begin
            fc.pc_we = 1'b1;
            d.itype.mult = (fn7_b0 && !fn7_b2 && !fn3[2]);
            d.itype.div = (fn7_b0 && !fn7_b2 && fn3[2]);
            d.a_sel = A_SEL_RS1;
            d.b_sel = B_SEL_RS2;
            d.alu_op = alu_op_t'({fn7_b5, fn7_b2, fn3});
            d.simd_arith_op = simd_arith_op_t'({2'h0, fn3});
            d.div_op = div_op_t'(fn3[1:0]);
            d.ewb_sel = d.itype.div ? EWB_SEL_DIV : EWB_SEL_ALU;
            d.wb_sel = d.itype.mult ? WB_SEL_SIMD : WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
            `ifndef SYNT
            unsupported_inst = !(
                (fn7 == 7'h0) || // rv32i
                ((fn7 == 7'h20) && ((fn3 == 3'h0) || (fn3 == 3'h5))) || // rv32i
                (fn7 == 7'h1) || // rv32m
                ((fn7 == 7'h5) && fn3[2]) // rv32 zbb partial
            );
            if (unsupported_inst) `INST_WARN("R_TYPE");
            `endif
        end

        OPC7_I_TYPE: begin
            fc.pc_we = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.b_sel = B_SEL_IMM;
            d.alu_op = (fn3[1:0] == 2'b01) ? // shift : immediate
                alu_op_t'({fn7_b5, 1'b0, fn3}) : alu_op_t'({2'h0, fn3});
            d.ig_sel = IG_I_TYPE;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
            `ifndef SYNT
            // shifts have fn7 constraints
            // all other fn3 values use full imm[11:0]
            unsupported_inst =
                ((fn3 == 3'h1) && (fn7 != 7'h00)) || // slli: fn7 must be 0x00
                ((fn3 == 3'h5) && (fn7 != 7'h00) && (fn7 != 7'h20)); //srli/srai
            if (unsupported_inst) `INST_WARN("I_TYPE");
            `endif
        end

        OPC7_LOAD: begin
            fc.pc_we = 1'b1;
            d.itype.load = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.ig_sel = IG_I_TYPE;
            d.dmem_en = 1'b1;
            d.wb_sel = WB_SEL_DMEM;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
            `ifndef SYNT
            unsupported_inst = (
                (fn3 == 3'h3) || (fn3 == 3'h6) || (fn3 == 3'h7)
            );
            if (unsupported_inst) `INST_WARN("LOAD");
            `endif
        end

        OPC7_STORE: begin
            fc.pc_we = 1'b1;
            d.itype.store = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.ig_sel = IG_S_TYPE;
            d.dmem_en = 1'b1;
            d.has_reg = '{rd: 0, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
            `ifndef SYNT
            unsupported_inst = ((fn3 == 3'h3) || fn3[2]);
            if (unsupported_inst) `INST_WARN("STORE");
            `endif
        end

        OPC7_BRANCH: begin
            // pc updated in fe_ctrl
            d.itype.branch = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.b_sel = B_SEL_RS2;
            d.alu_op = ALU_OP_ADD;
            d.ig_sel = IG_B_TYPE;
            d.branch_u = fn3[1];
            d.has_reg = '{rd: 0, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
            `ifndef SYNT
            unsupported_inst = ((fn3 == 3'h2) || (fn3 == 3'h3));
            if (unsupported_inst) `INST_WARN("BRANCH");
            `endif
        end

        OPC7_JAL: begin
            fc.pc_sel = PC_SEL_JAL_BP;
            fc.pc_we = 1'b1;
            d.itype.jal = 1'b1;
            d.ewb_sel = EWB_SEL_PC_INC4;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 0, rs2: 0, rs3: 0};
        end

        OPC7_JALR: begin
            // pc updated in fe_ctrl
            d.itype.jalr = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.b_sel = B_SEL_IMM;
            d.alu_op = ALU_OP_ADD;
            d.ig_sel = IG_I_TYPE;
            d.ewb_sel = EWB_SEL_PC_INC4;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
            `ifndef SYNT
            unsupported_inst = !(fn3 == 3'h0);
            if (unsupported_inst) `INST_WARN("JALR");
            `endif
        end

        OPC7_LUI: begin
            fc.pc_we = 1'b1;
            d.b_sel = B_SEL_IMM;
            d.ig_sel = IG_U_TYPE;
            d.ewb_sel = EWB_SEL_IMM_U;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 0, rs2: 0, rs3: 0};
        end

        OPC7_AUIPC: begin
            fc.pc_we = 1'b1;
            d.a_sel = A_SEL_PC;
            d.b_sel = B_SEL_IMM;
            d.alu_op = ALU_OP_ADD;
            d.ig_sel = IG_U_TYPE;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 0, rs2: 0, rs3: 0};
        end

        OPC7_CUSTOM: begin
            unique case (fn7)
                CUSTOM_ISA_FN7_SIMD_MUL: begin
                    fc.pc_we = 1'b1;
                    d.itype.simd_arith = 1'b1;
                    d.simd_arith_op = simd_arith_op_dec;
                    d.wb_sel = WB_SEL_SIMD;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 1};
                    `ifndef SYNT
                    unsupported_inst = ((fn3 == 3'h1) || (fn3 == 3'h3));
                    if (unsupported_inst) `INST_WARN("SIMD_MUL");
                    `endif
                end
                CUSTOM_ISA_FN7_SIMD_WMUL: begin
                    fc.pc_we = 1'b1;
                    d.itype.simd_arith = 1'b1;
                    d.simd_arith_op = simd_arith_op_dec;
                    d.wb_sel = WB_SEL_SIMD;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 1, rs3: 1};
                    `ifndef SYNT
                    unsupported_inst = (fn3[2]);
                    if (unsupported_inst) `INST_WARN("SIMD_WMUL");
                    `endif
                end
                CUSTOM_ISA_FN7_SIMD_DOT: begin
                    fc.pc_we = 1'b1;
                    d.itype.simd_arith = 1'b1;
                    d.simd_arith_op = simd_arith_op_dec;
                    d.wb_sel = WB_SEL_SIMD;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 1};
                end
                CUSTOM_ISA_FN7_SIMD_WIDEN: begin
                    fc.pc_we = 1'b1;
                    d.itype.simd_data_fmt = 1'b1;
                    d.simd_data_fmt_class = SIMD_DATA_FMT_CLASS_WIDEN;
                    d.simd_data_fmt_op = fn3;
                    d.ewb_sel = EWB_SEL_DATA_FMT;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 1, rs3: 0};
                end
                CUSTOM_ISA_FN7_SIMD_TXP: begin
                    fc.pc_we = 1'b1;
                    d.itype.simd_data_fmt = 1'b1;
                    d.simd_data_fmt_class = SIMD_DATA_FMT_CLASS_TXP;
                    d.simd_data_fmt_op = fn3;
                    d.ewb_sel = EWB_SEL_DATA_FMT;
                    d.rd_we = rd_nz;
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 1, rs3: 0};
                    `ifndef SYNT
                    unsupported_inst = (fn3[0]);
                    if (unsupported_inst) `INST_WARN("SIMD_TXP");
                    `endif
                end
                default: begin
                    `ifndef SYNT
                    unsupported_inst = !no_inst;
                    if (unsupported_inst) `INST_WARN("custom");
                    `endif
                end
            endcase
        end

        OPC7_MISC_MEM: begin
            fc.pc_we = 1'b1;
            `ifndef SYNT
            unsupported_inst = !(
                (fn3 == 3'h0) || //fence: fm/pred/succ fields are ordering hints
                (inst_dec == `INST_FENCE_I)
            );
            if (unsupported_inst) `INST_WARN("MISC_MEM");
            `endif
        end

        OPC7_SYSTEM: begin
            fc.pc_we = 1'b1;
            d.csr_ctrl.en = 1'b1;
            d.csr_ctrl.re = !((fn3[1:0] == CSR_OP_RW) && !rd_nz);
            d.csr_ctrl.we = (rs1_nz || (fn3[1:0] == CSR_OP_RW));
            d.csr_ctrl.ui = fn3[2];
            d.csr_ctrl.op = csr_op_t'(fn3[1:0]);
            d.ewb_sel = EWB_SEL_CSR;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0 , rs1: !fn3[2], rs2: 0, rs3: 0};
            `ifndef SYNT
            unsupported_inst = ((fn3 == 3'h0) || (fn3 == 3'h4));
            if (unsupported_inst) `INST_WARN("SYSTEM");
            `endif
        end

        default: begin
            `ifndef SYNT
            unsupported_inst = !no_inst;
            if (unsupported_inst) `INST_WARN("UNKNOWN");
            `endif
        end

    endcase
end

`ifndef SYNT
logic non_spec_unsupported;
assign non_spec_unsupported = (unsupported_inst && !`CORE.spec.active);
always_ff @(posedge `TB.clk) begin
    assert (!non_spec_unsupported || `CORE.flush.dec || `CORE.rst)
    else $fatal(1, "DECODER ERROR - unsupported instruction");
end
`endif

endmodule
