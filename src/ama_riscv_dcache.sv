`include "ama_riscv_defines.svh"
`ifndef SYNT
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

typedef struct packed {
    logic [CORE_BYTE_ADDR_BUS-1:0] addr;
    logic [ARCH_WIDTH-1:0] wdata;
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
    dmem_dtype_t dtype;
    logic [WAY_BITS-1:0] way_idx;
    logic [IDX_RANGE_TOP-1:0] set_idx;
    logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx;
    logic [ARCH_WIDTH-1:0] wdata;
} store_to_cache_t;

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
logic a_valid [WAYS-1:0][SETS-1:0];
logic a_dirty [WAYS-1:0][SETS-1:0];
logic [TAG_W-1:0] a_tag [WAYS-1:0][SETS-1:0];
cache_line_data_t a_data [WAYS-1:0][SETS-1:0];

core_request_t cr, cr_d;
core_request_pending_t cr_pend;
logic tag_match;
logic [TAG_W-1:0] tag_cr;
logic [IDX_RANGE_TOP-1:0] set_idx_cr;
logic [WAY_BITS-1:0] way_victim_idx, way_victim_idx_d;
logic new_core_req, new_core_req_d;
logic hit, hit_d;
logic cr_victim_dirty, cr_victim_dirty_d;
logic load_req_hit, store_req_hit, load_req_pending, store_req_pending;

if (WAYS == 1) begin: gen_dmap
// wrap in always_comb to force functions to evaluate first
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    // hardwired values for direct-mapped
    way_victim_idx = '0;
    way_victim_idx_d = '0;
    // tag search
    tag_match = (a_tag[cr.way_idx][set_idx_cr] == tag_cr);
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
    cr_victim_dirty = a_dirty[cr.way_idx][set_idx_cr];
end

end else begin: gen_assoc

logic [WAY_BITS-1:0] a_lru [WAYS-1:0][SETS-1:0];
localparam unsigned LRU_MAX_CNT = WAYS - 1;
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    tag_match = 1'b0;
    way_victim_idx = '0;
    for (int w = 0; w < WAYS; w++) begin
        if (a_valid[w][set_idx_cr] && (a_tag[w][set_idx_cr] == tag_cr)) begin
            tag_match = 1'b1;
            cr.way_idx = w;
        end else if (a_lru[w][set_idx_cr] == LRU_MAX_CNT) begin
            way_victim_idx = w;
        end
    end
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
    cr_victim_dirty = a_dirty[way_victim_idx][set_idx_cr];
end
`DFF_CI_RI_RVI_EN(new_core_req, way_victim_idx, way_victim_idx_d)

// FIXME: it's still not matching ISA sim dcache model
// lru
lru_cnt_access_t lca;
always_comb begin
    if (load_req_pending || store_req_pending) begin
        lca.way_idx = cr_pend.cr.way_idx;
        lca.set_idx = get_idx(cr_pend.cr.addr);
    end else if (load_req_hit || store_req_hit) begin
        lca.way_idx = cr.way_idx;
        lca.set_idx = get_idx(cr.addr);
    end else begin
        lca = '{'h0, 'h0};
    end
end

logic update_lru;
assign update_lru =
    load_req_hit || store_req_hit || load_req_pending || store_req_pending;

always_ff @(posedge clk) begin
    if (rst) begin
        for (int w = 0; w < WAYS; w++) begin
            for (int s = 0; s < SETS; s++) begin
                a_lru[w][s] <= w; // init LRU to way idx
            end
        end
    end else if (update_lru) begin
        for (int w = 0; w < WAYS; w++) begin
            // if LRU counter is less than the one that hit, increment it
            // no need to make cnt saturating - can't increment last lru
            if (a_lru[w][lca.set_idx] < a_lru[lca.way_idx][lca.set_idx]) begin
                a_lru[w][lca.set_idx] <= a_lru[w][lca.set_idx] + 1;
            end
        end
        // hit way becomes LRU 0
        a_lru[lca.way_idx][lca.set_idx] <= '0;
    end
end

end // gen_dmap/assoc

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

assign load_req_hit = (hit && (cr.rtype == DMEM_READ) && new_core_req);
assign store_req_hit = (hit && (cr.rtype == DMEM_WRITE) && new_core_req);
assign load_req_pending = (
    mem_r_transfer_done_d && cr_pend.active && (cr_pend.cr.rtype == DMEM_READ)
);
assign store_req_pending = (
    mem_r_transfer_done_d && cr_pend.active && (cr_pend.cr.rtype == DMEM_WRITE)
);

logic [IDX_RANGE_TOP-1:0] set_idx_pend;
logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx_pend;
logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx_cr;
assign set_idx_pend = get_idx(cr_pend.cr.addr);
assign byte_idx_pend = get_cl_byte_idx(cr_pend.cr.addr);
assign byte_idx_cr = get_cl_byte_idx(cr.addr);

store_to_cache_t stc;
always_comb begin
    if (store_req_pending || rsp_mem.valid) begin
        stc.dtype = cr_pend.cr.dtype;
        stc.way_idx = cr_pend.cr.way_idx;
        stc.set_idx = set_idx_pend;
        stc.byte_idx = byte_idx_pend;
        stc.wdata = cr_pend.cr.wdata;
    end else begin // store_req_hit
        stc.dtype = cr.dtype;
        stc.way_idx = cr.way_idx;
        stc.set_idx = set_idx_cr;
        stc.byte_idx = byte_idx_cr;
        stc.wdata = cr.wdata;
    end
end

logic [(ARCH_WIDTH/8)-1:0] store_mask_b;
assign store_mask_b = get_store_mask(stc.dtype[1:0]);

logic [MEM_DATA_BUS_B-1:0] store_mask_q, store_mask_core;
assign store_mask_core = {12'h0, store_mask_b} << stc.byte_idx[3:0];
assign store_mask_q = rsp_mem.valid ? 16'hffff : store_mask_core;

logic [MEM_DATA_BUS-1:0] store_data_q, store_data_core;
logic [7:0] store_shift_core;
assign store_shift_core = (stc.byte_idx[3:0] << 3);
assign store_data_core = {96'h0, stc.wdata} << store_shift_core;
assign store_data_q = rsp_mem.valid ? rsp_mem.data : store_data_core;

logic [1:0] stc_byte_idx_top;
assign stc_byte_idx_top = rsp_mem.valid ? mem_miss_cnt_d : stc.byte_idx[5:4];

logic [TAG_W-1:0] tag_pend;
assign tag_pend = (cr_pend.mem_r_start_addr >> (2 + IDX_BITS));

always_ff @(posedge clk) begin
    if (rst) begin
        for (int w = 0; w < WAYS; w++) begin
            for (int s = 0; s < SETS; s++) begin
                a_valid[w][s] <= 1'b0;
                a_dirty[w][s] <= 1'b0;
                a_tag[w][s] <= 'h0;
            end
        end

    end else if (rsp_mem.valid || store_req_pending || store_req_hit) begin
        for (int i = 0; i < MEM_DATA_BUS_B; i++) begin
            if (store_mask_q[i]) begin
                a_data[stc.way_idx][stc.set_idx]
                    .q[stc_byte_idx_top][i<<3 +: 8] <= store_data_q[i<<3 +: 8];
            end
        end
        if (mem_r_transfer_done) begin
            a_valid[stc.way_idx][stc.set_idx] <= 1'b1;
            a_dirty[stc.way_idx][stc.set_idx] <= 1'b0;
            a_tag[stc.way_idx][stc.set_idx] <= tag_pend;
        end
        if (store_req_pending || store_req_hit) begin
            a_dirty[stc.way_idx][stc.set_idx] <= 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) clear_pending_on_write <= 1'b0;
    else if (store_req_pending) clear_pending_on_write <= 1'b1;
    else clear_pending_on_write <= 1'b0;
end

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

logic [ARCH_WIDTH-1:0] rd_data;
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
    rd_data = 'h0;
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
                                {a_tag[way_victim_idx_d][set_idx], 2'b00};
                        end else begin
                            victim_wb_start_addr = {
                                a_tag[way_victim_idx_d][set_idx],
                                set_idx,
                                2'b00
                            };
                        end
                        // start eviction, initiate memory write
                        victim_wb_data = a_data[way_victim_idx_d][set_idx].q[0];
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
                rd_data = a_data[way_idx][set_idx].w[word_idx];
                // `LOG_D($sformatf("dcache data out: %8h", rd_data));
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
                    {a_tag[way_victim_idx_d][set_idx], 2'b00};
            end else begin
                victim_wb_start_addr =
                    {a_tag[way_victim_idx_d][set_idx], set_idx, 2'b00};
            end
            victim_wb_data = a_data[way_victim_idx_d][set_idx].q[mem_evict_cnt];
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
logic load_uns;
logic [1:0] load_dw;
assign load_dw = dtype[1:0];
assign load_uns = dtype[2]; // 0: signed, 1: unsigned

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
logic [ARCH_WIDTH-1:0] data_out;
always_comb begin
    data_out = 'h0;
    if (/* en && */ !unaligned_access) begin
        case (load_dw)
            DMEM_DTYPE_BYTE: begin
                data_out[7:0] = rd_data[rd_offset*8 +: 8];
                data_out[31:8] =
                    load_uns ? {24{1'b0}} : {24{rd_data[rd_offset*8 + 7]}};
            end

            DMEM_DTYPE_HALF: begin
                data_out[15:0] = rd_data[rd_offset*8 +: 16];
                data_out[31:16] =
                    load_uns ? {16{1'b0}} : {16{rd_data[rd_offset*8 + 15]}};
            end

            DMEM_DTYPE_WORD: begin
                data_out = rd_data;
            end

            default: begin
                data_out = 'h0;
            end

        endcase
    end /* else begin
        TODO: raise exception for unaligned access
    end */
end

// TODO: core is currently always ready
// so rsp_core.ready is not used by core nor checked by dcache
// this violates RV interface, but is functionally fine for now
assign rsp_core.data = data_out;

`ifndef SYNT
`ifdef DEBUG

`include "ama_riscv_defines.svh"

logic dbg_serving_pending_req;
assign dbg_serving_pending_req =
    (cr_pend.active && !new_core_req_d) && rsp_core.valid;

logic [CORE_BYTE_ADDR_BUS-1:0] dbg_req_core_bytes_valid;
assign dbg_req_core_bytes_valid =
    ((cr.addr) & {CORE_BYTE_ADDR_BUS{req_core.valid}});

if (SETS > 1) begin: dbg_assoc // set-associative views

// data view
typedef struct {
    logic valid;
    logic dirty;
    logic [WAY_BITS-1:0] lru;
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

cache_line_t data_view [WAYS-1:0][SETS-1:0];
always_comb begin
    for (int w = 0; w < WAYS; w++) begin
        for (int s = 0; s < SETS; s++) begin
            data_view[w][s].valid <= a_valid[w][s];
            data_view[w][s].dirty <= a_dirty[w][s];
            data_view[w][s].tag <= a_tag[w][s];
            data_view[w][s].lru <= `DCACHE.gen_assoc.a_lru[w][s];
            data_view[w][s].data <= a_data[w][s];
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
assign core_addr_bd = cr.addr;

end else begin: dbg_dmap // direct-mapped views

// data view
typedef struct {
    logic valid;
    logic dirty;
    logic [TAG_W-1:0] tag;
    cache_line_data_t data;
} cache_line_t;

cache_line_t data_view [WAYS-1:0][SETS-1:0];
always_comb @(posedge clk) begin
    for (int w = 0; w < WAYS; w++) begin
        for (int s = 0; s < SETS; s++) begin
            data_view[w][s].valid <= a_valid[w][s];
            data_view[w][s].dirty <= a_dirty[w][s];
            data_view[w][s].tag <= a_tag[w][s];
            data_view[w][s].data <= a_data[w][s];
        end
    end
end

// address breakdown
typedef struct packed {
    logic [TAG_W-1:0] tag;
    logic [5:0] byte_addr;
} core_addr_bd_t;

core_addr_bd_t core_addr_bd;
assign core_addr_bd = cr.addr;

end
// xsim is not happy with only one `assign core_addr_bd` at the end, so 2 it is

`endif
`endif

endmodule
