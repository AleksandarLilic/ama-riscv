#!/bin/bash

# check if $VIVADO_ROOT is set
if [ -z "$VIVADO_ROOT" ]; then
    echo "\$VIVADO_ROOT is not set. Please set it to the Vivado installation path."
    echo "Likely located at e.g. '<tool install path>/Vivado/2023.2/' "
    return
fi

# vivado (xvlog, xelab, xsim, ...)
source "$VIVADO_ROOT/.settings64-Vivado.sh"

# repo
REPO_ROOT="$(git rev-parse --show-toplevel)"
export REPO_ROOT

# utils
alias run='${REPO_ROOT}/run_test.py'

# generic run_cfg.tcl
tcl_cfg="run_cfg.tcl"
echo "# AUTOMATICALLY GENERATED FILE. DO NOT EDIT." > $tcl_cfg
echo "set start [expr {[clock seconds] - 1}]" >> $tcl_cfg
echo "log_wave -recursive *" >> $tcl_cfg
#echo "open_vcd test_wave.vcd" >> $tcl_cfg
#echo "log_vcd *" >> $tcl_cfg
echo "run all" >> $tcl_cfg
#echo "close_vcd" >> $tcl_cfg
echo "puts \"Simulation runtime: [expr {[clock seconds] - \$start}]s\"" >> $tcl_cfg
echo "exit" >> $tcl_cfg

# notes
echo "VIVADO_ROOT=$VIVADO_ROOT"
echo "REPO_ROOT=$REPO_ROOT"
