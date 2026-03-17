// Konata pipeline tracer - DPI functions
// Format:
//   https://github.com/shioyadan/Konata/blob/master/docs/kanata-log-format.md

#include "cosim.h"
#include "dpi_functions.h"

static FILE* g_file = nullptr;
static uint64_t g_last_cycle = 0;

DPI_DLLESPEC void konata_open(const char* outdir) {
    auto tag = std::string(outdir);
    auto pos = tag.find("_out_cosim/");
    if (pos != std::string::npos) {
        tag.erase(pos, std::string("_out_cosim/").size());
    }
    std::filesystem::path p =
        std::filesystem::path(outdir) / (tag + std::string(".kanata.log"));
    g_file = std::fopen(p.string().c_str(), "w");
    if (g_file) {
        fprintf(g_file, "Kanata\t0004\n");
        fprintf(g_file, "C=\t0\n");
        g_last_cycle = 0;
    }
}

void konata_cycle(uint64_t cycle) {
    //if (cycle > g_last_cycle) { // currently always true from tb
        fprintf(g_file, "C\t%lu\n", (cycle - g_last_cycle));
        g_last_cycle = cycle;
    //}
}

void konata_inst(unsigned int id) {
    fprintf(g_file, "I\t%u\t0\t0\n", id);
}

void konata_label(
    unsigned int id,
    unsigned int pc,
    unsigned int inst,
    const char* inst_asm_str
) {
    if (!inst) {
        fprintf(g_file, "L\t%u\t0\t%08x\n", id, pc);
        return;
    }
    fprintf(g_file, "L\t%u\t0\t%08x: %08x %s\n", id, pc, inst, inst_asm_str);
}

void konata_label_str(
    unsigned int id,
    unsigned int lane,
    const char* str
) {
    fprintf(g_file, "L\t%u\t%u\t%s\n", id, lane, str);
}

void konata_start_stage(unsigned int id, const char* stage) {
    fprintf(g_file, "S\t%u\t0\t%s\n", id, stage);
}

void konata_end_stage(unsigned int id, const char* stage) {
    fprintf(g_file, "E\t%u\t0\t%s\n", id, stage);
}

void konata_retire(unsigned int id, unsigned int retire_id, char is_flush) {
    fprintf(g_file, "R\t%u\t%u\t%d\n", id, retire_id, is_flush);
}

void konata_close() {
    if (g_file) {
        fclose(g_file);
        g_file = nullptr;
    }
}
