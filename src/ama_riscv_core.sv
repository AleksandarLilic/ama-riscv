`include "ama_riscv_defines.svh"

module ama_riscv_core (
    input  logic clk,
    input  logic rst,
    rv_if.TX     imem_req,
    rv_if.RX     imem_rsp,
    rv_if_dc.TX  dmem_req,
    rv_if.RX     dmem_rsp,
    rv_if.TX     uart_send_req,
    rv_if.RX     uart_recv_rsp,
    output logic inst_retired
);

pipeline_if #(.W(INST_WIDTH)) inst ();
pipeline_if #(.W(ARCH_WIDTH)) pc ();
pipeline_if #(.W(1)) flush ();
pipeline_if_typed #(.T(rf_addr_t)) rd_addr ();

// Reset sequence
logic [2:0] reset_seq;
`DFF_CI_RI_RV(3'b111, {reset_seq[1:0], 1'b0}, reset_seq)

// Pipeline control inputs
decoder_t decoded;
decoder_t decoded_exe;
fe_ctrl_t fe_ctrl;
logic move_past_dec_stall;

// from EXE stage
logic branch_taken;

// from DEC stage
alu_a_sel_t alu_a_sel_fwd_dec;
alu_b_sel_t alu_b_sel_fwd_dec;
logic bc_a_sel_fwd_dec;
logic bcs_b_sel_fwd_dec;
logic rf_a_sel_fwd;
logic rf_b_sel_fwd;

// from EXE stage
logic dc_stalled, dc_stalled_d;
logic load_inst_mem;
logic store_inst_mem;
logic load_hazard_stall;

// MEM stage
logic rd_we_mem;

//------------------------------------------------------------------------------
// FET Stage
arch_width_t pc_mux_out;
arch_width_t pc_inc4;
arch_width_t alu_out;

always_comb begin
    case (fe_ctrl.pc_sel)
        PC_SEL_INC4: pc_mux_out = pc_inc4;
        PC_SEL_ALU: pc_mux_out = alu_out;
        //PC_SEL_BP: pc_mux_out =  bp_out;
        PC_SEL_PC: pc_mux_out = pc.fet;
        default: pc_mux_out = pc_inc4;
    endcase
end

`DFF_CI_RI_RV_EN(`RESET_VECTOR, fe_ctrl.pc_we, pc_mux_out, pc.fet)
assign pc_inc4 = pc.fet + 'd4;
assign imem_req.data = pc_mux_out[15:2];

//------------------------------------------------------------------------------
// DEC Stage

// Bubble up?
inst_width_t inst_dec_d;
arch_width_t pc_dec_d;
always_comb begin
    if (dc_stalled_d) begin
        if (imem_rsp.valid) begin // V2.1
            // new inst arrived on miss before BE stalled
            // but d$ is still stalling
            inst.dec = imem_rsp.data;
            pc.dec = pc.fet;
        end else begin
            inst.dec = inst_dec_d;
            pc.dec = pc_dec_d;
        end
    end else if (fe_ctrl.bubble_dec) begin
        inst.dec = `NOP;
        pc.dec = 'h0;
    end else begin
        inst.dec = imem_rsp.data;
        pc.dec = pc.fet;
    end
end

`DFF_CI_RI_RVI(inst.dec, inst_dec_d) // keep old value, i$ won't respond again
`DFF_CI_RI_RVI(pc.dec, pc_dec_d)

fe_ctrl_t decoded_fe_ctrl;
ama_riscv_decoder ama_riscv_decoder_i (
    .clk (clk),
    .rst (rst),
    // inputs
    .inst (inst.IN),
    // outputs
    .decoded (decoded),
    .fe_ctrl (decoded_fe_ctrl)
);

ama_riscv_fe_ctrl ama_riscv_fe_ctrl_i (
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req),
    .imem_rsp (imem_rsp),
    // inputs
    .pc_dec (pc.dec),
    .pc_exe (pc.exe),
    .branch_inst_dec (decoded.branch_inst),
    .jump_inst_dec (decoded.jump_inst),
    .branch_inst_exe (decoded_exe.branch_inst),
    .jump_inst_exe (decoded_exe.jump_inst),
    .branch_taken (branch_taken),
    .decoded_fe_ctrl (decoded_fe_ctrl),
    .load_hazard_stall (load_hazard_stall),
    .dc_stalled (dc_stalled),
    // outputs
    .fe_ctrl (fe_ctrl),
    .move_past_dec_stall (move_past_dec_stall)
);

// from MEM stage
arch_width_t writeback;
// reg file
rf_addr_t rs1_addr_dec;
rf_addr_t rs2_addr_dec;
rf_addr_t rs1_addr_exe;
rf_addr_t rs2_addr_exe;
arch_width_t rd_data;
arch_width_t rs1_data_dec;
arch_width_t rs2_data_dec;
assign rs1_addr_dec = get_rs1(inst.dec);
assign rs2_addr_dec = get_rs2(inst.dec);
assign rd_addr.dec = get_rd(inst.dec);
assign rd_data = writeback;
// imm gen
logic [24:0] imm_gen_in;
arch_width_t imm_gen_out_dec;
assign imm_gen_in = inst.dec[31:7];

ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk (clk),
    // inputs
    .we (rd_we_mem && !dc_stalled),
    .addr_a (rs1_addr_dec),
    .addr_b (rs2_addr_dec),
    .addr_d (rd_addr.mem),
    .data_d (rd_data),
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

logic bc_a_sel_fwd_exe;
logic bcs_b_sel_fwd_exe;
alu_a_sel_t alu_a_sel_fwd_exe;
alu_b_sel_t alu_b_sel_fwd_exe;

ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    // inputs
    .store_inst_dec (decoded.store_inst),
    .branch_inst_dec (decoded.branch_inst),
    .store_inst_exe (decoded_exe.store_inst),
    .branch_inst_exe (decoded_exe.branch_inst),
    .load_inst_mem (load_inst_mem),
    .dc_stalled (dc_stalled),
    .rs1_dec (rs1_addr_dec),
    .rs2_dec (rs2_addr_dec),
    .rs1_exe (rs1_addr_exe),
    .rs2_exe (rs2_addr_exe),
    .rd_mem (rd_addr.mem),
    .rd_we_mem (rd_we_mem),
    .alu_a_sel_dec (decoded.alu_a_sel),
    .alu_b_sel_dec (decoded.alu_b_sel),
    .alu_a_sel_exe (decoded_exe.alu_a_sel),
    .alu_b_sel_exe (decoded_exe.alu_b_sel),
    // outputs
    .alu_a_sel_fwd (alu_a_sel_fwd_exe),
    .alu_b_sel_fwd (alu_b_sel_fwd_exe),
    .bc_a_sel_fwd (bc_a_sel_fwd_exe),
    .bcs_b_sel_fwd (bcs_b_sel_fwd_exe),
    .rf_a_sel_fwd (rf_a_sel_fwd),
    .rf_b_sel_fwd (rf_b_sel_fwd),
    .load_hazard_stall (load_hazard_stall)
);

//------------------------------------------------------------------------------
// Pipeline FF DEC/EXE
// Signals
arch_width_t rs1_data_exe;
arch_width_t rs2_data_exe;
arch_width_t imm_gen_out_exe;

arch_width_t rs1_data_fwd;
arch_width_t rs2_data_fwd;
assign rs1_data_fwd = rf_a_sel_fwd ? writeback : rs1_data_dec;
assign rs2_data_fwd = rf_b_sel_fwd ? writeback : rs2_data_dec;

logic dec_en;
assign dec_en = !dc_stalled || move_past_dec_stall;

`STAGE_EN(flush.dec, dec_en, pc.dec, pc.exe)
`STAGE_EN(flush.dec, dec_en, inst.dec, inst.exe)
`STAGE_EN_RV(flush.dec, dec_en, RF_X0_ZERO, rd_addr.dec, rd_addr.exe)
`STAGE_EN_RV(flush.dec, dec_en, RF_X0_ZERO, rs1_addr_dec, rs1_addr_exe)
`STAGE_EN_RV(flush.dec, dec_en, RF_X0_ZERO, rs2_addr_dec, rs2_addr_exe)
`STAGE_EN(flush.dec, dec_en, rs1_data_fwd, rs1_data_exe)
`STAGE_EN(flush.dec, dec_en, rs2_data_fwd, rs2_data_exe)
`STAGE_EN(flush.dec, dec_en, imm_gen_out_dec, imm_gen_out_exe)
`STAGE_EN_RV(flush.dec, dec_en, `DECODER_RST_VAL, decoded, decoded_exe)

//------------------------------------------------------------------------------
// EXE stage

// branch compare & resolution
arch_width_t bc_a;
arch_width_t bcs_b;
logic bc_a_eq_b;
logic bc_a_lt_b;
assign bc_a = bc_a_sel_fwd_exe ? writeback : rs1_data_exe;
assign bcs_b = bcs_b_sel_fwd_exe ? writeback : rs2_data_exe;
assign bc_a_eq_b =
    (decoded_exe.bc_uns) ? (bc_a == bcs_b) : ($signed(bc_a) == $signed(bcs_b));
assign bc_a_lt_b =
    (decoded_exe.bc_uns) ? (bc_a < bcs_b) : ($signed(bc_a) < $signed(bcs_b));

branch_sel_t branch_sel_exe;
assign branch_sel_exe = get_branch_sel(inst.exe);

always_comb begin
    case (branch_sel_exe)
        BRANCH_SEL_BEQ: branch_taken = bc_a_eq_b;
        BRANCH_SEL_BNE: branch_taken = !bc_a_eq_b;
        BRANCH_SEL_BLT: branch_taken = bc_a_lt_b;
        BRANCH_SEL_BGE: branch_taken = bc_a_eq_b || !bc_a_lt_b;
        default: branch_taken = 1'b0;
    endcase
end

// ALU
arch_width_t alu_in_a;
arch_width_t alu_in_b;
assign alu_in_a =
    (alu_a_sel_fwd_exe == ALU_A_SEL_RS1) ? rs1_data_exe :
    (alu_a_sel_fwd_exe == ALU_A_SEL_PC) ? pc.exe :
 /* (alu_a_sel_fwd_exe == ALU_A_SEL_FWD_ALU) ? */ writeback;
assign alu_in_b =
    (alu_b_sel_fwd_exe == ALU_B_SEL_RS2) ? rs2_data_exe :
    (alu_b_sel_fwd_exe == ALU_B_SEL_IMM) ? imm_gen_out_exe :
 /* (alu_b_sel_fwd_exe == ALU_B_SEL_FWD_ALU) ? */ writeback;

ama_riscv_alu ama_riscv_alu_i (
    // inputs
    .op_sel     (decoded_exe.alu_op_sel),
    .in_a       (alu_in_a),
    .in_b       (alu_in_b),
    // outputs
    .out_s      (alu_out)
);

// CSR
arch_width_t csr_tohost;
arch_width_t csr_mscratch;
arch_width_t csr_data_exe;
logic [11:0] csr_addr;
logic [ 4:0] csr_imm5;
arch_width_t csr_din_imm;
arch_width_t csr_wr_data_source;
arch_width_t csr_wr_data;
assign csr_imm5 = rs1_addr_exe;
assign csr_din_imm = {27'h0, csr_imm5}; // Immediate Zero-Extend
assign csr_wr_data_source = decoded_exe.csr_ctrl.ui ? csr_din_imm : alu_in_a;
assign csr_addr = inst.exe[31:20];

// csr read
always_comb begin
    csr_data_exe = 'h0;
    if (decoded_exe.csr_ctrl.en) begin
        case (csr_addr)
            `CSR_TOHOST: csr_data_exe = csr_tohost;
            `CSR_MSCRATCH: csr_data_exe = csr_mscratch;
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    csr_wr_data = 'h0;
    case(decoded_exe.csr_ctrl.op_sel)
        CSR_OP_SEL_ASSIGN: csr_wr_data = csr_wr_data_source;
        CSR_OP_SEL_SET_BITS: csr_wr_data = csr_data_exe | csr_wr_data_source;
        CSR_OP_SEL_CLR_BITS: csr_wr_data = csr_data_exe & ~csr_wr_data_source;
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        csr_tohost <= 'h0;
        csr_mscratch <= 'h0;
    end else if (decoded_exe.csr_ctrl.we) begin
        case (csr_addr)
            `CSR_TOHOST: csr_tohost <= csr_wr_data;
            `CSR_MSCRATCH: csr_mscratch <= csr_wr_data;
            default: ;
        endcase
    end
end

//------------------------------------------------------------------------------
// DMEM
dmem_dtype_t dmem_dtype, dmem_dtype_mem;
assign dmem_dtype = dmem_dtype_t'(get_fn3(inst.exe));

assign dmem_req.valid =
    (alu_out[19:16] == `DMEM_RANGE) && decoded_exe.dmem_en && (!dc_stalled);
assign dmem_req.wdata = bcs_b;
assign dmem_req.addr = alu_out[15:0];
assign dmem_req.dtype = dmem_dtype;
assign dmem_req.rtype = decoded_exe.store_inst ? DMEM_WRITE : DMEM_READ;
assign dc_stalled = !dmem_req.ready;

// UART
uart_addr_t uart_addr;
assign uart_addr = uart_addr_t'(alu_out[4:2]);
logic uart_en;
logic uart_we;
assign uart_en = (alu_out[19:16] == `MMIO_RANGE) && decoded_exe.dmem_en;
assign uart_we = uart_en && decoded_exe.store_inst;

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
arch_width_t pc_mem_inc4;
arch_width_t alu_out_mem;
arch_width_t csr_data_mem;
wb_sel_t wb_sel_mem;

`STAGE_EN(flush.exe, !dc_stalled, pc.exe, pc.mem)
`STAGE_EN(flush.exe, !dc_stalled, pc.exe + 'd4, pc_mem_inc4)
`STAGE_EN(flush.exe, !dc_stalled, inst.exe, inst.mem)
`STAGE_EN(flush.exe, !dc_stalled, alu_out, alu_out_mem)
`STAGE_EN_RV(flush.exe, !dc_stalled, RF_X0_ZERO, rd_addr.exe, rd_addr.mem)
`STAGE_EN_RV(flush.exe, !dc_stalled, WB_SEL_ALU, decoded_exe.wb_sel, wb_sel_mem)
`STAGE_EN(flush.exe, !dc_stalled, decoded_exe.rd_we, rd_we_mem)
`STAGE_EN(flush.exe, !dc_stalled, csr_data_exe, csr_data_mem)
`STAGE_EN(flush.exe, !dc_stalled, decoded_exe.load_inst, load_inst_mem)
`STAGE_EN(flush.exe, !dc_stalled, decoded_exe.store_inst, store_inst_mem)

`DFF_CI_RI_RVI(dc_stalled, dc_stalled_d)

//------------------------------------------------------------------------------
// MEM/Writeback
arch_width_t dmem_data;
assign dmem_data =
    (alu_out_mem[19:16] == `MMIO_RANGE) ? uart_read : dmem_rsp.data;

assign writeback = (wb_sel_mem == WB_SEL_DMEM) ? dmem_data :
                   (wb_sel_mem == WB_SEL_ALU ) ? alu_out_mem :
                   (wb_sel_mem == WB_SEL_INC4) ? pc_mem_inc4 :
                /* (wb_sel_mem == WB_SEL_CSR) ? */ csr_data_mem;

//------------------------------------------------------------------------------
// Pipeline FF MEM/WB
`STAGE_BB(flush.mem, dc_stalled, `NOP, inst.mem, inst.wbk)
`STAGE_BB(flush.mem, dc_stalled, 'h0, pc.mem, pc.wbk)
assign inst_retired = (pc.wbk != 'h0);

//------------------------------------------------------------------------------
// pipeline control

// Pipeline FFs flush
assign flush.fet = 1'b0;
assign flush.dec = reset_seq[0]; // TODO: eventually also BP
assign flush.exe = reset_seq[1];
assign flush.mem = reset_seq[2];
assign flush.wbk = 1'b0;

endmodule
