CXX := g++
CXXFLAGS := -Wall -Wextra -Werror -pedantic -g -std=gnu++17 -O3 -m64 -fPIC -shared
DPI_ROOT := $(REPO_ROOT)/dpi
SIM_SRCS := $(wildcard $(DPI_ROOT)/src/*.cpp)
SIM_SRCS := $(filter-out $(DPI_ROOT)/src/main.cpp, $(SIM_SRCS))
SIM_OBJS := $(SIM_SRCS:.cpp=.o)
SIM_OBJS := $(subst /src,,$(SIM_OBJS))
SIM_INC := $(DPI_ROOT)/src

DPI_SRC := $(DPI_ROOT)/core_dpi.cpp
DPI_OBJ := $(DPI_SRC:.cpp=.o)
DPI_INC := $(VIVADO_ROOT)/data/xsim/include
DPI_DEFINES := 
DPI_LINK_LIB := -L$(VIVADO_ROOT)/lib/lnx64.o/../../tps/lnx64/gcc-9.3.0/bin/../lib64
DPI_SO := ama-riscv-sim_dpi.so

TOP := ama_riscv_core_top_tb
SOURCE_FILES_SV := $(REPO_ROOT)/sources_sv.f
SOURCE_FILES_V := $(REPO_ROOT)/sources_v.f
VERILOG_DEFINES := 
COMP_OPTS_V := --incr --relax
COMP_OPTS_SV := -sv $(COMP_OPTS_V)
ELAB_DEBUG := typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8 -sv_lib $(DPI_SO)

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS :=

all: sim

$(DPI_SO): $(DPI_OBJ) $(SIM_OBJS)
	$(CXX) $(CXXFLAGS) -o $(DPI_SO) $^ $(DPI_LINK_LIB)
	@echo "DPI model built"

$(DPI_OBJ): $(DPI_SRC)
	$(CXX) $(CXXFLAGS) -c -o $@ $< -I$(DPI_INC) -I$(SIM_INC) $(DPI_DEFINES)

$(DPI_ROOT)/%.o: $(DPI_ROOT)/src/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $< -I$(DPI_INC) -I$(SIM_INC) $(DPI_DEFINES)

compile: .compile.touchfile
.compile.touchfile:
	xvlog $(COMP_OPTS_SV) -prj $(SOURCE_FILES_SV) $(VERILOG_DEFINES) > xvlog_sv.log 2>&1
	xvlog $(COMP_OPTS_V) -prj $(SOURCE_FILES_V) $(VERILOG_DEFINES) > xvlog_v.log 2>&1
	@rm xvlog.log xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(DPI_SO)
	xelab $(TOP) $(ELAB_OPTS) $(VERILOG_DEFINES) > xelab.log 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) > test.log 2>&1
	@touch .sim.touchfile
	@grep "PASS\|FAIL\|Error:" test.log

clean:
	rm -rf .*touchfile
	rm -rf xsim.dir
	rm -rf *.log
	rm -rf *.jou
	rm -rf *.pb
	rm -rf *.wdb

cleanall: clean
	rm -f $(DPI_ROOT)/*.*o
	rm -f *.so
