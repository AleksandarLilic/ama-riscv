#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path

# matching the order in flash_bit.tcl
WORKLOADS = [
    "dhrystone",
    "coremark",
    "stream_int",
    "mlp_w8a8",
    "mlp_w4a8",
    "mlp_w2a8",
    "embench_aha-mont64",
    "embench_crc32",
    "embench_cubic",
    "embench_edn",
    "embench_huffbench",
    "embench_matmult-int",
    "embench_md5sum",
    "embench_minver",
    "embench_nbody",
    "embench_nettle-aes",
    "embench_nettle-sha256",
    "embench_nsichneu",
    "embench_picojpeg",
    "embench_primecount",
    "embench_qrduino",
    "embench_sglib-combined",
    "embench_slre",
    "embench_st",
    "embench_statemate",
    "embench_tarfind",
    "embench_ud",
    "embench_wikisort",
]

def parse_odd_jsons(path: Path) -> list[dict]:
    """
    Return every odd-numbered JSON dict found in *path*.

    A line is considered a JSON object when it starts with '{'.
    Counter starts at 1; odd positions (1, 3, 5, …) are collected.
    """

    results = []
    json_counter = 0
    with path.open() as fh:
        for lineno, line in enumerate(fh, 1):
            stripped = line.strip()
            if not stripped.startswith("{"):
                continue
            json_counter += 1
            if json_counter % 2 == 1:  # odd
                try:
                    results.append(json.loads(stripped))
                except json.JSONDecodeError as exc:
                    sys.exit(
                        f"ERROR: JSON parse failure in {path}:{lineno}: {exc}\n"
                        f"  Line: {stripped!r}"
                    )
    return results

def main() -> None:
    #script_dir = Path(__file__).parent
    cwd = Path.cwd()
    parser = argparse.ArgumentParser(description="Merge TDA + HW UART logs into per-workload JSON files.")
    parser.add_argument("--tda", type=Path, default=cwd / "output_raw_tda.log", help="TDA counter log (default: output_raw_tda.log next to this script)")
    parser.add_argument("--hw", type=Path, default=cwd / "output_raw_hw.log", help="HW counter log (default: output_raw_hw.log next to this script)")
    parser.add_argument("--outdir", type=Path, default=cwd, help="Output directory for per-workload JSON files (default: script directory)")
    args = parser.parse_args()

    tda_path = args.tda
    hw_path = args.hw
    out_dir = args.outdir

    for p in (tda_path, hw_path):
        if not p.exists():
            sys.exit(f"ERROR: log file not found: {p}")

    out_dir.mkdir(parents=True, exist_ok=True)

    tda_dicts = parse_odd_jsons(tda_path)
    hw_dicts = parse_odd_jsons(hw_path)

    n = len(WORKLOADS)
    if len(tda_dicts) != n:
        sys.exit(
            f"ERROR: expected {n} odd JSON dicts in TDA log, "
            f"got {len(tda_dicts)}.\n  Check {tda_path}"
        )
    if len(hw_dicts) != n:
        sys.exit(
            f"ERROR: expected {n} odd JSON dicts in HW log, "
            f"got {len(hw_dicts)}.\n  Check {hw_path}"
        )

    col_w = max(len(w) for w in WORKLOADS)
    print(
        f"{'Workload':<{col_w}}"
        f"  {'cycles(tda)':>14}"
        f"  {'cycles(hw)':>14}"
        f"  {'diff(hw-tda)':>14}"
    )
    print("-" * (col_w + 48))

    for name, tda, hw in zip(WORKLOADS, tda_dicts, hw_dicts):
        # merge: TDA entries first, then HW entries that are not already present
        merged = dict(tda)
        merged.update({k: v for k, v in hw.items() if k not in merged})

        tda_cycles = tda.get("cycles", 0)
        hw_cycles = hw.get("cycles", 0)
        diff = hw_cycles - tda_cycles
        diff_s = f"{diff:>+14,}"
        print(f"{name:<{col_w}}  {tda_cycles:>14,}  {hw_cycles:>14,}  {diff_s}")

        out_path = out_dir / f"{name}_raw.json"
        with out_path.open("w") as fh:
            json.dump({"core": merged}, fh, indent=4)
            fh.write("\n")

    print("-" * (col_w + 48))
    print(f"Wrote {n} JSON files to {out_dir}")

if __name__ == "__main__":
    main()
