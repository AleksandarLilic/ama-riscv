#!/bin/bash

# repo
REPO_ROOT="$(git rev-parse --show-toplevel)"
export REPO_ROOT

# generic run_cfg.tcl
echo "log_wave -recursive *" > run_cfg.tcl
echo "run all" >> run_cfg.tcl
echo "exit" >> run_cfg.tcl

# notes
echo "REPO_ROOT=$REPO_ROOT"
echo "Also source Vivado settings script: '.settings64-Vivado.sh'"
