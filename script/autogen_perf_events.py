#!/usr/bin/env python3

import sys
from pathlib import Path
from types import SimpleNamespace

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
CONFIG_PATH = (SCRIPT_DIR / "autogen_perf_events_config.yaml")

INDENT = " " * 4

TAG_OPEN = "==== PERF_EVENT AUTOGEN BEGIN ===="
TAG_CLOSE = "==== PERF_EVENT AUTOGEN END ===="

MAX_EVENTS = 32
KEYS = SimpleNamespace(
    rtl = "rtl",
    sim = "isa_sim",
    model = "isa_sim_hw_model",
)

def load_perf_events(config_path=CONFIG_PATH):
    with open(config_path) as f:
        cfg = yaml.safe_load(f)
    events = cfg["perf_event_t"]
    assert isinstance(events, dict) and len(events) > 0, \
        f"perf_event_t must be a non-empty list in {config_path}"
    assert len(events) == len(set(events)), "duplicate event names in config"
    assert len(events) <= MAX_EVENTS, f"max possible elements is {MAX_EVENTS}"
    return events

def filter_events(events, key):
    return list(k for k,v in events.items() if key in v)

# generators
# each takes the event list and returns the lines to place strictly between
# a file's AUTOGEN BEGIN/END markers (marker lines themselves untouched)

# src/ama_riscv_types.svh
def gen_types_svh(events):
    lines = []
    events = filter_events(events, KEYS.rtl)

    lines.append("typedef struct packed {")
    for pe in events:
        lines.append(f"{INDENT}logic {pe};")
    lines.append("} perf_event_t;")
    lines.append("")

    lines.append(f"parameter unsigned MHPMEVENTS = {len(events)};\n")
    lines.append("typedef enum logic [MHPMEVENTS-1:0] {")
    lines.append(f"{INDENT}MHPMEVENT_NONE = 0,")
    for i, pe in enumerate(events):
        suffix = "," if i != len(events) - 1 else ""
        lines.append(f"{INDENT}MHPMEVENT_{pe.upper()} = (1 << {i}){suffix}")
    lines.append("} mhpmevent_t;")
    lines.append("")

    lines.append(
        "function automatic logic get_event(input perf_event_t pe, "
        "input mhpmevent_t ev);"
    )
    lines.append(f"{INDENT}case (ev)")
    for pe in events:
        lines.append(f"{INDENT}{INDENT}MHPMEVENT_{pe.upper()}: get_event = pe.{pe};")
    lines.append(f"{INDENT}{INDENT}default: get_event = 1'b0;")
    lines.append(f"{INDENT}endcase")
    lines.append("endfunction")

    return [""] + lines + [""]

# verif/direct_tb/ama_riscv_tb_types.svh
def gen_tb_types_svh(events):
    events = filter_events(events, KEYS.rtl)
    lines = ["typedef struct {"]
    lines.append(f"{INDENT}byte ret_inst = '0;")
    for pe in events:
        lines.append(f"{INDENT}byte {pe} = '0;")
    lines.append("} perf_event_bytes_t;")
    return lines

# verif/direct_tb/ama_riscv_tb.sv
def gen_tb_sv(events):
    events = filter_events(events, KEYS.rtl)
    lines = ["always_comb begin"]
    # ret_inst count from the dedicated core output
    lines.append(f"{INDENT}pe.ret_inst = `CORE.inst_retired;")
    for pe in events:
        lines.append(f"{INDENT}pe.{pe} = `CORE.cpe.{pe};")
    lines.append("end")
    return lines

# cosim/core_stats.h - pair 1:
# ret_inst added via CORE_STATS_JSON_ENTRY_MANUAL macro
# (for readable JSON key ordering)
# so the custom event gen here doesn't include it
def gen_core_stats_json_macro(events):
    events = filter_events(events, KEYS.rtl)
    lines = ["#define CORE_STATS_JSON_ENTRY_AUTOGEN \\"]
    for i, pe in enumerate(events):
        cont = " \\" if i != len(events) - 1 else ""
        lines.append(f"{INDENT}CORE_STATS_JSON_LINE({pe}){cont}")
    return lines + [""]

# cosim/core_stats.h - pair 2: uint64_t counter field declarations
def gen_core_stats_fields(events):
    events = filter_events(events, KEYS.rtl)
    lines = [f"{INDENT * 2}uint64_t ret_inst = 0;"]
    return lines + [f"{INDENT * 2}uint64_t {pe} = 0;" for pe in events]

# cosim/core_stats.h - pair 3: add_events() accumulation
def gen_core_stats_acc(events):
    events = filter_events(events, KEYS.rtl)
    lines = [f"{INDENT * 3}ret_inst += ev->ret_inst;"]
    return lines + [f"{INDENT * 3}{pe} += ev->{pe};" for pe in events]

# sim/src/types.h
def gen_types_cpp(events, map=False):
    events_rtl = filter_events(events, KEYS.rtl)
    events_sim = filter_events(events, KEYS.sim)
    events_model = filter_events(events, KEYS.model)
    event_rtl_unique = [
        pe for pe in events_rtl
        if pe not in events_sim and pe not in events_model
    ]
    lines = []

    def single_pass(as_str=False):
        def to_str(sin, b=False):
            if b:
                return f"\"{sin}\""
            return sin

        def add_lines(events):
            def types_line(pe):
                return f"{INDENT}{to_str(pe, as_str)},"

            def map_line(pe):
                return f"{INDENT}{{{to_str(pe, True)}, perf_event_t::{pe}}},"

            if not map:
                for pe in events:
                    lines.append(types_line(pe))
            else:
                for pe in events:
                    lines.append(map_line(pe))

        add_lines(["ret_inst"])
        add_lines(events_sim)
        if map:
            lines.append(f"{INDENT}#ifdef HW_MODELS_EN")
        else:
            lines.append(f"{INDENT}#if defined(HW_MODELS_EN) || defined(DPI)")

        add_lines(events_model)
        lines.append(f"{INDENT}#endif")
        if not map:
            lines.append(f"{INDENT}#ifdef DPI")
            add_lines(event_rtl_unique)
            lines.append(f"{INDENT}{to_str('cycle', as_str)},")
            lines.append(f"{INDENT}#endif")

    if not map:
        # type
        lines.append("enum class perf_event_t {")
        single_pass()
        lines.append(f"{INDENT}_count")
        lines.append("};")
        lines.append("")

        # strings for cli
        lines.append("static const")
        lines.append(
            "std::array<std::string, "
            "static_cast<uint32_t>(perf_event_t::_count)>"
        )
        lines.append("perf_event_names = {")
        single_pass(True)
        lines.append("};")
        lines.append("")

    else:
        # main.cpp map for help
        single_pass()

    return lines

def gen_types_h(events):
    return gen_types_cpp(events)

def gen_main_cpp(events):
    return gen_types_cpp(events, map=True)

# sim/sw/common/common.h
def gen_common_h(events):
    events = filter_events(events, KEYS.rtl)
    return [
        f"static const uint32_t mhpmevent_{pe} = (1u << {i});"
        for i, pe in enumerate(events)
    ]

def gen_zihpm_test(events):
    #TEST_CSR(CSR_MHPMEVENT3, mhpmevent_bad_spec);
    CNTRS = [
        "CSR_MHPMEVENT3",
        "CSR_MHPMEVENT4",
        "CSR_MHPMEVENT5",
        "CSR_MHPMEVENT6",
        "CSR_MHPMEVENT7",
        "CSR_MHPMEVENT8",
    ]
    LEN = len(CNTRS)
    events = filter_events(events, KEYS.rtl)
    return [
        f"{INDENT}TEST_CSR({CNTRS[i%LEN]}, mhpmevent_{pe});"
        for i, pe in enumerate(events)
    ]

FILES = {
    # rtl
    "types.svh": (REPO_ROOT / "src/ama_riscv_types.svh"),
    # tb
    "tb_types.svh": (REPO_ROOT / "verif/direct_tb/ama_riscv_tb_types.svh"),
    "tb.sv": (REPO_ROOT / "verif/direct_tb/ama_riscv_tb.sv"),
    # cosim
    "core_stats.h": (REPO_ROOT / "cosim/core_stats.h"),
    # isa sim
    "types.h": (REPO_ROOT / "sim/src/types.h"),
    "main.cpp": (REPO_ROOT / "sim/src/main.cpp"),
    # sw
    "common.h": (REPO_ROOT / "sim/sw/common/common.h"),
    "zihpm_test": (REPO_ROOT / "sim/sw/baremetal/rv32i_zihpm_all/main.c"),
}

TARGETS = {
    FILES["types.svh"]: [gen_types_svh],
    FILES["tb_types.svh"]: [gen_tb_types_svh],
    FILES["tb.sv"]: [gen_tb_sv],
    FILES["core_stats.h"]: [
        gen_core_stats_json_macro,
        gen_core_stats_fields,
        gen_core_stats_acc,
    ],
    FILES["types.h"]: [gen_types_h],
    FILES["main.cpp"]: [gen_main_cpp],
    FILES["common.h"]: [gen_common_h],
    FILES["zihpm_test"]: [gen_zihpm_test],
}

TARGETS_NOTES = {
    FILES["core_stats.h"]:
        "'show_tda()' and 'show_all()' functions might need manual updates; "
        "'cosim/dpi_functions.h' likely needs to be re-generated as well; "
        "'sim/script/{tda.py, perf_est_v2.py}' read hw_stats.json's 'core' "
        "fields directly (hardcoded key names) - might need manual updates",
    FILES["main.cpp"]:
        "'perf' aliases might need manual updates",
    FILES["common.h"]:
        "'common.c' might need manual updates to "
        "'*tda_counters()' and '*hw_counters()' functions, "
        "as well as dedicated 'baremetal/*zihpm*' tests; "
        "smoke 'rv32i_zihpm_all/main.c' is patched",
}

def find_tag_pairs(lines):
    # returns [(begin_idx, end_idx), ...] in file order,
    # 0-based line indices pointing at the marker lines themselves
    pairs = []
    i = 0
    n = len(lines)
    while i < n:
        if TAG_OPEN in lines[i]:
            begin = i
            j = i + 1
            while j < n and TAG_CLOSE not in lines[j]:
                if TAG_OPEN in lines[j]:
                    raise RuntimeError(
                        f"nested/unclosed AUTOGEN BEGIN at line {j + 1} "
                        f"before matching END for BEGIN at line {begin + 1}"
                    )
                j += 1
            if j == n:
                raise RuntimeError(
                    f"unterminated AUTOGEN BEGIN at line {begin + 1}: "
                    "no matching END"
                )
            pairs.append((begin, j))
            i = j + 1
        else:
            i += 1
    return pairs

def patch_file(path, generators, events):
    # returns (new_text, changed)
    original_text = path.read_text()
    lines = original_text.splitlines()
    pairs = find_tag_pairs(lines)

    if len(pairs) != len(generators):
        raise RuntimeError(
            f"{path}: found {len(pairs)} AUTOGEN tag-pair(s) but expected "
            f"{len(generators)} - script's TARGETS registration is out of "
            "sync with the file's actual markers"
        )

    new_lines = list(lines)
    # back-to-front so an earlier pair's body-length change can't invalidate
    # a later pair's line indices
    for (begin, end), gen in reversed(list(zip(pairs, generators))):
        new_lines[begin + 1:end] = gen(events)

    new_text = "\n".join(new_lines) + "\n"
    return new_text, (new_text != original_text)

def main():
    events = load_perf_events()

    any_error = False
    for path, generators in TARGETS.items():
        if not path.is_file():
            print(f"error: target file not found: {path}", file=sys.stderr)
            any_error = True
            continue
        try:
            new_text, changed = patch_file(path, generators, events)
        except RuntimeError as e:
            print(f"error: {e}", file=sys.stderr)
            any_error = True
            continue
        rel = path.relative_to(REPO_ROOT)
        if changed:
            path.write_text(new_text)
            print(f"patched: {rel}")
            if TARGETS_NOTES.get(path):
                print(
                    f"{INDENT}Due to updateds in {path}, {TARGETS_NOTES[path]}"
                )
        else:
            print(f"unchanged: {rel}")

    if any_error:
        sys.exit(1)

if __name__ == "__main__":
    main()
