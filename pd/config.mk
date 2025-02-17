include $(REPO_ROOT)/Makefile.inc

export DESIGN_NAME            = ama_riscv_core
export PLATFORM               = asap7
#export DESIGN_NICKNAME        =
#export FLOW_VARIANT           =

export VERILOG_FILES          = $(SRC_DESIGN)
export SDC_FILE               = $(REPO_ROOT)/pd/constraint.sdc

export CORE_UTILIZATION       = 60
export CORE_ASPECT_RATIO      = 0.9
export CORE_MARGIN            = 2
export PLACE_DENSITY_LB_ADDON = 0.20
export ENABLE_DPO             = 0
export TNS_END_PERCENT        = 100

export SYNTH_HIERARCHICAL     = 1
export MAX_UNGROUP_SIZE       = 0
export ASAP7_USELVT 		  = 1

YOSYS_FLAGS += -m slang
