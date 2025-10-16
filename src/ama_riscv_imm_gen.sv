`include "ama_riscv_defines.svh"

module ama_riscv_imm_gen (
    input  logic        clk,
    input  logic        rst,
    input  ig_sel_t     sel_in,
    input  logic [31:7] d_in,
    output arch_width_t d_out
);

logic disabled;
logic i_type;
logic s_type;
logic b_type;
logic j_type;
logic u_type;
assign disabled = (sel_in == IG_DISABLED);
assign i_type = (sel_in == IG_I_TYPE);
assign s_type = (sel_in == IG_S_TYPE);
assign b_type = (sel_in == IG_B_TYPE);
assign j_type = (sel_in == IG_J_TYPE);
assign u_type = (sel_in == IG_U_TYPE);

arch_width_t d_out_w; // TODO: parsing imm for 64-bit arch needs to be handled
assign d_out_w[31:20] = (u_type) ? d_in[31:20] :
                      /* others */ {12{d_in[31]}}; // s-ext

assign d_out_w[19:12] = (j_type || u_type) ? d_in[19:12] :
                     /* (i_type || s_type || b_type)*/ {8{d_in[31]}}; // s-ext

assign d_out_w[11] = (u_type) ? 1'b0 : // z-ext
                     (b_type) ? d_in[7] :
                     (j_type) ? d_in[20] :
                  /* (i_type || s_type) */ d_in[31]; // s-ext

assign d_out_w[10:5] = (u_type) ? 6'b0 : // z-ext
                     /* others */ d_in[30:25];

assign d_out_w[4:1] = (u_type) ? 4'b0 : // z-ext
                      (s_type || b_type) ? d_in[11: 8] :
                   /* (i_type || j_type) */ d_in[24:21];

assign d_out_w[0] = (i_type) ? d_in[20] :
                    (s_type) ? d_in[7] :
                 /* (b_type || j_type || u_type)*/ 1'b0; // z-ext

// Assign output
arch_width_t d_out_d;
assign d_out = (disabled) ? d_out_d : d_out_w;

// Store previous value
`DFF_CI_RI_RVI(d_out, d_out_d)

endmodule
