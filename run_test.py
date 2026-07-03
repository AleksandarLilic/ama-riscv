#!/usr/bin/env python3

import argparse
import datetime
import functools
import glob
import os
#import random
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from multiprocessing import Manager, Pool

from ruamel.yaml import YAML

from script.utils import (CC_GREEN, CC_RED, CC_YELLOW, INDENT,
                          color_code_string, print_runtime)

TEST_LOG = "test.log"
REPO_ROOT = os.getenv("REPO_ROOT") \
    or sys.exit("Error: REPO_ROOT not set. Source setup.sh first.")
RUN_CFG = os.path.join(REPO_ROOT, "run_cfg_suite.tcl")
MAX_WORKERS = int(os.cpu_count())
TEST_STATUS = "test.status"
TOUCHFILE_COV = ".cov.touchfile"
BUILD_LINKS = ["Makefile", "Makefile.sources.mk", "cosim"]

yaml = YAML()
yaml.preserve_quotes = True
yaml.indent(mapping=2, sequence=4, offset=2)

BUNDLES_KEY = "_bundles"

@dataclass
class make_args:
    timeout_clocks: int
    log_level: str
    log_kanata: bool

# utility functions
def read_from_yaml(file_path):
    with open(file_path, 'r') as file:
        return yaml.load(file)

def to_plusarg(arg, val):
    if val is True:
        return f"-testplusarg {arg}"
    return f"-testplusarg {arg}={val}"

# helper functions
def create_run_cfg(log_wave, log_vcd):
    tcl_content = []
    tcl_content.append("# AUTOMATICALLY GENERATED FILE. DO NOT EDIT.")
    tcl_content.append("set start [expr {[clock seconds] - 1}]")
    if log_wave:
        tcl_content.append("log_wave -recursive *")
    if log_vcd:
        tcl_content.append("open_vcd test_wave.vcd")
        tcl_content.append("log_vcd *")
    tcl_content.append("run all")
    if log_vcd:
        tcl_content.append("close_vcd")
    tcl_content.append(
        "puts \"Simulation runtime: [expr {[clock seconds] - $start}]s\"")
    tcl_content.append("exit")

    with open(RUN_CFG, 'w') as file:
        file.writelines(line + '\n' for line in tcl_content)

def find_all_tests(test_list, filters=None):
    # if filtering is used, apply on top level keys, and put only those entires
    # otherwise, just flatten the entire test_list

    if filters is None:
        filters = []

    bundles = test_list.get(BUNDLES_KEY, {}) or {}
    test_list = {
        key: val for key, val in test_list.items()
        if not str(key).startswith('_')
    }
    filters = [
        bundled_filter
        for f in filters
        for bundled_filter in bundles.get(f, [f])
    ]

    tl_flat = [item for sublist in test_list.values() for item in sublist]
    tl_filt = tl_flat
    if filters:
        tl_filt = [] # reset, filled after filtering
        mode = "neg" if all(f.startswith('~') for f in filters) else "pos"

        tl = {"inc" : [], "exc" : []}
        for key in test_list:
            for f in filters:
                idx = "inc"
                if f.startswith('~'):
                    f = f[1:]
                    idx = "exc"
                if re.search(f, key):
                    tl[idx].extend(test_list[key])

        if mode == "pos":
            # include all from inc, and remove items from exc
            if len(tl["inc"]) > 0:
                tl_filt_all = [
                    item for item in tl_flat
                    if (item in tl["inc"]) and (item not in tl["exc"])
                ]
                # go through list and add only unique items to tl_filt
                for item in tl_filt_all:
                    if item not in tl_filt:
                        tl_filt.append(item)
        else:
            # exclude from all those in exc, no inc list
            tl_filt = [item for item in tl_flat if item not in tl["exc"]]

    valid_tests = []
    some_mismatched = False
    for path, test_name_pattern in tl_filt:
        full_pattern = os.path.join(REPO_ROOT, path, test_name_pattern)
        matched_files = glob.glob(full_pattern)
        if matched_files:
            for file in matched_files:
                valid_tests.append(file)
        else:
            some_mismatched = True
            print(f"Warning: No files match the pattern " + \
                  f"'{test_name_pattern}' in '{path}'.")

    if some_mismatched:
        print("Some test names are invalid. Check the test name/testlist")
        if len(valid_tests) == 0:
            raise ValueError("Error: No valid tests specified")
        else:
            print("Proceeding with the valid tests")
            time.sleep(3)

    dedup = list(set(valid_tests)) # deduplicate after globbing
    dedup.sort()
    return dedup

def format_test_name(test_path):
    return f"{os.path.basename(os.path.dirname(test_path))}_" + \
        f"{os.path.splitext(os.path.basename(test_path))[0]}"

def get_paths_for_test(run_dir, test_name):
    p = {}
    p['test_dir'] = os.path.join(run_dir, test_name)
    p['test_log'] = os.path.join(p['test_dir'], TEST_LOG)
    p['run_sh'] = os.path.join(p['test_dir'], "run.sh") # save cmd for rerun
    p['status_file'] = os.path.join(p['test_dir'], TEST_STATUS)
    return p

def check_test_status(status_file, test_log_path):
    if not os.path.exists(status_file):
        return False, f"{TEST_STATUS} not found. Check {test_log_path} " + \
            "for simulator/tool failure details."

    def read_status_file(status_file):
        # convert testbench written status to dict
        status = {}
        with open(status_file, 'r') as f:
            for line in f:
                key, sep, val = line.strip().partition("=")
                if sep:
                    status[key] = val
        return status

    def format_status_msg(status):
        # parse dict for relevant fields and check values
        msg = status.get("reason", "")
        if status.get("tohost_checker") == "1" and \
        status.get("tohost_pass") != "1":
            msg = f"{msg}; tohost={status.get('tohost', 'unknown')}" \
                if msg else f"tohost={status.get('tohost', 'unknown')}"
        if status.get("errors") not in (None, "0"):
            msg = f"{msg}; errors={status['errors']}" \
                if msg else f"errors={status['errors']}"
        return "" if msg == "none" else msg

    status = read_status_file(status_file)
    if status.get("status") == "PASSED":
        return True, ""
    if status.get("status") == "FAILED":
        return False, format_status_msg(status)
    return False, f"Invalid status in {status_file}: " + \
        f"{status.get('status', '<missing>')}"

# main functions
def set_up_links(dest_dir, source_names):
    for s in source_names:
        path = os.path.join(os.getcwd(), s)
        linked_path = os.path.join(dest_dir, s)
        if not os.path.exists(linked_path):
            os.symlink(path, linked_path)

def build_tb(build_dir, force_rebuild, coverage=False):
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)
    os.makedirs(build_dir)

    set_up_links(build_dir, BUILD_LINKS)
    print(f"Building in {build_dir}... ", end='', flush=True)
    start_time = datetime.datetime.now()
    make_cmd = [
        "make", "elab",
        "ISA_SIM_BDIR=build_obj_for_cosim_runtest",
        "COSIM_BDIR=build_runtest",
        "TO_LOG=0",
        f"-j{MAX_WORKERS}",
    ]
    if coverage:
        # instrument at elab; xsim.codeCov gets created here and is copied into
        # each per-test dir, where each test populates its own DB
        make_cmd.append("COV=1")
    if force_rebuild:
        make_cmd.append("-B")

    make_status = subprocess.run(
        make_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=build_dir
    )

    build_log = os.path.join(build_dir, "build.log")
    with open(build_log, 'w') as f:
        f.write(make_status.stdout.decode('utf-8'))
        f.write(make_status.stderr.decode('utf-8'))

    if make_status.returncode != 0:
        raise ValueError(f"Error: Build failed. "
                         f"Check build log '{build_log}' for details.")

    if coverage: # marker so reused builds can be checked for instrumentation
        open(os.path.join(build_dir, TOUCHFILE_COV), 'w').close()

    print_runtime(start_time, "Build done,")

def run_test(
    test_path, run_dir, build_dir, make_args, mgr,
    keep_pass=False, stop_on_fail=False
    ) -> None:

    start_time = datetime.datetime.now()
    test_name = format_test_name(test_path)
    test_path_make = os.path.splitext(test_path)[0]

    if stop_on_fail and mgr["stop"].is_set():
        print(f"Skipping test '{test_name}' (stop_on_fail).")
        return

    with mgr["lock"]:
        mgr["test_cnt"].value += 1
        print(
            f"Running test {mgr['test_cnt'].value}/{mgr['all_tests']}: " \
            f"'{test_name}'"
        )

    p = get_paths_for_test(run_dir, test_name)
    if os.path.exists(p['test_dir']):
        if keep_pass:
            if os.path.exists(p['status_file']):
                with open(p['status_file'], 'r') as status_file:
                    status = status_file.read()
                    if "PASSED" in status:
                        print(f"Test '{test_name}' already passed.",
                              color_code_string("Skipping", CC_YELLOW))
                        return
        shutil.rmtree(p['test_dir'])

    shutil.copytree(build_dir, p['test_dir'], symlinks=True)
    make_cmd = [
        "make", "sim",
        "ISA_SIM_BDIR=build_obj_runtest",
        "COSIM_BDIR=build_runtest",
        f"TEST_PATH={test_path_make}",
        f"RUN_CFG={RUN_CFG}",
        f"TIMEOUT_CLOCKS={make_args.timeout_clocks}",
        f"LOG_LEVEL={make_args.log_level}",
        "UNIQUE_WDB=0",
        f"LOG_NAME={TEST_LOG}",
        "SIM_ONLY=1",
        f"USER_COSIM_ARGS={to_plusarg('enable_kanata', make_args.log_kanata)}"
    ]

    with open(p['run_sh'], "w") as f:
        f.write("#!/bin/sh\n")
        # quote each argument so spaces/special chars survive
        f.write(" ".join(shlex.quote(arg) for arg in make_cmd))
        f.write("\n")
    os.chmod(p['run_sh'], 0o755)

    # start_new_session puts make + simulator in their own process group
    # (pgid == proc.pid),
    # so killpg can reach all descendants, not just the direct make child
    proc = subprocess.Popen(
        make_cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=p['test_dir'],
        start_new_session=True
    )

    # on SIGTERM (sent by pool.terminate() on Ctrl+C), kill whole process group
    # so simulator orphans don't keep running after the pool workers are gone
    def _sigterm_handler(sig, frame):
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        sys.exit(1)

    old_handler = signal.signal(signal.SIGTERM, _sigterm_handler)
    try:
        proc.wait()
    finally:
        signal.signal(signal.SIGTERM, old_handler) # restore for next iteration

    print(f"Test '{test_name}' DONE.", end=" ")
    passed, msg = check_test_status(p['status_file'], p['test_log'])
    if proc.returncode != 0 and passed:
        passed = False
        msg = f"make/simulator failed with exit code {proc.returncode}."

    status_str, cc = ("PASSED", CC_GREEN) if passed else ("FAILED", CC_RED)
    print(color_code_string(status_str, cc), end=' ')
    print_runtime(start_time)
    if msg:
        print(msg.strip())

    if not passed and stop_on_fail:
        mgr["stop"].set()
        raise ValueError(f"Test '{test_name}' failed. Stopping.")

def run_suite(all_tests, run_dir, build_dir, ma, jobs, keep_pass, stop_on_fail):
    if jobs < 1:
        raise ValueError("The number of parallel jobs must be at least 1.")
    if jobs > MAX_WORKERS:
        print(f"Warning: The specified number of jobs ({jobs}) exceeds the " +
              f"number of available CPU cores ({MAX_WORKERS}).")
    w = min(jobs, MAX_WORKERS)
    print(f"Running simulation with {w} workers\n")

    #random.seed(5)
    #sv_seed = args.seed if args.seed is not None \
    #          else random.randint(0, 2**32 - 1)
    # run tests in parallel
    start_time = datetime.datetime.now()
    try:
        with Manager() as manager:
            mgr = manager.dict()
            mgr["test_cnt"] = manager.Value('i', 0)
            mgr["lock"] = manager.Lock()
            mgr["all_tests"] = len(all_tests)
            mgr["stop"] = manager.Event()
            with Pool(w) as pool:
                partial_run_test = \
                    functools.partial(
                        run_test,
                        run_dir=run_dir,
                        build_dir=build_dir,
                        make_args=ma,
                        mgr=mgr,
                        keep_pass=keep_pass,
                        stop_on_fail=stop_on_fail
                    )
                # imap_unordered yields results as workers finish, so the main
                # process can react to the first failure immediately rather than
                # waiting for all tasks to complete (pool.map behavior)
                try:
                    for _ in pool.imap_unordered(partial_run_test, all_tests):
                        pass
                except Exception:
                    if stop_on_fail:
                        # terminate sends SIGTERM to workers; _sigterm_handler
                        # in each worker kills the simulator process group
                        pool.terminate()
                    raise

    except KeyboardInterrupt:
        print("KeyboardInterrupt received. Terminating.")
        sys.exit(1)
    except Exception as e:
        print(f"Error during test execution: {e}")

    print_runtime(start_time, "Simulation")

def run_coverage(all_tests, run_dir):
    print("\nMerging code coverage...")
    # Makefile (+ its includes) must resolve from run_dir to run the targets
    set_up_links(run_dir, BUILD_LINKS)
    subprocess.run(["make", "cleancov"], cwd=run_dir, check=True)

    # only tests that actually produced a populated DB can be merged
    tests_with_db, missing = [], []
    for test_path in all_tests:
        test_name = format_test_name(test_path)
        if os.path.isdir(os.path.join(run_dir, test_name, "xsim.codeCov")):
            tests_with_db.append(test_name)
        else:
            missing.append(test_name)

    if missing:
        print(color_code_string(
            f"Warning: {len(missing)} test(s) had no coverage DB, skipping: " +
            ", ".join(missing), CC_YELLOW))
    if not tests_with_db:
        raise ValueError(
            "No coverage DBs found. Was the run built with --coverage?")

    cc_dirs = " ".join(f"-cc_dir '{name}'" for name in tests_with_db)
    subprocess.run(
        ["make", "coverage", f"CODE_COV_DB_ALL={cc_dirs}"],
        cwd=run_dir, check=True
    )

    # symlink in the workdir for convenience
    link = os.path.join(run_dir, "coverage_dashboard.html")
    if os.path.islink(link) or os.path.exists(link):
        os.remove(link)
    os.symlink(os.path.join("xcrg_code_cov_report", "dashboard.html"), link)
    print(color_code_string(f"Coverage report: {link}", CC_GREEN))

def parse_args():
    parser = argparse.ArgumentParser(description="Run RTL simulation.")
    parser.add_argument('-t', '--test', nargs='+', help="Specify one or more tests to run (space-separated)")
    parser.add_argument('--testlist', help="Path to a YAML file containing a list of tests")
    parser.add_argument('-f', '--filter', nargs='+', help="Apply filtering to the testlist. Tokens regex-match group names and exact-match bundle aliases from _bundles. Pass as space-separated values. Use ~ to exclude. E.g., '-f riscv_isa ~rv32m' includes all groups matching 'riscv_isa', except those matching 'rv32m'. Quote tokens with shell-special regex chars (e.g. '[', '*'). If not specified, all tests in the testlist are run")
    parser.add_argument('-r', '--rundir', help="Optional custom run directory name")
    parser.add_argument('-o', '--build_only', action='store_true', help="Only build the testbench")
    parser.add_argument('-k', '--keep_build', action='store_true', default=False, help="Reuse existing build if available")
    parser.add_argument('-b', '--rebuild_all', action='store_true', default=False, help="Rebuild everything: RTL, ISA sim, cosim. Takes priority over -k if both are specified")
    parser.add_argument('-p', '--keep_pass', action='store_true', default=False, help="Keep rundir of passed tests. Applicable only if -k is used")
    parser.add_argument('-s', '--stop_on_fail', action='store_true', default=False, help="Stop execution after the first test failure")
    parser.add_argument('-j', '--jobs', type=int, default=MAX_WORKERS, help="Number of parallel jobs to run (default: number of CPU cores)")
    parser.add_argument('-c', '--timeout_clocks', type=int, default=2_000_000, help="Number of clocks before simulations times out")
    parser.add_argument('-v', '--log_level', type=str, default="INFO", help="Log level during simulation")
    parser.add_argument('--coverage', action='store_true', default=False, help="Build instrumented for code coverage, then merge per-test DBs and generate an HTML report after the suite")
    parser.add_argument('--coverage_only', action='store_true', default=False, help="Only merge coverage and generate the report. Relies on existing instrumented test directories from a prior --coverage run")
    #parser.add_argument('--seed', type=int, help="Seed value for the tests")
    parser.add_argument('--dry_run', action='store_true', default=False, help="Print tests that would run without building or simulating")
    parser.add_argument('--log_wave', action='store_true', help="Collect .wdb waveform, all modules from the top down")
    parser.add_argument('--log_vcd', action='store_true', help="Collect .vcd waveform, all modules from the top down")
    parser.add_argument('--log_kanata', action='store_true', help="Collect kanata log")
    return parser.parse_args()

def main():
    start_time_suite = datetime.datetime.now()
    args = parse_args()
    ma = make_args(args.timeout_clocks, args.log_level, args.log_kanata)

    # check arguments
    if args.test and args.testlist:
        raise ValueError("Cannot use both -t|--test and --testlist. Choose one")
    if args.test and args.filter:
        raise ValueError(
            "Cannot use -f|--filter with -t|--test. " +
            "Filter can only be applied to testlist.")
    if args.coverage and args.coverage_only:
        raise ValueError(
            "Cannot use both --coverage and --coverage_only. Choose one.")
    if args.coverage_only and not args.rundir:
        raise ValueError(
            "--coverage_only needs -r|--rundir pointing at an " +
            "existing instrumented run directory.")

    if not args.dry_run:
        create_run_cfg(args.log_wave, args.log_vcd)

    if args.test:
        test_list = {
            f"test_{i}": [[os.path.dirname(t), os.path.basename(t)]]
            for i, t in enumerate(args.test)
        }
        all_tests = find_all_tests(test_list)
        if not all_tests:
            raise ValueError("Error: No tests found.")
        print(f"\nTestlist:")
        print("   " + "\n   ".join(all_tests))
        print(f"Running {len(all_tests)} test(s) total")
    elif args.testlist:
        filters = []
        if args.filter:
            filters = args.filter
            print(f"Applying filter(s): {filters}")
        all_tests = find_all_tests(read_from_yaml(args.testlist), filters)
        if not all_tests:
            raise ValueError("Error: No tests found after filtering.")
        print(f"\nTestlist:")
        print("   " + "\n   ".join(all_tests))
        print(f"Running {len(all_tests)} test(s) total")
    else:
        raise ValueError("Error: No test specified.")

    if args.dry_run:
        print(f"\nDry run completed. Exiting.")
        sys.exit(0)

    # handle run directory
    if args.rundir:
        run_dir = args.rundir
    else:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        run_dir = f"testrun_{timestamp}"

    build_dir = os.path.join(run_dir, "build")
    if args.coverage_only:
        if not os.path.isdir(run_dir):
            raise ValueError(f"--coverage_only: run dir '{run_dir}' not found.")
        print(f"Coverage-only: merging existing DBs in '{run_dir}'")

    elif args.keep_build and os.path.exists(f"{build_dir}/.elab.touchfile"):
        print(f"Reusing existing build directory at '{build_dir}'")
        if args.coverage and not os.path.exists(f"{build_dir}/{TOUCHFILE_COV}"):
            print(color_code_string(
                "Warning: reused build is not instrumented for coverage; "
                "coverage DBs will be empty. Rebuild without -k.", CC_YELLOW))

    else:
        if os.path.exists(run_dir): # clean up previous run_dir if it exists
            shutil.rmtree(run_dir)
        os.makedirs(run_dir)
        build_tb(build_dir, args.rebuild_all, coverage=args.coverage)

    if args.build_only:
        print(f"Building done at '{build_dir}'. Exiting")
        sys.exit(0)

    if not args.coverage_only:
        run_suite(all_tests, run_dir, build_dir, ma, args.jobs,
                  args.keep_pass, args.stop_on_fail)

    # check test suite results
    all_tests_passed = True
    tests_num = len(all_tests)
    tests_passed = 0
    failed_tests = []
    print("\nSummary:")
    for test_path in all_tests:
        test_name = format_test_name(test_path)
        p = get_paths_for_test(run_dir, test_name)
        t_passed, t_msg = check_test_status(p['status_file'], p['test_log'])
        if t_passed:
            tests_passed += 1
            cc = CC_GREEN
        else:
            all_tests_passed = False
            cc = CC_RED if os.path.exists(p['status_file']) else CC_YELLOW
            failed_tests.append(f"\n{INDENT}{test_name}")

        status_str = "PASSED" if t_passed else "FAILED"
        status = f"Test '{test_name}' {status_str}"
        if t_msg:
            status += f" {t_msg}. Log at {p['test_log']}"
        print(color_code_string(status, cc))

    print(f"\nTest suite DONE. Pass rate: {tests_passed}/{tests_num} passed;",
          end=" ")
    if all_tests_passed:
        print(color_code_string("Test suite PASSED.", CC_GREEN))
    else:
        print(color_code_string("Test suite FAILED.", CC_RED))
        print("\nFailed test(s):", end='')
        print("".join(failed_tests))

    # allow merge/report coverage even if some tests failed
    if args.coverage or args.coverage_only:
        run_coverage(all_tests, run_dir)

    print_runtime(start_time_suite, "Test suite", "\n")
    sys.exit(0 if all_tests_passed else 1)

if __name__ == "__main__":
    main()
