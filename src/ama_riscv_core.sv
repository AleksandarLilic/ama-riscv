`include "ama_riscv_defines.svh"

module ama_riscv_core (
    input   wire         clk,
    input   wire         rst,
    // mem in
    input   wire  [31:0] inst_id_read,
    input   wire  [31:0] dmem_read_data_mem,
    // mem out
    output  wire  [13:0] imem_addr,
    output  wire  [31:0] dmem_write_data,
    output  wire  [13:0] dmem_addr,
    output  wire         dmem_en,
    output  wire  [ 3:0] dmem_we,
    // mmio in
    input   wire  [31:0] mmio_instr_cnt,
    input   wire  [31:0] mmio_cycle_cnt,
    input   wire  [ 7:0] mmio_uart_data_out,
    input   wire         mmio_data_out_valid,
    input   wire         mmio_data_in_ready,
    // mmio out
    output  wire         store_to_uart,
    output  wire         load_from_uart,
    output  wire         inst_wb_nop_or_clear,
    output  reg          mmio_reset_cnt,
    output  reg   [ 7:0] mmio_uart_data_in
);

//-----------------------------------------------------------------------------
// Signals

// Pipeline control inputs
wire        stall_if;
wire        clear_if;
wire        clear_id;
wire        clear_ex;
wire        clear_mem;

// Signals - MEM stage
reg         reg_we_mem;
reg  [ 4:0] rd_addr_mem;

// Signals - EX stage
reg  [31:0] inst_ex;
reg         reg_we_ex;
reg  [ 4:0] rd_addr_ex;
reg         store_inst_ex;
reg         load_inst_ex;
// from datapath
wire        bc_a_eq_b;
wire        bc_a_lt_b;
wire [ 1:0] store_mask_offset;

// Signals - ID stage
 wire [31:0] inst_id;
wire        load_inst_id;
wire        store_inst_id;
wire        branch_inst_id;
wire        jump_inst_id;
wire        csr_en_id;
wire        csr_we_id;
wire        csr_ui_id;
wire [ 1:0] csr_op_sel_id;
wire [ 2:0] imm_gen_sel_id;
wire [ 3:0] alu_op_sel_id;
wire [ 1:0] alu_a_sel_fwd_id;
wire [ 1:0] alu_b_sel_fwd_id;
wire        bc_a_sel_fwd_id;
wire        bcs_b_sel_fwd_id;
wire        rf_a_sel_fwd_id;
wire        rf_b_sel_fwd_id;
wire        bc_uns_id;
wire        dmem_en_id;
wire        load_sm_en_id;
wire [ 1:0] wb_sel_id;
wire        reg_we_id;

// Signals - EX stage
wire [ 3:0] dmem_we_ex;

// Signals - IF stage
wire [ 1:0] pc_sel_if;
wire        pc_we_if;

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
    .clear_if           (clear_if),
    .clear_id           (clear_id),
    .clear_ex           (clear_ex),
    .clear_mem          (clear_mem),
    // pipeline resets

    // outputs
    .pc_sel             (pc_sel_if),
    .pc_we              (pc_we_if),
    .load_inst          (load_inst_id),
    .store_inst         (store_inst_id),
    .branch_inst        (branch_inst_id),
    .jump_inst          (jump_inst_id),
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
reg  [31:0] pc_mux_out;
reg  [31:0] pc;
wire [31:0] pc_inc4;
wire [31:0] alu_out;

// PC select mux
always @ (*) begin
    case (pc_sel_if)
        `PC_SEL_INC4: pc_mux_out = pc_inc4;
        `PC_SEL_ALU: pc_mux_out = alu_out;
        //`PC_SEL_BP: pc_mux_out =  bp_out;
        `PC_SEL_START_ADDR: pc_mux_out = `RESET_VECTOR;
        default: pc_mux_out = pc_inc4;
    endcase
end

// PC
always @ (posedge clk) begin
    if (rst) pc <= 32'h0;
    else if (pc_we_if) pc <= pc_mux_out;
end
assign pc_inc4 = pc + 32'd4;

// IMEM interface
assign imem_addr = pc_mux_out[15:2];

// stalls
reg stall_id;
always @ (posedge clk) begin
    if (rst) stall_id <= 1'b1;
    else stall_id <= stall_if;
end

reg [2:0] stall_id_seq;
always @ (posedge clk) begin
    if (rst) stall_id_seq <= 3'h0;
    else stall_id_seq <= {stall_id_seq[1:0], stall_id};
end

//-----------------------------------------------------------------------------
// ID Stage

// Convert to NOP?
assign inst_id = (stall_id) ? `NOP : inst_id_read;

// Signals - MEM stage
wire [31:0] writeback;

// Signals - ID stage
wire [31:0] pc_id = pc;
// Reg file
wire [ 4:0] rs1_addr_id = inst_id[19:15];
wire [ 4:0] rs2_addr_id = inst_id[24:20];
wire [ 4:0] rd_addr_id  = inst_id[11: 7];
wire [11:0] csr_addr    = inst_id[31:20];
wire [31:0] rd_data = writeback;
wire [31:0] rs1_data_id;
wire [31:0] rs2_data_id;
// Imm Gen
wire [24:0] imm_gen_in  = inst_id[31: 7];
wire [31:0] imm_gen_out_id;

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
reg  [31:0] pc_ex;
reg  [31:0] rs1_data_ex;
reg  [31:0] rs2_data_ex;
reg  [31:0] imm_gen_out_ex;
reg         bc_a_sel_fwd_ex;
reg         bcs_b_sel_fwd_ex;
reg         bc_uns_ex;
reg  [ 1:0] alu_a_sel_fwd_ex;
reg  [ 1:0] alu_b_sel_fwd_ex;
reg  [ 3:0] alu_op_sel_ex;
reg         dmem_en_ex;
reg         load_sm_en_ex;
reg  [ 1:0] wb_sel_ex;
reg         csr_en_ex;
reg         csr_we_ex;
reg         csr_ui_ex;
reg  [ 1:0] csr_op_sel_ex;

reg  [11:0] csr_addr_ex;
reg  [ 4:0] csr_imm5;

always @ (posedge clk) begin
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
wire [31:0] bc_a  = bc_a_sel_fwd_ex  ? writeback : rs1_data_ex;
wire [31:0] bcs_b = bcs_b_sel_fwd_ex ? writeback : rs2_data_ex;

assign bc_a_eq_b = (bc_uns_ex) ? (bc_a == bcs_b) :
                                 ($signed(bc_a) == $signed(bcs_b));
assign bc_a_lt_b = (bc_uns_ex) ? (bc_a < bcs_b) :
                                 ($signed(bc_a) < $signed(bcs_b));

// ALU
wire [31:0] alu_in_a =  (alu_a_sel_fwd_ex == `ALU_A_SEL_RS1)     ?    rs1_data_ex     :
                        (alu_a_sel_fwd_ex == `ALU_A_SEL_PC )     ?    pc_ex           :
                     /* (alu_a_sel_fwd_ex == `ALU_A_SEL_FWD_ALU) ? */ writeback;

wire [31:0] alu_in_b =  (alu_b_sel_fwd_ex == `ALU_B_SEL_RS2)     ?    rs2_data_ex     :
                        (alu_b_sel_fwd_ex == `ALU_B_SEL_IMM)     ?    imm_gen_out_ex  :
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
reg  [31:0] csr_tohost;
reg  [31:0] csr_mscratch;
reg  [31:0] csr_data_ex;
wire [31:0] csr_din_imm = {27'h0, csr_imm5}; // Immediate Zero-Extend
wire [31:0] csr_wr_data_source = csr_ui_ex ? csr_din_imm : alu_in_a;
reg  [31:0] csr_wr_data;

// csr read
always @ (*) begin
    csr_data_ex = 32'h0;
    if (csr_en_ex) begin
        case (csr_addr_ex)
            `CSR_TOHOST: csr_data_ex = csr_tohost;
            `CSR_MSCRATCH: csr_data_ex = csr_mscratch;
        endcase
    end
end

// csr write
always @ (*) begin
    case(csr_op_sel_ex)
        `CSR_OP_SEL_ASSIGN: csr_wr_data = csr_wr_data_source;
        `CSR_OP_SEL_SET_BITS: csr_wr_data = csr_data_ex | csr_wr_data_source;
        `CSR_OP_SEL_CLEAR_BITS: csr_wr_data = csr_data_ex & ~csr_wr_data_source;
        default: csr_wr_data = 32'h0;
    endcase
end

always @ (posedge clk) begin
    if (rst) begin
        csr_tohost <= 32'h0;
        csr_mscratch <= 32'h0;
    end else if (csr_we_ex) begin
        case (csr_addr_ex)
            `CSR_TOHOST: csr_tohost <= csr_wr_data;
            `CSR_MSCRATCH: csr_mscratch <= csr_wr_data;
        endcase
    end
end

//-----------------------------------------------------------------------------
// Data Memory Space
// Comprised of DMEM and MM I/O
assign store_mask_offset        = alu_out[1:0];
wire [ 4:0] store_byte_shift    = store_mask_offset << 3;           // store_mask converted to byte shifts
wire [31:0] dms_write_data      = bcs_b << store_byte_shift;     // shifts 0, 1, 2 or 3 bytes

// MM I/O
wire [31:0] mmio_write_data = dms_write_data;
wire [13:0] mmio_addr       = alu_out[ 4:2];
wire        mmio_en         = (alu_out[31:30] == `MMIO_RANGE) && dmem_en_ex;
wire [ 3:0] mmio_we         = {4{(alu_out[31:30] == `MMIO_RANGE)}} & dmem_we_ex;
reg  [31:0] mmio_read_data;

assign store_to_uart   = ((store_inst_ex) && (mmio_addr == 3'd2) && (mmio_en) && (mmio_we[0]));
assign load_from_uart  = ((load_inst_ex) && (mmio_addr == 3'd1) && (mmio_en));

// mmio sync write
always @(posedge clk) begin
    if(rst) begin
        mmio_uart_data_in   <= 8'd0;
        mmio_reset_cnt      <= 1'b0;
    end else begin
        if(mmio_en && mmio_we[0]) begin
            case (mmio_addr)
                3'd2    :   mmio_uart_data_in   <= mmio_write_data[7:0];
                3'd4    :   mmio_reset_cnt      <= mmio_write_data[0];
            endcase
        end
    end
end

// mmio sync read
always @(posedge clk) begin
    if(rst) begin
        mmio_read_data <= 32'd0;
    end else if(mmio_en) begin
        case (mmio_addr)
            3'd0    :   mmio_read_data <= {30'd0, mmio_data_out_valid, mmio_data_in_ready};
            3'd1    :   mmio_read_data <= {24'd0, mmio_uart_data_out};
            3'd5    :   mmio_read_data <= mmio_cycle_cnt;
            3'd6    :   mmio_read_data <= mmio_instr_cnt;
            default :   mmio_read_data <= 32'd0;
        endcase
    end
end

//-----------------------------------------------------------------------------
// DMEM
assign dmem_write_data     = dms_write_data;
assign dmem_addr           = alu_out[15:2];
assign dmem_en             = (alu_out[31:30] == `DMEM_RANGE) && dmem_en_ex;
assign dmem_we             = {4{(alu_out[31:30] == `DMEM_RANGE)}} & dmem_we_ex;

wire [ 1:0] load_sm_offset_ex   = store_mask_offset;

//-----------------------------------------------------------------------------
// Pipeline FF EX/MEM
// Signals
reg [31:0] pc_mem;
reg [31:0] pc_mem_inc4;
reg [31:0] alu_out_mem;
reg [ 1:0] load_sm_offset_mem;
reg [31:0] inst_mem;
reg        load_sm_en_mem;
reg [ 1:0] wb_sel_mem;
reg [31:0] csr_data_mem;

always_ff @ (posedge clk) begin
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
wire [ 2:0] funct3_mem = inst_mem[14:12];

// Load Shift & Mask
wire [ 2:0] load_sm_width = funct3_mem;
wire [31:0] load_sm_data_out;
reg  [31:0] load_sm_data_in;
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
assign writeback = (wb_sel_mem == `WB_SEL_DMEM) ?   load_sm_data_out  :
                   (wb_sel_mem == `WB_SEL_ALU ) ?   alu_out_mem       :
                   (wb_sel_mem == `WB_SEL_INC4) ?   pc_mem_inc4       :
                /* (wb_sel_mem == `WB_SEL_CSR) ? */ csr_data_mem;

//-----------------------------------------------------------------------------
// Pipeline FF MEM/WB
reg [31:0] inst_wb;
reg [31:0] pc_wb;
always @ (posedge clk) begin
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
assign inst_wb_nop_or_clear = (((inst_wb == `NOP) && stall_id_seq[2]) ||
                               (inst_wb[6:0] == 7'd0));

endmodule
