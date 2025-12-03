`include "ama_riscv_defines.svh"

module ama_riscv_core #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
)(
    input  logic clk,
    input  logic rst,
    rv_if.TX     imem_req,
    rv_if.RX     imem_rsp,
    rv_if_dc.TX  dmem_req,
    rv_if.RX     dmem_rsp,
    uart_if.TX   uart_ch,
    output spec_exec_t spec,
    output logic inst_retired
);

localparam unsigned PIPE_STAGES = 4;
localparam logic [PIPE_STAGES-1:0] RST_INIT = (1 << PIPE_STAGES) - 1;

pipeline_if #(.W(INST_WIDTH)) inst ();
pipeline_if #(.W(ARCH_WIDTH)) pc ();
pipeline_if_s flush ();

// Reset sequence
logic [PIPE_STAGES-1:0] reset_seq;
`DFF_CI_RI_RV(RST_INIT, {reset_seq[PIPE_STAGES-2:0], 1'b0}, reset_seq)

// pipe stage controls
stage_ctrl_t ctrl_exe_mem, ctrl_dec_exe, ctrl_mem_wbk, ctrl_wbk_ret;
perf_event_t perf_event;

//------------------------------------------------------------------------------
// FET Stage
arch_width_t pc_mux_out, pc_inc4, alu_out_exe; // pc mux inputs
fe_ctrl_t fe_ctrl;
logic be_stalled_d;

`ifdef USE_BP
arch_width_t pc_fet_cp; // checkpoint fetch PC before going to speculative
arch_width_t bp_pc;
branch_t bp_pred;
logic bp_hit;
`endif

always_comb begin
    unique case (fe_ctrl.pc_sel)
        PC_SEL_PC: pc_mux_out = pc.fet;
        PC_SEL_INC4: pc_mux_out = pc_inc4;
        PC_SEL_ALU: pc_mux_out = alu_out_exe;
        `ifdef USE_BP
        PC_SEL_BP: pc_mux_out = bp_pc;
        `endif
        default: pc_mux_out = pc.fet;
    endcase
end
assign imem_req.data = pc_mux_out[15:2];

`DFF_CI_RI_RV_EN(`RESET_VECTOR, fe_ctrl.pc_we, pc_mux_out, pc.fet)

`ifdef USE_BP
assign pc_inc4 = fe_ctrl.use_cp ? pc_fet_cp + 'd4 : pc.fet + 'd4;
`else
assign pc_inc4 = pc.fet + 'd4;
`endif

//------------------------------------------------------------------------------
// DEC Stage
inst_width_t inst_dec_d;
arch_width_t pc_dec_d;
always_comb begin
    if (be_stalled_d && !imem_rsp.valid) begin
        // keep current inst, new requests are not issued to the same addr
        inst.dec = inst_dec_d;
        pc.dec = pc_dec_d;
    end else begin
        // even if be in stall, take inst if imem_rsp.valid
        // happens when i$ missed before be stalled
        inst.dec = imem_rsp.data;
        pc.dec = pc.fet;
    end
end

`DFF_CI_RI_RVI(inst.dec, inst_dec_d)
`DFF_CI_RI_RVI(pc.dec, pc_dec_d)

decoder_t decoded, decoded_exe;
fe_ctrl_t decoded_fe_ctrl;
ama_riscv_decoder ama_riscv_decoder_i (
    .inst_dec (inst.dec), .decoded (decoded), .fe_ctrl (decoded_fe_ctrl)
);

logic dc_stalled;
branch_t branch_resolution;
hazard_t hazard;
ama_riscv_fe_ctrl ama_riscv_fe_ctrl_i (
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req),
    .imem_rsp (imem_rsp),
    // inputs
    .pc_dec (pc.dec),
    .pc_exe (pc.exe),
    .branch_inst_dec (decoded.itype.branch),
    .jump_inst_dec (decoded.itype.jump),
    .branch_inst_exe (decoded_exe.itype.branch),
    .jump_inst_exe (decoded_exe.itype.jump),
    `ifdef USE_BP
    .bp_pred (bp_pred),
    `endif
    .branch_resolution (branch_resolution),
    .decoded_fe_ctrl (decoded_fe_ctrl),
    .hazard (hazard),
    .dc_stalled (dc_stalled),
    // outputs
    `ifdef USE_BP
    .bp_hit (bp_hit),
    .pc_cp (pc_fet_cp),
    `endif
    .spec (spec), // tied to 0 when BP is not used
    .fe_ctrl (fe_ctrl)
);

arch_width_t e_writeback_mem, unpk_out_p_mem; // from MEM stage
arch_width_t writeback, unpk_out_p_wbk; // from WBK stage

// reg file
pipeline_if_typed #(.T(rf_addr_t)) rd_addr ();
pipeline_if_s rd_we ();
pipeline_if_s rdp_we ();
rf_addr_t rs1_addr_dec, rs2_addr_dec;
arch_width_t rs1_data_dec, rs2_data_dec;

assign rs1_addr_dec = get_rs1(inst.dec, decoded.has_reg.rs1);
assign rs2_addr_dec = get_rs2(inst.dec, decoded.has_reg.rs2);
assign rd_addr.dec = get_rd(inst.dec, decoded.has_reg.rd);

ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk (clk),
    // inputs
    .we (rd_we.wbk),
    .we_p (rdp_we.wbk),
    .addr_a (rs1_addr_dec),
    .addr_b (rs2_addr_dec),
    .addr_d (rd_addr.wbk),
    .data_d (writeback),
    .data_dp (unpk_out_p_wbk),
    // outputs
    .data_a (rs1_data_dec),
    .data_b (rs2_data_dec)
);

// imm gen
arch_width_t imm_gen_out_dec;
`ifdef USE_BP
arch_width_t imm_b;
`endif
ama_riscv_imm_gen ama_riscv_imm_gen_i(
    .sel (decoded.ig_sel),
    .in (inst.dec[31:7]),
    `ifdef USE_BP
    .out_b (imm_b),
    `endif
    .out (imm_gen_out_dec)
);

`ifdef USE_BP
// all predictors use imm_b right away, no BTB
assign bp_pc = decoded.itype.branch ? (pc.dec + imm_b) : 'h0;

if (BP_TYPE == BP_STATIC) begin: gen_bp_sttc

if (BP_STATIC_TYPE == BP_STATIC_AT) begin : gen_bp_sttc_at
assign bp_pred = B_T;
end else if (BP_STATIC_TYPE == BP_STATIC_ANT) begin: gen_bp_sttc_ant
assign bp_pred = B_NT;
end else if (BP_STATIC_TYPE == BP_STATIC_BTFN) begin: gen_bp_sttc_btfn
assign bp_pred = branch_t'(decoded.itype.branch && (bp_pc < pc.dec));
end

end else begin: gen_bp_dyn
branch_t bp_pred_1;
bp_pipe_t pipe_to_bp;
assign pipe_to_bp =
    '{pc_dec: pc.dec, pc_exe: pc.exe, spec: spec, br_res: branch_resolution};

ama_riscv_bp #(
    .PC_BITS (BP_1_PC_BITS),
    .CNT_BITS (BP_1_CNT_BITS),
    .BP_TYPE_SEL (BP_1_TYPE)
) ama_riscv_bp_c1_i (
    .clk (clk),
    .rst (rst),
    .pipe_in (pipe_to_bp),
    .bp_comp_pred ('{B_NT, B_NT}), // dc
    .pred (bp_pred_1)
);

if (BP_TYPE != BP_COMBINED) begin: gen_bp_dyn_single
assign bp_pred = bp_pred_1;

end else begin: gen_bp_dyn_comb
branch_t bp_pred_2, bp_pred_meta;

ama_riscv_bp #(
    .GR_BITS (BP_2_GR_BITS),
    .CNT_BITS (BP_2_CNT_BITS),
    .BP_TYPE_SEL (BP_2_TYPE)
) ama_riscv_bp_c2_i (
    .clk (clk),
    .rst (rst),
    .pipe_in (pipe_to_bp),
    .bp_comp_pred ('{B_NT, B_NT}), // dc
    .pred (bp_pred_2)
);

ama_riscv_bp #(
    .PC_BITS (BP_C_PC_BITS),
    .CNT_BITS (BP_C_CNT_BITS),
    .BP_TYPE_SEL (BP_COMBINED)
) ama_riscv_bp_i (
    .clk (clk),
    .rst (rst),
    .pipe_in (pipe_to_bp),
    .bp_comp_pred ('{bp_pred_1, bp_pred_2}),
    .pred (bp_pred_meta)
);
assign bp_pred = bp_pred_meta;

end // gen_bp_dyn_single/gen_bp_dyn_comb
end // gen_bp_sttc/gen_bp_dyn
`endif // USE_BP

fwd_be_t fwd_be_rs1_dec, fwd_be_rs2_dec, fwd_be_rs1_exe, fwd_be_rs2_exe;
logic rf_a_sel_fwd, rf_b_sel_fwd, bc_a_sel_fwd_exe, bcs_b_sel_fwd_exe;
alu_a_sel_t alu_a_sel_fwd;
alu_b_sel_t alu_b_sel_fwd;
rf_addr_t rs1_addr_exe, rs2_addr_exe;
logic load_inst_mem, store_inst_mem, mult_inst_mem;

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    // inputs
    .store_inst_dec (decoded.itype.store),
    .branch_inst_dec (decoded.itype.branch),
    .store_inst_exe (decoded_exe.itype.store),
    .load_inst_exe (decoded_exe.itype.load),
    .branch_inst_exe (decoded_exe.itype.branch),
    .load_inst_mem (load_inst_mem),
    .mult_inst_mem (mult_inst_mem),
    .rs1_dec (rs1_addr_dec),
    .rs2_dec (rs2_addr_dec),
    .rs1_exe (rs1_addr_exe),
    .rs2_exe (rs2_addr_exe),
    .rd_mem (rd_addr.mem),
    .rd_wbk (rd_addr.wbk),
    .rd_we_mem (rd_we.mem),
    .rd_we_wbk (rd_we.wbk),
    .rdp_we_mem (rdp_we.mem),
    .rdp_we_wbk (rdp_we.wbk),
    .alu_a_sel_dec (decoded.alu_a_sel),
    .alu_b_sel_dec (decoded.alu_b_sel),
    .alu_a_sel_exe (decoded_exe.alu_a_sel),
    .alu_b_sel_exe (decoded_exe.alu_b_sel),
    // outputs
    .fwd_be_rs1_dec (fwd_be_rs1_dec),
    .fwd_be_rs2_dec (fwd_be_rs2_dec),
    .fwd_be_rs1_exe (fwd_be_rs1_exe),
    .fwd_be_rs2_exe (fwd_be_rs2_exe),
    .alu_a_sel_fwd (alu_a_sel_fwd),
    .alu_b_sel_fwd (alu_b_sel_fwd),
    .bc_a_sel_fwd (bc_a_sel_fwd_exe),
    .bcs_b_sel_fwd (bcs_b_sel_fwd_exe),
    .rf_a_sel_fwd (rf_a_sel_fwd),
    .rf_b_sel_fwd (rf_b_sel_fwd),
    .hazard (hazard)
);

//------------------------------------------------------------------------------
// Pipeline FF DEC/EXE
arch_width_t rs1_dec_be_fwd, rs2_dec_be_fwd;

always_comb begin
    unique case (fwd_be_rs1_dec)
        //FWD_BE_EWB: rs1_dec_be_fwd = e_writeback_mem;
        FWD_BE_WB: rs1_dec_be_fwd = writeback;
        //FWD_BE_EWB_P: rs1_dec_be_fwd = unpk_out_p_mem;
        FWD_BE_WB_P: rs1_dec_be_fwd = unpk_out_p_wbk;
        default: rs1_dec_be_fwd = 'h0;
    endcase
end

always_comb begin
    unique case (fwd_be_rs2_dec)
        //FWD_BE_EWB: rs2_dec_be_fwd = e_writeback_mem;
        FWD_BE_WB: rs2_dec_be_fwd = writeback;
        //FWD_BE_EWB_P: rs2_dec_be_fwd = unpk_out_p_mem;
        FWD_BE_WB_P: rs2_dec_be_fwd = unpk_out_p_wbk;
        default: rs2_dec_be_fwd = 'h0;
    endcase
end

arch_width_t rs1_data_fwd, rs2_data_fwd;
assign rs1_data_fwd = rf_a_sel_fwd ? rs1_dec_be_fwd : rs1_data_dec;
assign rs2_data_fwd = rf_b_sel_fwd ? rs2_dec_be_fwd : rs2_data_dec;

logic en_dec_exe;
assign en_dec_exe = ((!dc_stalled) && (!hazard.to_exe));
assign ctrl_dec_exe = '{
    flush: flush.dec,
    en: en_dec_exe,
    bubble: (fe_ctrl.bubble_dec /*|| hazard.to_dec*/)
};

arch_width_t imm_gen_out_exe;
arch_width_t rs1_data_exe, rs2_data_exe;
`STAGE(ctrl_dec_exe, pc.dec, pc.exe, 'h0)
`STAGE(ctrl_dec_exe, inst.dec, inst.exe, 'h0)
`STAGE(ctrl_dec_exe, rd_addr.dec, rd_addr.exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, rs1_addr_dec, rs1_addr_exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, rs2_addr_dec, rs2_addr_exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, rs1_data_fwd, rs1_data_exe, 'h0)
`STAGE(ctrl_dec_exe, rs2_data_fwd, rs2_data_exe, 'h0)
`STAGE(ctrl_dec_exe, imm_gen_out_dec, imm_gen_out_exe, 'h0)
`STAGE(ctrl_dec_exe, decoded, decoded_exe, `DECODER_RST_VAL)

//------------------------------------------------------------------------------
// EXE stage
arch_width_t rs1_exe_be_fwd, rs2_exe_be_fwd;
always_comb begin
    rs1_exe_be_fwd = 'h0;
    unique case (fwd_be_rs1_exe)
        FWD_BE_EWB: rs1_exe_be_fwd = e_writeback_mem;
        FWD_BE_WB: rs1_exe_be_fwd = writeback;
        FWD_BE_EWB_P: rs1_exe_be_fwd = unpk_out_p_mem;
        FWD_BE_WB_P: rs1_exe_be_fwd = unpk_out_p_wbk;
    endcase
end

always_comb begin
    rs2_exe_be_fwd = 'h0;
    unique case (fwd_be_rs2_exe)
        FWD_BE_EWB: rs2_exe_be_fwd = e_writeback_mem;
        FWD_BE_WB: rs2_exe_be_fwd = writeback;
        FWD_BE_EWB_P: rs2_exe_be_fwd = unpk_out_p_mem;
        FWD_BE_WB_P: rs2_exe_be_fwd = unpk_out_p_wbk;
    endcase
end

// save wb in case inst in mem stalls, while exe inst needs forwarded value
logic use_swb_rs1, use_swb_rs2; // saved writeback
arch_width_t swb_rs1, swb_rs2;
always_ff @(posedge clk) begin
    if (rst) begin
        use_swb_rs1 = 1'b0;
        use_swb_rs2 = 1'b0;
    end else if (ctrl_exe_mem.bubble) begin
        if (bc_a_sel_fwd_exe || (alu_a_sel_fwd == ALU_A_SEL_FWD)) begin
            swb_rs1 = rs1_exe_be_fwd;
            use_swb_rs1 = 1'b1;
        end
        if (bcs_b_sel_fwd_exe || (alu_b_sel_fwd == ALU_B_SEL_FWD)) begin
            swb_rs2 = rs2_exe_be_fwd;
            use_swb_rs2 = 1'b1;
        end
    end else if (!ctrl_exe_mem.bubble) begin
        use_swb_rs1 = 1'b0;
        use_swb_rs2 = 1'b0;
    end
end

// branch compare & resolution
arch_width_t bc_a, bcs_b;
always_comb begin
    case (1'b1)
        bc_a_sel_fwd_exe: bc_a = rs1_exe_be_fwd;
        use_swb_rs1: bc_a = swb_rs1;
        default: bc_a = rs1_data_exe;
    endcase
end

always_comb begin
    case (1'b1)
        bcs_b_sel_fwd_exe: bcs_b = rs2_exe_be_fwd;
        use_swb_rs2: bcs_b = swb_rs2;
        default: bcs_b = rs2_data_exe;
    endcase
end

logic bc_a_eq_b, bc_a_lt_b;
assign bc_a_eq_b = (bc_a == bcs_b);
assign bc_a_lt_b =
    (decoded_exe.bc_uns) ? (bc_a < bcs_b) : ($signed(bc_a) < $signed(bcs_b));

branch_sel_t branch_sel_exe;
assign branch_sel_exe = get_branch_sel(inst.exe);

always_comb begin
    unique case (branch_sel_exe)
        BRANCH_SEL_BEQ: branch_resolution = branch_t'(bc_a_eq_b);
        BRANCH_SEL_BNE: branch_resolution = branch_t'(!bc_a_eq_b);
        BRANCH_SEL_BLT: branch_resolution = branch_t'(bc_a_lt_b);
        BRANCH_SEL_BGE: branch_resolution = branch_t'(bc_a_eq_b || !bc_a_lt_b);
    endcase
end

// ALU
arch_width_t alu_in_a, alu_in_b;
always_comb begin
    unique case (alu_a_sel_fwd)
        ALU_A_SEL_RS1: alu_in_a = use_swb_rs1 ? swb_rs1 : rs1_data_exe;
        ALU_A_SEL_PC: alu_in_a = pc.exe;
        ALU_A_SEL_FWD: alu_in_a = rs1_exe_be_fwd;
        default: alu_in_a = 'h0;
    endcase
end

always_comb begin
    unique case (alu_b_sel_fwd)
        ALU_B_SEL_RS2: alu_in_b = use_swb_rs2 ? swb_rs2 : rs2_data_exe;
        ALU_B_SEL_IMM: alu_in_b = imm_gen_out_exe;
        ALU_B_SEL_FWD: alu_in_b = rs2_exe_be_fwd;
        default: alu_in_b = 'h0;
    endcase
end

ama_riscv_alu ama_riscv_alu_i (
    .op (decoded_exe.alu_op), .a (alu_in_a), .b (alu_in_b), .s (alu_out_exe)
);

simd_d_t unpk_out;
ama_riscv_unpk ama_riscv_unpk_i (
    .op (decoded_exe.unpk_op), .a (alu_in_a), .s (unpk_out)
);

simd_t simd_out_mem;
ama_riscv_simd ama_riscv_simd_i (
    .clk (clk),
    .rst (rst),
    .ctrl_exe_mem (ctrl_exe_mem),
    .op (decoded_exe.mult_op),
    .a (alu_in_a),
    .b (alu_in_b),
    .p (simd_out_mem)
);

simd_t unpk_out_exe, unpk_out_p_exe;
assign unpk_out_exe = unpk_out.w[0];
assign unpk_out_p_exe = unpk_out.w[1];

// CSR
arch_width_t csr_out_exe;
logic inst_to_be_retired; // from retire pipeline
ama_riscv_csr #(
    .CLOCK_FREQ(CLOCK_FREQ)
) ama_riscv_csr_i (
    .clk (clk),
    .rst (rst),
    .ctrl (decoded_exe.csr_ctrl),
    .in (alu_in_a),
    .inst_exe (inst.exe),
    .inst_to_be_retired (inst_to_be_retired),
    .perf_event (perf_event),
    .out (csr_out_exe)
);

// memory map
logic map_dmem_exe, map_uart_exe;
assign map_dmem_exe = (alu_out_exe[19:16] == `DMEM_RANGE);
assign map_uart_exe = (alu_out_exe[19:16] == `MMIO_RANGE);

// DMEM
dmem_dtype_t dmem_dtype, dmem_dtype_mem;
assign dmem_dtype = dmem_dtype_t'(get_fn3(inst.exe));
assign dmem_req.valid =
    map_dmem_exe && decoded_exe.dmem_en && (!dc_stalled) && (!hazard.to_exe);
assign dmem_req.wdata = bcs_b;
assign dmem_req.addr = alu_out_exe[CORE_BYTE_ADDR_BUS-1:0];
assign dmem_req.dtype = dmem_dtype;
assign dmem_req.rtype = decoded_exe.itype.store ? DMEM_WRITE : DMEM_READ;
assign dc_stalled = !dmem_req.ready;

// UART
assign uart_ch.ctrl.en = map_uart_exe && decoded_exe.dmem_en;
assign uart_ch.ctrl.we = uart_ch.ctrl.en && decoded_exe.itype.store;
assign uart_ch.ctrl.addr = uart_addr_t'(alu_out_exe[4:2]);
assign uart_ch.ctrl.load_signed = (dmem_dtype == DMEM_DTYPE_BYTE);
assign uart_ch.send = bcs_b[7:0];
// uart_ch.recv aligned with mem stage

//------------------------------------------------------------------------------
// Pipeline FF EXE/MEM
arch_width_t pc_inc4_mem, alu_out_mem, csr_out_mem, unpk_out_mem;
logic map_uart_mem;
logic simd_inst_exe, simd_inst_mem;
assign simd_inst_exe =
    (decoded_exe.itype.unpk ||
    (decoded_exe.itype.mult && decoded_exe.mult_op[2])
);

pipeline_if_typed #(.T(ewb_sel_t)) ewb_sel ();
pipeline_if_typed #(.T(wb_sel_t)) wb_sel ();
assign ewb_sel.exe = decoded_exe.ewb_sel;
assign wb_sel.exe = decoded_exe.wb_sel;
assign rd_we.exe = decoded_exe.rd_we;
assign rdp_we.exe = decoded_exe.itype.unpk;
assign ctrl_exe_mem = '{
    flush: flush.exe,
    en: (!dc_stalled),
    bubble: (!ctrl_dec_exe.en || hazard.to_exe)
};

`STAGE(ctrl_exe_mem, pc.exe, pc.mem, 'h0)
`STAGE(ctrl_exe_mem, pc.exe + 'd4, pc_inc4_mem, 'h0)
`STAGE(ctrl_exe_mem, inst.exe, inst.mem, 'h0)
`STAGE(ctrl_exe_mem, alu_out_exe, alu_out_mem, 'h0)
`STAGE(ctrl_exe_mem, unpk_out_exe, unpk_out_mem, 'h0)
`STAGE(ctrl_exe_mem, unpk_out_p_exe, unpk_out_p_mem, 'h0)
`STAGE(ctrl_exe_mem, ewb_sel.exe, ewb_sel.mem, EWB_SEL_ALU)
`STAGE(ctrl_exe_mem, wb_sel.exe, wb_sel.mem, WB_SEL_EWB)
`STAGE(ctrl_exe_mem, rd_addr.exe, rd_addr.mem, RF_X0_ZERO)
`STAGE(ctrl_exe_mem, rd_we.exe, rd_we.mem, 'h0)
`STAGE(ctrl_exe_mem, rdp_we.exe, rdp_we.mem, 'h0)
`STAGE(ctrl_exe_mem, csr_out_exe, csr_out_mem, 'h0)
`STAGE(ctrl_exe_mem, decoded_exe.itype.load, load_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, decoded_exe.itype.store, store_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, decoded_exe.itype.mult, mult_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, map_uart_exe, map_uart_mem, 'h0)
`STAGE(ctrl_exe_mem, simd_inst_exe, simd_inst_mem, 'b0)

`DFF_CI_RI_RVI((dc_stalled /*|| hazard.to_dec*/ || hazard.to_exe), be_stalled_d)

//------------------------------------------------------------------------------
// MEM stage
always_comb begin
    e_writeback_mem = 'h0;
    unique case (ewb_sel.mem)
        EWB_SEL_ALU: e_writeback_mem = alu_out_mem;
        EWB_SEL_PC_INC4: e_writeback_mem = pc_inc4_mem;
        EWB_SEL_CSR: e_writeback_mem = csr_out_mem;
        EWB_SEL_UNPK: e_writeback_mem = unpk_out_mem;
    endcase
end

arch_width_t dmem_out_mem;
assign dmem_out_mem = map_uart_mem ? uart_ch.recv : dmem_rsp.data;

//------------------------------------------------------------------------------
// Pipeline FF MEM/WBK
arch_width_t e_writeback_wbk, dmem_out_wbk, simd_out_wbk;
logic simd_inst_wbk;

assign ctrl_mem_wbk = '{
    flush: flush.exe,
    en: 1'b1,
    bubble: (!ctrl_exe_mem.en)
};

`STAGE(ctrl_mem_wbk, inst.mem, inst.wbk, 'h0)
`STAGE(ctrl_mem_wbk, pc.mem, pc.wbk, 'h0)
`STAGE(ctrl_mem_wbk, dmem_out_mem, dmem_out_wbk, 'h0)
`STAGE(ctrl_mem_wbk, simd_out_mem, simd_out_wbk, 'h0)
`STAGE(ctrl_mem_wbk, unpk_out_p_mem, unpk_out_p_wbk, 'h0)
`STAGE(ctrl_mem_wbk, e_writeback_mem, e_writeback_wbk, 'h0)
`STAGE(ctrl_mem_wbk, rd_addr.mem, rd_addr.wbk, RF_X0_ZERO)
`STAGE(ctrl_mem_wbk, rd_we.mem, rd_we.wbk, 'h0)
`STAGE(ctrl_mem_wbk, rdp_we.mem, rdp_we.wbk, 'h0)
`STAGE(ctrl_mem_wbk, wb_sel.mem, wb_sel.wbk, WB_SEL_EWB)
`STAGE(ctrl_mem_wbk, simd_inst_mem, simd_inst_wbk, 'h0)

//------------------------------------------------------------------------------
// WBK stage
always_comb begin
    unique case (wb_sel.wbk)
        WB_SEL_EWB: writeback = e_writeback_wbk;
        WB_SEL_DMEM: writeback = dmem_out_wbk;
        WB_SEL_SIMD: writeback = simd_out_wbk;
        default: writeback = 'h0;
    endcase
end

assign inst_to_be_retired = (pc.wbk != 'h0) && (!flush.wbk);

//------------------------------------------------------------------------------
// retire
assign ctrl_wbk_ret = '{flush: flush.wbk, en: 1'b1, bubble: (!ctrl_mem_wbk.en)};

inst_width_t inst_ret;
arch_width_t pc_ret;
logic simd_inst_ret;
`STAGE(ctrl_wbk_ret, inst.wbk, inst_ret, 'h0)
`STAGE(ctrl_wbk_ret, pc.wbk, pc_ret, 'h0)
`STAGE(ctrl_wbk_ret, simd_inst_wbk, simd_inst_ret, 'h0)

assign inst_retired = (pc_ret != 'h0);

//------------------------------------------------------------------------------
// perf
logic stall_flow;
`ifdef USE_BP
assign stall_flow = decoded.itype.jump;
`else
assign stall_flow = decoded.itype.branch || decoded.itype.jump;
`endif

perf_event_t get_pe;
always_comb begin
    get_pe = '{0, 0, 0, 0, 0, 0};
    get_pe.bad_spec = spec.wrong;
    get_pe.ret_simd = (inst_retired && simd_inst_ret);
    if (!spec.wrong) begin
        get_pe.be = (dc_stalled || hazard.to_exe);
        get_pe.be_dc = dc_stalled;
        get_pe.fe = (!get_pe.be && (stall_flow || !imem_req.ready));
        get_pe.fe_ic = (!get_pe.be && (!imem_req.ready));
    end
end

`DFF_CI_RI_RVI(get_pe, perf_event)

//------------------------------------------------------------------------------
// pipeline control
assign flush.fet = 1'b0;
assign flush.dec = reset_seq[0];
assign flush.exe = reset_seq[1];
assign flush.mem = reset_seq[2];
assign flush.wbk = reset_seq[3];

endmodule
