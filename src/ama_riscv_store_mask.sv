`include "ama_riscv_defines.svh"

module ama_riscv_store_mask (
    input  logic        en,
    input  logic [ 1:0] offset,
    input  dmem_dtype_t dtype,
    output logic [ 3:0] mask
);

// Signals
logic [ 7:0] mask_byte;
logic [ 7:0] mask_half;
logic [ 3:0] mask_word;
logic        unaligned_access_h;
logic        unaligned_access_w;
logic        unaligned_access;
assign mask_byte = {8'b0001_0001};
assign mask_half = {8'b0011_0011};
assign mask_word = {4'b1111};

// Check unaligned access
assign unaligned_access_h = en &&
    ((dtype == DMEM_DTYPE_HALF) &&
     ((offset == `DMEM_BYTE_OFF_1) || (offset == `DMEM_BYTE_OFF_3)));
assign unaligned_access_w = en &&
    ((dtype == DMEM_DTYPE_WORD) && (offset != `DMEM_BYTE_OFF_0));
assign unaligned_access = en && (unaligned_access_h || unaligned_access_w);

// Shift mask
always_comb begin
    if (en && !unaligned_access) begin
        case (dtype)
            DMEM_DTYPE_BYTE: mask = mask_byte[(4-offset) +: 4];
            DMEM_DTYPE_HALF: mask = mask_half[(4-offset) +: 4];
            DMEM_DTYPE_WORD: mask = mask_word[3:0];
            default: mask = 4'h0;
        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        mask = 4'h0; // read
    end
end

endmodule
