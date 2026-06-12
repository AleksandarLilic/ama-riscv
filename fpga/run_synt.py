#!/usr/bin/env python3
"""
FPGA synt/impl driver: run one or more YAML experiment configs in parallel

each config is a non-project (in-memory) Vivado batch run (fpga/synt.tcl)
under its own timestamped run dir

strategy/defines/sources all come from YAML, see fpga/configs/_base.yaml

Usage:
    ./run_synt.py --config fpga/configs/simd_full_50.yaml [more.yaml ...]
"""

import argparse
import concurrent.futures
import datetime
import os
import shutil
import subprocess
import sys

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, REPO_ROOT)

from script.utils import INDENT, print_runtime

PARSE_FILELIST = os.path.join(REPO_ROOT, "script", "parse_filelist.py")
SYNT_TCL = os.path.join(SCRIPT_DIR, "synt.tcl")

# config loading
def deep_merge(base, over):
    """
    recursively merge `over` onto `base`; dicts merge per-key; else `over` wins
    """
    if isinstance(base, dict) and isinstance(over, dict):
        out = dict(base)
        for k, v in over.items():
            out[k] = deep_merge(base[k], v) if k in base else v
        return out
    return over

def load_config(path, _seen=None):
    _seen = _seen or []
    path = os.path.abspath(path)
    if path in _seen:
        sys.exit(f"error: extends cycle: {' -> '.join(_seen + [path])}")
    if not os.path.isfile(path):
        sys.exit(f"error: no such config: {path}")
    with open(path) as f:
        cfg = yaml.safe_load(f) or {}
    base = cfg.pop("extends", None)
    if base:
        base_cfg = load_config(
            os.path.join(os.path.dirname(path), base), _seen + [path]
        )
        cfg = deep_merge(base_cfg, cfg)
    return cfg

def resolve_path(p):
    return p if os.path.isabs(p) \
        else os.path.normpath(os.path.join(REPO_ROOT, p))

# params.tcl
def parse_filelist(mode, filelist):
    env = dict(os.environ, REPO_ROOT=REPO_ROOT)
    out = subprocess.run(
        [sys.executable, PARSE_FILELIST, mode, filelist],
        env=env, capture_output=True, text=True, check=True
    )
    return out.stdout.split()

def build_defines(cfg):
    defs = []
    for k, v in (cfg.get("defines") or {}).items():
        defs.append(k if v is None else f"{k}={v}")
    hex_path = cfg.get("hex_path")
    if hex_path:
        defs.append(f"FPGA_HEX_PATH={resolve_path(hex_path)}")
    return defs

def synt_options(synt):
    parts = []
    for k, v in (synt.get("options") or {}).items():
        if v is True:
            parts.append(f"-{k}")
        elif v is False:
            continue
        else:
            parts.append(f"-{k} {v}")
    return " ".join(parts)

def tcl_list(items):
    return "{" + " ".join(items) + "}"

def emit_params_tcl(cfg, run_dir, threads):
    filelist = resolve_path(cfg["sources"]["filelist"])
    design = [resolve_path(p) for p in parse_filelist("design", filelist)]
    headers = [p for p in design if p.endswith(".svh")]
    sources = [p for p in design if p.endswith(".sv")]
    incdirs = [resolve_path(p) for p in parse_filelist("include-dirs",filelist)]
    xdcs = [resolve_path(p) for p in cfg["sources"]["constraints"]]

    impl = cfg.get("impl") or {}
    def directive(step):
        return (impl.get(step) or {}).get("directive", "")
    def enabled(step): # power steps: enable-only, no -directive
        return 1 if (impl.get(step) or {}).get("enabled", False) else 0
    def directives_list(step):# repeatable steps: 0..N passes, one per directive
        v = impl.get(step) or []
        return tcl_list(v if isinstance(v, list) else [v])

    lines = [
        f'set PART {cfg["part"]}',
        f'set TOP {cfg["sources"]["top"]}',
        f'set RUN_DIR "{run_dir}"',
        f"set HEADERS {tcl_list(headers)}",
        f"set SOURCES {tcl_list(sources)}",
        f"set INCLUDE_DIRS {tcl_list(incdirs)}",
        f"set XDCS {tcl_list(xdcs)}",
        f"set DEFINES {tcl_list(build_defines(cfg))}",
        f'set SYNTH_FLATTEN {cfg["synt"]["flatten_hierarchy"]}',
        f'set SYNTH_DIRECTIVE {cfg["synt"]["directive"]}',
        f'set SYNTH_OPTIONS "{synt_options(cfg["synt"])}"',
        f'set IMPL_OPT_DIRECTIVE "{directive("opt_design")}"',
        f'set IMPL_POWER_OPT_ENABLE {enabled("power_opt_design")}',
        f'set IMPL_PLACE_DIRECTIVE "{directive("place_design")}"',
        f'set IMPL_POST_PLACE_POWER_OPT_ENABLE {enabled("post_place_power_opt_design")}',
        f'set IMPL_PHYS_OPT_DIRECTIVES {directives_list("phys_opt_design")}',
        f'set IMPL_ROUTE_DIRECTIVE "{directive("route_design")}"',
        f'set IMPL_POST_ROUTE_PHYS_OPT_DIRECTIVES {directives_list("post_route_phys_opt_design")}',
        f'set BITSTREAM {1 if cfg.get("bitstream") else 0}',
        f'set MMI {1 if cfg.get("mmi") else 0}',
        f'set MAX_THREADS {threads}',
    ]
    params = os.path.join(run_dir, "params.tcl")
    with open(params, "w") as f:
        f.write("\n".join(lines) + "\n")
    return params

# run
def run_one(name, cfg, run_dir, threads):
    start_time = datetime.datetime.now()
    os.makedirs(run_dir, exist_ok=True)
    params = emit_params_tcl(cfg, run_dir, threads)
    with open(os.path.join(run_dir, "config.resolved.yaml"), "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)
    cmd = [
        "vivado",
        "-log", os.path.join(run_dir, "run.log"),
        "-journal", os.path.join(run_dir, "run.jou"),
        "-mode", "batch",
        "-source", SYNT_TCL,
        "-tclargs", params
    ]

    console = os.path.join(run_dir, "console.log")
    with open(console, "w") as out:
        rc = subprocess.run(
            cmd, cwd=run_dir, stdout=out, stderr=subprocess.STDOUT,
        ).returncode
    status_str = f"[{'OK' if rc == 0 else 'FAIL'}] {name} (rc={rc})"
    print_runtime(start_time, status_str)

    # when vivado inevitably segfaults, print what happened
    if rc != 0:
        with open(console) as f:
            tail = f.readlines()[-15:]
        print(f"  -> {console} (tail):")
        for line in tail:
            print(f"  | {line.rstrip()}")

    return rc

def parse_args():
    parser = argparse.ArgumentParser(description="FPGA synt/impl driver (YAML configs)")
    parser.add_argument("--config", nargs="+", required=True, help="one or more YAML configs")
    parser.add_argument("-j", "--jobs", type=int, default=4, help="concurrent vivado processes")
    parser.add_argument("--threads", type=int, default=0, help="per-vivado max threads (general.maxThreads); 0 = vivado auto")
    parser.add_argument("--tag", type=str, help="append tag to the end of the rundir name")
    parser.add_argument("-d", "--dry_run", action='store_true', default=False, help="Print configs that would run and exit")
    return parser.parse_args()

def main():
    args = parse_args()

    if not shutil.which("vivado"):
        sys.exit("error: vivado not on PATH (`source setup.sh` likely missing)")

    ts = datetime.datetime.now().strftime("%y%m%d-%H%M%S")
    jobs, names = [], {}
    for cpath in args.config:
        cfg = load_config(cpath)
        name = \
            cfg.get("run_name") or os.path.splitext(os.path.basename(cpath))[0]
        if name in names:
            sys.exit(f"error: run name collision '{name}' "
                     f"({names[name]} and {cpath})")

        names[name] = cpath
        run_root = os.path.abspath(cfg.get("run_root", "."))
        run_dir = os.path.join(run_root, f"synt_{name}_{ts}_{args.tag}")
        jobs.append((name, cfg, run_dir))

    print(f"launching {len(jobs)} run(s), up to {args.jobs} parallel "
          f"({args.threads or 'auto'} threads each):")

    for name, _, run_dir in jobs:
        print(f"{INDENT}{name} -> {run_dir}")

    if args.dry_run:
        print(f"\nDry run completed. Exiting.")
        sys.exit(0)

    start_time = datetime.datetime.now()
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        fut = {
            ex.submit(run_one, name, cfg, rd, args.threads): (name, rd) \
                for name, cfg, rd in jobs
        }
        for f in concurrent.futures.as_completed(fut):
            name, rd = fut[f]
            rc = f.result()
            results[name] = (rc, rd)

    print_runtime(start_time, "All runs")
    sys.exit(0 if all(rc == 0 for rc, _ in results.values()) else 1)

if __name__ == "__main__":
    main()
