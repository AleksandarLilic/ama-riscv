`include "ama_riscv_defines.svh"

module ama_riscv_core (
    input  logic        clk,
    input  logic        rst,
    // imem
    rv_if.TX            imem_req,
    rv_if.RX            imem_rsp,
    // dmem
    output logic [ 3:0] dmem_we,
    rv_if_da.TX         dmem_req,
    rv_if.RX            dmem_rsp,
    // mmio in
    input  logic [31:0] mmio_instr_cnt,
    input  logic [31:0] mmio_cycle_cnt,
    input  logic [ 7:0] mmio_uart_data_out,
    input  logic        mmio_data_out_valid,
    input  logic        mmio_data_in_ready,
    // mmio out
    output logic        store_to_uart,
    output logic        load_from_uart,
    output logic        inst_wb_nop_or_clear,
    output logic        mmio_reset_cnt,
    output logic [ 7:0] mmio_uart_data_in
);

//------------------------------------------------------------------------------
// Signals

pipeline_if #(.W(32)) inst ();
pipeline_if #(.W(32)) pc ();
pipeline_if #(.W(1)) flush ();
pipeline_if_typed #(.T(rf_addr_t)) rd_addr ();
pipeline_if #(.W(1)) rd_we ();

// Reset sequence
logic [ 2:0] reset_seq;
`DFF_CI_RI_RV(3'b111, {reset_seq[1:0], 1'b0}, reset_seq)

// Pipeline control inputs
decoder_t    decoded;
fe_ctrl_t    fe_ctrl;

// Signals - EXE stage
logic store_inst_exe;
logic load_inst_exe;
logic branch_inst_exe;
logic jump_inst_exe;
logic branch_taken;
// from datapath
logic        bc_a_eq_b;
logic        bc_a_lt_b;
logic [ 1:0] store_mask_offset;

// Signals - DEC stage
alu_a_sel_t  alu_a_sel_fwd_dec;
alu_b_sel_t  alu_b_sel_fwd_dec;
logic        bc_a_sel_fwd_dec;
logic        bcs_b_sel_fwd_dec;
logic        rf_a_sel_fwd_dec;
logic        rf_b_sel_fwd_dec;
pipeline_if_typed #(.T(wb_sel_t)) wb_sel ();

// Signals - EXE stage
logic [ 3:0] dmem_we_exe;

//------------------------------------------------------------------------------
// FET Stage
logic [31:0] pc_mux_out;
logic [31:0] pc_inc4;
logic [31:0] alu_out;

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
assign pc_inc4 = pc.fet + 32'd4;

// IMEM interface
assign imem_req.data = pc_mux_out[15:2];

//------------------------------------------------------------------------------
// DEC Stage

// Bubble up?
assign inst.dec = fe_ctrl.bubble_dec ? `NOP : imem_rsp.data;
assign pc.dec = fe_ctrl.bubble_dec ? 'h0 : pc.fet;

ama_riscv_decoder ama_riscv_decoder_i (
    .clk (clk),
    .rst (rst),
    // inputs
    .inst (inst.IN),
    // outputs
    .decoded (decoded)
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
    .branch_inst_exe (branch_inst_exe),
    .jump_inst_exe (jump_inst_exe),
    .branch_taken (branch_taken),
    .decoded_fe_ctrl (decoded.fe_ctrl),
    // outputs
    .fe_ctrl (fe_ctrl)
);

assign wb_sel.dec = decoded.wb_sel;
assign rd_we.dec = decoded.rd_we;
// Signals - MEM stage
logic [31:0] writeback;

// reg file
rf_addr_t rs1_addr_dec;
rf_addr_t rs2_addr_dec;
logic [11:0] csr_addr;
logic [31:0] rd_data;
logic [31:0] rs1_data_dec;
logic [31:0] rs2_data_dec;
assign rs1_addr_dec = get_rs1(inst.dec);
assign rs2_addr_dec = get_rs2(inst.dec);
assign rd_addr.dec = get_rd(inst.dec);
assign csr_addr = inst.dec[31:20];
assign rd_data = writeback;
// imm gen
logic [24:0] imm_gen_in;
logic [31:0] imm_gen_out_dec;
assign imm_gen_in = inst.dec[31:7];

ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk (clk),
    // inputs
    .we (rd_we.mem),
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

 ama_riscv_operand_forwarding ama_riscv_operand_forwarding_i (
    // inputs
    .rd_we (rd_we.IN),
    .store_inst_dec (decoded.store_inst),
    .branch_inst_dec (decoded.branch_inst),
    .rs1_dec (rs1_addr_dec),
    .rs2_dec (rs2_addr_dec),
    .rd_exe (rd_addr.exe),
    .rd_mem (rd_addr.mem),
    .alu_a_sel_dec (decoded.alu_a_sel),
    .alu_b_sel_dec (decoded.alu_b_sel),
    // outputs
    .alu_a_sel_fwd (alu_a_sel_fwd_dec),
    .alu_b_sel_fwd (alu_b_sel_fwd_dec),
    .bc_a_sel_fwd (bc_a_sel_fwd_dec),
    .bcs_b_sel_fwd (bcs_b_sel_fwd_dec),
    .rf_a_sel_fwd (rf_a_sel_fwd_dec),
    .rf_b_sel_fwd (rf_b_sel_fwd_dec)
);

//------------------------------------------------------------------------------
// Pipeline FF DEC/EXE
// Signals
logic [31:0] rs1_data_exe;
logic [31:0] rs2_data_exe;
logic [31:0] imm_gen_out_exe;
logic        bc_a_sel_fwd_exe;
logic        bcs_b_sel_fwd_exe;
logic        bc_uns_exe;
logic [ 1:0] alu_a_sel_fwd_exe;
logic [ 1:0] alu_b_sel_fwd_exe;
alu_op_t     alu_op_sel_exe;
logic        dmem_en_exe;
logic        load_sm_en_exe;
csr_ctrl_t   csr_ctrl_exe;
logic [11:0] csr_addr_exe;
logic [ 4:0] csr_imm5;

logic [31:0] rs1_data_fwd_dec;
logic [31:0] rs2_data_fwd_dec;
assign rs1_data_fwd_dec = rf_a_sel_fwd_dec ? writeback : rs1_data_dec;
assign rs2_data_fwd_dec = rf_b_sel_fwd_dec ? writeback : rs2_data_dec;

//`STAGE(flush.dec, pc.exe, pc.dec)
// don't propagate PC on bubble, rest is fine
`STAGE_EN(flush.dec, !fe_ctrl.bubble_dec, pc.dec, pc.exe)
`STAGE_RV(flush.dec, RF_X0_ZERO, rd_addr.dec, rd_addr.exe)
`STAGE(flush.dec, rs1_data_fwd_dec, rs1_data_exe)
`STAGE(flush.dec, rs2_data_fwd_dec, rs2_data_exe)
`STAGE(flush.dec, imm_gen_out_dec, imm_gen_out_exe)
`STAGE(flush.dec, inst.dec, inst.exe)
`STAGE(flush.dec, decoded.load_inst, load_inst_exe)
`STAGE(flush.dec, decoded.store_inst, store_inst_exe)
`STAGE(flush.dec, decoded.branch_inst, branch_inst_exe)
`STAGE(flush.dec, decoded.jump_inst, jump_inst_exe)
`STAGE(flush.dec, bc_a_sel_fwd_dec, bc_a_sel_fwd_exe)
`STAGE(flush.dec, bcs_b_sel_fwd_dec, bcs_b_sel_fwd_exe)
`STAGE(flush.dec, decoded.bc_uns, bc_uns_exe)
`STAGE(flush.dec, alu_a_sel_fwd_dec, alu_a_sel_fwd_exe)
`STAGE(flush.dec, alu_b_sel_fwd_dec, alu_b_sel_fwd_exe)
`STAGE_RV(flush.dec, ALU_OP_ADD, decoded.alu_op_sel, alu_op_sel_exe)
`STAGE(flush.dec, decoded.dmem_en, dmem_en_exe)
`STAGE(flush.dec, decoded.load_sm_en, load_sm_en_exe)
`STAGE_RV(flush.dec, WB_SEL_ALU, wb_sel.dec, wb_sel.exe)
`STAGE(flush.dec, rd_we.dec, rd_we.exe)
`STAGE(flush.dec, decoded.csr_ctrl, csr_ctrl_exe)
`STAGE(flush.dec, csr_addr, csr_addr_exe)
`STAGE(flush.dec, rs1_addr_dec, csr_imm5)

//------------------------------------------------------------------------------
// EXE stage

// branch compare & resolution
logic [31:0] bc_a;
logic [31:0] bcs_b;
assign bc_a = bc_a_sel_fwd_exe ? writeback : rs1_data_exe;
assign bcs_b = bcs_b_sel_fwd_exe ? writeback : rs2_data_exe;
assign bc_a_eq_b =
    (bc_uns_exe) ? (bc_a == bcs_b) : ($signed(bc_a) == $signed(bcs_b));
assign bc_a_lt_b =
    (bc_uns_exe) ? (bc_a < bcs_b) : ($signed(bc_a) < $signed(bcs_b));

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
logic [31:0] alu_in_a;
logic [31:0] alu_in_b;
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
    .op_sel     (alu_op_sel_exe),
    .in_a       (alu_in_a),
    .in_b       (alu_in_b),
    // outputs
    .out_s      (alu_out)
);

// CSR
logic [31:0] csr_tohost;
logic [31:0] csr_mscratch;
logic [31:0] csr_data_exe;
logic [31:0] csr_din_imm;
logic [31:0] csr_wr_data_source;
logic [31:0] csr_wr_data;
assign csr_din_imm = {27'h0, csr_imm5}; // Immediate Zero-Extend
assign csr_wr_data_source = csr_ctrl_exe.ui ? csr_din_imm : alu_in_a;

// csr read
always_comb begin
    csr_data_exe = 32'h0;
    if (csr_ctrl_exe.en) begin
        case (csr_addr_exe)
            `CSR_TOHOST: csr_data_exe = csr_tohost;
            `CSR_MSCRATCH: csr_data_exe = csr_mscratch;
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    csr_wr_data = 32'h0;
    case(csr_ctrl_exe.op_sel)
        CSR_OP_SEL_ASSIGN: csr_wr_data = csr_wr_data_source;
        CSR_OP_SEL_SET_BITS: csr_wr_data = csr_data_exe | csr_wr_data_source;
        CSR_OP_SEL_CLR_BITS: csr_wr_data = csr_data_exe & ~csr_wr_data_source;
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        csr_tohost <= 32'h0;
        csr_mscratch <= 32'h0;
    end else if (csr_ctrl_exe.we) begin
        case (csr_addr_exe)
            `CSR_TOHOST: csr_tohost <= csr_wr_data;
            `CSR_MSCRATCH: csr_mscratch <= csr_wr_data;
            default: ;
        endcase
    end
end

//------------------------------------------------------------------------------
// Data Memory Space
// Comprised of DMEM and MM I/O
logic [ 4:0] store_byte_shift; // store_mask converted to byte shifts
logic [31:0] data_to_store; // shifts 0, 1, 2 or 3 bytes
assign store_mask_offset = alu_out[1:0];
assign store_byte_shift = store_mask_offset << 3;
assign data_to_store = bcs_b << store_byte_shift;

// MM I/O
logic [31:0] mmio_read_data;
logic [ 7:0] mmio_write_data;
logic [ 2:0] mmio_addr;
logic        mmio_en;
logic        mmio_we;
assign mmio_write_data = data_to_store[7:0]; // only byte writes to MMIO atm
assign mmio_addr = alu_out[ 4:2];
assign mmio_en = (alu_out[31:30] == `MMIO_RANGE) && dmem_en_exe;
assign mmio_we = {(alu_out[31:30] == `MMIO_RANGE)} & dmem_we_exe[0];
assign store_to_uart = (
    (store_inst_exe) && (mmio_addr == 3'd2) && (mmio_en) && (mmio_we)
);
assign load_from_uart = ((load_inst_exe) && (mmio_addr == 3'd1) && (mmio_en));

// mmio sync write
always_ff @(posedge clk) begin
    if (rst) begin
        mmio_uart_data_in <= 8'd0;
        mmio_reset_cnt <= 1'b0;
    end else begin
        if (mmio_en && mmio_we) begin
            case (mmio_addr)
                3'd2 : mmio_uart_data_in <= mmio_write_data[7:0];
                3'd4 : mmio_reset_cnt <= mmio_write_data[0];
                default: ;
            endcase
        end
    end
end

logic [ 1:0] mmio_ctrl;
assign mmio_ctrl = {mmio_data_out_valid, mmio_data_in_ready};
// mmio sync read
always_ff @(posedge clk) begin
    if (rst) begin
        mmio_read_data <= 32'd0;
    end else if (mmio_en) begin
        case (mmio_addr)
            3'd0: mmio_read_data <= {30'd0, mmio_ctrl};
            3'd1: mmio_read_data <= {24'd0, mmio_uart_data_out};
            3'd5: mmio_read_data <= mmio_cycle_cnt;
            3'd6: mmio_read_data <= mmio_instr_cnt;
            default: mmio_read_data <= 32'd0;
        endcase
    end
end

//------------------------------------------------------------------------------
// DMEM
logic [ 1:0] load_sm_offset_exe;
assign dmem_req.wdata = data_to_store;
assign dmem_req.addr = alu_out[15:2];
assign dmem_req.valid = (alu_out[31:30] == `DMEM_RANGE) && dmem_en_exe;
assign dmem_we = {4{(alu_out[31:30] == `DMEM_RANGE)}} & dmem_we_exe;
assign load_sm_offset_exe = store_mask_offset;
dmem_dtype_t dtype_exe;
assign dtype_exe = dmem_dtype_t'(get_fn3(inst.exe));

ama_riscv_store_mask ama_riscv_store_mask_i (
    .en (store_inst_exe),
    .offset (store_mask_offset),
    .dtype (dtype_exe),
    .mask (dmem_we_exe)
);

//------------------------------------------------------------------------------
// Pipeline FF EXE/MEM
logic [31:0] pc_mem_inc4;
logic [31:0] alu_out_mem;
logic [ 1:0] load_sm_offset_mem;
logic        load_sm_en_mem;
logic [31:0] csr_data_mem;

`STAGE(flush.exe, pc.exe, pc.mem)
`STAGE(flush.exe, pc.exe + 32'd4, pc_mem_inc4)
`STAGE(flush.exe, alu_out, alu_out_mem)
`STAGE(flush.exe, load_sm_offset_exe, load_sm_offset_mem)
`STAGE(flush.exe, inst.exe, inst.mem)
`STAGE_RV(flush.exe, RF_X0_ZERO, rd_addr.exe, rd_addr.mem)
`STAGE(flush.exe, load_sm_en_exe, load_sm_en_mem)
`STAGE_RV(flush.exe, WB_SEL_ALU, wb_sel.exe, wb_sel.mem)
`STAGE(flush.exe, rd_we.exe, rd_we.mem)
`STAGE(flush.exe, csr_data_exe, csr_data_mem)

//------------------------------------------------------------------------------
// MEM stage
// Load Shift & Mask
logic [31:0] load_sm_data_out;
logic [31:0] load_sm_data_in;
dmem_dtype_t load_sm_dtype;
assign load_sm_dtype = dmem_dtype_t'(get_fn3(inst.mem));
always_comb begin
    case (alu_out_mem[31:30])
        `DMEM_RANGE: load_sm_data_in = dmem_rsp.data;
        `MMIO_RANGE: load_sm_data_in = mmio_read_data;
        default: load_sm_data_in = 32'h0;
    endcase
end

ama_riscv_load_shift_mask ama_riscv_load_shift_mask_i (
    .clk (clk),
    .rst (rst),
    // inputs
    .en (load_sm_en_mem),
    .offset (load_sm_offset_mem),
    .dtype (load_sm_dtype),
    .data_in (load_sm_data_in),
    // outputs
    .data_out (load_sm_data_out)
);

//------------------------------------------------------------------------------
// Writeback
assign writeback = (wb_sel.mem == WB_SEL_DMEM) ? load_sm_data_out :
                   (wb_sel.mem == WB_SEL_ALU ) ? alu_out_mem :
                   (wb_sel.mem == WB_SEL_INC4) ? pc_mem_inc4 :
                /* (wb_sel.mem == WB_SEL_CSR) ? */ csr_data_mem;

//------------------------------------------------------------------------------
// Pipeline FF MEM/WB
`STAGE(flush.mem, inst.mem, inst.wbk)
`STAGE(flush.mem, pc.mem, pc.wbk)

logic [2:0] bubble_track;
`DFF_CI_RI_RVI({bubble_track[1:0], fe_ctrl.bubble_dec}, bubble_track)

// For instruction counter, only care about NOPs inserted by HW
assign inst_wb_nop_or_clear = (
    ((inst.wbk == `NOP) && bubble_track[2]) || (inst.wbk[6:0] == 7'd0)
);

//------------------------------------------------------------------------------
// pipeline control

// Pipeline FFs flush
assign flush.fet = 1'b0;
assign flush.dec = reset_seq[0]; // TODO: eventually also BP
assign flush.exe = reset_seq[1];
assign flush.mem = reset_seq[2];
assign flush.wbk = 1'b0;

endmodule
