# RTL build
TOP := ama_riscv_core_top_tb

# DPI variables needed during TB build
COSIM_DPI_SO := ama-riscv-sim_dpi.so
DPI_ROOT := $(REPO_ROOT)/dpi
DPI_FUNCS_H := $(DPI_ROOT)/dpi_functions.h

RTL_DEFINES :=
RTL_DEFINES += -d ENABLE_COSIM
COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

include $(REPO_ROOT)/Makefile.inc

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS :=
COSIM_CHECKER := -testplusarg enable_cosim_checkers
COSIM_CHECKER += -testplusarg stop_on_cosim_error

all: sim

compile: .compile.touchfile
.compile.touchfile: $(SRC_VERIF) $(SRC_DESIGN) $(SRC_INC)
	xvlog $(COMP_OPTS) -prj $(SOURCE_FILES) $(RTL_DEFINES) -log /dev/null > xvlog.log 2>&1
	@rm xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(COSIM_DPI_SO)
	xelab $(TOP) $(ELAB_OPTS) -sv_lib $(COSIM_DPI_SO) $(RTL_DEFINES) -log /dev/null > xelab.log 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

dpi_header_gen: .compile.touchfile
	xelab $(TOP) $(ELAB_OPTS) $(RTL_DEFINES) -dpiheader $(DPI_FUNCS_H) -log /dev/null > xelab_dpi_header_gen.log 2>&1

#SIM_LOG := -log test.log
SIM_LOG := -log /dev/null > test.log 2>&1

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) $(COSIM_CHECKER) $(SIM_LOG)
	@touch .sim.touchfile
	@printf "Test status: "
	@if   grep -q "PASS" test.log; then \
		msg=`grep "PASS" test.log`; \
		printf "$(GREEN)%s$(NC)\n" "$$msg"; \
	elif grep -qE "FAIL|Error:" test.log; then \
		msg=`grep -E "FAIL|Error:" test.log`; \
		printf "$(RED)%s$(NC)\n" "$$msg"; \
	else \
		printf "$(YELLOW)Can't determine test status$(NC)\n"; \
	fi

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

# DPI build
CXX := g++
CXXFLAGS := -Wall -Wextra
CXXFLAGS += -Wcast-qual -Wold-style-cast
CXXFLAGS += -Wunreachable-code -Wnull-dereference
CXXFLAGS += -Wnon-virtual-dtor -Woverloaded-virtual
CXXFLAGS += -Werror -pedantic -std=gnu++17
CXXFLAGS += -Wno-error=null-dereference # may be required for ELFIO only
CXXFLAGS += -Ofast -s -flto=auto -march=native -mtune=native
CXXFLAGS += -m64 -fPIC -shared
CXXFLAGS += -Wno-unused-parameter
#CXXFLAGS += -pg

COSIM_DIR := $(REPO_ROOT)/sim/src
COSIM_BDIR := build_dpi
$(shell mkdir -p $(COSIM_DIR)/$(COSIM_BDIR))

COSIM_SRCS := $(wildcard $(COSIM_DIR)/*.cpp)
COSIM_SRCS += $(wildcard $(COSIM_DIR)/devices/*.cpp)
COSIM_SRCS += $(wildcard $(COSIM_DIR)/profilers/*.cpp)
COSIM_SRCS := $(filter-out %main.cpp, $(COSIM_SRCS))
COSIM_OBJS := $(patsubst $(COSIM_DIR)/%, $(COSIM_DIR)/$(COSIM_BDIR)/%, $(COSIM_SRCS:.cpp=.o))
COSIM_H := $(wildcard $(COSIM_DIR)/*.h)
COSIM_H += $(wildcard $(COSIM_DIR)/devices/*.h)
COSIM_H += $(wildcard $(COSIM_DIR)/profilers/*.h)
COSIM_INC := -I$(COSIM_DIR) -I$(COSIM_DIR)/devices -I$(COSIM_DIR)/profilers
COSIM_INC += -isystem $(COSIM_DIR)/external/ELFIO

DPI_SRC := $(DPI_ROOT)/core_dpi.cpp
DPI_OBJ := $(DPI_SRC:.cpp=.o)
DPI_INC := -I$(VIVADO_ROOT)/data/xsim/include
DPI_LINK_LIB := -L$(VIVADO_ROOT)/tps/lnx64/gcc-9.3.0/lib64/

dpi: $(COSIM_DPI_SO)

$(COSIM_DPI_SO): .cosim_obj.touchfile $(DPI_OBJ)
	$(CXX) $(CXXFLAGS) -o $(COSIM_DPI_SO) $(DPI_OBJ) $(COSIM_OBJS) $(DPI_LINK_LIB)

cosim_obj: .cosim_obj.touchfile
.cosim_obj.touchfile: $(COSIM_SRCS) $(COSIM_H)
	$(MAKE) -C $(COSIM_DIR) obj BDIR=$(COSIM_BDIR) DEFINES="-DDPI -DCACHE_MODE=CACHE_MODE_FUNC"
	@touch .cosim_obj.touchfile

$(DPI_OBJ): $(DPI_SRC) $(DPI_FUNCS_H) $(COSIM_H)
	$(CXX) $(CXXFLAGS) -c -o $@ $< $(DPI_INC) $(COSIM_INC)

cleancosim:
	$(MAKE) -C $(COSIM_DIR) cleanbuild BDIR=$(COSIM_BDIR)
	rm -rf .cosim_obj.touchfile

cleandpi:
	rm -rf $(DPI_ROOT)/*.*o *.so

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_*

clean: cleanlogs
	rm -rf .*touchfile xsim.dir *.wdb

cleanall: clean cleancosim cleandpi
