# RTL build
TOP := ama_riscv_core_top_tb

# terminology:
# - ISA_SIM: ama-riscv-sim, C++
# - COSIM: wrapper around ISA_SIM, C++
# - DPI: interface between SV and C++; term is also used as a build switch for ama-riscv-sim

# COSIM variables needed during TB build
COSIM_SO := ama-riscv-cosim.so
COSIM_ROOT := $(REPO_ROOT)/cosim
DPI_FUNCS_H := $(COSIM_ROOT)/dpi_functions.h

RTL_DEFINES ?=
RTL_DEFINES += -d ENABLE_COSIM
COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

include $(REPO_ROOT)/Makefile.inc

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS ?= 500000
LOG_LEVEL ?= WARN
COSIM_CHECKER := -testplusarg enable_cosim_checkers
COSIM_CHECKER += -testplusarg stop_on_cosim_error

all: sim

compile: .compile.touchfile
.compile.touchfile: $(SRC_VERIF) $(SRC_DESIGN) $(SRC_INC)
	xvlog $(COMP_OPTS) -prj $(SOURCE_FILES) $(RTL_DEFINES) -log /dev/null 2>&1
	@rm xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(COSIM_SO)
	xelab $(TOP) $(ELAB_OPTS) -sv_lib $(COSIM_SO) $(RTL_DEFINES) -log /dev/null 2>&1
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

# COSIM build
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

ISA_SIM_DIR := $(REPO_ROOT)/sim/src
ISA_SIM_BDIR ?= build_cosim
$(shell mkdir -p $(ISA_SIM_DIR)/$(ISA_SIM_BDIR))

ISA_SIM_SRCS := $(wildcard $(ISA_SIM_DIR)/*.cpp)
ISA_SIM_SRCS += $(wildcard $(ISA_SIM_DIR)/devices/*.cpp)
ISA_SIM_SRCS += $(wildcard $(ISA_SIM_DIR)/profilers/*.cpp)
ISA_SIM_SRCS := $(filter-out %main.cpp, $(ISA_SIM_SRCS))

ISA_SIM_OBJS := $(patsubst $(ISA_SIM_DIR)/%, $(ISA_SIM_DIR)/$(ISA_SIM_BDIR)/%, $(ISA_SIM_SRCS:.cpp=.o))

ISA_SIM_H := $(wildcard $(ISA_SIM_DIR)/*.h)
ISA_SIM_H += $(wildcard $(ISA_SIM_DIR)/devices/*.h)
ISA_SIM_H += $(wildcard $(ISA_SIM_DIR)/profilers/*.h)

ISA_SIM_INC := -I$(ISA_SIM_DIR) -I$(ISA_SIM_DIR)/devices -I$(ISA_SIM_DIR)/profilers -I$(ISA_SIM_DIR)/hw_models
ISA_SIM_INC += -isystem $(ISA_SIM_DIR)/external/ELFIO

COSIM_SRC := $(COSIM_ROOT)/cosim.cpp
COSIM_OBJ := $(COSIM_SRC:.cpp=.o)
COSIM_INC := -I$(VIVADO_ROOT)/data/xsim/include
DPI_LINK_LIB := -L$(VIVADO_ROOT)/tps/lnx64/gcc-9.3.0/lib64/

cosim: $(COSIM_SO)

$(COSIM_SO): .isa_sim_obj.touchfile $(COSIM_OBJ)
	$(CXX) $(CXXFLAGS) -o $(COSIM_SO) $(COSIM_OBJ) $(ISA_SIM_OBJS) $(DPI_LINK_LIB)

# recipe calls isa sim's make which builds all isa sim objects
# even though not all objects may be strictly required for cosim
isa_sim_obj: .isa_sim_obj.touchfile
.isa_sim_obj.touchfile: $(ISA_SIM_SRCS) $(ISA_SIM_H)
	$(MAKE) -C $(ISA_SIM_DIR) obj BDIR=$(ISA_SIM_BDIR) DEFINES="-DDPI -DCACHE_MODE=CACHE_MODE_FUNC"
	@touch .isa_sim_obj.touchfile

$(COSIM_OBJ): $(COSIM_SRC) $(DPI_FUNCS_H) $(ISA_SIM_H)
	$(CXX) $(CXXFLAGS) -c -o $@ $< $(COSIM_INC) $(ISA_SIM_INC)

# cleaning
cleanisasim:
	$(MAKE) -C $(ISA_SIM_DIR) cleanbuild BDIR=$(ISA_SIM_BDIR)
	rm -rf .isa_sim_obj.touchfile

cleancosim:
	rm -rf $(COSIM_ROOT)/*.*o *.so

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_* *.wdb *.vcd

cleanrtl: cleanlogs
	rm -rf .compile.touchfile .elab.touchfile .sim.touchfile xsim.dir

clean: cleanrtl

cleanall: cleanrtl cleanisasim cleancosim
