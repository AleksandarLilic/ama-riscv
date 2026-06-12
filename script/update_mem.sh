#!/bin/bash

# NOTES
# assumed that 'fpga/run_synt.py' already finished, with .bit and .mmi generated
# `cd <synt_dir>/bistream/` and run this script

SW_DIR=$REPO_ROOT/sim/sw/baremetal/
if [ -z "$REPO_ROOT" ]; then
    echo "Error: REPO_ROOT is not set, 'source setup.sh' first"
    exit 1
fi

if [ ! -d "$SW_DIR" ]; then
    echo "Error: SW_DIR set to '$SW_DIR' but doesn't exist"
    exit 1
fi

if [[ "$1" =~ ^[0-9]+$ ]]; then # if first argument is a number, use as MAX_JOBS
    MAX_JOBS="$1"
else
    MAX_JOBS=8
fi

echo "Running with up to $MAX_JOBS concurrent jobs"

time_start=$(date +%s)
now=$(date +%Y-%m-%d_%H-%M-%S)
tag="testrun"
run_name="updatemem_${now}_${tag}"

PROC=ama_riscv_top_i/ama_riscv_mem_i/u_mem/xpm_memory_base_inst
BIT_NAME=ama_riscv_fpga
MMI=$BIT_NAME.mmi

fail_file="update_mem_tmp_$$" # append pid to avoid conflicts

check_fail() {
    local msg="$1"
    echo "Error: $msg"
    touch "$fail_file"
    exit 1
}

check_inputs() {
    local mem_file="$1"
    [ -f "$mem_file" ]     || check_fail "$mem_file not found"
    [ -f "$BIT_NAME.bit" ] || check_fail "$BIT_NAME.bit not found"
    [ -f "$MMI" ]          || check_fail "$MMI not found"
}

updatemem_check() {
    if [ $? -ne 0 ]; then
        check_fail "updatemem failed"
    fi
}

# general test structure
run_g() {
    local wl="$1"
    local test_name="$2"
    local mem_file="$SW_DIR/$wl/$test_name.mem"
    echo "Running $wl/$test_name"

    check_inputs "$mem_file"
    updatemem -meminfo $MMI \
    -data "$mem_file" \
    -bit $BIT_NAME.bit \
    -proc $PROC \
    -out $BIT_NAME."$wl"."$test_name".bit \
    -force >> "${run_name}.log"
    updatemem_check
}

# different flavours under the same test group
run_f() {
    local wl="$1"
    local test_name="$2"
    local mem_file="$SW_DIR/$wl/$test_name/$wl.mem"
    echo "Running $wl/$test_name"

    check_inputs "$mem_file"
    updatemem -meminfo $MMI \
    -data "$mem_file" \
    -bit $BIT_NAME.bit \
    -proc $PROC \
    -out $BIT_NAME."$wl"."$test_name".bit \
    -force >> "${run_name}.log"
    updatemem_check
}

jobs_running=0
run_job() {
    # $1 = type: "g" or "emb", rest = args
    [ -f "$fail_file" ] && return
    if (( jobs_running >= MAX_JOBS )); then
        wait -n # wait for any one job to finish
        (( jobs_running-- ))
        [ -f "$fail_file" ] && return
    fi
    "$@" &
    (( jobs_running++ ))
}

echo "" > "${run_name}.log"

run_job run_g dhrystone dhrystone
run_job run_g coremark coremark
run_job run_g stream_int stream

run_job run_g mlp w8a8
run_job run_g mlp w4a8
run_job run_g mlp w2a8

run_job run_f embench aha-mont64
run_job run_f embench crc32
run_job run_f embench cubic
run_job run_f embench edn
run_job run_f embench huffbench
run_job run_f embench matmult-int
run_job run_f embench md5sum
run_job run_f embench minver
run_job run_f embench nbody
run_job run_f embench nettle-aes
run_job run_f embench nettle-sha256
run_job run_f embench nsichneu
run_job run_f embench picojpeg
run_job run_f embench primecount
run_job run_f embench qrduino
run_job run_f embench sglib-combined
run_job run_f embench slre
run_job run_f embench st
run_job run_f embench statemate
run_job run_f embench tarfind
run_job run_f embench ud
run_job run_f embench wikisort

run_job run_f ustress branch_direct
run_job run_f ustress branch_indirect
run_job run_f ustress call_return
run_job run_f ustress div32
run_job run_f ustress div64
run_job run_f ustress l1d_cache
run_job run_f ustress l1i_cache
run_job run_f ustress load_after_store
run_job run_f ustress mac32
run_job run_f ustress mac64
run_job run_f ustress memcpy
run_job run_f ustress mul32
run_job run_f ustress mul64

wait # for all remaining jobs

if [ -f "$fail_file" ]; then
    rm "$fail_file"
    echo "Error: one or more updatemem jobs failed"
    exit 1
fi

time_end=$(date +%s)
time_diff=$((time_end - time_start))
echo "Runtime: $time_diff seconds"
