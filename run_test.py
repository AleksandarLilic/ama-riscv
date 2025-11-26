#!/usr/bin/env python3

import argparse
import datetime
import functools
import glob
import json
import os
import random
import re
import shlex
import shutil
import subprocess
import sys
import time
from collections import deque
from dataclasses import dataclass
from multiprocessing import Manager, Pool

CC_RED = "91m"
CC_GREEN = "32m"
INDENT = " " * 4
TEST_LOG = "test.log"
REPO_ROOT = os.getenv("REPO_ROOT")
RUN_CFG = os.path.join(REPO_ROOT, "run_cfg_suite.tcl")
TEST_STATUS = "test.status"

MSG_PASS = "==== PASS ===="
MSG_FAIL = "==== FAIL ===="

@dataclass
class make_args:
    timeout_clocks: int
    log_level: str

def parse_args():
    parser = argparse.ArgumentParser(description="Run RTL simulation.")
    parser.add_argument('-t', '--test', help="Specify single test to run")
    parser.add_argument('--testlist', help="Path to a JSON file containing a list of tests")
    parser.add_argument('-f', '--filter', help="Apply regex filtering to the testlist on the group name. Passed in as comma-separated values. Use ~ to exclude test. E.g., -f 'riscv_isa,~zmmul' includes all groups that match 'riscv_isa' string in the group name, except those that match 'zmmul'. If not specified, all tests in the testlist are run")
    parser.add_argument('-r', '--rundir', help="Optional custom run directory name")
    parser.add_argument('-o', '--build_only', action='store_true', help="Only build the testbench")
    parser.add_argument('-k', '--keep_build', action='store_true', default=False, help="Reuse existing build if available")
    parser.add_argument('-b', '--rebuild_all', action='store_true', default=False, help="Rebuild everything: RTL, ISA sim, cosim. Takes priority over -k if both are specified")
    parser.add_argument('-p', '--keep_pass', action='store_true', default=False, help="Keep rundir of passed tests. Applicable only if -k is used")
    parser.add_argument('-j', '--jobs', type=int, default=MAX_WORKERS, help="Number of parallel jobs to run (default: number of CPU cores)")
    parser.add_argument('-c', '--timeout_clocks', type=int, default=500_000, help="Number of clocks before simulations times out")
    parser.add_argument('-v', '--log_level', type=str, default="WARN", help="Log level during simulation")
    #parser.add_argument('--coverage', action='store_true', help="Enable coverage analysis")
    #parser.add_argument('--coverage-only', action='store_true', help="Only run coverage analysis. Relies on the existing test directories for the specified tests")
    #parser.add_argument('--seed', type=int, help="Seed value for the tests")
    parser.add_argument('--log_wave', action='store_true', help="Collect .wdb waveform, all modules from the top down")
    parser.add_argument('--log_vcd', action='store_true', help="Collect .vcd waveform, all modules from the top down")
    return parser.parse_args()

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

def format_test_name(test_path):
    return f"{os.path.basename(os.path.dirname(test_path))}_" + \
        f"{os.path.splitext(os.path.basename(test_path))[0]}"

def read_from_json(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

def find_all_tests(test_list, filters=[]):
    # if filtering is used, apply on top level keys, and put only those entires
    # otherwise, just flatten the entire test_list

    tl_flat = [item for sublist in test_list.values() for item in sublist]
    tl_filt = tl_flat
    if filters:
        tl_filt = [] # reset, filled after filtering
        mode = "neg" if all(f.startswith('~') for f in filters) else "pos"

        tl = {"inc" : [], "exc" : []}
        if filters:
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
                  f"<{test_name_pattern}> in <{path}>.")

    if some_mismatched:
        print("Some test names are invalid. Check the test name/testlist")
        if len(valid_tests) == 0:
            raise ValueError("Error: No valid tests specified")
        else:
            print("Proceeding with the valid tests")
            time.sleep(3)

    return valid_tests

def check_test_status(test_log_path, test_name):
    if os.path.exists(test_log_path):
        errors = []
        last_lines = deque(open(test_log_path, 'r'), maxlen=100)
        for line in last_lines:
            if "ERROR" in line:
                errors.append(f"\n{INDENT}{line.strip()}")
            if MSG_PASS in line:
                return f"Test <{test_name}> PASSED."
            elif MSG_FAIL in line:
                return f"Test <{test_name}> FAILED with: " + "".join(errors)
            elif "cosim_exec()" in line:
                return f"Test <{test_name}> FAILED. " + \
                        "Cosim stopped. Check the log for details."
        return f"Test <{test_name}> result is inconclusive. " + \
            f"Check {test_log_path} for details."
    else:
        return f"{TEST_LOG} not found at {test_log_path}. " + \
            "Cannot determine test result."

def build_tb(build_dir, force_rebuild):
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)
    os.makedirs(build_dir)

    def set_up_links(dest_dir, source_names):
        for s in source_names:
            path = os.path.join(os.getcwd(), s)
            linked_path = os.path.join(dest_dir, s)
            os.symlink(path, linked_path)

    set_up_links(build_dir, ["Makefile", "Makefile.inc", "cosim"])
    print(f"Building in {build_dir}... ", end='', flush=True)
    start_time = datetime.datetime.now()
    make_cmd = [
        "make", "elab",
        "ISA_SIM_BDIR=build_obj_runtest",
        "COSIM_BDIR=build_runtest",
        f"-j{MAX_WORKERS}",
    ]
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

    print_runtime(start_time, "Build done,")

def get_paths_for_test(run_dir, test_name):
    p = {}
    p['test_dir'] = os.path.join(run_dir, test_name)
    p['test_log'] = os.path.join(p['test_dir'], "test.log")
    p['run_sh'] = os.path.join(p['test_dir'], "run.sh") # save cmd for rerun
    p['status_file'] = os.path.join(p['test_dir'], TEST_STATUS)
    return p

def run_test(test_path, run_dir, build_dir, make_args, cnt, keep_pass=False):
    test_name = format_test_name(test_path)
    test_path_make = os.path.splitext(test_path)[0]
    with cnt["lock"]:
        cnt["t"].value += 1
        print(f"Running test {cnt['t'].value}/{cnt['total']}: <{test_name}>")

    p = get_paths_for_test(run_dir, test_name)
    if os.path.exists(p['test_dir']):
        if keep_pass:
            if os.path.exists(p['status_file']):
                with open(p['status_file'], 'r') as status_file:
                    status = status_file.read()
                    if "PASSED" in status:
                        print(f"Test <{test_name}> already PASSED. Skipping.")
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
        f"UNIQUE_WDB=0", # single wdb per test run dir, always the same wdb name
        f"TO_LOG=0", # stdout will be picked up by this script instead
    ]

    with open(p['run_sh'], "w") as f:
        f.write("#!/bin/sh\n")
        # quote each argument so spaces/special chars survive
        f.write(" ".join(shlex.quote(arg) for arg in make_cmd))
        f.write("\n")
    os.chmod(p['run_sh'], 0o755)

    make_status = subprocess.run(
        make_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=p['test_dir']
    )

    with open(p['test_log'], 'w') as f:
        f.write(make_status.stdout.decode('utf-8'))
        f.write(make_status.stderr.decode('utf-8'))

    print(f"Test <{test_name}> DONE.", end=" ")
    if make_status.returncode != 0:
        # something went wrong at make level
        raise ValueError(f"Error: Run test <{test_name}> failed. "
                         f"Check test log '{p['test_log']}' for details.")

    # write to test.status
    with open(p['status_file'], 'w') as status_file:
        status = check_test_status(p['test_log'], test_name)
        status_file.write(status+"\n")
        print(status.replace(f"Test <{test_name}>", "").strip())

def print_runtime(start_time, process_name, end='\n'):
    end_time = datetime.datetime.now()
    elapsed_time = end_time - start_time
    hours, remainder = divmod(elapsed_time.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    print(
        f"{process_name} runtime:",
        f"{hours}h" if hours else "",
        f"{minutes}m {seconds+1}s", # rounds down, correct +1 for sec here
        end=end
    )

def main():
    start_time_suite = datetime.datetime.now()
    args = parse_args()
    ma = make_args(args.timeout_clocks, args.log_level)

    # check arguments
    if args.test and args.testlist:
        raise ValueError("Cannot use both -t|--test and --testlist. Choose one")
    if args.test and args.filter:
        raise ValueError("Cannot use -f|--filter with -t|--test. " +
                         "Filter can only be applied to testlist.")

    create_run_cfg(args.log_wave, args.log_vcd)
    if args.test:
        all_tests = find_all_tests(
            [[os.path.dirname(args.test), os.path.basename(args.test)]]
        )
        print(f"\nRunning {all_tests[0]}")
    elif args.testlist:
        filters = []
        if args.filter:
            filters = [f.strip() for f in args.filter.split(',')]
            print(f"Applying filter(s): {filters}")
        all_tests = find_all_tests(read_from_json(args.testlist), filters)
        print(f"\nTestlist:")
        print("   " + "\n   ".join(all_tests))
        print(f"Running {len(all_tests)} test(s) total")
    else:
        raise ValueError("Error: No test specified.")

    # handle run directory
    if args.rundir:
        run_dir = args.rundir
    else:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        run_dir = f"testrun_{timestamp}"

    build_dir = os.path.join(run_dir, "build")
    if args.keep_build and os.path.exists(f"{build_dir}/.elab.touchfile"):
        print(f"Reusing existing build directory at <{build_dir}>")
    else:
        if os.path.exists(run_dir): # clean up previous run_dir if it exists
            shutil.rmtree(run_dir)
        os.makedirs(run_dir)
        build_tb(build_dir, args.rebuild_all)

    if args.build_only:
        print(f"Building done at <{build_dir}>. Exiting")
        sys.exit(0)

    # check if the specified number of jobs exceeds the number of CPU cores
    if args.jobs < 1:
        raise ValueError("The number of parallel jobs must be at least 1.")
    if args.jobs > MAX_WORKERS:
        print(f"Warning: The specified number of jobs ({args.jobs}) exceeds " +
              f"the number of available CPU cores ({MAX_WORKERS}).")
    #print(f"Running simulation with {min(args.jobs,MAX_WORKERS)} workers")

    #random.seed(5)
    #sv_seed = args.seed if args.seed is not None \
    #          else random.randint(0, 2**32 - 1)
    # run tests in parallel
    start_time = datetime.datetime.now()
    try:
        with Manager() as manager:
            cnt = manager.dict()
            cnt["t"] = manager.Value('i', 0)
            cnt["lock"] = manager.Lock()
            cnt["total"] = len(all_tests)
            with Pool(min(args.jobs, MAX_WORKERS)) as pool:
                partial_run_test = \
                    functools.partial(
                        run_test,
                        run_dir=run_dir,
                        build_dir=build_dir,
                        make_args=ma,
                        cnt=cnt,
                        keep_pass=args.keep_pass
                    )
                pool.map(partial_run_test, all_tests) # , chunksize=2

    except KeyboardInterrupt:
        print("KeyboardInterrupt received. Terminating.")
        # __exit__ in Pool should handle these
        #pool.terminate()
        #pool.join() # wait for them to actually exit
        sys.exit(1)

    print_runtime(start_time, "Simulation")
    # check test suite results
    all_tests_passed = True
    tests_num = len(all_tests)
    tests_passed = 0
    failed_tests = []
    print("\nSummary:")
    for test_path in all_tests:
        test_name = format_test_name(test_path)
        p = get_paths_for_test(run_dir, test_name)
        if os.path.exists(p['status_file']):
            with open(p['status_file'], 'r') as status_file:
                status = status_file.read()
                if "PASSED" not in status:
                    all_tests_passed = False
                    cc = CC_RED
                    failed_tests.append(f"\n{INDENT}{test_name}")
                else:
                    tests_passed += 1
                    cc = CC_GREEN
                print(f"\033[{cc}{status}\033[0m", end='')
        else:
            print(f"Status for <{test_name}> not found.")
            all_tests_passed = False

    print(f"\nTest suite DONE. Pass rate: {tests_passed}/{tests_num} passed;",
          end=" ")
    if all_tests_passed:
        print(f"\033[{CC_GREEN}Test suite PASSED.\033[0m")
    else:
        print(f"\033[{CC_RED}Test suite FAILED.\033[0m")
        print("\nFailed tests:", end='')
        print("".join(failed_tests))

    print_runtime(start_time_suite, "Test suite")
    print()

if __name__ == "__main__":
    MAX_WORKERS = int(os.cpu_count())
    main()
