`include "ama_riscv_defines.svh"

module ama_riscv_load_shift_mask (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic [ 1:0] offset,
    input  logic [ 2:0] width,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);

logic        data_sign;
logic [ 1:0] data_width;
logic        unaligned_access_h;
logic        unaligned_access_w;
logic        unaligned_access;
logic [31:0] data_out_d;
assign data_sign = width[2]; // 0: signed, 1: unsigned
assign data_width = width[1:0];

// Check unaligned access
assign unaligned_access_h = en &&
    ((data_width == DMEM_DTYPE_HALF) &&
     ((offset == `DMEM_BYTE_OFF_1) || (offset == `DMEM_BYTE_OFF_3)));
assign unaligned_access_w = en &&
    ((data_width == DMEM_DTYPE_WORD) && (offset != `DMEM_BYTE_OFF_0));
assign unaligned_access = en && (unaligned_access_h || unaligned_access_w);

// Shift mask
always_comb begin
    if (en && !unaligned_access) begin
        case (data_width)
            DMEM_DTYPE_BYTE: begin
                data_out[ 7: 0] = data_in[offset*8 +:  8];
                data_out[31: 8] = data_sign ? {24{1'b0}} :
                                              {24{data_in[offset*8 +  7]}};
            end

            DMEM_DTYPE_HALF: begin
                data_out[15: 0] = data_in[offset*8 +: 16];
                data_out[31:16] = data_sign ? {16{1'b0}} :
                                              {16{data_in[offset*8 + 15]}};
            end

            DMEM_DTYPE_WORD: begin
                data_out[31: 0] = data_in[31: 0];
            end

            default: begin
                data_out[31: 0] = data_out_d;
            end

        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        data_out = data_out_d;
    end
end

// Store old value
`DFF_CI_RI_RVI(data_out, data_out_d)

endmodule
