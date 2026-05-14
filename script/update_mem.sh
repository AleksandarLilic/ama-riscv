#!/bin/bash

# NOTES
# 0. assumed that the design is already synthesized and bitstream generated
# 1. `write_mem_info design.mmi -force` in the <project_dir> (vivado tcl shell)
# 2. `export SW_DIR=<path_to_sim/sw/baremetal>` (shell)
# 3. run from synt dir, e.g. <project_dir>/synt_proj.runs/impl_1 (shell)

# check if SW_DIR is set
if [ -z "$SW_DIR" ]; then
    echo "Error: SW_DIR is not set"
    exit 1
fi

# check if SW_DIR exists
if [ ! -d "$SW_DIR" ]; then
    echo "Error: SW_DIR does not exist"
    exit 1
fi

if [[ "$1" =~ ^[0-9]+$ ]]; then # if first argument is a number, use as MAX_JOBS
    MAX_JOBS="$1"
else
    MAX_JOBS=8
fi

echo "Running with up to $MAX_JOBS concurrent jobs"

now=$(date +%Y-%m-%d_%H-%M-%S)
tag="testrun"
run_name="updatemem_${now}_${tag}"

MMI=../../design.mmi
PROC=ama_riscv_top_i/ama_riscv_mem_i/u_mem/xpm_memory_base_inst
BIT_NAME=ama_riscv_fpga

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

run_emb() {
    local test_name="$1"
    local wl_emb=embench
    local mem_file="$SW_DIR/$wl_emb/$test_name/$wl_emb.mem"
    echo "Running $wl_emb/$test_name"

    check_inputs "$mem_file"
    updatemem -meminfo $MMI \
    -data "$mem_file" \
    -bit $BIT_NAME.bit \
    -proc $PROC \
    -out $BIT_NAME."$wl_emb"."$test_name".bit \
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

run_job run_emb aha-mont64
run_job run_emb crc32
run_job run_emb cubic
run_job run_emb edn
run_job run_emb huffbench
run_job run_emb matmult-int
run_job run_emb md5sum
run_job run_emb minver
run_job run_emb nbody
run_job run_emb nettle-aes
run_job run_emb nettle-sha256
run_job run_emb nsichneu
run_job run_emb picojpeg
run_job run_emb primecount
run_job run_emb qrduino
run_job run_emb sglib-combined
run_job run_emb slre
run_job run_emb st
run_job run_emb statemate
run_job run_emb tarfind
run_job run_emb ud
run_job run_emb wikisort

wait # for all remaining jobs

if [ -f "$fail_file" ]; then
    rm "$fail_file"
    echo "Error: one or more updatemem jobs failed"
    exit 1
fi
