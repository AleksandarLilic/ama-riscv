`include "ama_riscv_defines.svh"

module ama_riscv_store_mask (
    input  logic       en,
    input  logic [1:0] offset,
    input  logic [1:0] width,
    output logic [3:0] mask
);

// Signals
logic [ 7:0] mask_byte;
logic [ 7:0] mask_half;
logic [ 3:0] mask_word;
logic [ 1:0] data_width;
logic        unaligned_access;
assign mask_byte = {8'b0001_0001};
assign mask_half = {8'b0011_0011};
assign mask_word = {4'b1111};
assign data_width = width;

// Check unaligned access
assign unaligned_access = en &&
    (((data_width == `DMEM_HALF) && (offset == `DMEM_OFF_3)) ||
     ((data_width == `DMEM_WORD) && (offset != `DMEM_OFF_0)));

// Shift mask
always_comb begin
    if (en && !unaligned_access) begin
        case (data_width)
            `DMEM_BYTE: mask = mask_byte[(4-offset) +: 4];
            `DMEM_HALF: mask = mask_half[(4-offset) +: 4];
            `DMEM_WORD: mask = mask_word[3:0];
            default: mask = 4'h0;
        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        mask = 4'h0; // read
    end
end

endmodule
