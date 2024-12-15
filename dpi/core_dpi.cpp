#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "defines.h"
#include "memory.h"
#include "core.h"
#include "svdpi.h"

#define INST_ASM_LEN 80 // must match `define in the testbench

memory *mem;
core *rv32;
cfg_t cfg; // placeholder, dc
hw_cfg_t hw_cfg; // placeholder, dc

DPI_DLLESPEC extern "C"
void cosim_setup(const char *test_bin) {
    std::string l_test_bin(test_bin);
    mem = new memory(l_test_bin, hw_cfg);
    rv32 = new core(mem, "rtl_cosim", cfg, hw_cfg);
}

DPI_DLLESPEC extern "C"
void cosim_exec(uint32_t *pc, uint32_t *inst, char *inst_asm, uint32_t *rf) {
    *pc = rv32->get_pc();
    rv32->exec_inst();
    *inst = rv32->get_inst();
    for (int i = 0; i < 32; i++) rf[i] = rv32->get_reg(i);
    if (INST_ASM_LEN > rv32->get_inst_asm().length()) {
        strcpy(inst_asm, rv32->get_inst_asm().c_str());
    } else {
        strcpy(inst_asm, "Instruction too long");
    }
}

DPI_DLLESPEC extern "C"
uint32_t cosim_get_inst_cnt() {
    return rv32->get_inst_cnt();
}

DPI_DLLESPEC extern "C"
void cosim_finish() {
    rv32->finish(false);
}
