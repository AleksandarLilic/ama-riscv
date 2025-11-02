`include "ama_riscv_defines.svh"
`ifndef SYNTHESIS
`include "ama_riscv_tb_defines.svh"
`endif

module ama_riscv_dcache #(
    parameter unsigned SETS = 8,
    parameter unsigned WAYS = 2
)(
    input  logic clk,
    input  logic rst,
    rv_if_dc.RX  req_core,
    rv_if.TX     rsp_core,
    rv_if.TX     req_mem_r,
    rv_if_da.TX  req_mem_w,
    rv_if.RX     rsp_mem
);

// validate parameters
if (SETS < 1) begin: check_sets_size_min
    $error("dcache SETS < 1 - must be at least 1");
end

if (SETS > 1024) begin: check_sets_size_max
    $error("dcache SETS > 1024 - can't be bigger than the entire memory");
end

if (!is_pow2(SETS)) begin: check_sets_pow2
    $error("dcache SETS not power of 2");
end

if (WAYS > 32) begin: check_ways_size
    $error("dcache WAYS > 32 - currently not supported");
end

localparam unsigned IDX_BITS = $clog2(SETS);
localparam unsigned WAY_BITS = $clog2(WAYS);
localparam unsigned TAG_W = CORE_BYTE_ADDR_BUS - CACHE_LINE_BYTE_ADDR -IDX_BITS;
localparam unsigned IDX_RANGE_TOP = (SETS == 1) ? 1: IDX_BITS;

// just rename for clarity
`define DC_CR_ASSIGN \
    '{ \
        addr: req_core.addr, \
        wdata: req_core.wdata, \
        dtype: req_core.dtype, \
        rtype: req_core.rtype, \
        way_idx: 'h0 \
    }

`define DC_CR_CLEAR \
    '{ \
        addr: 'h0, \
        wdata: 'h0, \
        dtype: DMEM_DTYPE_BYTE, \
        rtype: DMEM_READ, \
        way_idx: 'h0 \
    }

`define DC_CR_PEND_CLEAR '{active:1'b0, mem_r_start_addr:'h0, cr:`DC_CR_CLEAR}

// custom types
typedef enum logic [1:0] {
    DC_RESET,
    DC_READY, // ready for next request, services load hit in the next cycle
    DC_MISS, // miss, go to main memory
    DC_EVICT // write back dirty line to main memory, then go to miss
} dcache_state_t;

typedef union packed {
    logic [CACHE_LINE_SIZE-1:0] f; // flat view
    logic [CACHE_LINE_SIZE/MEM_DATA_BUS-1:0] [MEM_DATA_BUS-1:0] q; // mem bus
    logic [CACHE_LINE_SIZE/ARCH_WIDTH-1:0] [ARCH_WIDTH-1:0] w; // core
    // logic [CACHE_LINE_SIZE/16-1:0] [15:0] h; // half
    logic [CACHE_LINE_SIZE/8-1:0] [7:0] b; // byte
} cache_line_data_t;

typedef struct {
    logic valid;
    logic dirty;
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

typedef struct {
    cache_line_t set [SETS-1:0];
} cache_way_t;

typedef union packed {
    logic [ARCH_WIDTH-1:0] wdata;
    logic [ARCH_WIDTH/8-1:0] [7:0] b;
} core_data_t;

typedef struct packed {
    logic [CORE_BYTE_ADDR_BUS-1:0] addr;
    core_data_t wdata;
    dmem_dtype_t dtype;
    dmem_rtype_t rtype;
    logic [WAY_BITS-1:0] way_idx;
} core_request_t;

typedef struct packed {
    logic active;
    logic [MEM_ADDR_BUS-1:0] mem_r_start_addr;
    core_request_t cr;
} core_request_pending_t;

typedef struct packed {
    logic [WAY_BITS-1:0] way_idx;
    logic [IDX_RANGE_TOP-1:0] set_idx;
} lru_cnt_access_t;

// helper functions
function automatic [TAG_W-1:0]
get_tag(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    get_tag = addr[CORE_BYTE_ADDR_BUS-1 -: TAG_W]; // get top TAG_W bits
endfunction

function automatic [IDX_RANGE_TOP-1:0]
get_idx(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic  [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = (addr >> 6) & (SETS - 1);
    get_idx = masked[IDX_RANGE_TOP-1:0];
endfunction

function automatic [CORE_WORD_ADDR_BUS-1:0]
get_cl_word(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = (addr >> 2) & 'hf;
    get_cl_word = masked[CORE_WORD_ADDR_BUS-1:0];
endfunction

function automatic [CACHE_LINE_BYTE_ADDR-1:0]
get_cl_byte_idx(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = addr & CACHE_LINE_B_MASK[CORE_BYTE_ADDR_BUS-1:0];
    get_cl_byte_idx = masked[CACHE_LINE_BYTE_ADDR-1:0];
endfunction

function automatic [(ARCH_WIDTH/8)-1:0]
get_store_mask(input logic [1:0] dw);
    case ({1'b0, dw})
        DMEM_DTYPE_BYTE: get_store_mask = 4'b0001;
        DMEM_DTYPE_HALF: get_store_mask = 4'b0011;
        DMEM_DTYPE_WORD: get_store_mask = 4'b1111;
        default: get_store_mask = '0;
    endcase
endfunction

// implementation
cache_way_t way [WAYS-1:0];

core_request_t cr, cr_d;
core_request_pending_t cr_pend;
logic tag_match;
logic [TAG_W-1:0] tag_cr;
logic [IDX_RANGE_TOP-1:0] set_idx_cr;
logic [WAY_BITS-1:0] way_victim_idx, way_victim_idx_d;
logic new_core_req, new_core_req_d;
logic hit, hit_d;
logic cr_victim_dirty, cr_victim_dirty_d;
logic load_hit_req, store_hit_req, load_req_pending, store_req_pending;

if (WAYS == 1) begin: gen_direct_mapped
// wrap in always_comb to force functions to evaluate first
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    // hardwired values for direct-mapped
    way_victim_idx = '0;
    way_victim_idx_d = '0;
    // tag search
    tag_match = (way[cr.way_idx].set[set_idx_cr].tag == tag_cr);
    hit = &{tag_match, new_core_req, way[cr.way_idx].set[set_idx_cr].valid};
    cr_victim_dirty = way[cr.way_idx].set[set_idx_cr].dirty;
end

end else begin: gen_set_assoc
logic [WAY_BITS-1:0] lru_cnt [WAYS-1:0][SETS-1:0];
localparam unsigned LRU_MAX_CNT = WAYS - 1;
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    tag_match = 1'b0;
    way_victim_idx = '0;
    for (int w = 0; w < WAYS; w++) begin
        if (way[w].set[set_idx_cr].valid &&
            (way[w].set[set_idx_cr].tag == tag_cr)) begin
            tag_match = 1'b1;
            cr.way_idx = w;
        end else if (lru_cnt[w][set_idx_cr] == LRU_MAX_CNT) begin
            way_victim_idx = w;
        end
    end
    hit = &{tag_match, new_core_req, way[cr.way_idx].set[set_idx_cr].valid};
    cr_victim_dirty = way[way_victim_idx].set[set_idx_cr].dirty;
end
`DFF_CI_RI_RVI_EN(new_core_req, way_victim_idx, way_victim_idx_d)

// FIXME: it's still not matching ISA sim dcache model
// lru
lru_cnt_access_t lca;
always_comb begin
    if (load_req_pending || store_req_pending) begin
        lca.way_idx = cr_pend.cr.way_idx;
        lca.set_idx = get_idx(cr_pend.cr.addr);
    end else if (load_hit_req || store_hit_req) begin
        lca.way_idx = cr.way_idx;
        lca.set_idx = get_idx(cr.addr);
    end else begin
        lca = '{'h0, 'h0};
    end
end

logic update_lru;
assign update_lru =
    load_hit_req || store_hit_req || load_req_pending || store_req_pending;

always_ff @(posedge clk) begin
    if (rst) begin
        for (int w = 0; w < WAYS; w++) begin
            for (int s = 0; s < SETS; s++) begin
                lru_cnt[w][s] <= w; // init LRU to way idx
            end
        end
    end else if (update_lru) begin
        for (int w = 0; w < WAYS; w++) begin
            // if LRU counter is less than the one that hit, increment it
            // no need to make cnt saturating - can't increment last lru
            if (lru_cnt[w][lca.set_idx] < lru_cnt[lca.way_idx][lca.set_idx])
            begin
                lru_cnt[w][lca.set_idx] <= lru_cnt[w][lca.set_idx] + 1;
            end
        end
        // hit way becomes LRU 0
        lru_cnt[lca.way_idx][lca.set_idx] <= '0;
    end
end
end

assign new_core_req = (req_core.valid && req_core.ready);
`DFF_CI_RI_RVI(new_core_req, new_core_req_d)
`DFF_CI_RI_RV_EN(`DC_CR_CLEAR, new_core_req, cr, cr_d);
`DFF_CI_RI_RVI_EN(new_core_req, hit, hit_d)
`DFF_CI_RI_RVI_EN(new_core_req, cr_victim_dirty, cr_victim_dirty_d)

// cache line (64B) to mem bus (16B) addressing, from core addr (1B)
logic [MEM_ADDR_BUS-1:0] mem_r_start_addr_d; // addr aligned to first mem block
assign mem_r_start_addr_d = (cr_d.addr >> 4) & ~'b11;

logic save_pending, clear_pending_on_write, clear_pending_on_read;
dcache_state_t state, nx_state;
always_ff @(posedge clk) begin
    if (rst) begin
        cr_pend <= `DC_CR_PEND_CLEAR;
    end else if (save_pending) begin
        cr_pend = '{
            active: 1'b1,
            mem_r_start_addr: mem_r_start_addr_d,
            cr: '{
                addr: cr_d.addr,
                wdata: cr_d.wdata,
                dtype: cr_d.dtype,
                rtype: cr_d.rtype,
                way_idx: way_victim_idx_d
            }
        };
        // `LOG_D($sformatf("saving pending request; with core addr byte at 0x%5h", cr.addr));
    end else if (clear_pending_on_read || clear_pending_on_write) begin
        cr_pend <= `DC_CR_PEND_CLEAR;
    end
end

localparam unsigned CNT_WIDTH = $clog2(MEM_TRANSFERS_PER_CL);
logic [CNT_WIDTH-1:0] mem_miss_cnt, mem_miss_cnt_d;
logic [CNT_WIDTH-1:0] mem_evict_cnt;
`DFF_CI_RI_RVI_EN(req_mem_r.valid, (mem_miss_cnt + 'h1), mem_miss_cnt)
`DFF_CI_RI_RVI(mem_miss_cnt, mem_miss_cnt_d)
`DFF_CI_RI_RVI_EN(req_mem_w.valid, (mem_evict_cnt + 'h1), mem_evict_cnt)

logic mem_r_transfer_done, mem_r_transfer_done_d;
assign mem_r_transfer_done =
    (rsp_mem.valid && (mem_miss_cnt_d == (MEM_TRANSFERS_PER_CL - 1)));
`DFF_CI_RI_RVI(mem_r_transfer_done, mem_r_transfer_done_d)

logic [IDX_RANGE_TOP-1:0] set_idx_pend;
assign set_idx_pend = get_idx(cr_pend.cr.addr);
logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx_pend;
assign byte_idx_pend = get_cl_byte_idx(cr_pend.cr.addr);
logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx_cr;
assign byte_idx_cr = get_cl_byte_idx(cr.addr);

assign load_hit_req = (hit && (cr.rtype == DMEM_READ) && new_core_req);
assign store_hit_req = (hit && (cr.rtype == DMEM_WRITE) && new_core_req);
assign load_req_pending = (
    mem_r_transfer_done_d && cr_pend.active && (cr_pend.cr.rtype == DMEM_READ)
);
assign store_req_pending = (
    mem_r_transfer_done_d && cr_pend.active && (cr_pend.cr.rtype == DMEM_WRITE)
);

logic [(ARCH_WIDTH/8)-1:0] store_mask;
always_ff @(posedge clk) begin
    if (rst) begin
        for (int w = 0; w < WAYS; w++) begin
            for (int s = 0; s < SETS; s++) begin
                way[w].set[s].valid <= 1'b0;
                way[w].set[s].dirty <= 1'b0;
                way[w].set[s].tag <= 'h0;
            end
        end
    clear_pending_on_write <= 1'b0;

    end else if (rsp_mem.valid) begin // loading cache line from mem
        way[cr_pend.cr.way_idx].set[set_idx_pend].data.q[mem_miss_cnt_d] <=
            rsp_mem.data;
        // on the last transfer, update metadata
        if (mem_r_transfer_done) begin
            way[cr_pend.cr.way_idx].set[set_idx_pend].valid <= 1'b1;
            way[cr_pend.cr.way_idx].set[set_idx_pend].dirty <= 1'b0;
            way[cr_pend.cr.way_idx].set[set_idx_pend].tag <=
                (cr_pend.mem_r_start_addr >> (2 + IDX_BITS));
        end
    clear_pending_on_write <= 1'b0;

    end else if (store_req_pending) begin
        // store pending req once eviction & miss on write-allocate are done
        store_mask = get_store_mask(cr_pend.cr.dtype[1:0]);
        // `LOG_D($sformatf("dcache write pending request; in cache line at byte idx %0d; core at byte 0x%5h; with input %8h; store_mask %b", byte_idx_pend, cr_pend.cr.addr, cr_pend.cr.wdata, store_mask));
        for (int i = 0; i < ARCH_WIDTH/8; i++) begin
            if (store_mask[i]) begin
                way[cr_pend.cr.way_idx]
                    .set[set_idx_pend]
                    .data.b[byte_idx_pend + i] <= cr_pend.cr.wdata.b[i];
            end
        end
        way[cr_pend.cr.way_idx].set[set_idx_pend].dirty <= 1'b1;
        clear_pending_on_write <= 1'b1;

    end else if (store_hit_req) begin
        store_mask = get_store_mask(cr.dtype[1:0]);
        // `LOG_D($sformatf("dcache write hit; in cache line at byte idx %0d; core at byte 0x%5h; with input %8h; store_mask %b", byte_idx_cr, cr.addr, cr.wdata, store_mask));
        for (int i = 0; i < ARCH_WIDTH/8; i++) begin
            if (store_mask[i]) begin
                way[cr.way_idx].set[set_idx_cr].data.b[byte_idx_cr + i] <=
                    cr.wdata.b[i];
            end
        end
        way[cr.way_idx].set[set_idx_cr].dirty <= 1'b1;
        clear_pending_on_write <= 1'b0;

    end else begin
        clear_pending_on_write <= 1'b0;
    end
end

`ifdef DBG_SIG
logic dbg_serving_pending_req;
assign dbg_serving_pending_req =
    (cr_pend.active && !new_core_req_d) && rsp_core.valid;

logic [CORE_BYTE_ADDR_BUS-1:0] dbg_req_core_bytes_valid;
assign dbg_req_core_bytes_valid =
    ((cr.addr) & {CORE_BYTE_ADDR_BUS{req_core.valid}});

if (SETS > 1) begin: dbg_s2p // 2 plus sets
typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [IDX_BITS-1:0] set_idx;
    logic [5:0] byte_addr;
} dbg_core_addr_t;
dbg_core_addr_t dbg_core_addr;
assign dbg_core_addr = cr.addr;

end else begin: dbg_s1 // 1 set
typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [5:0] byte_addr;
} dbg_core_addr_t;
dbg_core_addr_t dbg_core_addr;
assign dbg_core_addr = cr.addr;
end

`endif

// state transition
`DFF_CI_RI_RV(DC_RESET, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    case (state)
        DC_RESET: begin
            nx_state = DC_READY;
            // `LOG_D($sformatf(">> D$ STATE DC_RESET"));
        end

        DC_READY: begin
            // `LOG_D($sformatf(">> D$ STATE DC_READY"));
            if ((new_core_req_d) && (!hit_d)) begin
                // `LOG_D($sformatf(">> D$: %0s", (cr_d.rtype == DMEM_READ) ? "replace on miss" : "write-allocate on miss"));
                if (cr_victim_dirty_d) begin
                    nx_state = DC_EVICT;
                    // `LOG_D($sformatf(">> D$ next state: DC_EVICT; dirty line, need to evict first; missed on core addr byte: 0x%0h", cr_d.addr));
                end else begin
                    // go to miss state directly
                    nx_state = DC_MISS;
                    // `LOG_D($sformatf(">> D$ next state: DC_MISS; missed on core addr byte: 0x%0h", cr_d.addr));
                end
            end
        end

        DC_MISS: begin
            // `LOG_D($sformatf(">> D$ STATE DC_MISS"));
            // `LOG_D($sformatf(">> D$ miss state; cnt %0d", mem_miss_cnt));
            if (cr_pend.cr.rtype == DMEM_WRITE) begin
                if (clear_pending_on_write) nx_state = DC_READY;
            end else begin
                if (mem_miss_cnt_d == (MEM_TRANSFERS_PER_CL - 1)) begin
                    nx_state = DC_READY;
                end
            end
        end

        DC_EVICT: begin
            // same as miss, just writing to mem instead of reading
            // `LOG_D($sformatf(">> D$ STATE DC_EVICT"));
            // `LOG_D($sformatf(">> D$ evict state; cnt %0d", mem_evict_cnt));
            if (mem_evict_cnt == (MEM_TRANSFERS_PER_CL - 1)) begin
                nx_state = DC_MISS;
            end
        end

        default: ;

    endcase
end

logic serve_pending_load;
assign serve_pending_load =
    (cr_pend.active && !new_core_req_d && (cr_pend.cr.rtype == DMEM_READ));
logic hit_d_load;
assign hit_d_load = (hit_d && new_core_req_d && (cr_d.rtype == DMEM_READ));

logic [ARCH_WIDTH-1:0] data_out;
logic [IDX_RANGE_TOP-1:0] set_idx;
logic [WAY_BITS-1:0] way_idx;
logic [CORE_WORD_ADDR_BUS-1:0] word_idx;
dmem_dtype_t dtype;
logic [1:0] rd_offset;
logic [MEM_ADDR_BUS-1:0] victim_wb_start_addr;
logic [MEM_DATA_BUS-1:0] victim_wb_data;
// outputs
always_comb begin
    // to/from core
    rsp_core.valid = 1'b0;
    req_core.ready = 1'b0;
    // read from mem
    req_mem_r.valid = 1'b0;
    req_mem_r.data = 'h0;
    rsp_mem.ready = 1'b0;
    // write to mem
    req_mem_w.valid = 1'b0;
    req_mem_w.addr = 'h0;
    req_mem_w.wdata = 'h0;
    // others
    data_out = 'h0;
    dtype = DMEM_DTYPE_BYTE;
    rd_offset = 'h0;
    victim_wb_start_addr = 'h0;
    victim_wb_data = 'h0;
    clear_pending_on_read = 1'b0;
    save_pending = 1'b0;
    set_idx = 'h0;
    word_idx = 'h0;
    way_idx = 'h0;

    case (state)
        DC_RESET: begin
            rsp_core.valid = 1'b0;
            req_core.ready = 1'b0;
            req_mem_r.valid = 1'b0;
            rsp_mem.ready = 1'b0;
        end

        DC_READY: begin
            req_core.ready = 1'b1;
            if (serve_pending_load) begin
                // service the pending request after miss
                rsp_core.valid = 1'b1;
                set_idx = get_idx(cr_pend.cr.addr);
                word_idx = get_cl_word(cr_pend.cr.addr);
                way_idx = cr_pend.cr.way_idx;
                dtype = cr_pend.cr.dtype;
                rd_offset = cr_pend.cr.addr[1:0];
                // `LOG_D($sformatf("dcache OUT complete pending request; cache at word idx %0d; core at byte 0x%5h", (get_cl_word(cr_pend.cr.addr)), cr_d.addr));
                clear_pending_on_read = 1'b1;

            end else if (new_core_req_d) begin
                if (hit_d_load) begin
                    rsp_core.valid = 1'b1;
                    set_idx = get_idx(cr_d.addr);
                    word_idx = get_cl_word(cr_d.addr);
                    way_idx = cr_d.way_idx;
                    dtype = cr_d.dtype;
                    rd_offset = cr_d.addr[1:0];
                    // `LOG_D($sformatf("dcache OUT hit; cache at word idx %0d; core at byte 0x%5h", (get_cl_word(cr_d.addr)), cr_d.addr));

                end else if (!hit_d) begin
                    // whether read or write request, on miss go to mem
                    // NOTE: doesn't check for main mem ready
                    // main mem is currently always ready to take in new request
                    req_core.ready = 1'b0;
                    save_pending = 1'b1;
                    set_idx = get_idx(cr_d.addr);
                    if (cr_victim_dirty_d) begin
                        if (SETS == 1) begin
                            victim_wb_start_addr =
                                {way[way_victim_idx_d].set[set_idx].tag, 2'b00};
                        end else begin
                            victim_wb_start_addr = {
                                way[way_victim_idx_d].set[set_idx].tag,
                                set_idx,
                                2'b00
                            };
                        end
                        // start eviction, initiate memory write
                        victim_wb_data =
                            way[way_victim_idx_d].set[set_idx].data.q[0];
                        req_mem_w.valid = 1'b1;
                        req_mem_w.addr = victim_wb_start_addr;
                        req_mem_w.wdata = victim_wb_data;
                        // `LOG_D($sformatf("dcache OUT R->E transition; evicting dirty line; cache at word %0d; core at byte 0x%5h; victim_wb_start_addr: %0d 0x%5h; victim_wb_data: %32h", (get_cl_word(cr_d.addr)), cr_d.addr, victim_wb_start_addr, victim_wb_start_addr, victim_wb_data));

                    end else begin
                        // start miss handling, initiate memory read
                        rsp_mem.ready = 1'b1;
                        req_mem_r.valid = 1'b1;
                        req_mem_r.data = mem_r_start_addr_d;
                        // `LOG_D($sformatf("dcache OUT R->M transition; core at byte 0x%5h; mem_r_start_addr_d: %0d 0x%5h", cr_d.addr, mem_r_start_addr_d, mem_r_start_addr_d));
                    end
                end
            end
            if (serve_pending_load || hit_d_load) begin
                data_out = way[way_idx].set[set_idx].data.w[word_idx];
                // `LOG_D($sformatf("dcache data out: %8h", data_out));
            end
        end

        DC_MISS: begin
            // 1 clk at the end to wait in DC_MISS for last mem response
            if (mem_miss_cnt > 0) begin
                rsp_mem.ready = 1'b1;
                req_mem_r.valid = 1'b1;
                req_mem_r.data = (cr_pend.mem_r_start_addr + mem_miss_cnt);
                // `LOG_D($sformatf("dcache miss OUT; bus packet: %0d", (cr_pend.mem_r_start_addr + mem_miss_cnt)));
            end
        end

        DC_EVICT: begin
            set_idx = get_idx(cr_d.addr);
            if (SETS == 1) begin
                victim_wb_start_addr =
                    {way[way_victim_idx_d].set[set_idx].tag, 2'b00};
            end else begin
                victim_wb_start_addr =
                    {way[way_victim_idx_d].set[set_idx].tag, set_idx, 2'b00};
            end
            victim_wb_data =
                way[way_victim_idx_d].set[set_idx].data.q[mem_evict_cnt];
            req_mem_w.valid = 1'b1;
            req_mem_w.addr = victim_wb_start_addr + mem_evict_cnt;
            req_mem_w.wdata = victim_wb_data;
            // `LOG_D($sformatf("dcache evict OUT; bus packet: %0d 0x%5h; victim_wb_start_addr: %0d 0x%5h; victim_wb_data: %32h", (victim_wb_start_addr + mem_evict_cnt), (victim_wb_start_addr + mem_evict_cnt), victim_wb_start_addr, victim_wb_start_addr, victim_wb_data));
            if (mem_evict_cnt == (MEM_TRANSFERS_PER_CL - 1)) begin
                // initiate miss with the last writeback
                rsp_mem.ready = 1'b1;
                req_mem_r.valid = 1'b1;
                req_mem_r.data = mem_r_start_addr_d;
            end
        end

        default: ;

    endcase
end

// shift data as/if needed
logic [ 1:0] load_dw;
logic        load_ds;
assign load_dw = dtype[1:0];
assign load_ds = dtype[2]; // 0: signed, 1: unsigned

// Check unaligned access
logic unaligned_access_h;
logic unaligned_access_w;
logic unaligned_access;
assign unaligned_access_h =
    ((load_dw == DMEM_DTYPE_HALF) &&
     ((rd_offset == `DMEM_BYTE_OFF_1) || (rd_offset == `DMEM_BYTE_OFF_3)));
assign unaligned_access_w =
    ((load_dw == DMEM_DTYPE_WORD) && (rd_offset != `DMEM_BYTE_OFF_0));
assign unaligned_access = /* en && */ (unaligned_access_h || unaligned_access_w);

// Shift mask
always_comb begin
    rsp_core.data = 'h0;
    if (/* en && */ !unaligned_access) begin
        case (load_dw)
            DMEM_DTYPE_BYTE: begin
                rsp_core.data[ 7: 0] = data_out[rd_offset*8 +:  8];
                rsp_core.data[31: 8] =
                    load_ds ? {24{1'b0}} : {24{data_out[rd_offset*8 +  7]}};
            end

            DMEM_DTYPE_HALF: begin
                rsp_core.data[15: 0] = data_out[rd_offset*8 +: 16];
                rsp_core.data[31:16] =
                    load_ds ? {16{1'b0}} : {16{data_out[rd_offset*8 + 15]}};
            end

            DMEM_DTYPE_WORD: begin
                rsp_core.data = data_out;
            end

            default: begin
                rsp_core.data = 'h0;
            end

        endcase
    end /* else begin
        TODO: raise exception for unaligned access
    end */
end

endmodule
