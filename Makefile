# RTL build
TOP := ama_riscv_core_top_tb

# DPI variables needed during TB build
DPI_SO := ama-riscv-sim_dpi.so
DPI_ROOT := $(REPO_ROOT)/dpi
DPI_TB_FUNCS_H := $(DPI_ROOT)/dpi_tb_functions.h

RTL_DEFINES := -d CORE_ONLY -d ENABLE_COSIM
COMP_OPTS := -sv --incr --relax
ELAB_DEBUG ?= typical
ELAB_OPTS := -debug $(ELAB_DEBUG) --incr --relax --mt 8 -sdfroot ama_riscv_core_top_tb/DUT_ama_riscv_core_i

include $(REPO_ROOT)/Makefile.inc

TCLBATCH := run_cfg.tcl
TEST_PATH :=
TIMEOUT_CLOCKS :=
COSIM_CHECKER := -testplusarg enable_cosim_checkers
COSIM_CHECKER += -testplusarg stop_on_cosim_error

all: sim

#PDK := $(REPO_ROOT)/../asap7sc7p5t_28/Verilog
#GATES := lvt_hier.v.gates $(PDK)/asap7sc7p5t_AO_LVT_TT_201020.v $(PDK)/asap7sc7p5t_INVBUF_LVT_TT_201020.v $(PDK)/asap7sc7p5t_OA_LVT_TT_201020.v $(PDK)/asap7sc7p5t_SEQ_LVT_TT_220101.v $(PDK)/asap7sc7p5t_SIMPLE_LVT_TT_201020.v

#GATES := gates_rvt_flat.v $(PDK)/asap7sc7p5t_AO_RVT_TT_201020.v $(PDK)/asap7sc7p5t_INVBUF_RVT_TT_201020.v $(PDK)/asap7sc7p5t_OA_RVT_TT_201020.v $(PDK)/asap7sc7p5t_SEQ_RVT_TT_220101.v $(PDK)/asap7sc7p5t_SIMPLE_RVT_TT_201020.v

PDK := /home/alek/tools/openroad/OpenROAD-flow-scripts/flow/platforms/ihp-sg13g2/verilog
GATES := ihp.v.gates $(PDK)/sg13g2_stdcell.v

GATES_DEFS := -d CORE_ONLY -d GLS

compile_gates:
	xvlog --incr --relax $(GATES)

SRC_MEMS := $(REPO_ROOT)/src/ama_riscv_dmem.sv $(REPO_ROOT)/src/ama_riscv_imem.sv

compile_gates_tb:
	xvlog -sv --incr --relax $(SRC_VERIF) $(SRC_MEMS) $(GATES_DEFS) -i src/

elab_gates:
	xelab $(TOP) $(ELAB_OPTS) $(GATES_DEFS)

gls:
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=500

compile: .compile.touchfile
.compile.touchfile: $(SRC_VERIF) $(SRC_DESIGN) $(SRC_INC)
	xvlog $(COMP_OPTS) -prj $(SOURCE_FILES) $(RTL_DEFINES) -log /dev/null > xvlog.log 2>&1
	@rm xvlog.pb
	@touch .compile.touchfile

elab: .elab.touchfile
.elab.touchfile: .compile.touchfile $(DPI_SO)
	xelab $(TOP) $(ELAB_OPTS) -sv_lib $(DPI_SO) $(RTL_DEFINES) -log /dev/null > xelab.log 2>&1
	@rm xelab.pb
	@touch .elab.touchfile

dpi_header_gen: .compile.touchfile
	xelab $(TOP) $(ELAB_OPTS) $(RTL_DEFINES) -dpiheader $(DPI_TB_FUNCS_H) -log /dev/null > xelab_dpi_header_gen.log 2>&1

#SIM_LOG := -log test.log
SIM_LOG := -log /dev/null > test.log 2>&1

sim: .elab.touchfile
	xsim $(TOP) -tclbatch $(REPO_ROOT)/$(TCLBATCH) -stats -onerror quit -testplusarg test_path=$(REPO_ROOT)/$(TEST_PATH) -testplusarg timeout_clocks=$(TIMEOUT_CLOCKS) $(COSIM_CHECKER) $(SIM_LOG)
	@grep "PASS\|FAIL\|Error:" test.log || echo "Can't determine test status"

watch_slang:
	@make slang
	@while inotifywait -e close_write $(SRC_VERIF) $(SRC_DESIGN) 2>/dev/null; do \
		make slang; \
		echo ""; \
	done

slang:
	@slang $(SRC_VERIF) $(SRC_DESIGN) $(PLUS_INCDIR) -Wno-unconnected-port

lint:
	@verilator --lint-only $(SRC_DESIGN) -I$(REPO_ROOT)/src -Wall -Wpedantic > lint.log 2>&1

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

dpi: $(DPI_SO)

$(DPI_SO): .cosim_obj.touchfile $(DPI_OBJ)
	$(CXX) $(CXXFLAGS) -o $(DPI_SO) $(DPI_OBJ) $(COSIM_OBJS) $(DPI_LINK_LIB)

cosim_obj: .cosim_obj.touchfile
.cosim_obj.touchfile: $(COSIM_SRCS) $(COSIM_H)
	$(MAKE) -C $(COSIM_DIR) obj BDIR=$(COSIM_BDIR) DEFINES=-DDPI
	@touch .cosim_obj.touchfile

$(DPI_OBJ): $(DPI_SRC) $(DPI_TB_FUNCS_H) $(COSIM_H)
	$(CXX) $(CXXFLAGS) -c -o $@ $< $(DPI_INC) $(COSIM_INC)

cleancosim:
	$(MAKE) -C $(COSIM_DIR) cleanbuild BDIR=$(COSIM_BDIR)
	rm -rf .cosim_obj.touchfile

cleandpi:
	rm -rf $(DPI_ROOT)/*.*o *.so

cleanlogs:
	rm -rf *.log *.jou *.pb vivado_pid*.str out_*

clean: cleanlogs
	rm -rf .compile.touchfile .elab.touchfile xsim.dir *.wdb

cleanall: clean cleancosim cleandpi
