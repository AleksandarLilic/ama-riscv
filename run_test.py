import os
import subprocess
import datetime
import shutil
import argparse
import multiprocessing
import functools
import json
import random
import glob

RUN_CFG = "run_cfg_suite.tcl"

def parse_args():
    parser = argparse.ArgumentParser(description='Run RTL simulation.')
    #parser.add_argument('-t', '--test', action='append', help='Specify the tests to run')
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
            print(f"Warning: No files match the pattern <{test_name_pattern}> in <{path}>.")
    return valid_tests

def check_make_status(make_status, msg: str):
    if make_status.returncode != 0:
        raise RuntimeError(f"Error: Makefile failed to {msg}.")

def check_test_status(test_log_path, test_name):
    if os.path.exists(test_log_path):
        with open(test_log_path, 'r') as file:
            for line in file:
                if "==== PASS ====" in line:
                    return f"Test <{test_name}> PASSED."
                elif "==== FAIL ====" in line:
                    return f"Test <{test_name}> FAILED."
            return f"Test <{test_name}> result is inconclusive. Check {test_log_path} for details."
    else:
        return f"test.log not found at {test_log_path}. Cannot determine test result."

def run_test(test_path, run_dir, build_dir):
    test_name = os.path.splitext(os.path.basename(test_path))[0]
    print(f"Running test <{test_name}>")
    test_dir = os.path.join(run_dir, f"test_{test_name}")
    if os.path.exists(test_dir):
        shutil.rmtree(test_dir)
    shutil.copytree(build_dir, test_dir, symlinks=True)
    make_status = subprocess.run(["make", "sim",
                                  f"TEST_PATH={test_path}",
                                  f"TCLBATCH={RUN_CFG}"],
                                  stdout=subprocess.DEVNULL,
                                  cwd=test_dir)
    print(f"Test <{test_name}> DONE.", end=" ")
    check_make_status(make_status, f"run test <{test_name}>")
    # write to test.status
    status_file_path = os.path.join(test_dir, "test.status")
    with open(status_file_path, 'w') as status_file:
        status = check_test_status(os.path.join(test_dir, "test.log"), test_name)
        status_file.write(status)
        print(status)

def main():
    start_time = datetime.datetime.now()
    args = parse_args()

    # check arguments
    #if args.test and args.testlist:
    #    raise ValueError("Cannot use both -t|--test and --testlist. Choose one.")
    
    create_run_cfg(args.log_wave)
    all_tests = find_all_tests(read_from_json(args.testlist))
    
    print(f"\nRunning {len(all_tests)} tests:")
    for t in all_tests:
        print("   ",t)
    print()

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

        make_status = subprocess.run(["make", "elab"], cwd=build_dir)
        check_make_status(make_status, "build")
    
    # check if the specified number of jobs exceeds the number of CPU cores
    if args.jobs < 1:
        raise ValueError("Error: The number of parallel jobs must be at least 1.")
    if args.jobs > MAX_WORKERS:
        print(f"Warning: The specified number of jobs ({args.jobs}) exceeds the number of available CPU cores ({MAX_WORKERS}).")
    print(f"Running simulation with {min(args.jobs,MAX_WORKERS)} parallel jobs.")

    # run tests in parallel
    random.seed(5)
    #sv_seed = args.seed if args.seed is not None else random.randint(0, 2**32 - 1)
    with multiprocessing.Pool(min(args.jobs,MAX_WORKERS)) as pool:
        # create a partial function with all fixed arguments except test_name
        partial_run_test = functools.partial(run_test, run_dir=run_dir, build_dir=build_dir)
        pool.map(partial_run_test, all_tests)
    
    # check test suite results
    all_tests_passed = True
    tests_num = len(all_tests)
    tests_passed = 0
    print("\nSummary:")
    for test_path in all_tests:
        test_name = os.path.splitext(os.path.basename(test_path))[0]
        test_dir = os.path.join(run_dir, f"test_{test_name}")
        status_file_path = os.path.join(test_dir, "test.status")
        if os.path.exists(status_file_path):
            with open(status_file_path, 'r') as status_file:
                status = status_file.read()
                print(status)
                if "PASSED" not in status:
                    all_tests_passed = False
                else:
                    tests_passed += 1
        else:
            print(f"Status for <{test_name}> not found.")
            all_tests_passed = False
    
    print(f"\nTest suite DONE. Pass rate: {tests_passed}/{tests_num} passed")
    if all_tests_passed:
        print("\nTest suite PASSED.\n")
    else:
        print("\nTest suite FAILED.\n")
    
    end_time = datetime.datetime.now()
    elapsed_time = end_time - start_time
    hours, remainder = divmod(elapsed_time.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    
    print("Test suite runtime:")
    if hours:
        print(f"Runtime: {hours}h {minutes}m {seconds}s")
    else:
        print(f"Runtime: {minutes}m {seconds}s")
    print()

if __name__ == "__main__":
    MAX_WORKERS = int(os.cpu_count()/2) # most likely 1C/2T, fastest simulation as measured
    main()
