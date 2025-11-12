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
    rv_if.TX     uart_send_req,
    rv_if.RX     uart_recv_rsp,
    output spec_exec_t  spec,
    output logic inst_retired
);

localparam unsigned CLOCKS_PER_US = CLOCK_FREQ / 1_000_000;
localparam unsigned CNT_WIDTH = $clog2(CLOCKS_PER_US);
localparam unsigned PIPE_STAGES = 4;
localparam logic [PIPE_STAGES-1:0] RST_INIT = (1 << PIPE_STAGES) - 1;

pipeline_if #(.W(INST_WIDTH)) inst ();
pipeline_if #(.W(ARCH_WIDTH)) pc ();
pipeline_if_s flush ();

// Reset sequence
logic [PIPE_STAGES-1:0] reset_seq;
`DFF_CI_RI_RV(RST_INIT, {reset_seq[PIPE_STAGES-2:0], 1'b0}, reset_seq)

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
    pc_mux_out = pc.fet;
    unique case (fe_ctrl.pc_sel)
        PC_SEL_PC: pc_mux_out = pc.fet;
        PC_SEL_INC4: pc_mux_out = pc_inc4;
        PC_SEL_ALU: pc_mux_out = alu_out_exe;
        `ifdef USE_BP
        PC_SEL_BP: pc_mux_out = bp_pc;
        `endif
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
    .clk (clk),
    .rst (rst),
    // inputs
    .inst_dec (inst.dec),
    // outputs
    .decoded (decoded),
    .fe_ctrl (decoded_fe_ctrl)
);

logic dc_stalled, move_past_dec_exe_dc_stall;
branch_t branch_resolution;
hazard_be_t hazard_be;
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
    `ifdef USE_BP
    .bp_pred (bp_pred),
    `endif
    .branch_inst_exe (decoded_exe.itype.branch),
    .jump_inst_exe (decoded_exe.itype.jump),
    .branch_resolution (branch_resolution),
    .decoded_fe_ctrl (decoded_fe_ctrl),
    .hazard_be (hazard_be),
    .dc_stalled (dc_stalled),
    // outputs
    .fe_ctrl (fe_ctrl),
    `ifdef USE_BP
    .bp_hit (bp_hit),
    .pc_cp (pc_fet_cp),
    `endif
    .spec (spec), // tied to 0 when BP is not used
    .move_past_dec_exe_dc_stall (move_past_dec_exe_dc_stall)
);

// from MEM stage
arch_width_t e_writeback_mem;
// from WBK stage
arch_width_t writeback;

// reg file
pipeline_if_typed #(.T(rf_addr_t)) rd_addr ();
pipeline_if_s rd_we ();
rf_addr_t rs1_addr_dec, rs2_addr_dec;
arch_width_t rs1_data_dec, rs2_data_dec;

assign rs1_addr_dec = get_rs1(inst.dec, decoded.has_reg.rs1);
assign rs2_addr_dec = get_rs2(inst.dec, decoded.has_reg.rs2);
assign rd_addr.dec = get_rd(inst.dec, decoded.has_reg.rd);

// imm gen
logic [24:0] imm_gen_in;
arch_width_t imm_gen_out_dec;
assign imm_gen_in = inst.dec[31:7];

ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk (clk),
    // inputs
    .we (rd_we.wbk),
    .addr_a (rs1_addr_dec),
    .addr_b (rs2_addr_dec),
    .addr_d (rd_addr.wbk),
    .data_d (writeback),
    // outputs
    .data_a (rs1_data_dec),
    .data_b (rs2_data_dec)
);

ama_riscv_imm_gen ama_riscv_imm_gen_i(
    .clk (clk),
    .rst (rst),
    // inputs
    .sel_in (decoded.ig_sel),
    .d_in (imm_gen_in),
    // outputs
    .d_out (imm_gen_out_dec)
);

`ifdef USE_BP
// all predictors use imm_gen right away, no BTB
assign bp_pc = decoded.itype.branch ? (pc.dec + imm_gen_out_dec) : 'h0;

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
logic load_inst_mem, store_inst_mem;

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    // inputs
    .store_inst_dec (decoded.itype.store),
    .branch_inst_dec (decoded.itype.branch),
    .store_inst_exe (decoded_exe.itype.store),
    .branch_inst_exe (decoded_exe.itype.branch),
    .load_inst_mem (load_inst_mem),
    .rs1_dec (rs1_addr_dec),
    .rs2_dec (rs2_addr_dec),
    .rs1_exe (rs1_addr_exe),
    .rs2_exe (rs2_addr_exe),
    .rd_mem (rd_addr.mem),
    .rd_wbk (rd_addr.wbk),
    .rd_we_mem (rd_we.mem),
    .rd_we_wbk (rd_we.wbk),
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
    .hazard_be (hazard_be)
);

//------------------------------------------------------------------------------
// Pipeline FF DEC/EXE
arch_width_t rs1_dec_be_fwd, rs2_dec_be_fwd;
assign rs1_dec_be_fwd =
    (fwd_be_rs1_dec == FWD_BE_EWBK) ? e_writeback_mem : writeback;
assign rs2_dec_be_fwd =
    (fwd_be_rs2_dec == FWD_BE_EWBK) ? e_writeback_mem : writeback;

arch_width_t rs1_data_fwd, rs2_data_fwd;
assign rs1_data_fwd = rf_a_sel_fwd ? rs1_dec_be_fwd : rs1_data_dec;
assign rs2_data_fwd = rf_b_sel_fwd ? rs2_dec_be_fwd : rs2_data_dec;

logic en_dec_exe;
assign en_dec_exe =
    ((!dc_stalled) || move_past_dec_exe_dc_stall) && (!hazard_be.to_exe);

stage_ctrl_t ctrl_dec_exe;
assign ctrl_dec_exe = '{
    flush: flush.dec,
    en: en_dec_exe,
    bubble: (fe_ctrl.bubble_dec || hazard_be.to_dec)
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
assign rs1_exe_be_fwd =
    (fwd_be_rs1_exe == FWD_BE_EWBK) ? e_writeback_mem : writeback;
assign rs2_exe_be_fwd =
    (fwd_be_rs2_exe == FWD_BE_EWBK) ? e_writeback_mem : writeback;

// branch compare & resolution
arch_width_t bc_a, bcs_b;
assign bc_a = bc_a_sel_fwd_exe ? rs1_exe_be_fwd : rs1_data_exe;
assign bcs_b = bcs_b_sel_fwd_exe ? rs2_exe_be_fwd : rs2_data_exe;

logic bc_a_eq_b, bc_a_lt_b;
assign bc_a_eq_b =
    (decoded_exe.bc_uns) ? (bc_a == bcs_b) : ($signed(bc_a) == $signed(bcs_b));
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
    alu_in_a = 'h0;
    unique case (alu_a_sel_fwd)
        ALU_A_SEL_RS1: alu_in_a = rs1_data_exe;
        ALU_A_SEL_PC: alu_in_a = pc.exe;
        ALU_A_SEL_FWD: alu_in_a = rs1_exe_be_fwd;
    endcase
end

always_comb begin
    alu_in_b = 'h0;
    unique case (alu_b_sel_fwd)
        ALU_B_SEL_RS2: alu_in_b = rs2_data_exe;
        ALU_B_SEL_IMM: alu_in_b = imm_gen_out_exe;
        ALU_B_SEL_FWD: alu_in_b = rs2_exe_be_fwd;
    endcase
end

ama_riscv_alu ama_riscv_alu_i (
    .op (decoded_exe.alu_op), .a (alu_in_a), .b (alu_in_b), .s (alu_out_exe)
);

arch_width_t mult_out_exe, arith_out_exe;
ama_riscv_mult ama_riscv_mult_i (
    .op (decoded_exe.mult_op), .a (alu_in_a), .b (alu_in_b), .p (mult_out_exe)
);

assign arith_out_exe = decoded_exe.itype.mult ? mult_out_exe : alu_out_exe;

// CSR
csr_t csr; // regs
csr_addr_t csr_addr;
logic [4:0] csr_imm5;
arch_width_t csr_din_imm, csr_wr_data_source, csr_wr_data;
assign csr_imm5 = inst.exe[19:15];
assign csr_din_imm = {27'h0, csr_imm5}; // zero-extend
assign csr_wr_data_source = decoded_exe.csr_ctrl.ui ? csr_din_imm : alu_in_a;
assign csr_addr = csr_addr_t'(inst.exe[31:20] & {12{decoded_exe.csr_ctrl.en}});

// csr read
arch_width_t csr_data_exe;
always_comb begin
    csr_data_exe = 'h0;
    if (decoded_exe.csr_ctrl.en) begin
        case (csr_addr)
            CSR_TOHOST: csr_data_exe = csr.tohost;
            CSR_MCYCLE: csr_data_exe = csr.mcycle.r[CSR_LOW];
            CSR_MCYCLEH: csr_data_exe = csr.mcycle.r[CSR_HIGH];
            CSR_MINSTRET: csr_data_exe = csr.minstret.r[CSR_LOW];
            CSR_MINSTRETH: csr_data_exe = csr.minstret.r[CSR_HIGH];
            CSR_MSCRATCH: csr_data_exe = csr.mscratch;
            CSR_TIME: csr_data_exe = csr.mtime.r[CSR_LOW];
            CSR_TIMEH: csr_data_exe = csr.mtime.r[CSR_HIGH];
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    csr_wr_data = 'h0;
    case(decoded_exe.csr_ctrl.op)
        CSR_OP_ASSIGN: csr_wr_data = csr_wr_data_source;
        CSR_OP_SET_BITS: csr_wr_data = csr_data_exe | csr_wr_data_source;
        CSR_OP_CLR_BITS: csr_wr_data = csr_data_exe & ~csr_wr_data_source;
        default: ;
    endcase
end

// tohost/mscratch
always_ff @(posedge clk) begin
    if (rst) begin
        csr.tohost <= 'h0;
        csr.mscratch <= 'h0;
    end else if (decoded_exe.csr_ctrl.we) begin
        case (csr_addr)
            CSR_TOHOST: csr.tohost <= csr_wr_data;
            CSR_MSCRATCH: csr.mscratch <= csr_wr_data;
            default: ;
        endcase
    end
end

// mcycle
logic csr_addr_match_mcycle, csr_addr_match_mcycle_l;
assign csr_addr_match_mcycle_l = (csr_addr == CSR_MCYCLE);
assign csr_addr_match_mcycle =
    csr_addr_match_mcycle_l || (csr_addr == CSR_MCYCLEH);

always_ff @(posedge clk) begin
    if (rst) begin
        csr.mcycle <= 'h0;
    end else if (decoded_exe.csr_ctrl.we && csr_addr_match_mcycle) begin
        if (csr_addr_match_mcycle_l) csr.mcycle.r[CSR_LOW] <= csr_wr_data;
        else csr.mcycle.r[CSR_HIGH] <= csr_wr_data;
    end else begin
        csr.mcycle <= csr.mcycle + 'h1;
    end
end

// minstret
logic inst_to_be_retired; // from retire pipeline
logic csr_addr_match_minstret, csr_addr_match_minstret_l;
assign csr_addr_match_minstret_l = (csr_addr == CSR_MINSTRET);
assign csr_addr_match_minstret =
    csr_addr_match_minstret_l || (csr_addr == CSR_MINSTRETH);

always_ff @(posedge clk) begin
    if (rst) begin
        csr.minstret <= 'h0;
    end else if (decoded_exe.csr_ctrl.we && csr_addr_match_minstret) begin
        if (csr_addr_match_minstret_l) csr.minstret.r[CSR_LOW] <= csr_wr_data;
        else csr.minstret.r[CSR_HIGH] <= csr_wr_data;
    end else begin
        csr.minstret <= csr.minstret + inst_to_be_retired;
    end
end

// mtime
logic tick_us;
logic [CNT_WIDTH-1:0] cnt_us; // 1 microsecond cnt
always_ff @(posedge clk) begin
    if (rst) begin
        cnt_us <= 'h0;
        tick_us <= 1'b0;
    end else if (cnt_us == (CLOCKS_PER_US - 1)) begin
        cnt_us <= 'h0;
        tick_us <= 1'b1;
    end else begin
        cnt_us <= cnt_us + 'h1;
        tick_us <= 1'b0;
    end
end

`DFF_CI_RI_RVI((csr.mtime + tick_us), csr.mtime)

// memory map
logic map_dmem_exe, map_uart_exe;
assign map_dmem_exe = (alu_out_exe[19:16] == `DMEM_RANGE);
assign map_uart_exe = (alu_out_exe[19:16] == `MMIO_RANGE);

// DMEM
dmem_dtype_t dmem_dtype, dmem_dtype_mem;
assign dmem_dtype = dmem_dtype_t'(get_fn3(inst.exe));
assign dmem_req.valid =
    map_dmem_exe && decoded_exe.dmem_en && (!dc_stalled) && (!hazard_be.to_exe);
assign dmem_req.wdata = bcs_b;
assign dmem_req.addr = alu_out_exe[15:0];
assign dmem_req.dtype = dmem_dtype;
assign dmem_req.rtype = decoded_exe.itype.store ? DMEM_WRITE : DMEM_READ;
assign dc_stalled = !dmem_req.ready;

// UART
logic uart_en, uart_we;
uart_addr_t uart_addr;
assign uart_en = map_uart_exe && decoded_exe.dmem_en;
assign uart_we = uart_en && decoded_exe.itype.store;
assign uart_addr = uart_addr_t'(alu_out_exe[4:2]);

// uart sync write
always_ff @(posedge clk) begin
    if (rst) begin
        uart_send_req.data <= 'h0;
        uart_send_req.valid <= 'b0;
    end else begin
        if (uart_we) begin
            case (uart_addr)
                UART_TX: begin
                    uart_send_req.data <= bcs_b[7:0];
                    uart_send_req.valid <= 1'b1;
                end
                default: ;
            endcase
        end else begin
            uart_send_req.data <= 'h0;
            uart_send_req.valid <= 'b0;
        end
    end
end

// uart sync read
uart_ctrl_t uart_ctrl_in, uart_ctrl;
assign uart_ctrl_in =
    '{rx_valid: uart_recv_rsp.valid, tx_ready: uart_send_req.ready};
`DFF_CI_RI_RV('{0, 0}, uart_ctrl_in, uart_ctrl)

arch_width_t uart_read;
always_ff @(posedge clk) begin
    if (rst) begin
        uart_read <= 'h0;
        uart_recv_rsp.ready <= 1'b0;
    end else if (uart_en) begin
        case (uart_addr)
            UART_CTRL: begin
                uart_read <= {30'd0, uart_ctrl};
                uart_recv_rsp.ready <= 1'b1;
            end
            UART_RX: begin
                if (dmem_dtype == DMEM_DTYPE_BYTE) begin
                    uart_read <=
                        {{24{uart_recv_rsp.data[7]}}, uart_recv_rsp.data};
                end else begin // DMEM_DTYPE_UBYTE
                    uart_read <= {24'd0, uart_recv_rsp.data};
                end
                uart_recv_rsp.ready <= 1'b1;
            end
            default: begin
                uart_read <= 32'd0;
                uart_recv_rsp.ready <= 1'b0;
            end
        endcase
    end else begin
        uart_read <= 'h0;
        uart_recv_rsp.ready <= 1'b0;
    end
end

//------------------------------------------------------------------------------
// Pipeline FF EXE/MEM
arch_width_t pc_mem_inc4, arith_out_mem, csr_data_mem; // (early) writeback opts
stage_ctrl_t ctrl_exe_mem;
logic map_uart_mem;

pipeline_if_typed #(.T(wb_sel_t)) wb_sel ();
assign wb_sel.exe = decoded_exe.wb_sel;
assign rd_we.exe = decoded_exe.rd_we;
assign ctrl_exe_mem = '{
    flush: flush.exe,
    en: (!dc_stalled),
    bubble: (!ctrl_dec_exe.en)
};

`STAGE(ctrl_exe_mem, pc.exe, pc.mem, 'h0)
`STAGE(ctrl_exe_mem, pc.exe + 'd4, pc_mem_inc4, 'h0)
`STAGE(ctrl_exe_mem, inst.exe, inst.mem, 'h0)
`STAGE(ctrl_exe_mem, arith_out_exe, arith_out_mem, 'h0)
`STAGE(ctrl_exe_mem, wb_sel.exe, wb_sel.mem, WB_SEL_ALU)
`STAGE(ctrl_exe_mem, rd_addr.exe, rd_addr.mem, RF_X0_ZERO)
`STAGE(ctrl_exe_mem, rd_we.exe, rd_we.mem, 'h0)
`STAGE(ctrl_exe_mem, csr_data_exe, csr_data_mem, 'h0)
`STAGE(ctrl_exe_mem, decoded_exe.itype.load, load_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, decoded_exe.itype.store, store_inst_mem, 'h0)
`STAGE(ctrl_exe_mem, map_uart_exe, map_uart_mem, 'h0)

`DFF_CI_RI_RVI(dc_stalled || hazard_be.to_dec || hazard_be.to_exe, be_stalled_d)

//------------------------------------------------------------------------------
// MEM stage
always_comb begin
    e_writeback_mem = 'h0;
    case (wb_sel.mem)
        WB_SEL_ALU: e_writeback_mem = arith_out_mem;
        WB_SEL_INC4: e_writeback_mem = pc_mem_inc4;
        WB_SEL_CSR: e_writeback_mem = csr_data_mem;
    endcase
end

arch_width_t dmem_out_mem;
assign dmem_out_mem = map_uart_mem ? uart_read : dmem_rsp.data;

//------------------------------------------------------------------------------
// Pipeline FF MEM/WBK
arch_width_t dmem_out_wbk;
arch_width_t e_writeback_wbk;
stage_ctrl_t ctrl_mem_wbk;

assign ctrl_mem_wbk = '{
    flush: flush.exe,
    en: 1'b1,
    bubble: (!ctrl_exe_mem.en)
};

`STAGE(ctrl_mem_wbk, inst.mem, inst.wbk, 'h0)
`STAGE(ctrl_mem_wbk, pc.mem, pc.wbk, 'h0)
`STAGE(ctrl_mem_wbk, dmem_out_mem, dmem_out_wbk, 'h0)
`STAGE(ctrl_mem_wbk, e_writeback_mem, e_writeback_wbk, 'h0)
`STAGE(ctrl_mem_wbk, rd_addr.mem, rd_addr.wbk, RF_X0_ZERO)
`STAGE(ctrl_mem_wbk, rd_we.mem, rd_we.wbk, 'h0)
`STAGE(ctrl_mem_wbk, wb_sel.mem, wb_sel.wbk, WB_SEL_ALU)

//------------------------------------------------------------------------------
// WBK stage
assign writeback = (wb_sel.wbk == WB_SEL_DMEM) ? dmem_out_wbk : e_writeback_wbk;
assign inst_to_be_retired = (pc.wbk != 'h0) && (!flush.wbk);

//------------------------------------------------------------------------------
// retire
stage_ctrl_t ctrl_wbk_ret;
assign ctrl_wbk_ret = '{flush: flush.wbk, en: 1'b1, bubble: (!ctrl_mem_wbk.en)};

inst_width_t inst_ret;
arch_width_t pc_ret;
`STAGE(ctrl_wbk_ret, inst.wbk, inst_ret, 'h0)
`STAGE(ctrl_wbk_ret, pc.wbk, pc_ret, 'h0)

assign inst_retired = (pc_ret != 'h0);

//------------------------------------------------------------------------------
// pipeline control

// Pipeline FFs flush
assign flush.fet = 1'b0;
assign flush.dec = reset_seq[0];
assign flush.exe = reset_seq[1];
assign flush.mem = reset_seq[2];
assign flush.wbk = reset_seq[3];

endmodule
