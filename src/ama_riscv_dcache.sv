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
    rv_if_dc.RX req_core,
    rv_if.TX rsp_core,
    rv_if.TX req_mem_r,
    rv_if_da.TX req_mem_w,
    rv_if.RX rsp_mem
);

//------------------------------------------------------------------------------
// setup

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

// params and defs
`define LPU localparam unsigned
`LPU IDX_BITS = $clog2(SETS);
`LPU WAY_BITS = $clog2(WAYS);
`LPU TAG_W = CORE_BYTE_ADDR_BUS - CACHE_LINE_BYTE_ADDR -IDX_BITS;
`LPU IDX_RANGE_TOP = (SETS == 1) ? 1: IDX_BITS;
`LPU WORD_ADDR = $clog2(CACHE_LINE_SIZE_B / 4); // to 32bit words
// cache banks
`LPU BANK_LINE_SIZE = MEM_DATA_BUS; // 128-bit, rename for clarity
`LPU BANK_ADDR = (IDX_BITS + $clog2(CACHE_LINE_SIZE / BANK_LINE_SIZE)); // i + 2
`LPU WORD_TO_BANK_LINE_RATIO = (BANK_LINE_SIZE / INST_WIDTH); // 4, 128 -> 32
`LPU WORD_IN_BANK_LINE_ADDR = $clog2(WORD_TO_BANK_LINE_RATIO); // 2
`LPU BANK_LINE_ADDR = (WORD_ADDR - WORD_IN_BANK_LINE_ADDR); // 4 - 2
// store
`LPU STORE_PAD_WIDTH = (MEM_DATA_BUS - ARCH_WIDTH);
localparam [STORE_PAD_WIDTH-1:0] STORE_PAD = {STORE_PAD_WIDTH{1'b0}};
localparam [MEM_DATA_BUS_B-1:0] MEM_DATA_BUS_B_MASK = {MEM_DATA_BUS_B{1'b1}};
// other
`LPU MEM_MISS_CNT_WIDTH = $clog2(MEM_TRANSFERS_PER_CL);

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

`define DC_CR_PEND_CLEAR '{active: 1'b0, mem_start_addr: 'h0, cr: `DC_CR_CLEAR}

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
    logic [MEM_ADDR_BUS-1:0] mem_start_addr;
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
    dmem_dtype_t dtype;
    dmem_rtype_t rtype;
    logic [1:0] off;
    logic [WAY_BITS-1:0] way_idx;
    logic [IDX_RANGE_TOP-1:0] set_idx;
    logic [WORD_ADDR-1:0] word_idx;
} load_from_cache_t;

typedef struct packed {
    logic [WAY_BITS-1:0] way_idx;
    logic [IDX_RANGE_TOP-1:0] set_idx;
} lru_cnt_access_t;

typedef logic [MEM_MISS_CNT_WIDTH-1:0] mem_miss_cnt_t;
localparam mem_miss_cnt_t
    MEM_TRANSFER_MATCH_DONE = mem_miss_cnt_t'(MEM_TRANSFERS_PER_CL - 1);

typedef logic [WAY_BITS-1:0] lru_cnt_t;

// helper functions
/* verilator lint_off UNUSEDSIGNAL */
function automatic [TAG_W-1:0]
get_tag(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    get_tag = addr[CORE_BYTE_ADDR_BUS-1 -: TAG_W]; // get top TAG_W bits
endfunction

function automatic [IDX_RANGE_TOP-1:0]
get_idx(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = (addr >> 6) & (SETS - 1);
    get_idx = masked[IDX_RANGE_TOP-1:0];
endfunction

function automatic [WORD_ADDR-1:0]
get_cl_word(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = ((addr >> 2) & 'hf);
    get_cl_word = masked[WORD_ADDR-1:0];
endfunction

function automatic [CACHE_LINE_BYTE_ADDR-1:0]
get_cl_byte_idx(input logic [CORE_BYTE_ADDR_BUS-1:0] addr);
    logic [CORE_BYTE_ADDR_BUS-1:0] masked;
    masked = addr & CACHE_LINE_B_MASK[CORE_BYTE_ADDR_BUS-1:0];
    get_cl_byte_idx = masked[CACHE_LINE_BYTE_ADDR-1:0];
endfunction
/* verilator lint_on UNUSEDSIGNAL */

function automatic [(ARCH_WIDTH/8)-1:0]
get_store_mask(input logic [1:0] dw);
    case ({1'b0, dw})
        DMEM_DTYPE_BYTE: get_store_mask = 4'b0001;
        DMEM_DTYPE_HALF: get_store_mask = 4'b0011;
        DMEM_DTYPE_WORD: get_store_mask = 4'b1111;
        default: get_store_mask = '0;
    endcase
endfunction

//------------------------------------------------------------------------------
// implementation

//logic bank_en [WAYS-1:0];
logic [MEM_DATA_BUS_B-1:0] bank_we [WAYS-1:0];
logic [BANK_ADDR-1:0] bank_addr;
logic [MEM_DATA_BUS-1:0] bank_data [WAYS-1:0];
logic [MEM_DATA_BUS-1:0] store_data_q;

// mem array
genvar b;
generate
`IT_P_NT(b, WAYS) begin: gen_bank
    mem #(
        .DW (MEM_DATA_BUS),
        .AW (BANK_ADDR)
    ) bank_i (
        .clk (clk),
        .en (1'b1), // TODO: always enabled?
        .we (bank_we[b]),
        .addr (bank_addr),
        .din (store_data_q),
        .dout (bank_data[b])
    );
end
endgenerate

// tag & valid arrays
logic a_valid [WAYS-1:0][SETS-1:0];
logic a_dirty [WAYS-1:0][SETS-1:0];
logic [TAG_W-1:0] a_tag [WAYS-1:0][SETS-1:0];

// state, tag matching, lru logic
core_request_t cr;
core_request_pending_t cr_pend;
logic tag_match;
logic [TAG_W-1:0] tag_cr;
logic [IDX_RANGE_TOP-1:0] set_idx_cr;
logic [WAY_BITS-1:0] way_victim_idx;
logic new_core_req, new_core_req_d;
logic hit, hit_d, miss, miss_d;
logic cr_victim_dirty, cr_victim_dirty_d;
logic load_req_hit, store_req_hit, load_req_pending, store_req_pending;

//------------------------------------------------------------------------------
// lookup and tag matching

if (WAYS == 1) begin: gen_dmap_lookup

// wrap in always_comb to force functions to evaluate first
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    // hardwired values for direct-mapped
    way_victim_idx = '0;
    // tag search
    tag_match = (a_tag[cr.way_idx][set_idx_cr] == tag_cr);
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
    miss = (new_core_req && !hit);
    cr_victim_dirty = a_dirty[cr.way_idx][set_idx_cr];
end

end else begin: gen_assoc_lookup

lru_cnt_t a_lru [WAYS-1:0][SETS-1:0];
localparam [WAY_BITS-1:0] LRU_MAX_CNT = lru_cnt_t'(WAYS - 1);
always_comb begin
    cr = `DC_CR_ASSIGN;
    set_idx_cr = get_idx(cr.addr);
    tag_cr = get_tag(cr.addr);
    tag_match = 1'b0;
    way_victim_idx = '0;
    `IT_P(w, WAYS) begin
        if (a_valid[w][set_idx_cr] && (a_tag[w][set_idx_cr] == tag_cr)) begin
            tag_match = 1'b1;
            cr.way_idx = w[WAY_BITS-1:0];
        end else if (a_lru[w][set_idx_cr] == LRU_MAX_CNT) begin
            way_victim_idx = w[WAY_BITS-1:0];
        end
    end
    hit = &{tag_match, new_core_req, a_valid[cr.way_idx][set_idx_cr]};
    miss = (new_core_req && !hit);
    cr_victim_dirty = a_dirty[way_victim_idx][set_idx_cr];
end

// lru
lru_cnt_access_t lca;
logic lca_pend, lca_hit;
assign lca_pend = ((load_req_pending || store_req_pending) && (!lca_hit));
assign lca_hit = ((load_req_hit || store_req_hit) /* && (!lca_pend) */);
// FIXME: these are both active at some point?!
always_comb begin
    unique case (1'b1)
        lca_pend: lca = '{cr_pend.cr.way_idx, get_idx(cr_pend.cr.addr)};
        lca_hit: lca = '{cr.way_idx, get_idx(cr.addr)};
        default: lca = '{'h0, 'h0};
    endcase
end

logic update_lru;
assign update_lru =
    (load_req_hit || store_req_hit || load_req_pending || store_req_pending);

always_ff @(posedge clk) begin
    if (rst) begin
        `IT_P(w, WAYS) begin
            `IT_P(s, SETS) begin
                a_lru[w][s] <= w[WAY_BITS-1:0]; // init LRU to way idx
            end
        end
    end else if (update_lru) begin
        `IT_P(w, WAYS) begin
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

//------------------------------------------------------------------------------
// handling requests

assign new_core_req = (req_core.valid && req_core.ready);
`DFF_CI_RI_RVI(new_core_req, new_core_req_d)
`DFF_CI_RI_RVI_EN(new_core_req, hit, hit_d)
`DFF_CI_RI_RVI_EN(new_core_req, cr_victim_dirty, cr_victim_dirty_d)
assign miss_d = (new_core_req_d && !hit_d);

// cache line (64B) to mem bus (16B) addressing, from core addr (1B)
logic [MEM_ADDR_BUS-1:0] mem_start_addr; // addr aligned to first mem block
// take top MEM_ADDR_BUS bits and align to 1st out of 4 packets
assign mem_start_addr = (
    cr.addr[CORE_BYTE_ADDR_BUS-1 -: MEM_ADDR_BUS] & (~'b11)
);

logic save_pending, clear_pending_on_write, clear_pending_on_read;
assign save_pending = miss;
dcache_state_t state, nx_state;
always_ff @(posedge clk) begin
    if (rst) begin
        cr_pend <= `DC_CR_PEND_CLEAR;
    end else if (save_pending) begin
        cr_pend <= '{
            active: 1'b1,
            mem_start_addr: mem_start_addr,
            cr: '{
                addr: cr.addr,
                wdata: cr.wdata,
                dtype: cr.dtype,
                rtype: cr.rtype,
                way_idx: way_victim_idx
            }
        };
    end else if (clear_pending_on_read || clear_pending_on_write) begin
        cr_pend <= `DC_CR_PEND_CLEAR;
    end
end

mem_miss_cnt_t mem_miss_cnt, mem_miss_cnt_d, mem_evict_cnt;
`DFF_CI_RI_RVI_EN(req_mem_r.valid, (mem_miss_cnt + 'h1), mem_miss_cnt)
`DFF_CI_RI_RVI(mem_miss_cnt, mem_miss_cnt_d)
`DFF_CI_RI_RVI_EN(req_mem_w.valid, (mem_evict_cnt + 'h1), mem_evict_cnt)

logic [MEM_ADDR_BUS-1:0] mem_miss_cnt_pad, mem_evict_cnt_pad;
assign mem_miss_cnt_pad =
    {{MEM_ADDR_BUS-MEM_MISS_CNT_WIDTH{1'b0}}, mem_miss_cnt};
assign mem_evict_cnt_pad =
    {{MEM_ADDR_BUS-MEM_MISS_CNT_WIDTH{1'b0}}, mem_evict_cnt};

logic mem_r_transfer_done;
logic [1:0] mem_r_transfer_done_d;
assign mem_r_transfer_done =
    (rsp_mem.valid && (mem_miss_cnt_d == MEM_TRANSFER_MATCH_DONE));
`DFF_CI_RI_RVI(
    {mem_r_transfer_done_d[0], mem_r_transfer_done}, mem_r_transfer_done_d)

logic load_req, store_req;
assign load_req = (new_core_req && (cr.rtype == DMEM_READ));
assign store_req = (new_core_req && (cr.rtype == DMEM_WRITE));
assign load_req_hit = (hit && load_req);
assign store_req_hit = (hit && store_req);

logic req_pending;
assign req_pending = (mem_r_transfer_done_d[1] && cr_pend.active);
assign load_req_pending = (req_pending && (cr_pend.cr.rtype == DMEM_READ));
assign store_req_pending = (req_pending && (cr_pend.cr.rtype == DMEM_WRITE));

//------------------------------------------------------------------------------
// load & store addressing

logic cache_store;
assign cache_store = (rsp_mem.valid || store_req_pending || store_req_hit);

logic [IDX_RANGE_TOP-1:0] set_idx_pend;
logic [CACHE_LINE_BYTE_ADDR-1:0] byte_idx_pend, byte_idx_cr;
logic [BANK_ADDR-1:0] bank_addr_store, bank_addr_load;
logic [1:0] stc_byte_idx_top;
store_to_cache_t stc;
always_comb begin
    set_idx_pend = get_idx(cr_pend.cr.addr);
    byte_idx_pend = get_cl_byte_idx(cr_pend.cr.addr);
    byte_idx_cr = get_cl_byte_idx(cr.addr);
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
    stc_byte_idx_top = rsp_mem.valid ? mem_miss_cnt_d : stc.byte_idx[5:4];
    bank_addr_store = {stc.set_idx, stc_byte_idx_top};
    bank_addr = cache_store ? bank_addr_store : bank_addr_load;
end

logic [(ARCH_WIDTH/8)-1:0] store_mask_b;
assign store_mask_b = get_store_mask(stc.dtype[1:0]);

logic [MEM_DATA_BUS_B-1:0] store_mask_q, store_mask_core;
assign store_mask_core = {12'h0, store_mask_b} << stc.byte_idx[3:0];
assign store_mask_q = rsp_mem.valid ? MEM_DATA_BUS_B_MASK : store_mask_core;

logic [MEM_DATA_BUS-1:0] store_data_core;
logic [6:0] store_shift_core;
assign store_shift_core = {stc.byte_idx[3:0], 3'h0}; // to bytes
assign store_data_core = ({STORE_PAD, stc.wdata} << store_shift_core);
assign store_data_q = rsp_mem.valid ? rsp_mem.data : store_data_core;

always_comb begin
    `IT_P(w, WAYS) begin
        bank_we[w] = 'h0;
        if (cache_store && (w[WAY_BITS-1:0] == stc.way_idx)) begin
            bank_we[w] = store_mask_q;
        end
    end
end

mem_miss_cnt_t bank_evict_cnt;
always_ff @(posedge clk) begin
    if (rst) bank_evict_cnt <= 'h0;
    else if (state == DC_MISS && nx_state == DC_READY) bank_evict_cnt <= 'h0;
    else if (miss || req_mem_w.valid) bank_evict_cnt <= (bank_evict_cnt + 'h1);
end

/* verilator lint_off UNUSEDSIGNAL */
load_from_cache_t lfc, lfc_d; // lfc_d may have some bits unused
/* verilator lint_on UNUSEDSIGNAL */
logic [BANK_LINE_ADDR-1:0] bl_addr_load, bl_addr_load_l, bl_addr_load_e;
always_comb begin
    lfc.set_idx = get_idx(cr.addr);
    lfc.word_idx = get_cl_word(cr.addr);
    lfc.way_idx = cr.way_idx;
    lfc.dtype = cr.dtype;
    lfc.rtype = cr.rtype;
    lfc.off = cr.addr[1:0];
    if (cr_pend.active && (!clear_pending_on_read)) begin
        // used for core load, and mem miss/evict
        lfc.set_idx = get_idx(cr_pend.cr.addr);
        lfc.word_idx = get_cl_word(cr_pend.cr.addr);
        lfc.way_idx = cr_pend.cr.way_idx;
        lfc.dtype = cr_pend.cr.dtype;
        lfc.rtype = cr_pend.cr.rtype;
        lfc.off = cr_pend.cr.addr[1:0];
    end
    bl_addr_load_l = lfc.word_idx[(WORD_ADDR-1) -: BANK_LINE_ADDR];
    bl_addr_load_e = bank_evict_cnt;
    bl_addr_load =
        (miss || req_mem_w.valid) ? bl_addr_load_e : bl_addr_load_l;
    bank_addr_load = {lfc.set_idx, bl_addr_load};
    //`IT_P(w, WAYS) bank_en[w] = (w == way_idx);
end

`DFF_CI_RI_RVI(lfc, lfc_d)

//------------------------------------------------------------------------------
// metadata updates

logic [TAG_W-1:0] tag_pend;
assign tag_pend = cr_pend.mem_start_addr[MEM_ADDR_BUS-1 -: TAG_W];;

always_ff @(posedge clk) begin
    if (rst) begin
        `IT_P(w, WAYS) begin
            `IT_P(s, SETS) begin
                a_valid[w][s] <= 1'b0;
                a_dirty[w][s] <= 1'b0;
                a_tag[w][s] <= 'h0;
            end
        end
    end else if (cache_store) begin
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

//------------------------------------------------------------------------------
// state transition
`DFF_CI_RI_RV(DC_RESET, nx_state, state)

// next state
always_comb begin
    nx_state = state;
    case (state)
        DC_RESET: begin
            nx_state = DC_READY;
        end

        DC_READY: begin
            if (miss_d) begin
                if (cr_victim_dirty_d) nx_state = DC_EVICT;
                else nx_state = DC_MISS;
            end
        end

        DC_MISS: begin
            if (cr_pend.cr.rtype == DMEM_WRITE) begin
                if (clear_pending_on_write) nx_state = DC_READY;
            end else begin
                // extra cycle at the end so banks can read on that clk edge
                if ((mem_miss_cnt == 'h0) && (mem_miss_cnt_d == 'h0)) begin
                    nx_state = DC_READY;
                end
            end
        end

        DC_EVICT: begin
            if (mem_evict_cnt == MEM_TRANSFER_MATCH_DONE) nx_state = DC_MISS;
        end

        default: ;

    endcase
end

logic hit_d_load;
assign hit_d_load = (hit_d && new_core_req_d && (lfc_d.rtype == DMEM_READ));

logic [MEM_ADDR_BUS-1:0] victim_wb_start_addr;
// outputs
always_comb begin
    // to/from core
    rsp_core.valid = 1'b0;
    req_core.ready = 1'b0;
    // read from mem
    req_mem_r.valid = 1'b0;
    rsp_mem.ready = 1'b0;
    req_mem_r.data = 'h0;
    // write to mem
    req_mem_w.valid = 1'b0;
    req_mem_w.addr = 'h0;
    // others
    clear_pending_on_read = 1'b0;

    case (state)
        DC_RESET: begin
            rsp_core.valid = 1'b0;
            req_core.ready = 1'b0;
            req_mem_r.valid = 1'b0;
            rsp_mem.ready = 1'b0;
        end

        DC_READY: begin
            req_core.ready = 1'b1;
            if (load_req_pending) begin
                // service the pending request after miss
                rsp_core.valid = 1'b1;
                clear_pending_on_read = 1'b1;
            end else if (new_core_req_d) begin
                if (hit_d_load) begin
                    rsp_core.valid = 1'b1;
                end else if (!hit_d) begin
                    // on miss go to mem; mem always ready to take new request
                    req_core.ready = 1'b0;
                    if (cr_victim_dirty_d) begin

                        // start eviction, initiate memory write
                        req_mem_w.valid = 1'b1;
                        req_mem_w.addr = victim_wb_start_addr;
                    end else begin
                        // start replacement, initiate memory read
                        rsp_mem.ready = 1'b1;
                        req_mem_r.valid = 1'b1;
                        req_mem_r.data = cr_pend.mem_start_addr;
                    end
                end
            end
        end

        DC_MISS: begin
            // 1 clk at the end to wait in DC_MISS for last mem response
            if (mem_miss_cnt > 0) begin
                rsp_mem.ready = 1'b1;
                req_mem_r.valid = 1'b1;
                req_mem_r.data = (cr_pend.mem_start_addr + mem_miss_cnt_pad);
            end
        end

        DC_EVICT: begin
            req_mem_w.valid = 1'b1;
            req_mem_w.addr = (victim_wb_start_addr + mem_evict_cnt_pad);
            if (mem_evict_cnt == MEM_TRANSFER_MATCH_DONE) begin
                // initiate miss with the last writeback
                rsp_mem.ready = 1'b1;
                req_mem_r.valid = 1'b1;
                req_mem_r.data = cr_pend.mem_start_addr;
            end
        end

        default: ;

    endcase
end

if (SETS == 1) begin: gen_victim_addr_dm
    assign victim_wb_start_addr =
        {a_tag[lfc.way_idx][lfc.set_idx], 2'b00};
end else begin: gen_victim_addr_assoc
    assign victim_wb_start_addr =
        {a_tag[lfc.way_idx][lfc.set_idx], lfc.set_idx, 2'b00};
end

logic [ARCH_WIDTH-1:0] rd_data;
logic [WORD_IN_BANK_LINE_ADDR-1:0] word_in_bank_line_addr;
assign word_in_bank_line_addr = lfc_d.word_idx[WORD_IN_BANK_LINE_ADDR-1:0];
assign rd_data =
    bank_data[lfc_d.way_idx][(word_in_bank_line_addr*ARCH_WIDTH) +: ARCH_WIDTH];

assign req_mem_w.wdata = bank_data[lfc.way_idx];

// shift data as/if needed
logic load_uns;
logic [2:0] load_dw;
assign load_dw = {1'b0, lfc_d.dtype[1:0]};
assign load_uns = lfc_d.dtype[2]; // 0: signed, 1: unsigned

// check unaligned access
logic ua_h, ua_w, ua;
assign ua_h =
    ((load_dw == DMEM_DTYPE_HALF) &&
     ((lfc_d.off == `DMEM_BYTE_OFF_1) || (lfc_d.off == `DMEM_BYTE_OFF_3)));
assign ua_w =
    ((load_dw == DMEM_DTYPE_WORD) && (lfc_d.off != `DMEM_BYTE_OFF_0));
assign ua = /* en && */ (ua_h || ua_w);

// Shift mask
logic [ARCH_WIDTH-1:0] data_out;
always_comb begin
    data_out = 'h0;
    if (/* en && */ !ua) begin
        case (load_dw)
            DMEM_DTYPE_BYTE: begin
                data_out[7:0] = rd_data[lfc_d.off*8 +: 8];
                data_out[31:8] =
                    load_uns ? {24{1'b0}} : {24{rd_data[lfc_d.off*8 + 7]}};
            end

            DMEM_DTYPE_HALF: begin
                data_out[15:0] = rd_data[lfc_d.off*8 +: 16];
                data_out[31:16] =
                    load_uns ? {16{1'b0}} : {16{rd_data[lfc_d.off*8 + 15]}};
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

logic dbg_servicing_pending_req;
assign dbg_servicing_pending_req =
    (cr_pend.active && !new_core_req_d) && rsp_core.valid;

logic [CORE_BYTE_ADDR_BUS-1:0] dbg_req_core_bytes_valid;
assign dbg_req_core_bytes_valid =
    ((cr.addr) & {CORE_BYTE_ADDR_BUS{req_core.valid}});

if (WAYS > 1) begin: dbg_assoc // set-associative views

// data view
typedef struct {
    logic valid;
    logic dirty;
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
            d[gw][gs].q[0] = `DCACHE.gen_bank[gw].bank_i.m[(gs*4) + 0];
            d[gw][gs].q[1] = `DCACHE.gen_bank[gw].bank_i.m[(gs*4) + 1];
            d[gw][gs].q[2] = `DCACHE.gen_bank[gw].bank_i.m[(gs*4) + 2];
            d[gw][gs].q[3] = `DCACHE.gen_bank[gw].bank_i.m[(gs*4) + 3];
        end
    end
end

cache_line_t data_view [WAYS-1:0][SETS-1:0];
always_comb begin
    `IT_P(w, WAYS) begin
        `IT_P(s, SETS) begin
            data_view[w][s].valid <= a_valid[w][s];
            data_view[w][s].dirty <= a_dirty[w][s];
            data_view[w][s].tag <= a_tag[w][s];
            data_view[w][s].lru <= `DCACHE.gen_assoc_lookup.a_lru[w][s];
            data_view[w][s].data <= d[w][s];
        end
    end
end

// asserts
always_comb begin
    `IT_P(as, SETS) begin
        `IT_P(aw0, WAYS) begin
            `IT_P_I(aw1, (aw0+1), WAYS) begin
                if (data_view[aw0][as].valid && data_view[aw1][as].valid) begin
                    // tag check
                    assert (data_view[aw0][as].tag != data_view[aw1][as].tag)
                    else $fatal(1,
                        "DCACHE TAG DUPLICATE: set=%0d ways=%0d,%0d tag=0x%0h",
                        as, aw0, aw1, data_view[aw0][as].tag);
                    // lru check
                    assert (data_view[aw0][as].lru != data_view[aw1][as].lru)
                    else $fatal(1,
                        "DCACHE LRU DUPLICATE: set=%0d ways=%0d,%0d lru=%0d",
                        as, aw0, aw1, data_view[aw0][as].lru);
                end
            end
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

// proxy for convenience, but not for wave
cache_line_data_t d [SETS-1:0];
genvar gs;
`IT_P_NT(gs, SETS) begin
    always_comb begin
        d[gs].q[0] = `DCACHE.gen_bank[0].bank_i.m[(gs*4) + 0];
        d[gs].q[1] = `DCACHE.gen_bank[0].bank_i.m[(gs*4) + 1];
        d[gs].q[2] = `DCACHE.gen_bank[0].bank_i.m[(gs*4) + 2];
        d[gs].q[3] = `DCACHE.gen_bank[0].bank_i.m[(gs*4) + 3];
    end
end

cache_line_t data_view [SETS-1:0];
always_comb @(posedge clk) begin
    `IT_P(s, SETS) begin
        data_view[s].valid <= a_valid[0][s];
        data_view[s].dirty <= a_dirty[0][s];
        data_view[s].tag <= a_tag[0][s];
        data_view[s].data = d[s];
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
