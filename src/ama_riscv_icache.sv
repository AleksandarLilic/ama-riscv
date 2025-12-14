`include "ama_riscv_defines.svh"
`ifndef SYNT
`include "ama_riscv_tb_defines.svh"
`endif

module ama_riscv_icache #(
    parameter unsigned SETS = 4,
    parameter unsigned WAYS = 2
)(
    input  logic clk,
    input  logic rst,
    input  logic spec_wrong,
    rv_if.RX req_core,
    rv_if.TX rsp_core,
    rv_if.TX req_mem,
    rv_if.RX rsp_mem
);

//------------------------------------------------------------------------------
// setup

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

// params and defs
`define LPU localparam unsigned
// cache
`LPU IDX_BITS = $clog2(SETS);
`LPU WAY_BITS = $clog2(WAYS);
`LPU TAG_W = (CORE_BYTE_ADDR_BUS - CACHE_LINE_BYTE_ADDR - IDX_BITS);
`LPU IDX_RANGE_TOP = (SETS == 1) ? 1: IDX_BITS;
`LPU WORD_ADDR = $clog2(CACHE_LINE_SIZE / INST_WIDTH); // 4, to 32bit words
// cache banks
`LPU BANK_LINE_SIZE = MEM_DATA_BUS; // 128-bit, rename for clarity
`LPU BANK_ADDR = (IDX_BITS + $clog2(CACHE_LINE_SIZE / BANK_LINE_SIZE)); // i + 2
`LPU WORD_TO_BANK_LINE_RATIO = (BANK_LINE_SIZE / INST_WIDTH); // 4, 128 -> 32
`LPU WORD_IN_BANK_LINE_ADDR = $clog2(WORD_TO_BANK_LINE_RATIO); // 2
`LPU BANK_LINE_ADDR = (WORD_ADDR - WORD_IN_BANK_LINE_ADDR); // 4 - 2
// other
`LPU MEM_MISS_CNT_WIDTH = $clog2(MEM_TRANSFERS_PER_CL);

`define IC_CR_CLEAR '{addr: 'h0, way_idx: 'h0}
`define IC_CR_PEND_CLEAR '{active: 1'b0, mem_start_addr: 'h0, cr: `IC_CR_CLEAR}

// custom types
typedef enum logic [1:0] {
    IC_RESET,
    IC_READY, // ready for next request, services load hit in the next cycle
    IC_MISS // miss, go to main memory
} icache_state_t;

typedef struct packed {
    logic [CORE_WORD_ADDR_BUS-1:0] addr;
    logic [WAY_BITS-1:0] way_idx;
} core_request_t;

typedef struct packed {
    logic active;
    logic [MEM_ADDR_BUS-1:0] mem_start_addr;
    core_request_t cr;
} core_request_pending_t;

typedef struct packed {
    logic [WAY_BITS-1:0] way_idx;
    logic [IDX_RANGE_TOP-1:0] set_idx;
} lru_cnt_access_t;

// helper functions
function automatic [TAG_W-1:0]
get_tag(input logic [CORE_WORD_ADDR_BUS-1:0] addr);
    get_tag = addr[CORE_WORD_ADDR_BUS-1 -: TAG_W]; // get top TAG_W bits
endfunction

function automatic [IDX_RANGE_TOP-1:0]
get_idx(input logic [CORE_WORD_ADDR_BUS-1:0] addr);
    get_idx = (addr >> 4) & (SETS - 1);
endfunction

function automatic [WORD_ADDR-1:0]
get_cl_word(input logic [CORE_WORD_ADDR_BUS-1:0] addr);
    get_cl_word = addr[WORD_ADDR-1:0];
endfunction

//------------------------------------------------------------------------------
// implementation

//logic bank_en [WAYS-1:0];
logic bank_we [WAYS-1:0];
logic [BANK_ADDR-1:0] bank_addr;
logic [BANK_LINE_SIZE-1:0] bank_data [WAYS-1:0];

// mem array
genvar b;
generate
`IT_P_NT(b, WAYS) begin: gen_bank
    mem #(
        .DW (BANK_LINE_SIZE),
        .AW (BANK_ADDR)
    ) bank_i (
        .clk (clk),
        .en (1'b1), // better timing
        //.en (bank_en[b]), // lower power
        .we ({MEM_DATA_BUS_B{bank_we[b]}}),
        .addr (bank_addr),
        .din (rsp_mem.data),
        .dout (bank_data[b])
    );
end
endgenerate

// tag & valid arrays
logic a_valid [WAYS-1:0][SETS-1:0];
logic [TAG_W-1:0] a_tag [WAYS-1:0][SETS-1:0];

// state, tag matching, lru logic
icache_state_t state, nx_state;
core_request_t cr, cr_d;
core_request_pending_t cr_pend;
logic tag_match;
logic [TAG_W-1:0] tag_cr;
logic [IDX_RANGE_TOP-1:0] set_idx_cr;
logic [WAY_BITS-1:0] way_victim_idx, way_victim_idx_d;
logic new_core_req, new_core_req_d;
logic hit, hit_d;
logic load_req_hit, load_req_pend;

//------------------------------------------------------------------------------
// lookup and tag matching

if (WAYS == 1) begin: gen_dmap_lookup

// wrap in always_comb to force functions to evaluate first
always_comb begin
    cr.addr = req_core.data;
    cr.way_idx = 'h0;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    // hardwired values for direct-mapped
    way_victim_idx = '0;
    way_victim_idx_d = '0;
    // tag search
    tag_match = (a_tag[cr.way_idx][set_idx_cr] == tag_cr);
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
end

end else begin: gen_assoc_lookup

logic [WAY_BITS-1:0] a_lru [WAYS-1:0][SETS-1:0];
localparam unsigned LRU_MAX_CNT = WAYS - 1;
always_comb begin
    cr.addr = req_core.data;
    cr.way_idx = '0;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    tag_match = 1'b0;
    way_victim_idx = '0;
    `IT_P(w, WAYS) begin
        if (a_valid[w][set_idx_cr] && (a_tag[w][set_idx_cr] == tag_cr)) begin
            tag_match = 1'b1;
            cr.way_idx = w;
        end else if (a_lru[w][set_idx_cr] == LRU_MAX_CNT) begin
            way_victim_idx = w;
        end
    end
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
end
`DFF_CI_RI_RVI(way_victim_idx, way_victim_idx_d)

// lru
lru_cnt_access_t lca;
always_comb begin
    unique case (1'b1)
        load_req_pend: lca = '{cr_pend.cr.way_idx, get_idx(cr_pend.cr.addr)};
        load_req_hit: lca = '{cr.way_idx, get_idx(cr.addr)};
        default: lca = '{'h0, 'h0};
    endcase
end

logic update_lru;
assign update_lru = (load_req_hit || load_req_pend);
always_ff @(posedge clk) begin
    if (rst) begin
        `IT_P(w, WAYS) begin
            `IT_P(s, SETS) begin
                a_lru[w][s] <= w; // init LRU to way idx
            end
        end
    end else if (update_lru) begin
        `IT_P(w, WAYS) begin
            // if LRU counter is less than the one that hit, increment it
            // no need to make cnt saturating - can't increment last lru
            if (a_lru[w][lca.set_idx] < a_lru[lca.way_idx][lca.set_idx]) begin
                a_lru[w][lca.set_idx] <= (a_lru[w][lca.set_idx] + 1);
            end
        end
        // hit way becomes LRU 0
        a_lru[lca.way_idx][lca.set_idx] <= '0;
    end
end

end // gen_dmap/assoc

//------------------------------------------------------------------------------
// handling requests

assign new_core_req = (req_core.valid && (req_core.ready || spec_wrong));
`DFF_CI_RI_RVI(new_core_req, new_core_req_d)
`DFF_CI_RI_RV_EN(`IC_CR_CLEAR, new_core_req, cr, cr_d)
`DFF_CI_RI_RVI_EN(new_core_req, hit, hit_d)

// cache line (64B) to mem bus (16B) addressing, from core addr (4B)
logic [MEM_ADDR_BUS-1:0] mem_start_addr_d; // address aligned to first mem block
assign mem_start_addr_d = ((cr_d.addr >> 2) & (~'b11));

logic save_pending, clear_pending;
always_ff @(posedge clk) begin
    if (rst) begin
        cr_pend <= `IC_CR_PEND_CLEAR;
    end else if (save_pending) begin
        cr_pend <= '{
            active: 1'b1,
            mem_start_addr: mem_start_addr_d,
            cr: '{addr: cr_d.addr, way_idx: way_victim_idx_d}
        };
    end else if (clear_pending) begin
        cr_pend <= `IC_CR_PEND_CLEAR;
    end
end

logic [MEM_MISS_CNT_WIDTH-1:0] mem_miss_cnt, mem_miss_cnt_d;
`DFF_CI_RI_RVI_CLR_CLRVI_EN(
    spec_wrong, req_mem.valid, (mem_miss_cnt + 'h1), mem_miss_cnt)
`DFF_CI_RI_RVI(mem_miss_cnt, mem_miss_cnt_d)

logic mem_transfer_done, mem_transfer_done_d;
assign mem_transfer_done =
    (rsp_mem.valid && (mem_miss_cnt_d == (MEM_TRANSFERS_PER_CL - 1)));
`DFF_CI_RI_RVI(mem_transfer_done, mem_transfer_done_d)

assign load_req_hit = (hit && new_core_req);
assign load_req_pend = (mem_transfer_done_d && cr_pend.active);

//------------------------------------------------------------------------------
// addressing banks

logic [TAG_W-1:0] tag_pend;
assign tag_pend = (cr_pend.mem_start_addr >> (2 + IDX_BITS));

logic mem_to_cache_wr;
assign mem_to_cache_wr = (rsp_mem.valid && (state == IC_MISS) && !spec_wrong);
always_comb begin
    `IT_P(w, WAYS) begin
        bank_we[w] = 1'b0;
        if (mem_to_cache_wr) bank_we[w] = (w == cr_pend.cr.way_idx);
    end
end

logic [IDX_RANGE_TOP-1:0] set_idx, set_idx_pend;
logic [WAY_BITS-1:0] way_idx, way_idx_d;
logic [WORD_ADDR-1:0] word_idx, word_idx_d;

logic [BANK_ADDR-1:0] bank_addr_store, bank_addr_load;
logic [BANK_LINE_ADDR-1:0] bank_line_addr_load;
always_comb begin
    set_idx = get_idx(cr.addr);
    word_idx = get_cl_word(cr.addr);
    way_idx = cr.way_idx;
    if (cr_pend.active && !clear_pending) begin
        set_idx = get_idx(cr_pend.cr.addr);
        word_idx = get_cl_word(cr_pend.cr.addr);
        way_idx = cr_pend.cr.way_idx;
    end
    bank_line_addr_load = word_idx[(WORD_ADDR-1) -: BANK_LINE_ADDR];
    bank_addr_load = {set_idx, bank_line_addr_load};
    set_idx_pend = get_idx(cr_pend.cr.addr);
    bank_addr_store = {set_idx_pend, mem_miss_cnt_d};
    bank_addr = mem_to_cache_wr ? bank_addr_store : bank_addr_load;
    //`IT_P(w, WAYS) bank_en[w] = (w == way_idx);
end

`DFF_CI_RI_RVI(way_idx, way_idx_d)
`DFF_CI_RI_RVI(word_idx, word_idx_d)

//------------------------------------------------------------------------------
// tag and valid updates
always_ff @(posedge clk) begin
    if (rst) begin
        `IT_P(w, WAYS) begin
            `IT_P(s, SETS) begin
                a_valid[w][s] <= 1'b0;
                a_tag[w][s] <= 'h0;
            end
        end
    end else if (mem_to_cache_wr && mem_transfer_done) begin
        // on the last transfer, update valid and tag
        a_valid[cr_pend.cr.way_idx][set_idx_pend] <= 1'b1;
        a_tag[cr_pend.cr.way_idx][set_idx_pend] <= tag_pend;
    end else if (new_core_req && !hit) begin
        // invalidate line right away
        a_valid[way_victim_idx][set_idx_cr] = 1'b0;
    end
end

//------------------------------------------------------------------------------
// state transition
`DFF_CI_RI_RV(IC_RESET, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    case (state)
        IC_RESET: begin
            nx_state = IC_READY;
        end

        IC_READY: begin
            if (new_core_req_d && (!hit_d) && (!spec_wrong)) nx_state = IC_MISS;
        end

        IC_MISS: begin
            if (mem_transfer_done_d || spec_wrong) nx_state = IC_READY;
        end

        default: ;

    endcase
end

// outputs
logic [WORD_IN_BANK_LINE_ADDR-1:0] word_in_bank_line_addr;
assign word_in_bank_line_addr = word_idx_d[WORD_IN_BANK_LINE_ADDR-1:0];
assign rsp_core.data =
    bank_data[way_idx_d][(word_in_bank_line_addr*INST_WIDTH) +: INST_WIDTH];

always_comb begin
    // to/from core
    rsp_core.valid = 1'b0;
    req_core.ready = 1'b0;
    // to/from mem
    req_mem.valid = 1'b0;
    req_mem.data = 'h0;
    rsp_mem.ready = 1'b0;
    // others
    save_pending = 1'b0;
    clear_pending = 1'b0;

    case (state)
        IC_RESET: begin
            rsp_core.valid = 1'b0;
            req_core.ready = 1'b0;
            req_mem.valid = 1'b0;
            rsp_mem.ready = 1'b0;
        end

        IC_READY: begin
            req_core.ready = 1'b1;
            if (cr_pend.active) begin
                rsp_core.valid = 1'b1;
                clear_pending = 1'b1;

            end else if (new_core_req_d) begin
                if (hit_d) begin
                    rsp_core.valid = 1'b1;
                end else if (!spec_wrong) begin
                    // TODO: move all miss handling to MISS state (for timing)?
                    // handle miss, initiate memory read
                    // NOTE: doesn't check for main mem ready
                    // main mem is currently always ready to take in new request
                    req_core.ready = 1'b0;
                    rsp_mem.ready = 1'b1;
                    req_mem.valid = 1'b1;
                    req_mem.data = mem_start_addr_d;
                    save_pending = 1'b1;
                end
            end
        end

        IC_MISS: begin
            // 1 clk at the end to wait in IC_MISS for last mem response
            if (mem_miss_cnt > 0) begin
                rsp_mem.ready = 1'b1;
                req_mem.valid = 1'b1;
                req_mem.data = (cr_pend.mem_start_addr + mem_miss_cnt);
            end
            // if at any point during a speculative miss this turns out to be
            // wrong path, clear wrong pending request and go to ready
            clear_pending = spec_wrong;
        end

        default: ;

    endcase
end

//------------------------------------------------------------------------------
// debug views
`ifndef SYNT
`ifdef DEBUG

logic dbg_serving_pending_req;
assign dbg_serving_pending_req =
    ((cr_pend.active && !new_core_req_d) && rsp_core.valid);

logic [CORE_BYTE_ADDR_BUS-1:0] dbg_req_core_bytes;
assign dbg_req_core_bytes = (cr.addr << 2);

logic [CORE_BYTE_ADDR_BUS-1:0] dbg_req_core_bytes_valid;
assign dbg_req_core_bytes_valid =
    ((cr.addr << 2) & {CORE_BYTE_ADDR_BUS{req_core.valid}});

logic miss, miss_d;
assign miss = (new_core_req && !hit);
assign miss_d = (new_core_req_d && !hit_d);

if (WAYS > 1) begin: dbg_assoc // set-associative views

// data view
typedef struct {
    logic valid;
    logic [WAY_BITS-1:0] lru;
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

// proxy for convenience, but not for wave
cache_line_data_t d [WAYS-1:0][SETS-1:0];
genvar gw, gs;
`IT_P_NT(gw, WAYS) begin: gen_bank
    `IT_P_NT(gs, SETS) begin
        always_comb begin
            d[gw][gs].q[0] = `ICACHE.gen_bank[gw].bank_i.m[gs + 0];
            d[gw][gs].q[1] = `ICACHE.gen_bank[gw].bank_i.m[gs + 1];
            d[gw][gs].q[2] = `ICACHE.gen_bank[gw].bank_i.m[gs + 2];
            d[gw][gs].q[3] = `ICACHE.gen_bank[gw].bank_i.m[gs + 3];
        end
    end
end

cache_line_t data_view [WAYS-1:0][SETS-1:0];
always_comb begin
    `IT_P(w, WAYS) begin
        `IT_P(s, SETS) begin
            data_view[w][s].valid = a_valid[w][s];
            data_view[w][s].tag = a_tag[w][s];
            data_view[w][s].lru = `ICACHE.gen_assoc_lookup.a_lru[w][s];
            data_view[w][s].data = d[w][s];
        end
    end
end

// address breakdown
typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [IDX_BITS-1:0] set_idx;
    logic [5:0] byte_addr;
} core_addr_bd_t;

core_addr_bd_t core_addr_bd;
assign core_addr_bd = (cr.addr << 2);

end else begin: dbg_dmap // direct-mapped views

// data view
typedef struct {
    logic valid;
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

// proxy for convenience, but not for wave
cache_line_data_t d [SETS-1:0];
genvar gs;
`IT_P_NT(gs, SETS) begin
    always_comb begin
        d[gs].q[0] = `ICACHE.gen_bank[0].bank_i.m[gs + 0];
        d[gs].q[1] = `ICACHE.gen_bank[0].bank_i.m[gs + 1];
        d[gs].q[2] = `ICACHE.gen_bank[0].bank_i.m[gs + 2];
        d[gs].q[3] = `ICACHE.gen_bank[0].bank_i.m[gs + 3];
    end
end

cache_line_t data_view [SETS-1:0];
always_comb @(posedge clk) begin
    `IT_P(s, SETS) begin
        data_view[s].valid = a_valid[0][s];
        data_view[s].tag = a_tag[0][s];
        data_view[s].data = d[s];
    end
end

// address breakdown
typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [5:0] byte_addr;
} core_addr_bd_t;

core_addr_bd_t core_addr_bd;
assign core_addr_bd = (cr.addr << 2);

end
// xsim is not happy with only one `assign core_addr_bd` at the end, so 2 it is

`endif
`endif

endmodule
