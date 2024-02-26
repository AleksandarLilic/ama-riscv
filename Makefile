TOP := ama_riscv_core_top_tb
SOURCE_FILES_SV := $(REPO_ROOT)/sources_sv.f
SOURCE_FILES_V := $(REPO_ROOT)/sources_v.f
VERILOG_DEFINES := 
COMP_OPTS_V := --incr --relax
COMP_OPTS_SV := -sv $(COMP_OPTS_V)
ELAB_DEBUG := typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

TCLBATCH := run_cfg.tcl
TEST_PATH :=

all: sim

compile: .compile.touchfile
.compile.touchfile:
	@echo "Compiling SystemVerilog"
	xvlog $(COMP_OPTS_SV) -prj $(SOURCE_FILES_SV) $(VERILOG_DEFINES) > xvlog_sv.log 2>&1
	@echo "Compiling Verilog"
	xvlog $(COMP_OPTS_V) -prj $(SOURCE_FILES_V) $(VERILOG_DEFINES) > xvlog_v.log 2>&1
	@touch .compile.touchfile
	@echo "RTL compilation done"

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile
	@echo "Elaborating design"
	xelab $(TOP) $(ELAB_OPTS) $(VERILOG_DEFINES) > /dev/null 2>&1
	@touch .elab.touchfile
	@echo "Elaboration done"

sim: .elab.touchfile
	@echo "Running simulation"
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(TEST_PATH) -log test.log > /dev/null 2>&1
	@touch .sim.touchfile
	@echo "Simulation done"

clean:
	rm -rf .*touchfile
	rm -rf xsim.dir
	rm -rf *.log
	rm -rf *.jou
	rm -rf *.pb