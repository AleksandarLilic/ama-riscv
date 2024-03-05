#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "defines.h"
#include "memory.h"
#include "core.h"
#include "svdpi.h"

memory *mem;
core *rv32;

DPI_DLLESPEC
extern "C" void emu_setup(const char* test_bin, uint32_t base_address) {
    std::string l_test_bin(test_bin);
    mem = new memory(base_address, l_test_bin);
    rv32 = new core(base_address, mem);
}

DPI_DLLESPEC
extern "C" void emu_exec() {
    rv32->exec_inst();
}

DPI_DLLESPEC
extern "C" void emu_dump() {
    rv32->dump();
}
