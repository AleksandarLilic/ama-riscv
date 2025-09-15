# RTL build
TOP := ama_riscv_core_top_tb

# terminology:
# - ISA_SIM: ama-riscv-sim, C++
# - COSIM: wrapper around ISA_SIM, C++
# - DPI: interface between SV and C++; term is also used as a build switch for ama-riscv-sim

RTL_DEFINES ?=
RTL_DEFINES += -d ENABLE_COSIM
COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

include Makefile.inc

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS ?= 500000
LOG_LEVEL ?= WARN
COSIM_CHECKER := -testplusarg enable_cosim_checkers
COSIM_CHECKER += -testplusarg stop_on_cosim_error

all: sim

include cosim/Makefile.cosim.inc

compile: .compile.touchfile
.compile.touchfile: $(SRC_VERIF) $(SRC_DESIGN) $(SRC_INC)
	xvlog $(COMP_OPTS) -prj $(SOURCE_FILES) $(RTL_DEFINES) -log /dev/null 2>&1
	@rm xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(COSIM_TARGET)
	xelab $(TOP) $(ELAB_OPTS) -sv_lib $(COSIM_TARGET) $(RTL_DEFINES) -log /dev/null 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

dpi_header_gen: .compile.touchfile
	xelab $(TOP) $(ELAB_OPTS) $(RTL_DEFINES) -dpiheader $(DPI_FUNCS_H) -log /dev/null 2>&1

#SIM_LOG := -log test.log
#SIM_LOG := -log /dev/null > test.log 2>&1
SIM_LOG := -log /dev/null 2>&1

# used to limit the number of delta cycles during simulation, default is 10000
# prevents large logs and long runtimes when debugging accidental comb. loops
MAX_DELTA = -maxdeltaid 100

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) -testplusarg log_level=$(LOG_LEVEL) $(COSIM_CHECKER) $(SIM_LOG) $(MAX_DELTA)
	@touch .sim.touchfile

watch_slang:
	@make slang
	@while inotifywait -e close_write $(SRC_VERIF) $(SRC_DESIGN) 2>/dev/null; do \
		make slang; \
		echo ""; \
	done

slang:
	@slang $(SRC_VERIF) $(SRC_DESIGN) $(PLUS_INCDIR) -Wno-unconnected-port -Wno-duplicate-definition

lint:
	@verilator --lint-only $(SRC_DESIGN) $(PLUS_INCDIR) -Wall -Wpedantic > lint.log 2>&1

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_* *.wdb *.vcd

cleanrtl: cleanlogs
	rm -rf .compile.touchfile .elab.touchfile .sim.touchfile xsim.dir

clean: cleanrtl

cleanall: cleanrtl cleancosim cleanisa
