`ifndef AMA_RISCV_DEFINES
`define AMA_RISCV_DEFINES

// Memory map
`define RESET_VECTOR 32'h4_0000
`define DMEM_RANGE 4'b0100
`define MMIO_RANGE 4'b0101

`define UART_SIZE 12 // 3 32-bit registers per UART {ctrl, rx_data, tx_data}

// NOP inst
`define NOP 32'h13 // addi x0 x0 0

`define TO_STRING(x) `"x`"

`ifdef FPGA_SYNT
`error_DONT_TOUCH_FPGA_SYNT_DEFINE
`endif

`ifdef SYNT
`ifdef FPGA
`define FPGA_SYNT
`endif
`endif

`include "ama_riscv_types.svh"

// DMEM Offset
`define DMEM_BYTE_OFF_0 2'd0
`define DMEM_BYTE_OFF_1 2'd1
`define DMEM_BYTE_OFF_2 2'd2
`define DMEM_BYTE_OFF_3 2'd3

// `ifdef IMEM_DELAY
// `define IMEM_DELAY_CLK 3
// `else
// `define IMEM_DELAY_CLK 1
// `endif

// IT - ITerator
// _NT - No Type specified (e.g. for genvars)
// _I - with provided Initial value (when not starting from 0)
// _P - with Parametrized index name (for nested loops, or specific index name)
`define IT(limit) for (int i = 0; i < limit; i++)
`define IT_NT(limit) for (i = 0; i < limit; i++)
`define IT_I(init, limit) for (int i = init; i < limit; i++)
`define IT_I_NT(init, limit) for (i = init; i < limit; i++)
`define IT_P(p, limit) for (int p = 0; p < limit; p++)
`define IT_P_NT(p, limit) for (p = 0; p < limit; p++)

`define FE_CTRL_INIT_VAL \
    '{ \
        pc_sel: PC_SEL_INC4, \
        pc_we: 1'b0, \
        bubble_dec: 1'b1, \
        use_cp: 1'b0 \
    }

`define INST_TYPE_INIT_VAL \
    '{ \
        mult: 1'b0, \
        unpk: 1'b0, \
        load: 1'b0, \
        store: 1'b0, \
        branch: 1'b0, \
        jal: 1'b0, \
        jalr: 1'b0 \
    }

`define HAS_REG_INIT_VAL \
    '{ \
        rd: 1'b0, \
        rs1: 1'b0, \
        rs2: 1'b0 \
    }

`define DECODER_INIT_VAL \
    '{ \
        itype: `INST_TYPE_INIT_VAL, \
        has_reg: `HAS_REG_INIT_VAL, \
        has_reg_p: 1'b0, \
        csr_ctrl: '{en: 1'b0, re: 1'b0, we: 1'b0, ui: 1'b0, op: CSR_OP_NONE}, \
        alu_op: ALU_OP_OFF, \
        mult_op: MULT_OP_MUL, \
        unpk_op: UNPK_OP_16, \
        a_sel: A_SEL_RS1, \
        b_sel: B_SEL_RS2, \
        ig_sel: IG_OFF, \
        bc_uns: 1'b0, \
        dmem_en: 1'b0, \
        ewb_sel: EWB_SEL_ALU, \
        wb_sel: WB_SEL_EWB, \
        rd_we: 1'b0 \
    }

`define DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI(_rstv, _clr, _en, _clr2, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else if (_clr) _q <= _rstv; \
        else if (_en) begin \
            if (_clr2) _q <= _rstv; \
            else _q <= _d; \
        end \
    end

`define STAGE(_ctrl, _en, _d, _q, _rstv) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI( \
        _rstv, _ctrl.flush, (_ctrl.en && _en), _ctrl.bubble, _d, _q)

`define STAGE_D_E(_en, _d, _q, _rstv) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI( \
        _rstv, ctrl_dec_exe.flush, (ctrl_dec_exe.en && _en), ctrl_dec_exe.bubble, _d, _q)

`define STAGE_E_M(_en, _d, _q, _rstv) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI( \
        _rstv, ctrl_exe_mem.flush, (ctrl_exe_mem.en && _en), ctrl_exe_mem.bubble, _d, _q)

`define STAGE_M_W(_en, _d, _q, _rstv) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI( \
        _rstv, ctrl_mem_wbk.flush, (ctrl_mem_wbk.en && _en), ctrl_mem_wbk.bubble, _d, _q)

`define STAGE_W_R(_en, _d, _q, _rstv) \
    `DFF_CI_RI_RV_CLR_CLRVI_EN_CLR2_CLR2VI( \
        _rstv, ctrl_wbk_ret.flush, (ctrl_wbk_ret.en && _en), ctrl_wbk_ret.bubble, _d, _q)

// DFF macros
`define DFF_CI_RI_RV(_rstv, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RVI(_d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else _q <= _d; \
    end

`define DFF_CI_RI_RV_EN(_rstv, _en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= _rstv; \
        else if (_en) _q <= _d; \
    end

`define DFF_CI_RI_RVI_EN(_en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else if (_en) _q <= _d; \
    end

`define DFF_CI_EN(_en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (_en) _q <= _d; \
    end

`define DFF_CI_RI_RVI_CLR_CLRVI_EN(_clr, _en, _d, _q) \
    always_ff @(posedge clk) begin \
        if (rst) _q <= 'h0; \
        else if (_clr) _q <= 'h0; \
        else if (_en) _q <= _d; \
    end

`endif // AMA_RISCV_DEFINES
