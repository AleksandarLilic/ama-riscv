`include "ama_riscv_defines.svh"

`ifndef SYNT
`include "ama_riscv_tb_defines.svh"

`define INST_WARN_ON_ILLEGAL_INST(x) \
    if (illegal_inst) \
        `LOG($sformatf( \
            "WARNING: decoder received illegal %0s instruction: %8h at %8h", \
            x, inst_dec, `CORE.pc.dec) \
        )
`else
`define INST_WARN_ON_ILLEGAL_INST(x)
`endif

`define D_EXC_ILLEGAL_INST \
    d.xcpt = '{pend: 1'b1, cause: MCAUSE_ILLEGAL_INST};

module ama_riscv_decoder #(
    parameter bit SIMD_EN = 1
)(
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
logic [11:0] fn12;
logic fn7_b5, fn7_b2, fn7_b0;
assign opc7 = get_opc7(inst_dec);
assign fn3 = get_fn3(inst_dec);
assign fn7 = get_fn7(inst_dec);
assign fn12 = get_fn12(inst_dec);
assign fn7_b0 = get_fn7_b0(inst_dec);
assign fn7_b2 = get_fn7_b2(inst_dec);
assign fn7_b5 = get_fn7_b5(inst_dec);

logic no_inst, illegal_inst;
assign no_inst = (inst_dec == 'h0);

simd_arith_op_t simd_arith_op_dec;
assign simd_arith_op_dec = simd_arith_op_t'({fn7[3:0], fn3});

simd_data_fmt_op_t simd_data_fmt_op_dec;
assign simd_data_fmt_op_dec = simd_data_fmt_op_t'({fn7[4:0], fn3});

// shorthands
decoder_t d;
fe_ctrl_t fc;
assign decoded = d;
assign fe_ctrl = fc;

always_comb begin
    d = `DECODER_INIT_VAL;
    fc = `FE_CTRL_INIT_VAL;
    illegal_inst = 'b0;

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
            d.simd_arith_op = simd_arith_op_t'({SIMD_ARITH_CLASS_RV32M, fn3});
            d.div_op = div_op_t'(fn3[1:0]);
            d.ewb_sel = d.itype.div ? EWB_SEL_DIV : EWB_SEL_ALU;
            d.wb_sel = d.itype.mult ? WB_SEL_SIMD : WB_SEL_EWB;
            d.rd_we = rd_nz;
            d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
            illegal_inst = !(
                (fn7 == 7'h0) || // rv32i
                ((fn7 == 7'h20) && ((fn3 == 3'h0) || (fn3 == 3'h5))) || // rv32i
                (fn7 == 7'h1) || // rv32m
                ((fn7 == 7'h5) && fn3[2]) // rv32 zbb partial
            );
            `INST_WARN_ON_ILLEGAL_INST("R_TYPE");
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
            // shifts have fn7 constraints
            // all other fn3 values use full imm[11:0]
            illegal_inst =
                ((fn3 == 3'h1) && (fn7 != 7'h00)) || // slli: fn7 must be 0x00
                ((fn3 == 3'h5) && (fn7 != 7'h00) && (fn7 != 7'h20)); //srli/srai
            `INST_WARN_ON_ILLEGAL_INST("I_TYPE");
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
            illegal_inst = (
                (fn3 == 3'h3) || (fn3 == 3'h6) || (fn3 == 3'h7)
            );
            `INST_WARN_ON_ILLEGAL_INST("LOAD");
        end

        OPC7_STORE: begin
            fc.pc_we = 1'b1;
            d.itype.store = 1'b1;
            d.a_sel = A_SEL_RS1;
            d.ig_sel = IG_S_TYPE;
            d.dmem_en = 1'b1;
            d.has_reg = '{rd: 0, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
            illegal_inst = ((fn3 == 3'h3) || fn3[2]);
            `INST_WARN_ON_ILLEGAL_INST("STORE");
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
            illegal_inst = ((fn3 == 3'h2) || (fn3 == 3'h3));
            `INST_WARN_ON_ILLEGAL_INST("BRANCH");
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
            illegal_inst = !(fn3 == 3'h0);
            `INST_WARN_ON_ILLEGAL_INST("JALR");
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
            if (!fn7[5]) begin // simd arithmetic
                fc.pc_we = 1'b1;
                d.itype.simd_arith = 1'b1;
                d.simd_arith_op = simd_arith_op_dec;
                d.wb_sel = WB_SEL_SIMD;
                d.rd_we = rd_nz;
            end else begin // simd data fmt
                fc.pc_we = 1'b1;
                d.itype.simd_data_fmt = 1'b1;
                d.simd_data_fmt_op = simd_data_fmt_op_dec;
                d.ewb_sel = EWB_SEL_DATA_FMT;
                d.rd_we = rd_nz;
            end

            unique case (fn7)
                CUSTOM_ISA_FN7_SIMD_ADDSUB: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                    illegal_inst = (fn3[0]);
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_ADDSUB");
                end
                CUSTOM_ISA_FN7_SIMD_QADDSUB: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                end
                CUSTOM_ISA_FN7_SIMD_MUL: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                    illegal_inst = ((fn3 == 3'h1) || (fn3 == 3'h3));
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_MUL");
                end
                CUSTOM_ISA_FN7_SIMD_WMUL: begin
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 1, rs3: 0};
                    illegal_inst = (fn3[2]);
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_WMUL");
                end
                CUSTOM_ISA_FN7_SIMD_DOT: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 1};
                end
                CUSTOM_ISA_FN7_SIMD_COMPARE: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                end
                CUSTOM_ISA_FN7_SIMD_SHIFT: begin
                    d.itype.simd_shift = 1'b1;
                    d.simd_shift_op = simd_shift_op_t'({1'b0, fn3});
                    d.ig_sel = IG_I_TYPE;
                    d.b_sel = B_SEL_IMM; // shift
                    d.ewb_sel = EWB_SEL_DATA_FMT; // go through data fmt path
                    d.wb_sel = WB_SEL_EWB;
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
                    illegal_inst = ((fn3 == 3'h1) || fn3 == 3'h3);
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_SHIFT");
                end

                // data format groups
                CUSTOM_ISA_FN7_SIMD_WIDEN: begin
                    d.itype.simd_shift = 1'b1;
                    d.simd_shift_op = simd_shift_op_t'({1'b1, fn3});
                    d.ig_sel = IG_I_TYPE;
                    d.b_sel = B_SEL_IMM; // shift
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 0, rs3: 0};
                end
                CUSTOM_ISA_FN7_SIMD_NARROW: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                    illegal_inst = (fn3[0]);
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_NARROW");
                end
                CUSTOM_ISA_FN7_SIMD_QNARROW: begin
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 1, rs3: 0};
                end
                CUSTOM_ISA_FN7_SIMD_TXP: begin
                    d.has_reg = '{rd: 1, rdp: 1, rs1: 1, rs2: 1, rs3: 0};
                    illegal_inst = (fn3[0]);
                    `INST_WARN_ON_ILLEGAL_INST("SIMD_TXP");
                end
                CUSTOM_ISA_FN7_SIMD_DUP_VINS: begin
                    if(!fn3[0]) begin // dup
                        d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
                    end else begin // vins
                        d.ig_sel = IG_I_TYPE;
                        d.b_sel = B_SEL_IMM; // index
                        d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 1};
                    end
                end
                CUSTOM_ISA_FN7_SIMD_VEXT: begin
                    d.ig_sel = IG_I_TYPE;
                    d.b_sel = B_SEL_IMM; // index
                    d.has_reg = '{rd: 1, rdp: 0, rs1: 1, rs2: 0, rs3: 0};
                end

                default: begin
                    illegal_inst = !no_inst;
                    `INST_WARN_ON_ILLEGAL_INST("custom");
                end

            endcase

            // SIMD disabled: wipe the custom decode -> illegal (NOP-like)
            if (!SIMD_EN) begin
                d = `DECODER_INIT_VAL;
                fc.pc_we = 1'b1;
                illegal_inst = !no_inst;
                `INST_WARN_ON_ILLEGAL_INST("custom (SIMD off)");
            end
        end

        OPC7_MISC_MEM: begin
            fc.pc_we = 1'b1;
            illegal_inst = !(
                (fn3 == 3'h0) || //fence: fm/pred/succ fields are ordering hints
                (inst_dec == `INST_FENCE_I)
            );
            `INST_WARN_ON_ILLEGAL_INST("SYSTEM");
        end

        OPC7_SYSTEM: begin
            fc.pc_we = 1'b1;
            if (fn3 == FN3_PRIV) begin
                // privileged: ecall/ebreak/mret/wfi
                case (fn12)
                    SYSTEM_FN12_ECALL: d.xcpt = '{pend: 1'b1, cause: MCAUSE_MACHINE_ECALL};
                    SYSTEM_FN12_EBREAK: d.xcpt = '{pend: 1'b1, cause: MCAUSE_BREAKPOINT};
                    SYSTEM_FN12_MRET: d.mret = 1'b1;
                    // SYSTEM_FN12_WFI: // TODO
                    default: begin
                        illegal_inst = 1'b1;
                        `INST_WARN_ON_ILLEGAL_INST("SYSTEM");
                    end
                endcase
            end else if (fn3 == FN3_PRIVM) begin
                illegal_inst = 1'b1;
                `INST_WARN_ON_ILLEGAL_INST("SYSTEM");
            end else begin // zicsr
                d.csr_ctrl.en = 1'b1;
                d.csr_ctrl.re = !((fn3[1:0] == CSR_OP_RW) && !rd_nz);
                d.csr_ctrl.we = (rs1_nz || (fn3[1:0] == CSR_OP_RW));
                d.csr_ctrl.ui = fn3[2];
                d.csr_ctrl.op = csr_op_t'(fn3[1:0]);
                d.ewb_sel = EWB_SEL_CSR;
                d.rd_we = rd_nz;
                d.has_reg = '{rd: 1, rdp: 0 , rs1: !fn3[2], rs2: 0, rs3: 0};
            end
        end

        default: begin
            illegal_inst = !no_inst;
            `INST_WARN_ON_ILLEGAL_INST("SYSTEM");
        end

    endcase

    if (illegal_inst) begin
        // reset to idle state and trap
        d = `DECODER_INIT_VAL;
        fc = `FE_CTRL_INIT_VAL;
        if (!d.xcpt.pend) `D_EXC_ILLEGAL_INST; // if not already raised
    end

end

`ifndef SYNT
logic non_spec_unsupported;
assign non_spec_unsupported = (illegal_inst && !`CORE.spec.active);
always_ff @(posedge `TB.clk) begin
    assert (!non_spec_unsupported || `CORE.flush.dec || `CORE.rst)
    else $warning("DECODER - unsupported instruction");
end
`endif

endmodule
