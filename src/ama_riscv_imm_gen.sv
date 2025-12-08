`include "ama_riscv_defines.svh"

module ama_riscv_imm_gen (
   input  ig_sel_t sel,
   input  logic [31:7] in,
   `ifdef USE_BP
   output arch_width_t out_b,
   `endif
   output arch_width_t out_jal,
   output arch_width_t out
);

arch_width_t i, s, b, j, u;
assign i = {{20{in[31]}}, in[31:20]};
assign s = {{20{in[31]}}, in[31:25], in[11:7]};
assign b = {{20{in[31]}}, in[7], in[30:25], in[11:8], 1'b0};
assign j = {{12{in[31]}}, in[19:12], in[20], in[30:21], 1'b0};
assign u = {in[31:12], 12'h0};

always_comb begin
   unique case (sel)
      IG_OFF: out = 'h0;
      IG_I_TYPE: out = i;
      IG_S_TYPE: out = s;
      IG_B_TYPE: out = b;
      //IG_J_TYPE: out = j;
      IG_U_TYPE: out = u;
   endcase
end

assign out_jal = j;
`ifdef USE_BP
assign out_b = b;
`endif

endmodule
