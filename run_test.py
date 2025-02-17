#!/usr/bin/env python3

import os
import subprocess
import datetime
import shutil
import argparse
from multiprocessing import Pool, Manager
import functools
import json
import random
import glob

RUN_CFG = "run_cfg_suite.tcl"
CC_RED = "91m"
CC_GREEN = "32m"
TEST_LOG = "test.log"

def parse_args():
    parser = argparse.ArgumentParser(description='Run RTL simulation.')
    parser.add_argument('-t', '--test', help='Specify single test to run')
    parser.add_argument('--testlist', help='Path to a JSON file containing a list of tests')
    parser.add_argument('--rundir', help='Optional custom run directory name')
    parser.add_argument('--keep-build', action='store_true', help='Reuse existing build directory if available')
    parser.add_argument('-j', '--jobs', type=int, default=MAX_WORKERS, help='Number of parallel jobs to run (default: number of CPU cores)')
    #parser.add_argument('--coverage', action='store_true', help='Enable coverage analysis')
    #parser.add_argument('--coverage-only', action='store_true', help='Only run coverage analysis. Relies on the existing test directories for the specified tests')
    #parser.add_argument('--seed', type=int, help='Seed value for the tests')
    parser.add_argument('--log_wave', action='store_true', help='Include log wave command in TCL script')
    return parser.parse_args()

def create_run_cfg(add_log_wave):
    tcl_content = []
    if add_log_wave:
        tcl_content.append("log_wave -recursive *")
    tcl_content.extend([
        "run all",
        "exit"
    ])

    with open(RUN_CFG, 'w') as file:
        file.writelines(line + '\n' for line in tcl_content)

def format_test_name(test_path):
    return f"{os.path.basename(os.path.dirname(test_path))}_" + \
        f"{os.path.splitext(os.path.basename(test_path))[0]}"

def read_from_json(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

def find_all_tests(test_list):
    valid_tests = []
    for path, test_name_pattern in test_list:
        full_pattern = os.path.join(path, test_name_pattern)
        matched_files = glob.glob(full_pattern)
        if matched_files:
            for file in matched_files:
                valid_tests.append(file)
        else:
            print(f"Warning: No files match the pattern " + \
                  f"<{test_name_pattern}> in <{path}>.")
    return valid_tests

def check_make_status(make_status, msg: str) -> int:
    if make_status.returncode != 0:
        print("Makefile stdout:")
        print(make_status.stdout.decode('utf-8'))
        print("Makefile stderr:")
        print(make_status.stderr.decode('utf-8'))
        print(f"Error: Makefile failed to {msg}.")
        return make_status.returncode
    return 0

def check_test_status(test_log_path, test_name):
    if os.path.exists(test_log_path):
        with open(test_log_path, 'r') as file:
            for line in file:
                if "==== PASS ====" in line:
                    return f"Test <{test_name}> PASSED."
                elif "==== FAIL ====" in line:
                    return f"Test <{test_name}> FAILED."
                elif "cosim_exec()" in line:
                    return f"Test <{test_name}> FAILED. " + \
                           "Cosim stopped. Check the log for details."
            return f"Test <{test_name}> result is inconclusive. " + \
                f"Check {test_log_path} for details."
    else:
        return f"{TEST_LOG} not found at {test_log_path}. " + \
            "Cannot determine test result."

def run_test(test_path, run_dir, build_dir, cnt):
    test_name = format_test_name(test_path)
    test_path_make = os.path.splitext(test_path)[0]
    with cnt["lock"]:
        cnt["t"].value += 1
        print(f"Running test {cnt['t'].value}/{cnt['total']}: <{test_name}>")
    #print(f"Running test <{test_name}>")
    test_dir = os.path.join(run_dir, f"test_{test_name}")
    if os.path.exists(test_dir):
        shutil.rmtree(test_dir)
    shutil.copytree(build_dir, test_dir, symlinks=True)
    make_status = subprocess.run(["make", "sim", f"-j{MAX_WORKERS}",
                                 f"TEST_PATH={test_path_make}",
                                 f"TCLBATCH={RUN_CFG}"],
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE,
                                 cwd=test_dir)
    print(f"Test <{test_name}> DONE.", end=" ")
    _ = check_make_status(make_status, f"run test <{test_name}>")
    # write to test.status
    status_file_path = os.path.join(test_dir, "test.status")
    with open(status_file_path, 'w') as status_file:
        status = check_test_status(os.path.join(test_dir, TEST_LOG), test_name)
        status_file.write(status)
        print(status)

def print_runtime(start_time, process_name):
    end_time = datetime.datetime.now()
    elapsed_time = end_time - start_time
    hours, remainder = divmod(elapsed_time.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    print(f"{process_name} runtime: ", end="")
    if hours:
        print(f"{hours}h {minutes}m {seconds}s")
    else:
        print(f"{minutes}m {seconds}s")

def main():
    start_time_suite = datetime.datetime.now()
    args = parse_args()

    # check arguments
    if args.test and args.testlist:
        raise ValueError("Cannot use both -t|--test and --testlist. Choose one")

    create_run_cfg(args.log_wave)
    if args.test:
        all_tests = find_all_tests([[os.path.dirname(args.test),
                                     os.path.basename(args.test)]])
    elif args.testlist:
        all_tests = find_all_tests(read_from_json(args.testlist))
    else:
        raise ValueError("Error: No test specified.")

    print(f"\nTestlist:")
    print("   " + "\n   ".join(all_tests))
    print(f"Running {len(all_tests)} tests total")

    # handle run directory
    if args.rundir:
        run_dir = args.rundir
    else:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        run_dir = f"rv_test_{timestamp}"

    if not os.path.exists(run_dir):
        os.makedirs(run_dir)

    build_dir = os.path.join(run_dir, "build")
    if args.keep_build and os.path.exists(f"{build_dir}/.elab.touchfile"):
        print(f"Reusing existing build directory at <{build_dir}>")
    else:
        if os.path.exists(build_dir):
            shutil.rmtree(build_dir)
        os.makedirs(build_dir)
        makefile_path = os.path.join(os.getcwd(), "Makefile")
        linked_makefile_path = os.path.join(build_dir, "Makefile")
        os.symlink(makefile_path, linked_makefile_path)

        print("Building...")
        start_time = datetime.datetime.now()
        make_build_log = subprocess.run(["make", "elab", f"-j{MAX_WORKERS}"],
                                        stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE,
                                        cwd=build_dir)
        print_runtime(start_time, "Build")
        if check_make_status(make_build_log, "build") != 0:
            raise ValueError("Error: Build failed.")
        print("Build DONE.")

    # check if the specified number of jobs exceeds the number of CPU cores
    if args.jobs < 1:
        raise ValueError("The number of parallel jobs must be at least 1.")
    if args.jobs > MAX_WORKERS:
        print(f"Warning: The specified number of jobs ({args.jobs}) exceeds " +
              f"the number of available CPU cores ({MAX_WORKERS}).")
    print(f"Running simulation with {min(args.jobs,MAX_WORKERS)} parallel jobs")

    # run tests in parallel
    random.seed(5)
    #sv_seed = args.seed if args.seed is not None \
    #          else random.randint(0, 2**32 - 1)
    start_time = datetime.datetime.now()
    with Manager() as manager:
        cnt = manager.dict()
        cnt["t"] = manager.Value('i', 0)
        cnt["lock"] = manager.Lock()
        cnt["total"] = len(all_tests)
        with Pool(min(args.jobs,MAX_WORKERS)) as pool:
            partial_run_test = functools.partial(run_test, run_dir=run_dir,
                                                 build_dir=build_dir, cnt=cnt)
            pool.map(partial_run_test, all_tests)
    print_runtime(start_time, "Simulation")

    # check test suite results
    all_tests_passed = True
    tests_num = len(all_tests)
    tests_passed = 0
    print("\nSummary:")
    for test_path in all_tests:
        test_name = format_test_name(test_path)
        test_dir = os.path.join(run_dir, f"test_{test_name}")
        status_file_path = os.path.join(test_dir, "test.status")
        if os.path.exists(status_file_path):
            with open(status_file_path, 'r') as status_file:
                status = status_file.read()
                if "PASSED" not in status:
                    all_tests_passed = False
                    cc = CC_RED
                else:
                    tests_passed += 1
                    cc = CC_GREEN
                print(f"\033[{cc}{status}\033[0m")
        else:
            print(f"Status for <{test_name}> not found.")
            all_tests_passed = False

    print(f"\nTest suite DONE. Pass rate: {tests_passed}/{tests_num} passed;",
          end=" ")
    if all_tests_passed:
        print(f"\033[{CC_GREEN}Test suite PASSED.\033[0m\n")
    else:
        print(f"\033[{CC_RED}Test suite FAILED.\033[0m\n")

    print_runtime(start_time_suite, "Test suite")
    print()

if __name__ == "__main__":
    MAX_WORKERS = int(os.cpu_count())
    main()
