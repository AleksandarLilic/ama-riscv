//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          FIFO RTL
// File:            fifo.v
// Date created:    2021-06-07
// Author:          Aleksandar Lilic
// Description:     Parametrized FIFO module
//
// Version history:
//      2021-06-07  AL  0.1.0 - Initial
//      2021-06-07  AL  1.0.0 - Release
//-----------------------------------------------------------------------------

module fifo #(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 32,
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)   //def: 5
) (
    input  logic        clk,
    input  logic        rst,
    // Write side
    input  logic [DATA_WIDTH-1:0] din,
    input  logic        wr_en,
    output logic        fifo_full,
    // Read side
    input  logic        rd_en,
    output logic        fifo_empty,
    output logic [DATA_WIDTH-1:0] dout
);

//-----------------------------------------------------------------------------
// Signals
// FIFO memory
logic [DATA_WIDTH-1:0] fifo_logic[FIFO_DEPTH-1:0];

// Pointers
// with added MSB in order to implement full/empty flags
logic [ADDR_WIDTH-1+1:0] rd_ptr;
logic [ADDR_WIDTH-1+1:0] wr_ptr;
// R/W Address
logic [ADDR_WIDTH-1  :0] wr_addr;
logic [ADDR_WIDTH-1  :0] rd_addr;
// Full/Empty detection
logic wr_msb;
logic rd_msb;
// Flags
logic ptr_cmp_addr;
logic ptr_cmp_msb;

//-----------------------------------------------------------------------------
// FIFO Flags
assign wr_addr = wr_ptr[ADDR_WIDTH-1:0];
assign rd_addr = rd_ptr[ADDR_WIDTH-1:0];
assign wr_msb  = wr_ptr[ADDR_WIDTH    ];
assign rd_msb  = rd_ptr[ADDR_WIDTH    ];

assign ptr_cmp_addr = (rd_addr == wr_addr);
assign ptr_cmp_msb  = (rd_msb  == wr_msb );
assign fifo_full    = (ptr_cmp_addr && !ptr_cmp_msb);
assign fifo_empty   = (ptr_cmp_addr &&  ptr_cmp_msb);

//-----------------------------------------------------------------------------
// FIFO Write
always @ (posedge clk) begin
    if (rst) begin
        wr_ptr  <= 'h0;
    end
    else if (wr_en & !fifo_full) begin
        wr_ptr            <= wr_ptr + 1;
        fifo_reg[wr_addr] <= din;
    end
end

//-----------------------------------------------------------------------------
// FIFO Read
always @ (posedge clk) begin
    if (rst) begin
        rd_ptr  <= 'h0;
        dout    <= 'h0;
    end
    else if (rd_en & !fifo_empty) begin
        rd_ptr  <= rd_ptr + 1;
        dout    <= fifo_reg[rd_addr];
    end
end

endmodule
