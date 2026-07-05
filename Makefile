SHELL := /bin/bash

NPROCS_DEF := 8
NPROCS := $(shell nproc 2>/dev/null || echo $(NPROCS_DEF))
# only add -j if MAKEFLAGS doesn't already contain a job limit
ifeq ($(filter -j% --jobserver%, $(MAKEFLAGS)),)
    MAKEFLAGS += -j$(NPROCS)
endif

# RTL build
TOP := ama_riscv_tb
DESIGN_TOP := ama_riscv_top

# terminology:
# - ISA_SIM: ama-riscv-sim, C++
# - COSIM: wrapper around ISA_SIM, C++
# - DPI: interface between SV and C++; term is also used as a build switch for ama-riscv-sim

COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

# code coverage: opt-in instrumentation at elab
# once -cc_type is on, xsim auto-creates
# and populates xsim.codeCov/$(WLIB_TOP) with no sim-side flags
# s=statement, b=branch, c=condition, t=toggle (no fsm flag in xsim in v2023)
COV ?= 0
COV_TYPES ?= sbct
ifeq ($(strip $(COV)),1)
    ELAB_OPTS += -cc_type $(COV_TYPES)
endif

include Makefile.sources.mk

RUN_CFG ?= $(REPO_ROOT)/run_cfg.tcl
TCLBATCH_SWITCH := -tclbatch $(RUN_CFG)

GENERIC_RUN :=
TEST_PATH ?=
# if TEST_PATH is not set, use a default unique name with timestamp
ifeq ($(strip $(TEST_PATH)),)
    TEST_WDB := make_run_$(shell date +%Y-%m-%d_%H-%M-%S)
    GENERIC_RUN := 1
else
    TEST_WDB := $(shell path='$(TEST_PATH)'; echo "$$(basename "$$(dirname "$$path")")_$$(basename "$$path")")
endif

# useful for standalone make runs, but not for test suite
UNIQUE_WDB ?= 1
WDB_SWITCH :=
ifeq ($(strip $(UNIQUE_WDB)),1)
    WDB_SWITCH := -wdb $(CURDIR)/$(TEST_WDB)
endif

#LOG_ARG :=
#LOG_ARG := -log test.log
#LOG_ARG := -log /dev/null > test.log 2>&1
LOG_ARG := -log /dev/null

LOG_NAME ?= $(TEST_WDB).log
TO_LOG ?= 1
ifeq ($(strip $(TO_LOG)),1)
    ifneq ($(strip $(GENERIC_RUN)),1)
        $(shell echo "" > $(LOG_NAME)) # flush old log if it exists
    endif
    LOG_ARG := $(LOG_ARG) >> $(LOG_NAME) 2>&1
else
    LOG_ARG := $(LOG_ARG) 2>&1
endif

# silence make output if logging to file
ifeq ($(strip $(TO_LOG)), 1)
Q = @
else
Q =
endif

TEST_PATH_ABS := $(abspath $(TEST_PATH))

TIMEOUT_CLOCKS ?= 500000
LOG_LEVEL ?= WARN

# TODO: run_test should set these up for testlist runs
COSIM_ARGS :=

# checkers
COSIM_ARGS += -testplusarg enable_tohost_checker
COSIM_ARGS += -testplusarg enable_cosim_checkers
COSIM_ARGS += -testplusarg stop_on_cosim_error

# profiling
COSIM_ARGS += -testplusarg prof_trace
COSIM_ARGS += -testplusarg prof_pc_start=80000000
#COSIM_ARGS += -testplusarg prof_pc_start=80001238
#COSIM_ARGS += -testplusarg prof_pc_stop=80001300
#COSIM_ARGS += -testplusarg prof_pc_single_match=2
# all events available under 'script/autogen_perf_events_config.yaml'
#COSIM_ARGS += -testplusarg perf_events=ret_inst,cycle,l1d_ref,l1d_miss,bp_miss

# konata, separate isa sim's "exec.log"
#COSIM_ARGS += -testplusarg enable_konata
#COSIM_ARGS += -testplusarg log_isa_sim

# others
#COSIM_ARGS += -testplusarg uart_in=A # FIXME: drop UART_SHORTCUT define first

USER_COSIM_ARGS ?=
COSIM_ARGS += $(USER_COSIM_ARGS)

TB_ARGS :=
TB_ARGS += -testplusarg test_path=$(TEST_PATH)
TB_ARGS += -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS)
TB_ARGS += -testplusarg log_level=$(LOG_LEVEL)

all: sim

# if SIM_ONLY, ignore getting sources so it doesn't trigger rebuilds
ifeq ($(strip $(SIM_ONLY)), 0)
include cosim/Makefile.cosim.mk
endif

# used to limit the number of delta cycles during simulation, default is 10000
# prevents large logs and long runtimes when debugging accidental comb. loops
MAX_DELTA = -maxdeltaid 100

WLIB_TOP := $(WORKLIB).$(TOP)

CMD_COMP := xvlog $(COMP_OPTS) -prj $(SOURCE_FILES) $(LOG_ARG)
CMD_ELAB := xelab $(WLIB_TOP) $(ELAB_OPTS) -sv_lib $(COSIM_TARGET) $(LOG_ARG)
CMD_SIM := xsim $(WLIB_TOP) $(TCLBATCH_SWITCH) $(WDB_SWITCH) -stats \
    -onerror quit $(TB_ARGS) $(COSIM_ARGS) $(MAX_DELTA) $(LOG_ARG)

compile: .compile.touchfile
.compile.touchfile: $(SRC_VERIF) $(SRC_DESIGN) $(SRC_INC)
	@if [ "$(TO_LOG)" -eq 1 ]; then \
		echo $(CMD_COMP) >> $(LOG_NAME); \
	fi
	$(Q)$(CMD_COMP)
	@rm xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(COSIM_TARGET)
	@if [ "$(TO_LOG)" -eq 1 ]; then \
		echo $(CMD_ELAB) >> $(LOG_NAME); \
	fi
	$(Q)$(CMD_ELAB)
	@rm xelab.pb
	@touch .elab.touchfile

dpi_header_gen: .compile.touchfile
	xelab $(WLIB_TOP) $(ELAB_OPTS) -dpiheader $(DPI_FUNCS_H) -log /dev/null 2>&1

autogen_perf_events:
	@$(REPO_ROOT)/script/autogen_perf_events.py

# example usage:
# 'make sim TEST_PATH=sim/sw/baremetal/asm_rv32i/basic TIMEOUT_CLOCKS=1000'
sim: .elab.touchfile
	@rm -f test.status
	@if [ "$(TO_LOG)" -eq 1 ]; then \
		echo $(CMD_SIM) >> $(LOG_NAME); \
	fi
	$(Q)$(CMD_SIM)
	@if [ ! -f test.status ]; then \
		echo "Error: test.status not found"; \
		exit 3; \
	fi
	@status=$$(sed -n 's/^status=//p' test.status | tail -n 1); \
	case "$$status" in \
		PASSED) echo "Test PASSED";; \
		FAILED) echo "Error: RTL test failed. See test.status"; exit 2 ;; \
		*) echo "Error: Invalid RTL test status '$$status'"; exit 3 ;; \
	esac
	@rm xsim.jou
	@touch .sim.touchfile
	@if [ "$(TO_LOG)" -eq 1 ]; then \
		tail -n 50 $(LOG_NAME) | grep "^Simulation cycles:" | tee >(grep --color=always "===="); \
		tail -n 5 $(LOG_NAME) | grep "^Simulation runtime:" | tee >(grep --color=always "===="); \
		echo "Log available under '$(LOG_NAME)'"; \
	fi
#	@if [ "$(TO_LOG)" -eq 1 ]; then \
#		tail -n 50 $(LOG_NAME) | grep -A40 "^Test" | tee >(grep --color=always "===="); \
#	fi

#-------------------------------------------------------------------------------
# non-simulation tools

# run target in terminal once; it will watch for any file save and re-run slang
# alternative to a setup with vscode extension(s)
slang_watch:
	@make slang SLANG_EXTRA=-q --no-print-directory
	@while inotifywait -e close_write $(SRC_VERIF) $(SRC_DESIGN) 2>/dev/null; do \
		make slang SLANG_EXTRA=-q --no-print-directory; \
	done

COMMON_RTL := $(RTL_DEFINES_CS) $(PLUS_INCDIR)
COMMON_RTL_SRC := $(COMMON_RTL) $(SRC_DESIGN)

SLANG_OPTS := -Wno-unconnected-port -Wno-duplicate-definition
SLANG_OPTS += --std 1800-2017 --strict-driver-checking
SLANG_OPTS += --error-limit=1000
SLANG_OPTS += $(SLANG_EXTRA)
slang:
	@slang -j 8 --top $(TOP) $(COMMON_RTL_SRC) $(SRC_VERIF) $(SLANG_OPTS)

# run preprocessor only, useful for debugging
SLANG_PP_OUT := slang_e.sv
slang_pp:
	@make slang --no-print-directory SLANG_EXTRA="-E --comments > \
		$(SLANG_PP_OUT) 2>&1"

HIER_TOP ?= $(DESIGN_TOP)
HIER_ARGS ?=
hier:
	@slang -q --top $(HIER_TOP) -DSYNT $(COMMON_RTL_SRC) $(SLANG_OPTS) \
		--ast-json - | $(REPO_ROOT)/script/slang_hier.py $(HIER_ARGS)

# slang has poor linting capabilities, use verilator instead
LINT_OPTS := -sv -Wall -Wpedantic
lint:
	@verilator --lint-only $(LINT_OPTS) --top $(DESIGN_TOP) -DSYNT \
		$(COMMON_RTL_SRC) > lint.log 2>&1

FILE ?=
lint_file:
	@verilator --lint-only $(LINT_OPTS) -Wno-fatal -DSYNT $(COMMON_RTL) $(FILE)

print_defs:
	@echo "$(RTL_DEFINES_LIST)"

print_defs_vivado:
	@echo "set_property verilog_define { $(RTL_DEFINES_LIST)} [current_fileset]"

#-------------------------------------------------------------------------------
# unit testing
# run unit_test bench with provided sources and top name, oneshot

# unit_test testbench sources file path
UT_F ?=
# unit_test testbench top name
UT_TOP ?=

# unit_test work library name, should match the one in the first line of $(UT_F)
# not really meant to be changed even for multiple tops
# as each top will have its own dir under xsim.dir
UT_WORKLIB := unit_test

# example usage: 'make unit_test UT_F=../filelist/sources_uart.f UT_TOP=uart_tb'
unit_test:
	@if [ -z "$(UT_F)" ]; then \
		echo "Error: Please provide UT_F variable (unit_test testbench sources file path)"; \
		exit 1; \
	fi
	@if [ -z "$(UT_TOP)" ]; then \
		echo "Error: Please provide UT_TOP variable (unit_test testbench top name)"; \
		exit 1; \
	fi
	xvlog $(COMP_OPTS) -prj $(UT_F) -log /dev/null 2>&1
	@rm xvlog.pb
	xelab $(UT_WORKLIB).$(UT_TOP) $(ELAB_OPTS) -log /dev/null 2>&1
	@rm xelab.pb
	xsim $(UT_WORKLIB).$(UT_TOP) $(TCLBATCH_SWITCH) -log /dev/null 2>&1
	@rm xsim.jou

WORKDIR ?= workdir_test
workdir:
	@mkdir $(REPO_ROOT)/$(WORKDIR)
	@cd $(REPO_ROOT)/$(WORKDIR) && \
	ln -s $(REPO_ROOT)/Makefile && \
	ln -s $(REPO_ROOT)/Makefile.sources.mk && \
	ln -s $(REPO_ROOT)/cosim
	@echo "Workdir created at: $(REPO_ROOT)/$(WORKDIR)"

#-------------------------------------------------------------------------------
# code coverage report generation

# CODE_COV_DB_ALL is overridden by run_test.py
CODE_COV_DB_ALL := -cc_dir .
CC_REPORT ?= xcrg_code_cov_report

# merge the specified per-test code coverage DBs and emit a single HTML report
# a single -cc_db applies across all -cc_dir entries (they share a DB name)
# merged DB lands at xsim.codeCov/xcrg_merged, report at $(CC_REPORT)
coverage:
	@xcrg -merge_cc -cc_db $(WLIB_TOP) $(CODE_COV_DB_ALL) \
		-cc_report $(CC_REPORT) -report_format html -log xcrg_cc.log \
		> /dev/null 2>&1

#-------------------------------------------------------------------------------
# cleanup

cleancov:
	@rm -rf xcrg_cc.log $(CC_REPORT) xsim.codeCov/xcrg_merged \
		coverage_dashboard.html

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_* *.wdb *.vcd

cleanrtl: cleanlogs cleancov
	rm -rf .compile.touchfile .elab.touchfile .sim.touchfile .cov.touchfile xsim.dir xsim.codeCov $(SLANG_PP_OUT)

clean: cleanrtl

cleanall: cleanrtl cleancosim cleanisa

.PHONY: lint slang slang_pp hier watch_slang workdir autogen_perf_events coverage cleancov cleanrtl cleancosim cleanisa cleanall
