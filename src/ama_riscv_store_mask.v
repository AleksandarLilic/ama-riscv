`include "ama_riscv_defines.v"

module ama_riscv_store_mask (
    input  wire       en,
    input  wire [1:0] offset,
    input  wire [2:0] width,
    output reg  [3:0] mask
);

// Signals
wire [ 7:0] mask_byte  = {8'b0001_0001};
wire [ 7:0] mask_half  = {8'b0011_0011};
wire [ 3:0] mask_word  = {4'b1111};
wire [ 1:0] data_width = width[1:0];
wire        unaligned_access;

// Check unaligned access
assign unaligned_access = en && 
    (((data_width == `DMEM_HALF) && (offset == `DMEM_OFF_3)) ||
     ((data_width == `DMEM_WORD) && (offset != `DMEM_OFF_0)));

// Shift mask
always @ (*) begin
    if (en && !unaligned_access) begin
        case (data_width)
            `DMEM_BYTE:
                mask = mask_byte[(4-offset) +: 4]; 
            `DMEM_HALF:
                mask = mask_half[(4-offset) +: 4];
            `DMEM_WORD:
                mask = mask_word[3:0];
            default: 
                mask = 4'h0;
        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        mask = 4'h0; // read
    end
end

endmodule
