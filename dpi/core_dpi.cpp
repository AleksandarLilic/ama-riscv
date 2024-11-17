#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "defines.h"
#include "memory.h"
#include "core.h"
#include "svdpi.h"

#define INST_ASM_LEN 64

memory *mem;
core *rv32;

DPI_DLLESPEC
extern "C" void cosim_setup(const char *test_bin, uint32_t base_address) {
    std::string l_test_bin(test_bin);
    mem = new memory(base_address, l_test_bin);
    rv32 = new core(base_address, mem, "rtl_cosim", {0, 0});
}

DPI_DLLESPEC
extern "C" void cosim_exec(
    uint32_t *pc,
    uint32_t *inst,
    char *inst_asm,
    uint32_t *rf
) {
    *pc = rv32->get_pc();
    rv32->exec_inst();
    *inst = rv32->get_inst();
    if (INST_ASM_LEN > rv32->get_inst_asm().length()) {
        strcpy(inst_asm, rv32->get_inst_asm().c_str());
    } else {
        strcpy(inst_asm, "Instruction too long");
    }
    for (int i = 0; i < 32; i++) {
        rf[i] = rv32->get_reg(i);
    }
}

DPI_DLLESPEC
extern "C" uint32_t cosim_get_inst_cnt() {
    return rv32->get_inst_cnt();
}

DPI_DLLESPEC
extern "C" void cosim_finish() {
    rv32->finish(false);
}
