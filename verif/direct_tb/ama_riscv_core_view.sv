
`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"

module ama_riscv_core_view (
    // top level signals
    input logic clk,
    input logic rst,
    rv_if_dc.TX dmem_req,
    input logic inst_retired,
    // internal signals
    input stage_ctrl_t ctrl_dec,
    input stage_ctrl_t ctrl_exe,
    input stage_ctrl_t ctrl_mem,
    input decoder_t decoded_exe,
    input logic branch_taken,
    `ifdef USE_BP
    input logic bp_hit,
    `endif
    input logic dc_stalled
);

pipeline_if_typed #(.T(inst_t)) inst_shadow ();
pipeline_if_s nop ();
pipeline_if_s flush ();

function automatic inst_t classify_inst(input inst_width_t s);
    inst_t d;
    // d = 0; // to avoid X in wave, but Xs are easier to visually separate imo
    unique case (get_opc7(s))
        OPC7_R_TYPE: d.r_type = inst.dec;
        OPC7_I_TYPE,
        OPC7_LOAD,
        OPC7_JALR,
        OPC7_SYSTEM: d.i_type = inst.dec;
        OPC7_STORE: d.s_type = inst.dec;
        OPC7_BRANCH: d.b_type = inst.dec;
        OPC7_JAL: d.j_type = inst.dec;
        OPC7_LUI,
        OPC7_AUIPC: d.u_type = inst.dec;
        // default: d = 0; // would catch flush as 0s inst ...
        default: ; // ... but make it Xs
    endcase
    return d;
endfunction

always_comb inst_shadow.dec = classify_inst(inst.dec);
always_comb inst_shadow.exe = classify_inst(inst.exe);
always_comb inst_shadow.mem = classify_inst(inst.mem);
always_comb inst_shadow.wbk = classify_inst(inst.wbk);

assign nop.dec = (inst.dec == `NOP);
assign nop.exe = (inst.exe == `NOP);
assign nop.mem = (inst.mem == `NOP);
assign nop.wbk = (inst.wbk == `NOP);

assign flush.dec = (inst.dec == 'h0);
assign flush.exe = (inst.exe == 'h0);
assign flush.mem = (inst.mem == 'h0);
assign flush.wbk = (inst.wbk == 'h0);

// signals for tracing

// inst, pc
inst_width_t inst_wbk;
arch_width_t pc_wbk;
assign inst_wbk = inst.wbk & {INST_WIDTH{inst_retired}};
assign pc_wbk = pc.wbk & {ARCH_WIDTH{inst_retired}};

// branches
logic branch_inst_mem, branch_inst_wbk;
`STAGE(ctrl_exe, decoded_exe.branch_inst, branch_inst_mem, 'h0)
`STAGE(ctrl_mem, branch_inst_mem, branch_inst_wbk, 'h0)

logic branch_taken_exe, branch_taken_mem, branch_taken_wbk;
assign branch_taken_exe = (branch_taken && decoded_exe.branch_inst);
`STAGE(ctrl_exe, branch_taken_exe, branch_taken_mem, 'h0)
`STAGE(ctrl_mem, branch_taken_mem, branch_taken_wbk, 'h0)

`ifdef USE_BP
logic bp_hit_exe, bp_hit_mem, bp_hit_wbk;
assign bp_hit_exe = (decoded_exe.branch_inst && bp_hit);
`STAGE(ctrl_exe, bp_hit_exe, bp_hit_mem, 'h0)
`STAGE(ctrl_mem, bp_hit_mem, bp_hit_wbk, 'h0)
`else
logic bp_hit_wbk;
assign bp_hit_wbk = 1'b0; // just to make trace function happy
`endif

// dmem
arch_width_t dmem_addr_exe, dmem_addr_mem, dmem_addr_wbk;
assign dmem_addr_exe = dmem_req.addr & {ARCH_WIDTH{dmem_req.valid}};

// enum class dmem_size_t {
//     lb, lh, lw, ld,
//     sb, sh, sw, sd,
//     no_access
// };
localparam int unsigned DMEM_SIZE_NA = 8;
logic [2:0] dmem_size;
logic [3:0] dmem_size_exe, dmem_size_mem, dmem_size_wbk;
assign dmem_size = dmem_req.dtype | {dmem_req.rtype, 2'b00};
assign dmem_size_exe = dmem_req.valid ? {1'b0, dmem_size} : DMEM_SIZE_NA;

`STAGE(ctrl_exe, dmem_addr_exe, dmem_addr_mem, 'h0)
`STAGE(ctrl_mem, dmem_addr_mem, dmem_addr_wbk, 'h0)

`STAGE(ctrl_exe, dmem_size_exe, dmem_size_mem, 'h0)
`STAGE(ctrl_mem, dmem_size_mem, dmem_size_wbk, DMEM_SIZE_NA)

endmodule
