`include "ama_riscv_defines.svh"
`include "ama_riscv_tb_defines.svh"

module ama_riscv_icache #(
    parameter int unsigned SETS = 4,
    parameter int unsigned WAYS = 2
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     req_core,
    rv_if.TX     rsp_core,
    rv_if.TX     req_mem,
    rv_if.RX     rsp_mem
);

// validate parameters
if (SETS < 1) begin: check_sets_size_min
    $error("icache SETS < 1 - must be at least 1");
end

if (SETS > 1024) begin: check_sets_size_max
    $error("icache SETS > 1024 - can't be bigger than the entire memory");
end

if (!is_pow2(SETS)) begin: check_sets_pow2
    $error("icache SETS not power of 2");
end

if (WAYS > 32) begin: check_ways_size
    $error("icache WAYS > 32 - currently not supported");
end

parameter int unsigned INDEX_BITS = $clog2(SETS);

// custom types
typedef union packed {
    logic [CACHE_LINE_SIZE-1:0] f; // flat view
    logic [CACHE_LINE_SIZE/MEM_DATA_BUS-1:0] [MEM_DATA_BUS-1:0] q; // mem bus
    logic [CACHE_LINE_SIZE/CORE_DATA_BUS-1:0] [CORE_DATA_BUS-1:0] w; // inst 32
    // logic [CACHE_LINE_SIZE/16-1:0] [15:0] h; // inst 16 (compressed isa)
    // logic [CACHE_LINE_SIZE/8-1:0] [7:0] b; // byte
} cache_line_data_t;

typedef struct {
    logic valid;
    logic [$clog2(WAYS)-1:0] lru_cnt; // optimized away for direct-mapped cache
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

typedef struct {
    cache_line_t set [SETS-1:0];
} cache_way_t;

typedef struct packed {
    logic active;
    logic [$clog2(WAYS)-1:0] way_idx;
    logic [CORE_ADDR_BUS_W-1:0] addr;
    logic [MEM_ADDR_BUS-1:0] mem_start_addr;
} core_request_pending_t;

// helper functions
function automatic [TAG_W-1:0]
get_tag(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_tag = (addr >> (4 + INDEX_BITS));
endfunction

function automatic [INDEX_BITS-1:0]
get_idx(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_idx = (addr >> 4) & (SETS - 1);
endfunction

function automatic [CORE_ADDR_BUS_W-1:0]
get_cl_word(input logic [CORE_ADDR_BUS_W-1:0] addr);
    get_cl_word = addr & 4'hf;
endfunction

// implementation
cache_way_t way [WAYS-1:0];

logic [CORE_ADDR_BUS_W-1:0] cr_addr, cr_d_addr;
assign cr_addr = req_core.data; // just rename for clarity

logic tag_match;
logic [TAG_W-1:0] tag_cr;
logic [$clog2(SETS)-1:0] set_idx_cr;
logic [$clog2(WAYS)-1:0] way_idx_cr, way_idx_cr_d;
logic [$clog2(WAYS)-1:0] way_victim_idx, way_victim_idx_d;

if (WAYS == 1) begin: direct_mapped_search
    // wrap in always_comb to force functions to evaluate first
    always_comb begin
        set_idx_cr = get_idx(cr_addr);
        tag_cr = get_tag(cr_addr);
        // hardwired values for direct-mapped
        way_idx_cr = '0;
        way_victim_idx = '0;
        way_idx_cr_d = '0;
        way_victim_idx_d = '0;
        // tag search
        tag_match = (way[way_idx_cr].set[set_idx_cr].tag == tag_cr);
    end

end else begin: set_associative_search
    logic [$clog2(WAYS)-1:0] victim_lru;
    always_comb begin
        set_idx_cr = get_idx(cr_addr);
        tag_cr = get_tag(cr_addr);
        tag_match = 1'b0;
        way_idx_cr = '0;
        victim_lru = '0;
        way_victim_idx = '0;
        for (int w = 0; w < WAYS; w++) begin
            if (way[w].set[set_idx_cr].tag == tag_cr) begin
                tag_match = 1'b1;
                way_idx_cr = w;
            end else if (way[w].set[set_idx_cr].lru_cnt >= victim_lru) begin
                victim_lru = way[w].set[set_idx_cr].lru_cnt;
                way_victim_idx = w;
            end
        end
    end

`DFF_CI_RI_RVI(way_idx_cr, way_idx_cr_d)
`DFF_CI_RI_RVI(way_victim_idx, way_victim_idx_d)
end

logic new_core_req, new_core_req_d;
assign new_core_req = (req_core.valid && req_core.ready);
`DFF_CI_RI_RVI(new_core_req, new_core_req_d)

logic hit, hit_d;
assign hit = &{tag_match, new_core_req, way[way_idx_cr].set[set_idx_cr].valid};
`DFF_CI_RI_RVI_EN(new_core_req, hit, hit_d)
`DFF_CI_RI_RVI_EN(new_core_req, cr_addr, cr_d_addr);

// cache line (64B) to mem bus (16B) addressing, from core addr (4B)
logic [MEM_ADDR_BUS-1:0] mem_start_addr_d; // address aligned to first mem block
assign mem_start_addr_d = (cr_d_addr >> 2) & ~'b11;

icache_state_t state, nx_state;
core_request_pending_t cr_pend;

logic save_pending, clear_pending;
always_ff @(posedge clk) begin
    if (rst) begin
        cr_pend <= '{1'b0, 'h0, 'h0, 'h0};
    end else if (save_pending) begin
        cr_pend <= '{1'b1, way_victim_idx_d, cr_d_addr, mem_start_addr_d};
        // `LOG_D($sformatf("saving pending request; with core addr byte at 0x%5h", cr_addr<<2));
    end else if (clear_pending) begin
        cr_pend <= '{1'b0, 'h0, 'h0, 'h0};
    end
end

parameter unsigned CNT_WIDTH = $clog2(MEM_TRANSFERS_PER_CL);
logic [CNT_WIDTH-1:0] mem_miss_cnt;
`DFF_CI_RI_RVI_EN(req_mem.valid, (mem_miss_cnt + 'h1), mem_miss_cnt)
logic [CNT_WIDTH-1:0] mem_miss_cnt_d;
`DFF_CI_RI_RVI(mem_miss_cnt, mem_miss_cnt_d)

logic mem_transfer_done;
assign mem_transfer_done =
    (rsp_mem.valid && (mem_miss_cnt_d == (MEM_TRANSFERS_PER_CL - 1)));

logic [$clog2(SETS)-1:0] set_idx_pend;
logic [$clog2(SETS)-1:0] set_idx_cr_d;
// no need to wrap with always_comb, outputs are used in always_ff only
assign set_idx_pend = get_idx(cr_pend.addr);
assign set_idx_cr_d = get_idx(cr_d_addr);

always_ff @(posedge clk) begin
    if (rst) begin
        for (int w = 0; w < WAYS; w++) begin
            for (int s = 0; s < SETS; s++) begin
                way[w].set[s].valid <= 1'b0;
                if (WAYS > 1) way[w].set[s].lru_cnt <= w; // init LRU to way idx
            end
        end
    end else if (rsp_mem.valid) begin // loading cache line from mem
        way[cr_pend.way_idx].set[set_idx_pend].data.q[mem_miss_cnt_d] <=
            rsp_mem.data;
        // on the last transfer, update valid and tag
        if (mem_transfer_done) begin
            way[cr_pend.way_idx].set[set_idx_pend].valid <= 1'b1;
            way[cr_pend.way_idx].set[set_idx_pend].tag <=
                (cr_pend.mem_start_addr >> (2 + INDEX_BITS));
        end
    end else if (new_core_req_d && hit_d) begin // update LRU on hit
        // optimized away for direct-mapped cache
        if (WAYS > 1) begin
            for (int w = 0; w < WAYS; w++) begin
                // if LRU counter is less than the one that hit, increment it
                // no need to make cnt saturating - can't increment last lru
                if (way[w].set[set_idx_cr_d].lru_cnt <
                    way[way_idx_cr_d].set[set_idx_cr_d].lru_cnt) begin
                    way[w].set[set_idx_cr_d].lru_cnt <=
                        way[w].set[set_idx_cr_d].lru_cnt + 1;
                end
            end
        // hit way becomes LRU 0
        way[way_idx_cr_d].set[set_idx_cr_d].lru_cnt <= '0;
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
            // `LOG_D($sformatf(">> I$ miss state; cnt %0d", mem_miss_cnt));
            if (mem_miss_cnt_d == (MEM_TRANSFERS_PER_CL - 1)) begin
                nx_state = IC_READY;
            end
        end

        default: ;

    endcase
end

// because reasons
logic [$clog2(SETS)-1:0] set_idx;
logic [15:0] word_idx;

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
    save_pending = 1'b0;
    clear_pending = 1'b0;
    set_idx = 'h0;
    word_idx = 'h0;

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
                set_idx = get_idx(cr_pend.addr);
                word_idx = get_cl_word(cr_pend.addr);
                rsp_core.valid = 1'b1;
                rsp_core.data =
                    way[cr_pend.way_idx].set[set_idx].data.w[word_idx];
                clear_pending = 1'b1;
                // `LOG_D($sformatf("icache OUT complete pending request; cache at word %0d; core at byte 0x%5h; with output %8h", get_cl_word(cr_pend.addr), cr_d_addr<<2, rsp_core.data));

            end else if (new_core_req_d) begin
                if (hit_d) begin
                    set_idx = get_idx(cr_d_addr);
                    word_idx = get_cl_word(cr_d_addr);
                    rsp_core.valid = 1'b1;
                    rsp_core.data =
                        way[way_idx_cr_d].set[set_idx].data.w[word_idx];
                    // `LOG_D($sformatf("icache OUT hit; cache at word %0d; core at byte 0x%5h; with output %8h", get_idx(cr_d_addr), cr_d_addr<<2, rsp_core.data));

                end else begin
                    // handle miss, initiate memory read
                    // NOTE: doesn't check for main mem ready
                    // main mem is currently always ready to take in new request
                    req_core.ready = 1'b0;
                    rsp_mem.ready = 1'b1;
                    req_mem.valid = 1'b1;
                    req_mem.data = mem_start_addr_d;
                    save_pending = 1'b1;
                    // `LOG_D($sformatf("icache OUT H->M transition; core at byte 0x%5h; mem_start_addr_d: %0d 0x%5h", cr_d_addr<<2, mem_start_addr_d, mem_start_addr_d));
                end
            end
        end

        IC_MISS: begin
            // 1 clk at the end to wait in IC_MISS for last mem response
            if (mem_miss_cnt > 0) begin
                rsp_mem.ready = 1'b1;
                req_mem.valid = 1'b1;
                req_mem.data = (cr_pend.mem_start_addr + mem_miss_cnt);
                // `LOG_D($sformatf("icache miss OUT; bus packet: %0d", (cr_pend.mem_start_addr + mem_miss_cnt)));
            end
        end

        default: ;

    endcase
end

endmodule
