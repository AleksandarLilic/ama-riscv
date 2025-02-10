# RTL build
TOP := ama_riscv_core_top_tb
DPI_SO := ama-riscv-sim_dpi.so
SOURCE_FILES_SV := $(REPO_ROOT)/sources_sv.f
SOURCE_FILES_V := $(REPO_ROOT)/sources_v.f
VERILOG_DEFINES := -d CORE_ONLY -d ENABLE_COSIM
COMP_OPTS_V := --incr --relax
COMP_OPTS_SV := -sv $(COMP_OPTS_V)
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8

define get_sources
$(foreach file,$(shell cat $(1) | grep -v -- '--include' | grep -oP '"\K[^"]+' | sed 's/\\//g'),$(shell echo $(file)))
endef
define get_include_dirs
$(foreach file,$(shell cat $(1) | grep -- '--include' | grep -oP '"\K[^"]+' | sed 's/\\//g'),$(shell echo $(file)))
endef

DEPS_SV := $(call get_sources,$(SOURCE_FILES_SV))
INC_DIRS_SV := $(call get_include_dirs,$(SOURCE_FILES_SV))
DEPS_INC_SV := $(foreach dir,$(INC_DIRS_SV),$(shell echo $(dir))/*)

DEPS_V := $(call get_sources,$(SOURCE_FILES_V))
INC_DIRS_V := $(call get_include_dirs,$(SOURCE_FILES_V))
DEPS_INC_V := $(foreach dir,$(INC_DIRS_V),$(shell echo $(dir))/*)

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS :=
COSIM_CHECKER := -testplusarg enable_cosim_checkers
COSIM_CHECKER += -testplusarg stop_on_cosim_error

all: sim

compile: .compile.touchfile
.compile.touchfile: .compile_sv.touchfile .compile_v.touchfile
	@rm xvlog.pb
	@touch .compile.touchfile

.compile_sv.touchfile: $(DEPS_SV) $(DEPS_INC_SV)
	xvlog $(COMP_OPTS_SV) -prj $(SOURCE_FILES_SV) $(VERILOG_DEFINES) -log /dev/null > xvlog_sv.log 2>&1
	@touch .compile_sv.touchfile

.compile_v.touchfile: $(DEPS_V) $(DEPS_INC_V)
	xvlog $(COMP_OPTS_V) -prj $(SOURCE_FILES_V) $(VERILOG_DEFINES) -log /dev/null > xvlog_v.log 2>&1
	@touch .compile_v.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(DPI_SO)
	xelab $(TOP) $(ELAB_OPTS) -sv_lib $(DPI_SO) $(VERILOG_DEFINES) -log /dev/null > xelab.log 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

#SIM_LOG := -log test.log
SIM_LOG := -log /dev/null > test.log 2>&1

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) $(COSIM_CHECKER) $(SIM_LOG)
	@touch .sim.touchfile
	@grep "PASS\|FAIL\|Error:" test.log

# DPI build
CXX := g++
CXXFLAGS := -Wall -Wextra -Werror -pedantic -std=gnu++17
CXXFLAGS += -Ofast -s -flto=auto -march=native -mtune=native
CXXFLAGS += -m64 -fPIC -shared
CXXFLAGS += -Wno-unused-parameter
#CXXFLAGS += -pg

COSIM_DIR := sim/src
COSIM_BDIR := build_dpi

COSIM_SRCS := $(wildcard $(COSIM_DIR)/*.cpp)
COSIM_SRCS += $(wildcard $(COSIM_DIR)/devices/*.cpp)
COSIM_SRCS += $(wildcard $(COSIM_DIR)/profilers/*.cpp)
COSIM_SRCS := $(filter-out $(COSIM_DIR)/main.cpp, $(COSIM_SRCS))
COSIM_OBJS := $(patsubst $(COSIM_DIR)/%, $(COSIM_DIR)/$(COSIM_BDIR)/%, $(COSIM_SRCS:.cpp=.o))
COSIM_INC := -I$(COSIM_DIR) -I$(COSIM_DIR)/devices -I$(COSIM_DIR)/profilers
COSIM_INC += -isystem $(COSIM_DIR)/external/ELFIO
COSIM_DEFINES := -DDPI -DPROFILERS_EN -DDASM_EN

DPI_ROOT := $(REPO_ROOT)/dpi
DPI_SRC := $(DPI_ROOT)/core_dpi.cpp
DPI_OBJ := $(DPI_SRC:.cpp=.o)
DPI_INC := -I$(VIVADO_ROOT)/data/xsim/include
DPI_LINK_LIB := -L$(VIVADO_ROOT)/tps/lnx64/gcc-9.3.0/lib64/

dpi: $(DPI_SO)

$(DPI_SO): .cosim_obj.touchfile $(DPI_OBJ)
	$(CXX) $(CXXFLAGS) -o $(DPI_SO) $(DPI_OBJ) $(COSIM_OBJS) $(DPI_LINK_LIB)

cosim_obj: .cosim_obj.touchfile
.cosim_obj.touchfile: $(COSIM_SRCS)
	$(MAKE) -C $(COSIM_DIR) obj BDIR=$(COSIM_BDIR) USER_DEFINES="$(COSIM_DEFINES)"
	@touch .cosim_obj.touchfile

$(DPI_OBJ): $(DPI_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $< $(DPI_INC) $(COSIM_INC) $(COSIM_DEFINES)

cleancosim:
	$(MAKE) -C $(COSIM_DIR) cleanbuild BDIR=$(COSIM_BDIR)
	rm -rf .cosim_obj.touchfile

cleandpi:
	rm -rf $(DPI_ROOT)/*.*o *.so

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str

clean: cleanlogs
	rm -rf .*touchfile xsim.dir *.wdb

cleanall: clean cleancosim cleandpi
