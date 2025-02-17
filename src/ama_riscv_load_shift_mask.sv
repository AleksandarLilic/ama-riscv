`include "ama_riscv_defines.svh"

module ama_riscv_load_shift_mask (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire [ 1:0] offset,
    input  wire [ 2:0] width,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out
);

wire        data_sign = width[2]; // 0: signed, 1: unsigned
wire [ 1:0] data_width = width[1:0];
wire        unaligned_access;
reg  [31:0] data_out_d;

// Check unaligned access
assign unaligned_access = en && 
    (((data_width == `DMEM_HALF) && (offset == `DMEM_OFF_3)) ||
     ((data_width == `DMEM_WORD) && (offset != `DMEM_OFF_0)));

// Shift mask
always @ (*) begin
    if (en && !unaligned_access) begin
        case (data_width)
            `DMEM_BYTE: begin
                data_out[ 7: 0] = data_in[offset*8 +:  8];
                data_out[31: 8] = data_sign ? {24{1'b0}} : 
                                              {24{data_in[offset*8 +  7]}};
            end
            
            `DMEM_HALF: begin
                data_out[15: 0] = data_in[offset*8 +: 16];
                data_out[31:16] = data_sign ? {16{1'b0}} : 
                                              {16{data_in[offset*8 + 15]}};
            end
            
            `DMEM_WORD: begin
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
always @ (posedge clk) begin
    if (rst)
        data_out_d <= 32'h0000;
    else
        data_out_d <= data_out;
end

endmodule