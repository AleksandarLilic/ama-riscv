# generic non-project FPGA synth + impl + reports flow
# all run-specific settings come from a Python-emitted params.tcl, sourced below
# usage (driven by run_synt.py):
#   vivado -mode batch -source synt.tcl -tclargs <run_dir>/params.tcl

set start [expr {[clock seconds] - 1}]

source [lindex $argv 0]

# per-invocation thread cap (0 = let vivado auto-detect); balance against --jobs
if {$MAX_THREADS > 0} { set_param general.maxThreads $MAX_THREADS }

# ------------------------------------------------------------------------------
# in-memory project + sources
create_project -in_memory -part $PART
set_property target_language Verilog [current_project]
set_property verilog_define $DEFINES [current_fileset]
if {[llength $INCLUDE_DIRS] > 0} {
    set_property include_dirs $INCLUDE_DIRS [current_fileset]
}

if {[llength $HEADERS] > 0} {
    read_verilog $HEADERS
    foreach h $HEADERS {
        set_property file_type "Verilog Header" [get_files $h]
    }
}
read_verilog -library xil_defaultlib -sv $SOURCES
foreach xdc $XDCS { read_xdc $xdc }

# ------------------------------------------------------------------------------
# synthesis
set synth_cmd "synth_design -top $TOP -part $PART \
    -flatten_hierarchy $SYNTH_FLATTEN \
    -directive $SYNTH_DIRECTIVE $SYNTH_OPTIONS"
puts "INFO: $synth_cmd"
eval $synth_cmd

report_utilization -file $RUN_DIR/util_flat_synth.rpt
report_utilization -hierarchical -hierarchical_percentages \
    -file $RUN_DIR/util_hier_synth.rpt
write_checkpoint -force $RUN_DIR/post_synth.dcp

# ------------------------------------------------------------------------------
# implementation
# directive steps run only if directive is not empty
# power steps (enable-only, no -directive) run only if enabled
if {$IMPL_OPT_DIRECTIVE ne ""} { opt_design -directive $IMPL_OPT_DIRECTIVE }
if {$IMPL_POWER_OPT_ENABLE} { power_opt_design }
if {$IMPL_PLACE_DIRECTIVE ne ""} { place_design -directive $IMPL_PLACE_DIRECTIVE }
if {$IMPL_POST_PLACE_POWER_OPT_ENABLE} { power_opt_design }
foreach d $IMPL_PHYS_OPT_DIRECTIVES { phys_opt_design -directive $d }
if {$IMPL_ROUTE_DIRECTIVE ne ""} { route_design -directive $IMPL_ROUTE_DIRECTIVE }
foreach d $IMPL_POST_ROUTE_PHYS_OPT_DIRECTIVES { phys_opt_design -directive $d }

# ------------------------------------------------------------------------------
# routed reports
report_utilization -file $RUN_DIR/util_routed.rpt
report_utilization -hierarchical -hierarchical_percentages \
    -file $RUN_DIR/util_routed.hier.rpt

set timing_cfg {-max_paths 10 -report_unconstrained -warn_on_violation}
report_timing_summary -delay_type min {*}$timing_cfg \
    -file $RUN_DIR/timing_summary_routed.min.rpt
report_timing_summary -delay_type max {*}$timing_cfg \
    -file $RUN_DIR/timing_summary_routed.max.rpt
report_power -file $RUN_DIR/power_routed.rpt
write_checkpoint -force $RUN_DIR/routed.dcp

set DESIGN_NAME "ama_riscv_fpga"

if {$BITSTREAM || $MMI} { file mkdir $RUN_DIR/bitstream }

if {$BITSTREAM} {
    write_bitstream -force $RUN_DIR/bitstream/${DESIGN_NAME}.bit
}

if {$MMI} {
    write_mem_info -force $RUN_DIR/bitstream/${DESIGN_NAME}.mmi
}

puts "Synthesis runtime: [expr {[clock seconds] - $start}]s"
