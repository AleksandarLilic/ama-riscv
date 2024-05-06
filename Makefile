CXX := g++
CXXFLAGS := -Wall -Wextra -Werror -pedantic -g -std=gnu++17 -O3 -m64 -fPIC -shared
DPI_ROOT := $(REPO_ROOT)/dpi
SIM_SRCS := $(wildcard $(DPI_ROOT)/src/*.cpp)
SIM_SRCS := $(filter-out $(DPI_ROOT)/src/main.cpp, $(SIM_SRCS))
SIM_OBJS := $(SIM_SRCS:.cpp=.o)
SIM_OBJS := $(subst /src,,$(SIM_OBJS))
SIM_INC := $(DPI_ROOT)/src
SIM_DEFINES := -DENABLE_DASM -DENABLE_PROF -DDPI

DPI_SRC := $(DPI_ROOT)/core_dpi.cpp
DPI_OBJ := $(DPI_SRC:.cpp=.o)
DPI_INC := $(VIVADO_ROOT)/data/xsim/include
DPI_LINK_LIB := -L$(VIVADO_ROOT)/lib/lnx64.o/../../tps/lnx64/gcc-9.3.0/bin/../lib64
DPI_SO := ama-riscv-sim_dpi.so

TOP := ama_riscv_core_top_tb
SOURCE_FILES_SV := $(REPO_ROOT)/sources_sv.f
SOURCE_FILES_V := $(REPO_ROOT)/sources_v.f
VERILOG_DEFINES := -d CORE_ONLY -d ENABLE_COSIM
COMP_OPTS_V := --incr --relax
COMP_OPTS_SV := -sv $(COMP_OPTS_V)
ELAB_DEBUG := typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8 -sv_lib $(DPI_SO)

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

all: sim

$(DPI_SO): $(DPI_OBJ) $(SIM_OBJS)
	$(CXX) $(CXXFLAGS) -o $(DPI_SO) $^ $(DPI_LINK_LIB)

$(DPI_OBJ): $(DPI_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $< -I$(DPI_INC) -I$(SIM_INC) $(SIM_DEFINES)

$(DPI_ROOT)/%.o: $(DPI_ROOT)/src/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $< -I$(DPI_INC) -I$(SIM_INC) $(SIM_DEFINES)

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
	xelab $(TOP) $(ELAB_OPTS) $(VERILOG_DEFINES) -log /dev/null > xelab.log 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) $(COSIM_CHECKER) -log /dev/null > test.log 2>&1
	@touch .sim.touchfile
	@grep "PASS\|FAIL\|Error:" test.log

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str

clean: cleanlogs
	rm -rf .*touchfile xsim.dir *.wdb

cleanall: clean
	rm -f $(DPI_ROOT)/*.*o *.so
