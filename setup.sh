#!/bin/bash

# check if $VIVADO_ROOT is set
if [ -z "$VIVADO_ROOT" ]; then
    echo "\$VIVADO_ROOT is not set. Please set it to the Vivado installation path."
    echo "Likely located at '<tool install path>/Vivado/<version>/' "
    return
fi

# repo
REPO_ROOT="$(git rev-parse --show-toplevel)"
export REPO_ROOT

# vivado
source "$VIVADO_ROOT/.settings64-Vivado.sh"

# generic run_cfg.tcl
echo "log_wave -recursive *" > run_cfg.tcl
echo "run all" >> run_cfg.tcl
echo "exit" >> run_cfg.tcl

# notes
echo "REPO_ROOT=$REPO_ROOT"
echo "VIVADO_ROOT=$VIVADO_ROOT"
