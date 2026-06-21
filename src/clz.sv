`include "ama_riscv_defines.svh"

// leading/trailing zero counter, recursive-halving (fold) style

module clz #(
    parameter int unsigned WIDTH = 8,
    parameter bit MODE = 1'b0, // 0 -> trailing zero, 1 -> leading zero
    localparam int unsigned CNT_WIDTH = $clog2(WIDTH)
)(
    input  logic [WIDTH-1:0] in, // vector
    output logic [CNT_WIDTH-1:0] cnt, // zeros count
    output logic empty // vector empty
);

if (WIDTH < 1) begin: check_width
    $error("clz: WIDTH must be >= 1");
end

//------------------------------------------------------------------------------
// at each level, test whether the upper half of the live window is all-zero
// that test is one bit of the count (MSB first)
// then narrow into the half that holds the first set bit
// log2(WIDTH) levels, width halving each level

if (WIDTH <= 1) begin: gen_degenerate
// single-bit input: zero leading/trailing zeros if set, else empty
assign cnt[0] = !in[0];
assign empty = !in[0];

end else begin: gen_clz

// internal datapath always counts leading zeros (from MSB)
// for trailing mode, reverse the input since tz(in) == lz(reverse(in))
logic [WIDTH-1:0] in_aligned;
if (MODE) begin: gen_lead
    assign in_aligned = in;
end else begin: gen_trail
    bit_reverse #(.W(WIDTH)) br_i (.a(in), .s(in_aligned));
end

// cur[L] holds the live (WIDTH>>L)-bit window in its low bits
/* verilator lint_off UNUSEDSIGNAL */
logic [WIDTH-1:0] cur [CNT_WIDTH+1]; // high bits unused
/* verilator lint_on UNUSEDSIGNAL */

assign cur[0] = in_aligned;
for (genvar level = 0; level < CNT_WIDTH; level++) begin: gen_level
    localparam int unsigned CW = (WIDTH >> level); // current width
    localparam int unsigned HW = (CW >> 1); // half width
    logic upper_nz;
    assign upper_nz = |cur[level][CW-1 : HW];
    // top count bit first; 1 => first set bit is in the lower half
    assign cnt[CNT_WIDTH-1-level] = ~upper_nz;
    assign cur[level+1][HW-1:0] = upper_nz ?
        cur[level][CW-1:HW] : cur[level][HW-1:0];
end

assign empty = ~(|in);

end

endmodule
