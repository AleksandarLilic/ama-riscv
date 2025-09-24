`include "ama_riscv_defines.svh"

module ama_riscv_icache #(
    parameter int unsigned ADDR_W = CORE_ADDR_BUS_W,
    parameter int unsigned DATA_W = CORE_DATA_BUS,
    parameter int unsigned BUS_W = MEM_DATA_BUS,
    parameter int unsigned SETS = 4 // must be power of 2
    //parameter int unsigned WAYS = 1
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_core,
    rv_if.TX     rsp_core,
    rv_if.TX     req_mem,
    rv_if.RX     rsp_mem
    // TODO: write enables for dcache flavor
);

if (SETS > 1024) begin
    $error("icache SETS > 1024 - can't be bigger than the entire memory");
end

if (!is_pow2(SETS)) begin
    $error("icache SETS not power of 2");
end

typedef struct packed {
    logic valid;
    logic [TAG_W-1:0] tag;
    logic [CACHE_LINE_SIZE-1:0] data;
} cache_line_t;

cache_line_t arr [SETS-1:0];

//if (WAYS > 2) $error("icache WAYS > 2 currently not supported");

parameter int unsigned INDEX_BITS = $clog2(SETS);

logic [DATA_W-1-4:0] core_req_addr_64b_aligned;
assign core_req_addr_64b_aligned = (req_core.data >> 4);
logic [TAG_W-1:0] core_req_tag;
assign core_req_tag = (core_req_addr_64b_aligned >> INDEX_BITS);
logic [INDEX_BITS-1:0] core_req_idx;
assign core_req_idx = core_req_addr_64b_aligned & (SETS - 1);

logic tag_match;
assign tag_match = (arr[core_req_idx].tag == core_req_tag);
logic hit, hit_d;
assign hit =
    &{tag_match, req_core.valid, req_core.ready, arr[core_req_idx].valid};
`DFF_CI_RI_RVI(hit, hit_d)

// TODO DPI 1: query from cpp model

logic new_core_req;
`DFF_CI_RI_RVI((req_core.valid && req_core.ready), new_core_req)

logic [CORE_ADDR_BUS_W-1:0] core_addr_d;
`DFF_CI_RI_RVI(req_core.data, core_addr_d)

// cache line (64B) to mem bus (16B) addressing, from core addr (4B)
logic [MEM_ADDR_BUS-1:0] mem_start_addr;
assign mem_start_addr = (core_addr_d >> 2) & ~'b11; // align to first block

cache_state_t state, nx_state;

logic pending_req, pending_req_d;
logic [CORE_ADDR_BUS_W-1:0] pending_core_addr;
logic [MEM_ADDR_BUS-1:0] mem_start_addr_hold;
always_ff @(posedge clk) begin
    if (rst) begin
        pending_req <= 1'b0;
        pending_core_addr <= 'h0;
        mem_start_addr_hold <= 'h0;
    end else if ((state == IC_READY) && (nx_state == IC_MISS)) begin
        `LOG_D($sformatf("saving pending request; with core addr byte at 0x%5h", req_core.data<<2));
        pending_req = 1'b1;
        pending_core_addr <= core_addr_d;
        mem_start_addr_hold <= mem_start_addr;
    end else if (pending_req && (state == IC_READY)) begin
        pending_req = 1'b0;
        pending_core_addr <= 'h0;
    end
end

`DFF_CI_RI_RVI(pending_req, pending_req_d)
logic [1:0] mem_bus_cnt;
`DFF_CI_RI_RVI_EN(req_mem.valid, (mem_bus_cnt + 'h1), mem_bus_cnt)
logic [1:0] mem_bus_cnt_d;
`DFF_CI_RI_RVI(mem_bus_cnt, mem_bus_cnt_d)

logic mem_transfer_done;
assign mem_transfer_done =
    (rsp_mem.valid && (mem_bus_cnt_d == (MEM_TRANSFERS_PER_CL - 1)));

logic [DATA_W-1-4:0] core_req_addr_64b_aligned_pending;
assign core_req_addr_64b_aligned_pending = (pending_core_addr >> 4);
logic [INDEX_BITS-1:0] core_req_idx_pending;
assign core_req_idx_pending = core_req_addr_64b_aligned_pending & (SETS - 1);

`DFF_CI_RI_RVI_EN(
    mem_transfer_done,
    (mem_start_addr_hold >> (2 + INDEX_BITS)),
    arr[core_req_idx_pending].tag
)

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < SETS; i++) arr[i].valid <= 1'b0;
    end else if (mem_transfer_done) begin
        arr[core_req_idx_pending].valid <= 1'b1;
    end
end

`DFF_CI_EN(
    rsp_mem.valid,
    rsp_mem.data,
    arr[core_req_idx_pending]
    .data[(MEM_DATA_BUS*mem_bus_cnt_d) +: MEM_DATA_BUS]
)

// debug signals
logic serving_pending_req;
assign serving_pending_req = (pending_req && !new_core_req) && rsp_core.valid;

logic [CORE_ADDR_BUS_B-1:0] req_core_bytes;
assign req_core_bytes = req_core.data<<2;

logic [CORE_ADDR_BUS_B-1:0] req_core_bytes_valid;
assign req_core_bytes_valid = (
    (req_core.data<<2) & {CORE_ADDR_BUS_B{req_core.valid}});

// state transition
`DFF_CI_RI_RV(IC_RESET, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    case (state)
        IC_RESET: begin
            `LOG_D($sformatf(">> I$ STATE IC_RESET"));
            nx_state = IC_READY;
        end

        IC_READY: begin
            `LOG_D($sformatf(">> I$ STATE IC_READY"));
            if ((new_core_req) && (!hit_d)) begin
                nx_state = IC_MISS;
                `LOG_D($sformatf(">> I$ next state: IC_MISS; missed on core addr byte: 0x%0h", req_core.data<<2));
            end
        end

        IC_MISS: begin
            `LOG_D($sformatf(">> I$ STATE IC_MISS"));
            // count 4 beats after main mem responds and go to ready
            `LOG_D($sformatf(">> I$ miss state; cnt %0d", mem_bus_cnt));
            if (mem_bus_cnt_d == (MEM_TRANSFERS_PER_CL - 1)) begin
                nx_state = IC_READY;
            end
        end

    endcase
end

logic [CORE_ADDR_BUS_W-1:0] core_addr_d_cl_word;
logic [INDEX_BITS-1:0] core_addr_d_idx;
// outputs
always_comb begin
    // to/from core
    rsp_core.data = 'h0;
    rsp_core.valid = 1'b0;
    req_core.ready = 1'b0;
    // to/from mem
    req_mem.valid = 1'b0;
    req_mem.data = 'h0;
    rsp_mem.ready = 1'b0;
    // others
    core_addr_d_cl_word = 'h0;
    core_addr_d_idx = 'h0;

    case (state)
        IC_RESET: begin
            rsp_core.valid = 1'b0;
            req_core.ready = 1'b0;
            req_mem.valid = 1'b0;
            rsp_mem.ready = 1'b0;
        end

        IC_READY: begin
            req_core.ready = 1'b1;
            if (pending_req && !new_core_req) begin
                // service the pending request after miss
                core_addr_d_cl_word = (pending_core_addr & 4'hf);
                rsp_core.data =
                    arr[core_req_idx_pending]
                    .data[(core_addr_d_cl_word << (2+3)) +: 32];
                rsp_core.valid = 1'b1;
                `LOG_D($sformatf("icache OUT complete pending request; cache at word %0d; core at byte 0x%5h; with output %8h", core_addr_d_cl_word, core_addr_d<<2, rsp_core.data));

            end else if (new_core_req) begin
                if (hit_d) begin
                    core_addr_d_idx = ((core_addr_d >> 4) & (SETS - 1));
                    core_addr_d_cl_word = (core_addr_d & 4'hf);
                    rsp_core.data =
                        arr[core_addr_d_idx]
                        .data[(core_addr_d_cl_word << (2+3)) +: 32];
                    rsp_core.valid = 1'b1;
                    `LOG_D($sformatf("icache OUT hit; cache at word %0d; core at byte 0x%5h; with output %8h", core_addr_d_cl_word, core_addr_d<<2, rsp_core.data));

                end else begin
                    // handle miss, initiate memory read
                    req_mem.data = mem_start_addr;
                    `LOG_D($sformatf("icache OUT H->M transition; core at byte 0x%5h; mem_start_addr: %0d 0x%5h", core_addr_d<<2, mem_start_addr, mem_start_addr));
                    // NOTE: doesn't check for main mem ready
                    // main mem is currently always ready to take in new request
                    req_mem.valid = 1'b1;
                    rsp_mem.ready = 1'b1;
                    req_core.ready = 1'b0;
                end
            end
        end

        IC_MISS: begin
            // 1 clk at the end to wait in IC_MISS for last mem response
            if (mem_bus_cnt > 0) begin
                req_mem.data = (mem_start_addr_hold + mem_bus_cnt);
                `LOG_D($sformatf("icache miss OUT; bus packet: %0d", (mem_start_addr_hold + mem_bus_cnt)));
                req_mem.valid = 1'b1;
                rsp_mem.ready = 1'b1;
            end
        end
    endcase
end

endmodule
