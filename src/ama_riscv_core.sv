`include "ama_riscv_defines.svh"

module ama_riscv_core (
    input  logic        clk,
    input  logic        rst,
    // mem in
    input  logic [31:0] inst_id_read,
    input  logic [31:0] dmem_read_data_mem,
    // mem out
    output logic [13:0] imem_addr,
    output logic [31:0] dmem_write_data,
    output logic [13:0] dmem_addr,
    output logic        dmem_en,
    output logic [ 3:0] dmem_we,
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

//-----------------------------------------------------------------------------
// Signals

// Pipeline control inputs
logic        stall_if;
//logic        clear_if;
logic        clear_id;
logic        clear_ex;
logic        clear_mem;

// Signals - MEM stage
logic        reg_we_mem;
logic [ 4:0] rd_addr_mem;

// Signals - EX stage
logic [31:0] inst_ex;
logic        reg_we_ex;
logic [ 4:0] rd_addr_ex;
logic        store_inst_ex;
logic        load_inst_ex;
// from datapath
logic        bc_a_eq_b;
logic        bc_a_lt_b;
logic [ 1:0] store_mask_offset;

// Signals - ID stage
logic [31:0] inst_id;
logic        load_inst_id;
logic        store_inst_id;
//logic        branch_inst_id;
//logic        jump_inst_id;
logic        csr_en_id;
logic        csr_we_id;
logic        csr_ui_id;
logic [ 1:0] csr_op_sel_id;
logic [ 2:0] imm_gen_sel_id;
logic [ 3:0] alu_op_sel_id;
logic [ 1:0] alu_a_sel_fwd_id;
logic [ 1:0] alu_b_sel_fwd_id;
logic        bc_a_sel_fwd_id;
logic        bcs_b_sel_fwd_id;
logic        rf_a_sel_fwd_id;
logic        rf_b_sel_fwd_id;
logic        bc_uns_id;
logic        dmem_en_id;
logic        load_sm_en_id;
logic [ 1:0] wb_sel_id;
logic        reg_we_id;

// Signals - EX stage
logic [ 3:0] dmem_we_ex;

// Signals - IF stage
logic [ 1:0] pc_sel_if;
logic        pc_we_if;

//-----------------------------------------------------------------------------
// Control
ama_riscv_control ama_riscv_control_i (
    .clk                (clk),
    .rst                (rst),
    // inputs
    .inst_id            (inst_id),
    .bc_a_eq_b          (bc_a_eq_b),
    .bc_a_lt_b          (bc_a_lt_b),
    .store_mask_offset  (store_mask_offset),
    // pipeline inputs
    .inst_ex            (inst_ex),
    .reg_we_ex          (reg_we_ex),
    .reg_we_mem         (reg_we_mem),
    .rd_ex              (rd_addr_ex),
    .rd_mem             (rd_addr_mem),
    .store_inst_ex      (store_inst_ex),
    // pipeline outputs
    .stall_if           (stall_if),
    //.clear_if           (clear_if),
    .clear_id           (clear_id),
    .clear_ex           (clear_ex),
    .clear_mem          (clear_mem),
    // pipeline resets

    // outputs
    .pc_sel             (pc_sel_if),
    .pc_we              (pc_we_if),
    .load_inst          (load_inst_id),
    .store_inst         (store_inst_id),
    //.branch_inst        (branch_inst_id),
    //.jump_inst          (jump_inst_id),
    .csr_en             (csr_en_id),
    .csr_we             (csr_we_id),
    .csr_ui             (csr_ui_id),
    .csr_op_sel         (csr_op_sel_id),
    .alu_op_sel         (alu_op_sel_id),
    .ig_sel             (imm_gen_sel_id),
    .bc_uns             (bc_uns_id),
    .dmem_en            (dmem_en_id),
    .load_sm_en         (load_sm_en_id),
    .wb_sel             (wb_sel_id),
    .reg_we             (reg_we_id),
    .alu_a_sel_fwd      (alu_a_sel_fwd_id),
    .alu_b_sel_fwd      (alu_b_sel_fwd_id),
    .bc_a_sel_fwd       (bc_a_sel_fwd_id),
    .bcs_b_sel_fwd      (bcs_b_sel_fwd_id),
    .rf_a_sel_fwd       (rf_a_sel_fwd_id),
    .rf_b_sel_fwd       (rf_b_sel_fwd_id),
    .dmem_we            (dmem_we_ex)
);

//-----------------------------------------------------------------------------
// IF Stage
logic [31:0] pc_mux_out;
logic [31:0] pc;
logic [31:0] pc_inc4;
logic [31:0] alu_out;

// PC select mux
always_comb begin
    case (pc_sel_if)
        `PC_SEL_INC4: pc_mux_out = pc_inc4;
        `PC_SEL_ALU: pc_mux_out = alu_out;
        //`PC_SEL_BP: pc_mux_out =  bp_out;
        `PC_SEL_START_ADDR: pc_mux_out = `RESET_VECTOR;
        default: pc_mux_out = pc_inc4;
    endcase
end

// PC
always_ff @(posedge clk) begin
    if (rst) pc <= 32'h0;
    else if (pc_we_if) pc <= pc_mux_out;
end
assign pc_inc4 = pc + 32'd4;

// IMEM interface
assign imem_addr = pc_mux_out[15:2];

// stalls
logic stall_id;
always_ff @(posedge clk) begin
    if (rst) stall_id <= 1'b1;
    else stall_id <= stall_if;
end

logic [2:0] stall_id_seq;
always_ff @(posedge clk) begin
    if (rst) stall_id_seq <= 3'h0;
    else stall_id_seq <= {stall_id_seq[1:0], stall_id};
end

//-----------------------------------------------------------------------------
// ID Stage

// Convert to NOP?
assign inst_id = (stall_id) ? `NOP : inst_id_read;

// Signals - MEM stage
logic [31:0] writeback;

// Signals - ID stage
logic [31:0] pc_id;
assign pc_id = pc;
// Reg file
logic [ 4:0] rs1_addr_id;
logic [ 4:0] rs2_addr_id;
logic [ 4:0] rd_addr_id;
logic [11:0] csr_addr;
logic [31:0] rd_data;
logic [31:0] rs1_data_id;
logic [31:0] rs2_data_id;
assign rs1_addr_id = inst_id[19:15];
assign rs2_addr_id = inst_id[24:20];
assign rd_addr_id = inst_id[11: 7];
assign csr_addr = inst_id[31:20];
assign rd_data = writeback;
// Imm Gen
logic [24:0] imm_gen_in;
logic [31:0] imm_gen_out_id;
assign imm_gen_in = inst_id[31: 7];

// Register File
ama_riscv_reg_file ama_riscv_reg_file_i(
    .clk    (clk),
    // inputs
    .we     (reg_we_mem),
    .addr_a (rs1_addr_id),
    .addr_b (rs2_addr_id),
    .addr_d (rd_addr_mem),
    .data_d (rd_data),
    // outputs
    .data_a (rs1_data_id),
    .data_b (rs2_data_id)
);

// Imm Gen
ama_riscv_imm_gen ama_riscv_imm_gen_i(
    .clk     (clk),
    .rst     (rst),
    // inputs
    .ig_sel  (imm_gen_sel_id),
    .ig_in   (imm_gen_in),
    // outputs
    .ig_out  (imm_gen_out_id)
);

//-----------------------------------------------------------------------------
// Pipeline FF ID/EX
// Signals
logic [31:0] pc_ex;
logic [31:0] rs1_data_ex;
logic [31:0] rs2_data_ex;
logic [31:0] imm_gen_out_ex;
logic        bc_a_sel_fwd_ex;
logic        bcs_b_sel_fwd_ex;
logic        bc_uns_ex;
logic [ 1:0] alu_a_sel_fwd_ex;
logic [ 1:0] alu_b_sel_fwd_ex;
logic [ 3:0] alu_op_sel_ex;
logic        dmem_en_ex;
logic        load_sm_en_ex;
logic [ 1:0] wb_sel_ex;
logic        csr_en_ex;
logic        csr_we_ex;
logic        csr_ui_ex;
logic [ 1:0] csr_op_sel_ex;
logic [11:0] csr_addr_ex;
logic [ 4:0] csr_imm5;

always_ff @(posedge clk) begin
    if (rst) begin
        // datapath
        pc_ex            <= 32'h0;
        rd_addr_ex       <=  5'h0;
        rs1_data_ex      <= 32'h0;
        rs2_data_ex      <= 32'h0;
        imm_gen_out_ex   <= 32'h0;
        inst_ex          <= 32'h0;
        // control
        load_inst_ex     <=  1'b0;
        store_inst_ex    <=  1'b0;
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
        load_sm_en_ex    <=  1'b0;
        wb_sel_ex        <=  2'h0;
        reg_we_ex        <=  1'b0;
        csr_en_ex        <=  1'b0;
        csr_we_ex        <=  1'b0;
        csr_ui_ex        <=  1'b0;
        csr_op_sel_ex    <=  2'h0;
        csr_addr_ex      <= 12'h0;
        csr_imm5         <=  5'h0;
    end else if (clear_id) begin
        // datapath
        pc_ex            <= 32'h0;
        rd_addr_ex       <=  5'h0;
        rs1_data_ex      <= 32'h0;
        rs2_data_ex      <= 32'h0;
        imm_gen_out_ex   <= 32'h0;
        inst_ex          <= 32'h0;
        // control
        load_inst_ex     <=  1'b0;
        store_inst_ex    <=  1'b0;
        bc_a_sel_fwd_ex  <=  1'b0;
        bcs_b_sel_fwd_ex <=  1'b0;
        bc_uns_ex        <=  1'b0;
        alu_a_sel_fwd_ex <=  2'h0;
        alu_b_sel_fwd_ex <=  2'h0;
        alu_op_sel_ex    <=  4'h0;
        dmem_en_ex       <=  1'b0;
        load_sm_en_ex    <=  1'b0;
        wb_sel_ex        <=  2'h0;
        reg_we_ex        <=  1'b0;
        csr_en_ex        <=  1'b0;
        csr_we_ex        <=  1'b0;
        csr_ui_ex        <=  1'b0;
        csr_op_sel_ex    <=  2'h0;
        csr_addr_ex      <= 12'h0;
        csr_imm5         <=  5'h0;
    end else begin
        // datapath
        pc_ex            <= pc_id;
        rd_addr_ex       <= rd_addr_id;
        rs1_data_ex      <= rf_a_sel_fwd_id ? writeback : rs1_data_id;
        rs2_data_ex      <= rf_b_sel_fwd_id ? writeback : rs2_data_id;
        imm_gen_out_ex   <= imm_gen_out_id;
        inst_ex          <= inst_id;
        // control
        load_inst_ex     <= load_inst_id;
        store_inst_ex    <= store_inst_id;
        bc_a_sel_fwd_ex  <= bc_a_sel_fwd_id;
        bcs_b_sel_fwd_ex <= bcs_b_sel_fwd_id;
        bc_uns_ex        <= bc_uns_id;
        alu_a_sel_fwd_ex <= alu_a_sel_fwd_id;
        alu_b_sel_fwd_ex <= alu_b_sel_fwd_id;
        alu_op_sel_ex    <= alu_op_sel_id;
        dmem_en_ex       <= dmem_en_id;
        load_sm_en_ex    <= load_sm_en_id;
        wb_sel_ex        <= wb_sel_id;
        reg_we_ex        <= reg_we_id;
        csr_en_ex        <= csr_en_id;
        csr_we_ex        <= csr_we_id;
        csr_ui_ex        <= csr_ui_id;
        csr_op_sel_ex    <= csr_op_sel_id;
        csr_addr_ex      <= csr_addr;
        csr_imm5         <= rs1_addr_id;
    end
end

//-----------------------------------------------------------------------------
// EX stage

// Branch Compare
logic [31:0] bc_a;
logic [31:0] bcs_b;
assign bc_a = bc_a_sel_fwd_ex  ? writeback : rs1_data_ex;
assign bcs_b = bcs_b_sel_fwd_ex ? writeback : rs2_data_ex;
assign bc_a_eq_b =
    (bc_uns_ex) ? (bc_a == bcs_b) : ($signed(bc_a) == $signed(bcs_b));
assign bc_a_lt_b =
    (bc_uns_ex) ? (bc_a < bcs_b) : ($signed(bc_a) < $signed(bcs_b));

// ALU
logic [31:0] alu_in_a;
logic [31:0] alu_in_b;
assign alu_in_a = (alu_a_sel_fwd_ex == {1'b0,`ALU_A_SEL_RS1}) ? rs1_data_ex :
                  (alu_a_sel_fwd_ex == {1'b0,`ALU_A_SEL_PC}) ? pc_ex :
               /* (alu_a_sel_fwd_ex == `ALU_A_SEL_FWD_ALU) ? */ writeback;
assign alu_in_b = (alu_b_sel_fwd_ex == {1'b0,`ALU_B_SEL_RS2}) ? rs2_data_ex :
                  (alu_b_sel_fwd_ex == {1'b0,`ALU_B_SEL_IMM}) ? imm_gen_out_ex :
               /* (alu_b_sel_fwd_ex == `ALU_B_SEL_FWD_ALU) ? */ writeback;

ama_riscv_alu ama_riscv_alu_i (
    // inputs
    .op_sel     (alu_op_sel_ex),
    .in_a       (alu_in_a),
    .in_b       (alu_in_b),
    // outputs
    .out_s      (alu_out)
);

// CSR
logic [31:0] csr_tohost;
logic [31:0] csr_mscratch;
logic [31:0] csr_data_ex;
logic [31:0] csr_din_imm;
logic [31:0] csr_wr_data_source;
logic [31:0] csr_wr_data;
assign csr_din_imm = {27'h0, csr_imm5}; // Immediate Zero-Extend
assign csr_wr_data_source = csr_ui_ex ? csr_din_imm : alu_in_a;

// csr read
always_comb begin
    csr_data_ex = 32'h0;
    if (csr_en_ex) begin
        case (csr_addr_ex)
            `CSR_TOHOST: csr_data_ex = csr_tohost;
            `CSR_MSCRATCH: csr_data_ex = csr_mscratch;
            default: ;
        endcase
    end
end

// csr write
always_comb begin
    csr_wr_data = 32'h0;
    case(csr_op_sel_ex)
        `CSR_OP_SEL_ASSIGN: csr_wr_data = csr_wr_data_source;
        `CSR_OP_SEL_SET_BITS: csr_wr_data = csr_data_ex | csr_wr_data_source;
        `CSR_OP_SEL_CLEAR_BITS: csr_wr_data = csr_data_ex & ~csr_wr_data_source;
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        csr_tohost <= 32'h0;
        csr_mscratch <= 32'h0;
    end else if (csr_we_ex) begin
        case (csr_addr_ex)
            `CSR_TOHOST: csr_tohost <= csr_wr_data;
            `CSR_MSCRATCH: csr_mscratch <= csr_wr_data;
            default: ;
        endcase
    end
end

//-----------------------------------------------------------------------------
// Data Memory Space
// Comprised of DMEM and MM I/O
logic [ 4:0] store_byte_shift; // store_mask converted to byte shifts
logic [31:0] dms_write_data; // shifts 0, 1, 2 or 3 bytes
assign store_mask_offset = alu_out[1:0];
assign store_byte_shift = store_mask_offset << 3;
assign dms_write_data = bcs_b << store_byte_shift;

// MM I/O
logic [31:0] mmio_read_data;
logic [31:0] mmio_write_data;
logic [ 2:0] mmio_addr;
logic        mmio_en;
logic [ 3:0] mmio_we;
assign mmio_write_data = dms_write_data;
assign mmio_addr = alu_out[ 4:2];
assign mmio_en = (alu_out[31:30] == `MMIO_RANGE) && dmem_en_ex;
assign mmio_we = {4{(alu_out[31:30] == `MMIO_RANGE)}} & dmem_we_ex;
assign store_to_uart =
    ((store_inst_ex) && (mmio_addr == 3'd2) && (mmio_en) && (mmio_we[0]));
assign load_from_uart = ((load_inst_ex) && (mmio_addr == 3'd1) && (mmio_en));

// mmio sync write
always_ff @(posedge clk) begin
    if(rst) begin
        mmio_uart_data_in <= 8'd0;
        mmio_reset_cnt <= 1'b0;
    end else begin
        if(mmio_en && mmio_we[0]) begin
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
    if(rst) begin
        mmio_read_data <= 32'd0;
    end else if(mmio_en) begin
        case (mmio_addr)
            3'd0: mmio_read_data <= {30'd0, mmio_ctrl};
            3'd1: mmio_read_data <= {24'd0, mmio_uart_data_out};
            3'd5: mmio_read_data <= mmio_cycle_cnt;
            3'd6: mmio_read_data <= mmio_instr_cnt;
            default: mmio_read_data <= 32'd0;
        endcase
    end
end

//-----------------------------------------------------------------------------
// DMEM
logic [ 1:0] load_sm_offset_ex;
assign dmem_write_data = dms_write_data;
assign dmem_addr = alu_out[15:2];
assign dmem_en = (alu_out[31:30] == `DMEM_RANGE) && dmem_en_ex;
assign dmem_we = {4{(alu_out[31:30] == `DMEM_RANGE)}} & dmem_we_ex;
assign load_sm_offset_ex = store_mask_offset;

//-----------------------------------------------------------------------------
// Pipeline FF EX/MEM
// Signals
logic [31:0] pc_mem;
logic [31:0] pc_mem_inc4;
logic [31:0] alu_out_mem;
logic [ 1:0] load_sm_offset_mem;
logic [31:0] inst_mem;
logic        load_sm_en_mem;
logic [ 1:0] wb_sel_mem;
logic [31:0] csr_data_mem;

always_ff @(posedge clk) begin
    if (rst) begin
        // datapath
        pc_mem              <= 32'h0;
        pc_mem_inc4         <= 32'h0;
        alu_out_mem         <= 32'h0;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <=  2'h0;
        inst_mem            <= 32'h0;
        rd_addr_mem         <=  5'h0;
        // control
        load_sm_en_mem      <=  1'b0;
        wb_sel_mem          <=  2'h0;
        reg_we_mem          <=  1'b0;
        csr_data_mem        <= 32'h0;
    end else if (clear_ex) begin
        // datapath
        pc_mem              <= 32'h0;
        pc_mem_inc4         <= 32'h0;
        alu_out_mem         <= 32'h0;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <=  2'h0;
        inst_mem            <= 32'h0;
        rd_addr_mem         <=  5'h0;
        // control
        load_sm_en_mem      <=  1'b0;
        wb_sel_mem          <=  2'h0;
        reg_we_mem          <=  1'b0;
        csr_data_mem        <= 32'h0;
    end else begin
        // datapath
        pc_mem              <= pc_ex;
        pc_mem_inc4         <= pc_ex + 32'd4;
        alu_out_mem         <= alu_out;
        // dmem_read_data_mem          // sync memory
        load_sm_offset_mem  <= load_sm_offset_ex;
        inst_mem            <= inst_ex;
        rd_addr_mem         <= rd_addr_ex;
        // control
        load_sm_en_mem      <= load_sm_en_ex;
        wb_sel_mem          <= wb_sel_ex;
        reg_we_mem          <= reg_we_ex;
        csr_data_mem        <= csr_data_ex;
    end
end

//-----------------------------------------------------------------------------
// MEM stage
logic [ 2:0] funct3_mem;
assign funct3_mem = inst_mem[14:12];

// Load Shift & Mask
logic [31:0] load_sm_data_out;
logic [31:0] load_sm_data_in;
logic [ 2:0] load_sm_width;
assign load_sm_width = funct3_mem;
always_comb begin
    case (alu_out_mem[31:30])
        `DMEM_RANGE: load_sm_data_in = dmem_read_data_mem;
        `MMIO_RANGE: load_sm_data_in = mmio_read_data;
        default: load_sm_data_in = 32'h0;
    endcase
end

ama_riscv_load_shift_mask ama_riscv_load_shift_mask_i (
    .clk        (clk),
    .rst        (rst),
    // inputs
    .en         (load_sm_en_mem),
    .offset     (load_sm_offset_mem),
    .width      (load_sm_width),
    .data_in    (load_sm_data_in),
    // outputs
    .data_out   (load_sm_data_out)
);

//-----------------------------------------------------------------------------
// Writeback
assign writeback = (wb_sel_mem == `WB_SEL_DMEM) ? load_sm_data_out :
                   (wb_sel_mem == `WB_SEL_ALU ) ? alu_out_mem :
                   (wb_sel_mem == `WB_SEL_INC4) ? pc_mem_inc4 :
                /* (wb_sel_mem == `WB_SEL_CSR) ? */ csr_data_mem;

//-----------------------------------------------------------------------------
// Pipeline FF MEM/WB
logic [31:0] inst_wb;
logic [31:0] pc_wb;
always_ff @(posedge clk) begin
    if (rst) begin
        inst_wb <= 32'h0;
        pc_wb <= 32'h0;
    end else if (clear_mem) begin
        inst_wb <= 32'h0;
        pc_wb <= 32'h0;
    end else begin
        inst_wb <= inst_mem;
        pc_wb <= pc_mem;
    end
end

// For instruction counter, only care about NOPs inserted by HW
assign inst_wb_nop_or_clear =
    (((inst_wb == `NOP) && stall_id_seq[2]) || (inst_wb[6:0] == 7'd0));

endmodule
