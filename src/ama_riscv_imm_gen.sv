`include "ama_riscv_defines.svh"

module ama_riscv_imm_gen (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 2:0] ig_sel,
    input  logic [31:7] ig_in,
    output logic [31:0] ig_out
);

logic [31:0] ig_out_d;
logic [31:0] ig_out_w;

logic disabled;
logic i_type;
logic s_type;
logic b_type;
logic j_type;
logic u_type;
assign disabled = (ig_sel == `IG_DISABLED);
assign i_type = (ig_sel == `IG_I_TYPE);
assign s_type = (ig_sel == `IG_S_TYPE);
assign b_type = (ig_sel == `IG_B_TYPE);
assign j_type = (ig_sel == `IG_J_TYPE);
assign u_type = (ig_sel == `IG_U_TYPE);

// MUXes
assign ig_out_w[31:20] = (u_type) ? ig_in[31:20] :
                       /* others */ {12{ig_in[31]}}; // s-ext

assign ig_out_w[19:12] = (j_type || u_type) ? ig_in[19:12] :
                      /* (i_type || s_type || b_type)*/ {8{ig_in[31]}}; // s-ext

assign ig_out_w[11] = (u_type) ? 1'b0 : // z-ext
                      (b_type) ? ig_in[7] :
                      (j_type) ? ig_in[20] :
                   /* (i_type || s_type) */ ig_in[31]; // s-ext

assign ig_out_w[10:5] = (u_type) ? 6'b0 : // z-ext
                      /* others */ ig_in[30:25];

assign ig_out_w[4:1] = (u_type) ? 4'b0 : // z-ext
                       (s_type || b_type) ? ig_in[11: 8] :
                    /* (i_type || j_type) */ ig_in[24:21];

assign ig_out_w[0] = (i_type) ? ig_in[20] :
                     (s_type) ? ig_in[7] :
                  /* (b_type || j_type || u_type)*/ 1'b0; // z-ext

// Assign output
assign ig_out = (disabled) ? ig_out_d : ig_out_w;

// Store previous value
`DFF_RST(ig_out_d, rst, 32'h0, ig_out)

endmodule
