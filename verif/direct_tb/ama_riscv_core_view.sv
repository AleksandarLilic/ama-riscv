
`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"

module ama_riscv_core_view (input logic clk);

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

endmodule
