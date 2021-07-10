//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Store Mask
// File:            ama_riscv_store_mask.v
// Date created:    2021-07-10
// Author:          Aleksandar Lilic
// Description:     Store masking for DMEM Store operations
//
// Version history:
//      2021-07-10  AL  0.1.0 - Initial
//      2021-07-10  AL  1.0.0 - Release
//      2021-07-10  AL  1.0.1 - Signal fix
//
//-----------------------------------------------------------------------------

module ama_riscv_store_mask (
    // inputs
    input   wire        en    ,
    input   wire [ 1:0] offset,
    input   wire [ 2:0] width ,
    // outputs
    output  reg  [ 3:0] mask
);

//-----------------------------------------------------------------------------
// Signals
wire  [ 7:0] mask_byte = {8'b0001_0001};
wire  [ 7:0] mask_half = {8'b0011_0011};
wire  [ 3:0] mask_word = {4'b1111};
wire  [ 1:0] data_width = width[1:0];
wire         unaligned_access;

//-----------------------------------------------------------------------------
// Check unaligned access
assign unaligned_access = en && 
                         (((data_width == 2'd1) && (offset == 2'd3)) ||
                          ((data_width == 2'd2) && (offset != 2'd0))     );

//-----------------------------------------------------------------------------
// Shift mask
always @ (*) begin
    if (en && !unaligned_access) begin
        case (data_width)
            5'd0:
                mask = mask_byte[(4-offset) +: 4]; 
            5'd1:
                mask = mask_half[(4-offset) +: 4];
            5'd2:
                mask = mask_word[3:0];
            default: 
                mask = 4'h0;
        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        mask = 4'h0;    // read
    end
end // Shift mask

endmodule