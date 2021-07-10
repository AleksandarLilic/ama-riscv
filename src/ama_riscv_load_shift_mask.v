//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Load Shift Mask
// File:            ama_riscv_load_shift_mask.v
// Date created:    2021-07-10
// Author:          Aleksandar Lilic
// Description:     Shifting and masking after DMEM read
//                  DMEM is 32-bits, RV32I has byte access
//
// Version history:
//      2021-07-10  AL  0.1.0 - Initial
//
//-----------------------------------------------------------------------------

module ama_riscv_load_shift_mask (
    input   wire        clk     ,
    input   wire        rst     ,
    // inputs
    input   wire        en      ,
    input   wire [ 1:0] offset  ,
    input   wire [ 2:0] width   ,
    input   wire [31:0] data_in ,
    // outputs
    output  reg  [31:0] data_out
);

//-----------------------------------------------------------------------------
// Signals
wire         data_sign  = width[2];     // 0: signed, 1: unsigned
wire  [ 1:0] data_width = width[1:0];
wire         unaligned_access;
reg   [31:0] data_out_prev;

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
            2'd0: begin  // byte
                data_out[ 7: 0] = data_in[offset*8 +:  8];
                data_out[31: 8] = data_sign ? {24{1'b0}} : {24{data_in[offset*8 +  7]}};
            end
            2'd1: begin  // half
                data_out[15: 0] = data_in[offset*8 +: 16];
                data_out[31:16] = data_sign ? {16{1'b0}} : {16{data_in[offset*8 + 15]}};
            end
            2'd2: begin  // word
                data_out[31: 0] = data_in[31: 0];
            end
            default: begin
                data_out[31: 0] = data_out_prev;
            end
        endcase
    end
    else /* (!en || unaligned_access)*/ begin
        data_out = data_out_prev;
    end
end // Shift mask

//-----------------------------------------------------------------------------
// Store old value
always @ (posedge clk) begin
    if (rst)
        data_out_prev <= 32'h0000;
    else
        data_out_prev <= data_out;
end

endmodule