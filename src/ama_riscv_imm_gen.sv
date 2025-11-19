`include "ama_riscv_defines.svh"

module ama_riscv_imm_gen (
    input  logic clk,
    input  logic rst,
    input  ig_sel_t sel_in,
    input  logic [31:7] d_in,
    output arch_width_t d_out
);

logic disabled, i_type, s_type, b_type, j_type, u_type;
assign disabled = (sel_in == IG_DISABLED);
assign i_type = (sel_in == IG_I_TYPE);
assign s_type = (sel_in == IG_S_TYPE);
assign b_type = (sel_in == IG_B_TYPE);
assign j_type = (sel_in == IG_J_TYPE);
assign u_type = (sel_in == IG_U_TYPE);

arch_width_t g;
always_comb begin
   g = 'h0;

   g[31:20] = u_type ? d_in[31:20] : {12{d_in[31]}};
   g[19:12] = (j_type || u_type) ? d_in[19:12] : {8{d_in[31]}};

   unique case (1'b1)
      u_type: g[11] = 1'b0;
      b_type: g[11] = d_in[7];
      j_type: g[11] = d_in[20];
      default: g[11] = d_in[31]; // i_type, s_type
   endcase

   g[10:5] = u_type ? 6'h0 : d_in[30:25];

   unique case (1'b1)
      (s_type || b_type): g[4:1] = d_in[11:8];
      (i_type || j_type): g[4:1] = d_in[24:21];
      default: g[4:1] = 4'h0; // u_type
   endcase

   unique case (1'b1)
      i_type: g[0] = d_in[20];
      s_type: g[0] = d_in[7];
      default: g[0] = 1'b0; // (b_type || j_type || u_type)
   endcase

end

arch_width_t d_out_d;
assign d_out = (disabled) ? d_out_d : g;

`DFF_CI_RI_RVI(d_out, d_out_d)

endmodule
