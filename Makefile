# RTL build
TOP := ama_riscv_tb
DESIGN_TOP := ama_riscv_top

# terminology:
# - ISA_SIM: ama-riscv-sim, C++
# - COSIM: wrapper around ISA_SIM, C++
# - DPI: interface between SV and C++; term is also used as a build switch for ama-riscv-sim

RTL_DEFINES ?=
RTL_DEFINES += -d ENABLE_COSIM
RTL_DEFINES += -d DBG_SIG
#RTL_DEFINES += -d SYNTHESIS
RTL_DEFINES_SLANG := $(subst -d,-D,$(RTL_DEFINES)) # upper case for slang
COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8
# work library name, should match the one in the first line of $(SOURCE_FILES)
WORKLIB := work

include Makefile.inc

TCLBATCH ?= run_cfg.tcl
TCLBATCH_SWITCH := -tclbatch $(REPO_ROOT)/$(TCLBATCH)

TEST_PATH ?=
TEST_WDB := $(shell path='$(TEST_PATH)'; echo "$$(basename "$$(dirname "$$path")")_$$(basename "$$path")")

# useful for standalone make runs
UNIQUE_WDB ?=
WDB_SWITCH :=
ifeq ($(strip $(UNIQUE_WDB)),1)
    WDB_SWITCH := -wdb $(CURDIR)/$(TEST_WDB)
endif

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
	xelab $(WORKLIB).$(TOP) $(ELAB_OPTS) -sv_lib $(COSIM_TARGET) $(RTL_DEFINES) -log /dev/null 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

dpi_header_gen: .compile.touchfile
	xelab $(WORKLIB).$(TOP) $(ELAB_OPTS) $(RTL_DEFINES) -dpiheader $(DPI_FUNCS_H) -log /dev/null 2>&1

#SIM_LOG := -log test.log
#SIM_LOG := -log /dev/null > test.log 2>&1
SIM_LOG := -log /dev/null 2>&1

# used to limit the number of delta cycles during simulation, default is 10000
# prevents large logs and long runtimes when debugging accidental comb. loops
MAX_DELTA = -maxdeltaid 100

# example usage: 'make sim -j TEST_PATH=sim/sw/baremetal/asm_rv32i/basic UNIQUE_WDB=1 TIMEOUT_CLOCKS=1000 LOG_LEVEL=$LL | tee make_run_asm_rv32i.log | tail -n 30 | tee >(rg "====")'
sim: .elab.touchfile
	xsim $(TOP) $(TCLBATCH_SWITCH) $(WDB_SWITCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) -testplusarg log_level=$(LOG_LEVEL) $(COSIM_CHECKER) $(SIM_LOG) $(MAX_DELTA)
	@rm xsim.jou
	@touch .sim.touchfile

# run target in terminal once; it will watch for any file save and re-run slang
# alternative to a setup with vscode extension(s)
slang_watch:
	@make slang SLANG_EXTRA=-q --no-print-directory
	@while inotifywait -e close_write $(SRC_VERIF) $(SRC_DESIGN) 2>/dev/null; do \
		make slang SLANG_EXTRA=-q --no-print-directory; \
	done

SLANG_OPTS := -Wno-unconnected-port -Wno-duplicate-definition
SLANG_OPTS += --std 1800-2017 --strict-driver-checking
slang:
	@slang -j 8 --top $(TOP) $(RTL_DEFINES_SLANG) $(SRC_VERIF) $(SRC_DESIGN) $(PLUS_INCDIR) $(SLANG_OPTS) $(SLANG_EXTRA)

# run preprocessor only, useful for debugging
SLANG_PP_OUT := slang_e.sv
slang_pp:
	@make slang --no-print-directory SLANG_EXTRA="-E --comments > $(SLANG_PP_OUT) 2>&1"

# slang has poor linting capabilities, use verilator instead
lint:
	@verilator --top $(DESIGN_TOP) -DSYNTHESIS --lint-only $(SRC_DESIGN) $(PLUS_INCDIR) -Wall -Wpedantic > lint.log 2>&1

# run standalone bench with provided sources and top name, oneshot

# standalone testbench sources file path
SAS ?=
# standalone testbench top name
SAT ?=

# standalone work library name, should match the one in the first line of $(SAS)
# not really meant to be changed even for multiple tops
# as each top will have its own dir under xsim.dir
SA_WORKLIB := standalone_tb

# example usage: 'make standalone SAS=sources_uart.f SAT=uart_tb'
standalone:
	@if [ -z "$(SAS)" ]; then \
		echo "Error: Please provide SAS variable (standalone testbench sources file path)"; \
		exit 1; \
	fi
	@if [ -z "$(SAT)" ]; then \
		echo "Error: Please provide SAT variable (standalone testbench top name)"; \
		exit 1; \
	fi
	xvlog $(COMP_OPTS) -prj $(SAS) -log /dev/null 2>&1
	@rm xvlog.pb
	xelab $(SA_WORKLIB).$(SAT) $(ELAB_OPTS) -log /dev/null 2>&1
	@rm xelab.pb
	xsim $(SA_WORKLIB).$(SAT) $(TCLBATCH_SWITCH) -log /dev/null 2>&1
	@rm xsim.jou

WORKDIR ?= workdir_test
workdir:
	@mkdir $(REPO_ROOT)/$(WORKDIR)
	@cd $(REPO_ROOT)/$(WORKDIR) && \
	ln -s $(REPO_ROOT)/Makefile && \
	ln -s $(REPO_ROOT)/Makefile.inc && \
	ln -s $(REPO_ROOT)/cosim
	@echo "Workdir created at: $(REPO_ROOT)/$(WORKDIR)"

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_* *.wdb *.vcd

cleanrtl: cleanlogs
	rm -rf .compile.touchfile .elab.touchfile .sim.touchfile xsim.dir $(SLANG_PP_OUT)

clean: cleanrtl

cleanall: cleanrtl cleancosim cleanisa

.PHONY: lint slang watch_slang workdir cleanrtl cleancosim cleanisa cleanall
