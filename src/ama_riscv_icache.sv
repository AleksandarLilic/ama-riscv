`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"

module ama_riscv_icache #(
    parameter int unsigned SETS = 4 // must be power of 2
    //parameter int unsigned WAYS = 1
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_core,
    rv_if.TX     rsp_core,
    rv_if.TX     req_mem,
    rv_if.RX     rsp_mem
);

// validate parameters
if (SETS > 1024) begin: check_sets_size
    $error("dcache SETS > 1024 - can't be bigger than the entire memory");
end

if (!is_pow2(SETS)) begin: check_sets_pow2
    $error("dcache SETS not power of 2");
end

parameter int unsigned WAYS = 1; // currently only direct-mapped supported
//if (WAYS > 2) $error("icache WAYS > 2 currently not supported");

parameter int unsigned INDEX_BITS = $clog2(SETS);

// custom types
typedef struct {
    logic valid;
    // logic lru_cnt; // for 2-way set associative
    logic [TAG_W-1:0] tag;
    logic [CACHE_LINE_SIZE-1:0] data;
} cache_line_t;

typedef struct {
    cache_line_t cl [SETS-1:0] ;
} cache_way_t;

typedef struct packed {
    logic active;
    logic [CORE_ADDR_BUS_W-1:0] addr;
    logic [MEM_ADDR_BUS-1:0] mem_start_addr;
} core_request_pending_t;

// helper functions
function [TAG_W-1:0]
get_tag(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_tag = (addr >> (4 + INDEX_BITS));
endfunction

function [INDEX_BITS-1:0]
get_idx(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_idx = (addr >> 4) & (SETS - 1);
endfunction

function [CORE_ADDR_BUS_W-1:0]
get_cl_word(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_cl_word = addr & 4'hf;
endfunction

function [CORE_ADDR_BUS_W-1:0]
get_w_idx(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_w_idx = (get_cl_word(addr) << (2+3));
endfunction

// implementation
cache_way_t arr [WAYS-1:0];

parameter int unsigned way_idx = 0; // TODO: implement set associativity

logic [CORE_ADDR_BUS_W-1:0] cr_addr, cr_d_addr;
assign cr_addr = req_core.data; // just rename for clarity

logic tag_match;
assign tag_match = (arr[way_idx].cl[get_idx(cr_addr)].tag == get_tag(cr_addr));

logic new_core_req, new_core_req_d;
assign new_core_req = (req_core.valid && req_core.ready);
`DFF_CI_RI_RVI(new_core_req, new_core_req_d)

logic hit, hit_d;
assign hit =
    &{tag_match, new_core_req, arr[way_idx].cl[get_idx(cr_addr)].valid};
`DFF_CI_RI_RVI_EN(new_core_req, hit, hit_d)
`DFF_CI_RI_RVI_EN(new_core_req, cr_addr, cr_d_addr);

// TODO DPI 1: query from cpp model

// cache line (64B) to mem bus (16B) addressing, from core addr (4B)
logic [MEM_ADDR_BUS-1:0] mem_start_addr_d; // address aligned to first mem block
assign mem_start_addr_d = (cr_d_addr >> 2) & ~'b11;

icache_state_t state, nx_state;
core_request_pending_t cr_pend;

always_ff @(posedge clk) begin
    if (rst) begin
        cr_pend <= '{1'b0, 'h0, 'h0};
    end else if ((state == IC_READY) && (nx_state == IC_MISS)) begin
        cr_pend <= '{1'b1, cr_d_addr, mem_start_addr_d};
        // `LOG_D($sformatf("saving pending request; with core addr byte at 0x%5h", cr_addr<<2));
    end else if (cr_pend.active && (state == IC_READY)) begin
        cr_pend <= '{1'b0, 'h0, 'h0};
    end
end

parameter unsigned CNT_WIDTH = $clog2(MEM_TRANSFERS_PER_CL);
logic [CNT_WIDTH-1:0] mem_bus_cnt;
`DFF_CI_RI_RVI_EN(req_mem.valid, (mem_bus_cnt + 'h1), mem_bus_cnt)
logic [CNT_WIDTH-1:0] mem_bus_cnt_d;
`DFF_CI_RI_RVI(mem_bus_cnt, mem_bus_cnt_d)

logic mem_transfer_done;
assign mem_transfer_done =
    (rsp_mem.valid && (mem_bus_cnt_d == (MEM_TRANSFERS_PER_CL - 1)));

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < SETS; i++) begin
            arr[way_idx].cl[i].valid <= 1'b0;
        end
    end else if (rsp_mem.valid) begin // loading cache line from mem
        arr[way_idx]
            .cl[get_idx(cr_pend.addr)]
            .data[(MEM_DATA_BUS*mem_bus_cnt_d) +: MEM_DATA_BUS] <= rsp_mem.data;
        // on the last transfer, update valid and tag
        if (mem_transfer_done) begin
            arr[way_idx].cl[get_idx(cr_pend.addr)].valid <= 1'b1;
            arr[way_idx].cl[get_idx(cr_pend.addr)].tag <=
                (cr_pend.mem_start_addr >> (2 + INDEX_BITS));
        end
    end
end

// debug signals
logic dbg_serving_pending_req;
assign dbg_serving_pending_req =
    (cr_pend.active && !new_core_req_d) && rsp_core.valid;

logic [CORE_ADDR_BUS_B-1:0] dbg_req_core_bytes;
assign dbg_req_core_bytes = cr_addr<<2;

logic [CORE_ADDR_BUS_B-1:0] dbg_req_core_bytes_valid;
assign dbg_req_core_bytes_valid = (
    (cr_addr<<2) & {CORE_ADDR_BUS_B{req_core.valid}});

// state transition
`DFF_CI_RI_RV(IC_RESET, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    case (state)
        IC_RESET: begin
            nx_state = IC_READY;
            // `LOG_D($sformatf(">> I$ STATE IC_RESET"));
        end

        IC_READY: begin
            // `LOG_D($sformatf(">> I$ STATE IC_READY"));
            if ((new_core_req_d) && (!hit_d)) begin
                nx_state = IC_MISS;
                // `LOG_D($sformatf(">> I$ next state: IC_MISS; missed on core addr byte: 0x%0h", cr_addr<<2));
            end
        end

        IC_MISS: begin
            // `LOG_D($sformatf(">> I$ STATE IC_MISS"));
            // `LOG_D($sformatf(">> I$ miss state; cnt %0d", mem_bus_cnt));
            if (mem_bus_cnt_d == (MEM_TRANSFERS_PER_CL - 1)) begin
                nx_state = IC_READY;
            end
        end

        default: ;

    endcase
end

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

    case (state)
        IC_RESET: begin
            rsp_core.valid = 1'b0;
            req_core.ready = 1'b0;
            req_mem.valid = 1'b0;
            rsp_mem.ready = 1'b0;
        end

        IC_READY: begin
            req_core.ready = 1'b1;
            if (cr_pend.active && !new_core_req_d) begin
                // service the pending request after miss
                rsp_core.valid = 1'b1;
                rsp_core.data = arr[way_idx]
                    .cl[get_idx(cr_pend.addr)]
                    .data[get_w_idx(cr_pend.addr) +: CORE_DATA_BUS];
                // `LOG_D($sformatf("icache OUT complete pending request; cache at word %0d; core at byte 0x%5h; with output %8h", get_w_idx(cr_pend.addr), cr_d_addr<<2, rsp_core.data));

            end else if (new_core_req_d) begin
                if (hit_d) begin
                    rsp_core.valid = 1'b1;
                    rsp_core.data = arr[way_idx]
                        .cl[get_idx(cr_d_addr)]
                        .data[get_w_idx(cr_d_addr) +: CORE_DATA_BUS];
                    // `LOG_D($sformatf("icache OUT hit; cache at word %0d; core at byte 0x%5h; with output %8h", get_idx(cr_d_addr), cr_d_addr<<2, rsp_core.data));

                end else begin
                    // handle miss, initiate memory read
                    // NOTE: doesn't check for main mem ready
                    // main mem is currently always ready to take in new request
                    req_core.ready = 1'b0;
                    rsp_mem.ready = 1'b1;
                    req_mem.valid = 1'b1;
                    req_mem.data = mem_start_addr_d;
                    // `LOG_D($sformatf("icache OUT H->M transition; core at byte 0x%5h; mem_start_addr_d: %0d 0x%5h", cr_d_addr<<2, mem_start_addr_d, mem_start_addr_d));
                end
            end
        end

        IC_MISS: begin
            // 1 clk at the end to wait in IC_MISS for last mem response
            if (mem_bus_cnt > 0) begin
                rsp_mem.ready = 1'b1;
                req_mem.valid = 1'b1;
                req_mem.data = (cr_pend.mem_start_addr + mem_bus_cnt);
                // `LOG_D($sformatf("icache miss OUT; bus packet: %0d", (cr_pend.mem_start_addr + mem_bus_cnt)));
            end
        end

        default: ;

    endcase
end

endmodule
