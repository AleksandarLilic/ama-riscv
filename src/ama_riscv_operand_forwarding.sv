`include "ama_riscv_defines.svh"

module ama_riscv_operand_forwarding (
    // inputs
    input  logic load_inst_mem,
    input  logic load_inst_wbk,
    input  logic dc_stalled,
    input  logic mult_inst_mem,
    input  rf_addr_t rs1_dec,
    input  rf_addr_t rs2_dec,
    input  rf_addr_t rs1_exe,
    input  rf_addr_t rs2_exe,
    input  rf_addr_t rd_mem,
    input  rf_addr_t rd_wbk,
    input  logic rd_we_mem,
    input  logic rd_we_wbk,
    input  logic rdp_we_mem,
    input  logic rdp_we_wbk,
    input  a_sel_t a_sel_dec,
    input  b_sel_t b_sel_dec,
    // outputs
    output fwd_be_t fwd_src_sel_rs1_dec,
    output fwd_be_t fwd_src_sel_rs2_dec,
    output a_sel_t a_sel_dec_fwd,
    output b_sel_t b_sel_dec_fwd,
    output fwd_be_t fwd_src_sel_rs1_exe,
    output fwd_be_t fwd_src_sel_rs2_exe,
    output logic a_sel_fwd_exe,
    output logic b_sel_fwd_exe,
    output hazard_t hazard
);

typedef struct packed {
    logic has;
    // logic on_rd;
    logic on_rdp;
    logic in_mem;
    logic in_wbk;
    logic in_mem_on_rd;
    logic in_mem_on_rdp;
    logic in_wbk_on_rd;
    logic in_wbk_on_rdp;
} dep_t;

// get paired reg addr
rf_addr_t rdp_mem, rdp_wbk;
assign rdp_mem = get_rdp(rd_mem);
assign rdp_wbk = get_rdp(rd_wbk);

// shorthands for common checks
function automatic logic in_mem (input rf_addr_t rs);
    in_mem = ((rs == rd_mem) && rd_we_mem);
endfunction

function automatic logic in_mem_p (input rf_addr_t rs);
    in_mem_p = ((rs == rdp_mem) && rdp_we_mem);
endfunction

function automatic logic in_wbk (input rf_addr_t rs);
    in_wbk = ((rs == rd_wbk) && rd_we_wbk);
endfunction

function automatic logic in_wbk_p (input rf_addr_t rs);
    in_wbk_p = ((rs == rdp_wbk) && rdp_we_wbk);
endfunction

// are source regs non-zeros
logic rs1_dec_nz, rs2_dec_nz, rs1_exe_nz, rs2_exe_nz;
assign rs1_dec_nz = (rs1_dec != RF_X0_ZERO);
assign rs2_dec_nz = (rs2_dec != RF_X0_ZERO);
assign rs1_exe_nz = (rs1_exe != RF_X0_ZERO);
assign rs2_exe_nz = (rs2_exe != RF_X0_ZERO);

// has any source reg anywhere in the machine?
// anywhere in the mem stage?
dep_t d_rs1_dec, d_rs2_dec, d_rs1_exe, d_rs2_exe;
always_comb begin
    d_rs1_dec.in_mem_on_rd = (rs1_dec_nz && in_mem(rs1_dec));
    d_rs2_dec.in_mem_on_rd = (rs2_dec_nz && in_mem(rs2_dec));
    d_rs1_exe.in_mem_on_rd = (rs1_exe_nz && in_mem(rs1_exe));
    d_rs2_exe.in_mem_on_rd = (rs2_exe_nz && in_mem(rs2_exe));

    d_rs1_dec.in_mem_on_rdp = (rs1_dec_nz && in_mem_p(rs1_dec));
    d_rs2_dec.in_mem_on_rdp = (rs2_dec_nz && in_mem_p(rs2_dec));
    d_rs1_exe.in_mem_on_rdp = (rs1_exe_nz && in_mem_p(rs1_exe));
    d_rs2_exe.in_mem_on_rdp = (rs2_exe_nz && in_mem_p(rs2_exe));

    d_rs1_dec.in_mem = (d_rs1_dec.in_mem_on_rd || d_rs1_dec.in_mem_on_rdp);
    d_rs2_dec.in_mem = (d_rs2_dec.in_mem_on_rd || d_rs2_dec.in_mem_on_rdp);
    d_rs1_exe.in_mem = (d_rs1_exe.in_mem_on_rd || d_rs1_exe.in_mem_on_rdp);
    d_rs2_exe.in_mem = (d_rs2_exe.in_mem_on_rd || d_rs2_exe.in_mem_on_rdp);
end

// anywhere in the writeback stage?
always_comb begin
    d_rs1_dec.in_wbk_on_rd = (rs1_dec_nz && in_wbk(rs1_dec));
    d_rs2_dec.in_wbk_on_rd = (rs2_dec_nz && in_wbk(rs2_dec));
    d_rs1_exe.in_wbk_on_rd = (rs1_exe_nz && in_wbk(rs1_exe));
    d_rs2_exe.in_wbk_on_rd = (rs2_exe_nz && in_wbk(rs2_exe));

    d_rs1_dec.in_wbk_on_rdp = (rs1_dec_nz && in_wbk_p(rs1_dec));
    d_rs2_dec.in_wbk_on_rdp = (rs2_dec_nz && in_wbk_p(rs2_dec));
    d_rs1_exe.in_wbk_on_rdp = (rs1_exe_nz && in_wbk_p(rs1_exe));
    d_rs2_exe.in_wbk_on_rdp = (rs2_exe_nz && in_wbk_p(rs2_exe));

    d_rs1_dec.in_wbk = (d_rs1_dec.in_wbk_on_rd || d_rs1_dec.in_wbk_on_rdp);
    d_rs2_dec.in_wbk = (d_rs2_dec.in_wbk_on_rd || d_rs2_dec.in_wbk_on_rdp);
    d_rs1_exe.in_wbk = (d_rs1_exe.in_wbk_on_rd || d_rs1_exe.in_wbk_on_rdp);
    d_rs2_exe.in_wbk = (d_rs2_exe.in_wbk_on_rd || d_rs2_exe.in_wbk_on_rdp);
end

// on paired register?
assign d_rs1_dec.on_rdp = (d_rs1_dec.in_mem_on_rdp || d_rs1_dec.in_wbk_on_rdp);
assign d_rs2_dec.on_rdp = (d_rs2_dec.in_mem_on_rdp || d_rs2_dec.in_wbk_on_rdp);
assign d_rs1_exe.on_rdp = (d_rs1_exe.in_mem_on_rdp || d_rs1_exe.in_wbk_on_rdp);
assign d_rs2_exe.on_rdp = (d_rs2_exe.in_mem_on_rdp || d_rs2_exe.in_wbk_on_rdp);

// anywhere in the machine?
assign d_rs1_dec.has = (d_rs1_dec.in_wbk);
assign d_rs2_dec.has = (d_rs2_dec.in_wbk);
assign d_rs1_exe.has = (d_rs1_exe.in_mem || d_rs1_exe.in_wbk);
assign d_rs2_exe.has = (d_rs2_exe.in_mem || d_rs2_exe.in_wbk);

// if it has, where to get the data from and which rd?
// if it's found in both mem and wbk, prioritize mem as a later update to the rd
// also set rd/rdp high bit
assign fwd_src_sel_rs1_dec = fwd_be_t'({d_rs1_dec.on_rdp, 1'b1});
assign fwd_src_sel_rs2_dec = fwd_be_t'({d_rs2_dec.on_rdp, 1'b1});
assign fwd_src_sel_rs1_exe = fwd_be_t'({d_rs1_exe.on_rdp, !d_rs1_exe.in_mem});
assign fwd_src_sel_rs2_exe = fwd_be_t'({d_rs2_exe.on_rdp, !d_rs2_exe.in_mem});

// should forward in exec?
assign a_sel_fwd_exe = d_rs1_exe.has;
assign b_sel_fwd_exe = d_rs2_exe.has;

// should forward in decode?
// only if instruction is using rs1/rs2
assign a_sel_dec_fwd = (d_rs1_dec.has && (a_sel_dec == A_SEL_RS1)) ?
    A_SEL_FWD : a_sel_dec;
assign b_sel_dec_fwd = (d_rs2_dec.has && (b_sel_dec == B_SEL_RS2)) ?
    B_SEL_FWD : b_sel_dec;

// hazards on 2 cycle execute instructions?
logic hazard_from_mem, hazard_from_wbk;
assign hazard_from_mem = (
    (load_inst_mem || mult_inst_mem) && (d_rs1_exe.in_mem || d_rs2_exe.in_mem)
);
assign hazard_from_wbk = (
    load_inst_wbk && dc_stalled && (d_rs1_exe.in_wbk || d_rs2_exe.in_wbk)
);
assign hazard.to_exe = (hazard_from_mem || hazard_from_wbk);

endmodule
