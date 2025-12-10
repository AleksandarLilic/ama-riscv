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
    output logic spec_wrong,
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
arch_width_t imem_addr, pc_inc4, pc_jal, pc_new_exe, pc_branch;
fe_ctrl_t fe_ctrl;
logic be_stalled_d;
decoder_t decoded; // from decode

`ifdef USE_BP
arch_width_t pc_fet_cp; // checkpoint fetch PC before going to speculative
arch_width_t pc_fet_cp_get;
assign pc_fet_cp_get = fe_ctrl.use_cp ? pc_fet_cp : pc.fet;
assign pc_inc4 = (pc_fet_cp_get + 'd4);
branch_t bp_pred;
logic bp_hit;
`else
assign pc_inc4 = (pc.fet + 'd4);
`endif

always_comb begin
    unique case (fe_ctrl.pc_sel)
        PC_SEL_PC: imem_addr = pc.fet;
        PC_SEL_INC4: imem_addr = pc_inc4;
        PC_SEL_ALU: imem_addr = pc_new_exe;
        PC_SEL_JAL: imem_addr = pc_jal;
        `ifdef USE_BP
        PC_SEL_BP: imem_addr = pc_branch;
        `endif
        default: imem_addr = pc.fet;
    endcase
end
assign imem_req.data = imem_addr[15:2];

`DFF_CI_RI_RV_EN(`RESET_VECTOR, fe_ctrl.pc_we, imem_addr, pc.fet)

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
        pc.dec = pc.fet;
        // even if be in stall, take inst if imem_rsp.valid
        // happens when i$ missed before be stalled
        inst.dec = imem_rsp.valid ? imem_rsp.data : 'h0;
    end
end

`DFF_CI_RI_RVI(inst.dec, inst_dec_d)
`DFF_CI_RI_RVI(pc.dec, pc_dec_d)

fe_ctrl_t decoded_fe_ctrl;
ama_riscv_decoder ama_riscv_decoder_i (
    .inst_dec (inst.dec), .decoded (decoded), .fe_ctrl (decoded_fe_ctrl)
);

decoder_t decoded_exe;
logic dc_stalled;
branch_t branch_resolution;
hazard_t hazard;
spec_exec_t spec;
rv_ctrl_if imem_req_rv ();
rv_ctrl_if imem_rsp_rv ();
assign imem_req_rv.ready = imem_req.ready;
assign imem_req.valid = imem_req_rv.valid;
assign imem_rsp.ready = imem_rsp_rv.ready;
assign imem_rsp_rv.valid = imem_rsp.valid;
ama_riscv_fe_ctrl ama_riscv_fe_ctrl_i (
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req_rv),
    .imem_rsp (imem_rsp_rv),
    // inputs
    .pc_dec (pc.dec),
    .pc_exe (pc.exe),
    .branch_in_dec (decoded.itype.branch),
    .jalr_in_dec (decoded.itype.jalr),
    .branch_in_exe (decoded_exe.itype.branch),
    .jalr_in_exe (decoded_exe.itype.jalr),
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

assign spec_wrong = spec.wrong; // module output

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
arch_width_t imm_gen_out_dec, imm_jal;
`ifdef USE_BP
arch_width_t imm_b;
`endif
ama_riscv_imm_gen ama_riscv_imm_gen_i(
    .sel (decoded.ig_sel),
    .in (inst.dec[31:7]),
    `ifdef USE_BP
    .out_b (imm_b),
    `endif
    .out_jal (imm_jal),
    .out (imm_gen_out_dec)
);

assign pc_jal = (pc.dec + imm_jal);
assign pc_branch = decoded.itype.branch ? (pc.dec + imm_b) : 'h0;

`ifdef USE_BP
// all predictors use imm_b right away, no BTB

if (BP_TYPE == BP_STATIC) begin: gen_bp_sttc

if (BP_STATIC_TYPE == BP_STATIC_AT) begin : gen_bp_sttc_at
assign bp_pred = B_T;
end else if (BP_STATIC_TYPE == BP_STATIC_ANT) begin: gen_bp_sttc_ant
assign bp_pred = B_NT;
end else if (BP_STATIC_TYPE == BP_STATIC_BTFN) begin: gen_bp_sttc_btfn
assign bp_pred = branch_t'(decoded.itype.branch && (pc_branch < pc.dec));
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

rf_addr_t rs1_addr_exe, rs2_addr_exe;
logic load_inst_mem, load_inst_wbk, mult_inst_mem;

fwd_be_t fwd_src_sel_rs1_dec, fwd_src_sel_rs2_dec;
fwd_be_t fwd_src_sel_rs1_exe, fwd_src_sel_rs2_exe;
a_sel_t a_sel_dec_fwd;
b_sel_t b_sel_dec_fwd;
logic a_sel_fwd_exe, b_sel_fwd_exe;

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    // inputs
    .load_inst_mem (load_inst_mem),
    .load_inst_wbk (load_inst_wbk),
    .dc_stalled (dc_stalled),
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
    .a_sel_dec (decoded.a_sel),
    .b_sel_dec (decoded.b_sel),
    // outputs (to decode)
    .fwd_src_sel_rs1_dec (fwd_src_sel_rs1_dec),
    .fwd_src_sel_rs2_dec (fwd_src_sel_rs2_dec),
    .a_sel_dec_fwd (a_sel_dec_fwd),
    .b_sel_dec_fwd (b_sel_dec_fwd),
    // outputs (to execute)
    .fwd_src_sel_rs1_exe (fwd_src_sel_rs1_exe),
    .fwd_src_sel_rs2_exe (fwd_src_sel_rs2_exe),
    .a_sel_fwd_exe (a_sel_fwd_exe),
    .b_sel_fwd_exe (b_sel_fwd_exe),
    // hazard detection
    .hazard (hazard)
);

// prepare forwading values from backend
arch_width_t rs1_dec_be_fwd, rs2_dec_be_fwd;
always_comb begin
    unique case (fwd_src_sel_rs1_dec)
        FWD_BE_WBK: rs1_dec_be_fwd = writeback;
        FWD_BE_WBK_P: rs1_dec_be_fwd = unpk_out_p_wbk;
        default: rs1_dec_be_fwd = 'h0;
    endcase
end

always_comb begin
    unique case (fwd_src_sel_rs2_dec)
        FWD_BE_WBK: rs2_dec_be_fwd = writeback;
        FWD_BE_WBK_P: rs2_dec_be_fwd = unpk_out_p_wbk;
        default: rs2_dec_be_fwd = 'h0;
    endcase
end

// get RF (rs1/rs2) or alternate (pc/imm), or forward from backend if rs1/rs2
arch_width_t op_a_dec, op_b_dec;
always_comb begin
    unique case (a_sel_dec_fwd)
        A_SEL_RS1: op_a_dec = rs1_data_dec;
        A_SEL_PC: op_a_dec = pc.dec;
        A_SEL_FWD: op_a_dec = rs1_dec_be_fwd;
        default: op_a_dec = 'h0;
    endcase
end

always_comb begin
    unique case (b_sel_dec_fwd)
        B_SEL_RS2: op_b_dec = rs2_data_dec;
        B_SEL_IMM: op_b_dec = imm_gen_out_dec;
        B_SEL_FWD: op_b_dec = rs2_dec_be_fwd;
        default: op_b_dec = 'h0;
    endcase
end

//------------------------------------------------------------------------------
// Pipeline FF DEC/EXE

logic [DMEM_ADDR_OFFSET_WIDTH-1:0] dmem_offset_dec, dmem_offset_exe;
assign dmem_offset_dec = imm_gen_out_dec[DMEM_ADDR_OFFSET_WIDTH-1:0];
logic decoded_itype_dmem;
assign decoded_itype_dmem = (decoded.itype.load || decoded.itype.store);

logic en_dec_exe;
assign en_dec_exe = ((!dc_stalled) && (!hazard.to_exe));
assign ctrl_dec_exe = '{
    flush: flush.dec,
    en: en_dec_exe,
    bubble: (fe_ctrl.bubble_dec /*|| hazard.to_dec*/)
};

arch_width_t op_a_exe, op_b_exe;
arch_width_t pc_branch_exe;

`STAGE(ctrl_dec_exe, 1'b1, pc.dec, pc.exe, 'h0)
`STAGE(ctrl_dec_exe, 1'b1, inst.dec, inst.exe, 'h0)
`STAGE(ctrl_dec_exe, 1'b1, rd_addr.dec, rd_addr.exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, 1'b1, rs1_addr_dec, rs1_addr_exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, 1'b1, rs2_addr_dec, rs2_addr_exe, RF_X0_ZERO)
`STAGE(ctrl_dec_exe, 1'b1, op_a_dec, op_a_exe, 'h0)
`STAGE(ctrl_dec_exe, 1'b1, op_b_dec, op_b_exe, 'h0)
`STAGE(ctrl_dec_exe, decoded.itype.branch, pc_branch, pc_branch_exe, 'h0)
`STAGE(ctrl_dec_exe, decoded_itype_dmem, dmem_offset_dec, dmem_offset_exe, 'h0)
`STAGE(ctrl_dec_exe, 1'b1, decoded, decoded_exe, `DECODER_INIT_VAL)

//------------------------------------------------------------------------------
// EXE stage
arch_width_t rs1_exe_be_fwd, rs2_exe_be_fwd;
always_comb begin
    rs1_exe_be_fwd = 'h0;
    unique case (fwd_src_sel_rs1_exe)
        FWD_BE_MEM: rs1_exe_be_fwd = e_writeback_mem;
        FWD_BE_WBK: rs1_exe_be_fwd = writeback;
        FWD_BE_MEM_P: rs1_exe_be_fwd = unpk_out_p_mem;
        FWD_BE_WBK_P: rs1_exe_be_fwd = unpk_out_p_wbk;
    endcase
end

always_comb begin
    rs2_exe_be_fwd = 'h0;
    unique case (fwd_src_sel_rs2_exe)
        FWD_BE_MEM: rs2_exe_be_fwd = e_writeback_mem;
        FWD_BE_WBK: rs2_exe_be_fwd = writeback;
        FWD_BE_MEM_P: rs2_exe_be_fwd = unpk_out_p_mem;
        FWD_BE_WBK_P: rs2_exe_be_fwd = unpk_out_p_wbk;
    endcase
end

// save wb in case inst in mem stalls, while exe inst needs forwarded value
logic use_swb_rs1, use_swb_rs2; // saved writeback
arch_width_t swb_rs1, swb_rs2;
always_ff @(posedge clk) begin
    if (rst) begin
        {use_swb_rs1, use_swb_rs2} = 2'b00;
    end else if (ctrl_exe_mem.bubble) begin
        if (a_sel_fwd_exe) {swb_rs1, use_swb_rs1} = {rs1_exe_be_fwd, 1'b1};
        if (b_sel_fwd_exe) {swb_rs2, use_swb_rs2} = {rs2_exe_be_fwd, 1'b1};
    end else if (!ctrl_exe_mem.bubble) begin
        {use_swb_rs1, use_swb_rs2} = 2'b00;
    end
end

arch_width_t op_a_r, op_b_r; // resolved operands
always_comb begin
    case (1'b1)
        a_sel_fwd_exe: op_a_r = rs1_exe_be_fwd;
        use_swb_rs1: op_a_r = swb_rs1;
        default: op_a_r = op_a_exe;
    endcase
end

always_comb begin
    case (1'b1)
        b_sel_fwd_exe: op_b_r = rs2_exe_be_fwd;
        use_swb_rs2: op_b_r = swb_rs2;
        default: op_b_r = op_b_exe;
    endcase
end

// branch compare & resolution
logic bc_a_eq_b, bc_a_lt_b;
assign bc_a_eq_b = (op_a_r == op_b_r);
assign bc_a_lt_b = (decoded_exe.bc_uns) ?
        (op_a_r < op_b_r) : ($signed(op_a_r) < $signed(op_b_r));

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
arch_width_t alu_out_exe;
ama_riscv_alu ama_riscv_alu_i (
    .op (decoded_exe.alu_op), .a (op_a_r), .b (op_b_r), .s (alu_out_exe)
);
assign pc_new_exe = decoded_exe.itype.branch ? pc_branch_exe : alu_out_exe;

simd_d_t unpk_out;
ama_riscv_unpk ama_riscv_unpk_i (
    .op (decoded_exe.unpk_op), .a (op_a_r), .s (unpk_out)
);

simd_t unpk_out_exe, unpk_out_p_exe;
assign unpk_out_exe = unpk_out.w[0];
assign unpk_out_p_exe = unpk_out.w[1];

logic simd_en_exe;
assign simd_en_exe = decoded_exe.itype.mult;
simd_t simd_out_mem;
ama_riscv_simd ama_riscv_simd_i (
    .clk (clk),
    .rst (rst),
    .en (simd_en_exe),
    .ctrl_exe_mem (ctrl_exe_mem),
    .op (decoded_exe.mult_op),
    .a (op_a_r),
    .b (op_b_r),
    .p (simd_out_mem)
);

// CSR
arch_width_t csr_out_exe;
logic inst_to_be_retired; // from retire pipeline
ama_riscv_csr #(
    .CLOCK_FREQ(CLOCK_FREQ)
) ama_riscv_csr_i (
    .clk (clk),
    .rst (rst),
    .ctrl (decoded_exe.csr_ctrl),
    .in (op_a_r),
    .imm5 (inst.exe[19:15]),
    .addr (csr_addr_t'(inst.exe[31:20])),
    .inst_to_be_retired (inst_to_be_retired),
    .perf_event (perf_event),
    .out (csr_out_exe)
);

// execute stage instruction result mux
arch_width_t e_writeback_exe;
always_comb begin
    unique case (decoded_exe.ewb_sel)
        EWB_SEL_ALU: e_writeback_exe = alu_out_exe;
        EWB_SEL_IMM_U: e_writeback_exe = op_b_r;
        EWB_SEL_PC_INC4: e_writeback_exe = (pc.exe + 'd4);
        EWB_SEL_CSR: e_writeback_exe = csr_out_exe;
        EWB_SEL_UNPK: e_writeback_exe = unpk_out_exe;
        default: e_writeback_exe = 'h0;
    endcase
end

// AGU
arch_width_t dmem_addr;
assign dmem_addr = (op_a_r + {{20{dmem_offset_exe[11]}}, dmem_offset_exe});

// memory map
logic map_dmem_exe, map_uart_exe;
assign map_dmem_exe = (dmem_addr[19:16] == `DMEM_RANGE);
assign map_uart_exe = (dmem_addr[19:16] == `MMIO_RANGE);

// DMEM
dmem_req_side_t dmem_req_exe;
dmem_dtype_t dmem_dtype;
assign dmem_dtype = dmem_dtype_t'(get_fn3(inst.exe));
assign dmem_req_exe.wdata = op_b_r;
assign dmem_req_exe.addr = dmem_addr[CORE_BYTE_ADDR_BUS-1:0];
assign dmem_req_exe.dtype = dmem_dtype;
assign dmem_req_exe.rtype = decoded_exe.itype.store ? DMEM_WRITE : DMEM_READ;
assign dmem_req_exe.en =
    (map_dmem_exe && decoded_exe.dmem_en && (!hazard.to_exe));

// UART
uart_ch_side_t uart_ch_exe;
assign uart_ch_exe.ctrl.en =
    (map_uart_exe && decoded_exe.dmem_en && (!hazard.to_exe));
assign uart_ch_exe.ctrl.we = (uart_ch_exe.ctrl.en && decoded_exe.itype.store);
assign uart_ch_exe.ctrl.addr = uart_addr_t'(dmem_addr[4:2]);
assign uart_ch_exe.ctrl.load_signed = (dmem_dtype == DMEM_DTYPE_BYTE);
assign uart_ch_exe.send = op_b_r[7:0]; // uart is 1 byte wide

//------------------------------------------------------------------------------
// Pipeline FF EXE/MEM
logic unpk_en_exe, unpk_en_mem;
assign unpk_en_exe = decoded_exe.itype.unpk;
logic simd_inst_exe, simd_inst_mem;
assign simd_inst_exe = (unpk_en_exe || (simd_en_exe && decoded_exe.mult_op[2]));

pipeline_if_typed #(.T(wb_sel_t)) wb_sel ();
assign wb_sel.exe = decoded_exe.wb_sel;
assign rd_we.exe = decoded_exe.rd_we;
assign rdp_we.exe = decoded_exe.itype.unpk;
assign ctrl_exe_mem = '{
    flush: flush.exe,
    en: (!dc_stalled),
    bubble: (!ctrl_dec_exe.en || hazard.to_exe)
};

logic map_uart_mem, dmem_en_mem;
dmem_req_side_t dmem_req_mem;
uart_ch_side_t uart_ch_mem;

`STAGE(ctrl_exe_mem, 1'b1, pc.exe, pc.mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, inst.exe, inst.mem, 'h0)
`STAGE(ctrl_exe_mem, rd_we.exe, e_writeback_exe, e_writeback_mem, 'h0)
`STAGE(ctrl_exe_mem, unpk_en_exe, unpk_out_p_exe, unpk_out_p_mem, 'h0)
`STAGE(ctrl_exe_mem, unpk_en_exe, unpk_en_exe, unpk_en_mem, 'h0)
`STAGE(ctrl_exe_mem, rd_we.exe, wb_sel.exe, wb_sel.mem, WB_SEL_EWB)
`STAGE(ctrl_exe_mem, 1'b1, rd_addr.exe, rd_addr.mem, RF_X0_ZERO)
`STAGE(ctrl_exe_mem, 1'b1, rd_we.exe, rd_we.mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, rdp_we.exe, rdp_we.mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, decoded_exe.itype.load, load_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, dmem_req_exe, dmem_req_mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, uart_ch_exe, uart_ch_mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, decoded_exe.itype.mult, mult_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, 1'b1, simd_inst_exe, simd_inst_mem, 'b0)
`STAGE(ctrl_exe_mem, 1'b1, map_uart_exe, map_uart_mem, 'h0)

`DFF_CI_RI_RVI((dc_stalled /*|| hazard.to_dec*/ || hazard.to_exe), be_stalled_d)

//------------------------------------------------------------------------------
// MEM stage

// DMEM
assign dmem_req.wdata = dmem_req_mem.wdata;
assign dmem_req.addr = dmem_req_mem.addr;
assign dmem_req.dtype = dmem_req_mem.dtype;
assign dmem_req.rtype = dmem_req_mem.rtype;
assign dmem_req.valid = (dmem_req_mem.en && (!dc_stalled));
assign dc_stalled = !dmem_req.ready;

// UART
assign uart_ch.ctrl.en = uart_ch_mem.ctrl.en;
assign uart_ch.ctrl.we = uart_ch_mem.ctrl.we;
assign uart_ch.ctrl.addr = uart_ch_mem.ctrl.addr;
assign uart_ch.ctrl.load_signed = uart_ch_mem.ctrl.load_signed;
assign uart_ch.send = uart_ch_mem.send;
// uart_ch.recv arrives in the next cycle

//------------------------------------------------------------------------------
// Pipeline FF MEM/WBK
assign ctrl_mem_wbk = '{
    flush: flush.exe,
    en: (!dc_stalled),
    bubble: (!ctrl_exe_mem.en)
};

logic simd_or_mult_en_mem;
assign simd_or_mult_en_mem = (mult_inst_mem || simd_inst_mem);

logic simd_inst_wbk, map_uart_wbk;
arch_width_t e_writeback_wbk, simd_out_wbk;

`STAGE(ctrl_mem_wbk, 1'b1, pc.mem, pc.wbk, 'h0)
`STAGE(ctrl_mem_wbk, 1'b1, inst.mem, inst.wbk, 'h0)
`STAGE(ctrl_mem_wbk, simd_or_mult_en_mem, simd_out_mem, simd_out_wbk, 'h0)
`STAGE(ctrl_mem_wbk, rd_we.mem, e_writeback_mem, e_writeback_wbk, 'h0)
`STAGE(ctrl_mem_wbk, unpk_en_mem, unpk_out_p_mem, unpk_out_p_wbk, 'h0)
`STAGE(ctrl_mem_wbk, rd_we.mem, wb_sel.mem, wb_sel.wbk, WB_SEL_EWB)
`STAGE(ctrl_mem_wbk, 1'b1, rd_addr.mem, rd_addr.wbk, RF_X0_ZERO)
`STAGE(ctrl_mem_wbk, 1'b1, rd_we.mem, rd_we.wbk, 'h0)
`STAGE(ctrl_mem_wbk, 1'b1, rdp_we.mem, rdp_we.wbk, 'h0)
`STAGE(ctrl_mem_wbk, 1'b1, load_inst_mem, load_inst_wbk, 'h0)
`STAGE(ctrl_mem_wbk, 1'b1, simd_inst_mem, simd_inst_wbk, 'h0)
`STAGE(ctrl_mem_wbk, 1'b1, map_uart_mem, map_uart_wbk, 'h0)

//------------------------------------------------------------------------------
// WBK stage

arch_width_t dmem_out_wbk;
assign dmem_out_wbk = map_uart_wbk ? uart_ch.recv : dmem_rsp.data;

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

`STAGE(ctrl_wbk_ret, 1'b1, inst.wbk, inst_ret, 'h0)
`STAGE(ctrl_wbk_ret, 1'b1, pc.wbk, pc_ret, 'h0)
`STAGE(ctrl_wbk_ret, 1'b1, simd_inst_wbk, simd_inst_ret, 'h0)

assign inst_retired = (pc_ret != 'h0);

//------------------------------------------------------------------------------
// perf
logic stall_flow;
`ifdef USE_BP
assign stall_flow = decoded.itype.jalr;
`else
assign stall_flow = decoded.itype.branch || decoded.itype.jalr;
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
