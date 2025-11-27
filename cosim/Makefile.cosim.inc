# meant to be included in the <repo_root>/Makefile

# ISA SIM
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
ISA_SIM_BDIR ?= build_obj
$(shell mkdir -p $(ISA_SIM_DIR)/$(ISA_SIM_BDIR))

ISA_SIM_SRCS := $(wildcard $(ISA_SIM_DIR)/*.cpp)
ISA_SIM_SRCS += $(wildcard $(ISA_SIM_DIR)/devices/*.cpp)
ISA_SIM_SRCS += $(wildcard $(ISA_SIM_DIR)/profilers/*.cpp)
ISA_SIM_SRCS := $(filter-out %main.cpp, $(ISA_SIM_SRCS))

ISA_SIM_OBJS := $(patsubst $(ISA_SIM_DIR)/%, $(ISA_SIM_DIR)/$(ISA_SIM_BDIR)/%, $(ISA_SIM_SRCS:.cpp=.o))

ISA_SIM_H := $(wildcard $(ISA_SIM_DIR)/*.h)
ISA_SIM_H += $(wildcard $(ISA_SIM_DIR)/devices/*.h)
ISA_SIM_H += $(wildcard $(ISA_SIM_DIR)/profilers/*.h)
ISA_SIM_H += $(wildcard $(ISA_SIM_DIR)/hw_models/*.h)

# ISA sim header files needed for cosim build
ISA_SIM_INC := -I$(ISA_SIM_DIR) -I$(ISA_SIM_DIR)/devices -I$(ISA_SIM_DIR)/profilers -I$(ISA_SIM_DIR)/hw_models
ISA_SIM_INC += -isystem $(ISA_SIM_DIR)/external/ELFIO

# COSIM
COSIM_ROOT := cosim
COSIM_ROOT_ABS := $(REPO_ROOT)/$(COSIM_ROOT)
DPI_FUNCS_H := $(COSIM_ROOT)/dpi_functions.h # auto-generated, needs exact path
COSIM_H := $(wildcard $(COSIM_ROOT)/*.h) # all cosim headers
COSIM_BDIR := build
COSIM_BDIR_FULL := $(COSIM_ROOT)/$(COSIM_BDIR)
COSIM_SO := ama-riscv-cosim.so
COSIM_TARGET := $(COSIM_BDIR_FULL)/$(COSIM_SO)

COSIM_SRCS := $(wildcard $(COSIM_ROOT)/*.cpp)
COSIM_OBJS := $(patsubst $(COSIM_ROOT)/%.cpp,$(COSIM_ROOT)/$(COSIM_BDIR)/%.o,$(COSIM_SRCS))
COSIM_DEPS := $(patsubst $(COSIM_ROOT)/%.cpp,$(COSIM_ROOT)/$(COSIM_BDIR)/%.d,$(COSIM_SRCS))

COSIM_INC := -I$(VIVADO_ROOT)/data/xsim/include
COSIM_INC += -I$(COSIM_ROOT)
DPI_LINK_LIB := -L$(VIVADO_ROOT)/tps/lnx64/gcc-9.3.0/lib64/

ISA_SIM_EXT := -I$(COSIM_ROOT_ABS)
ISA_SIM_EXT += -I$(VIVADO_ROOT)/data/xsim/include

# TARGETS
cosim_target: $(COSIM_TARGET)

cosim_obj: $(COSIM_OBJS)

$(COSIM_TARGET): .isa_sim_obj.touchfile $(COSIM_OBJS)
	echo "Building COSIM SO"
	$(CXX) $(CXXFLAGS) -o $(COSIM_TARGET) $(COSIM_OBJS) $(ISA_SIM_OBJS) $(DPI_LINK_LIB)

# recipe calls isa sim's make which builds all isa sim objects
# even though not all objects may be strictly required for cosim
isa_sim_obj: .isa_sim_obj.touchfile
.isa_sim_obj.touchfile: $(ISA_SIM_SRCS) $(ISA_SIM_H) $(COSIM_H)
	@echo "Building ISA SIM"
	$(MAKE) -C $(ISA_SIM_DIR) obj_for_cosim INC_EXT="$(ISA_SIM_EXT)" BDIR=$(ISA_SIM_BDIR) DEFINES="-DDPI -DCACHE_MODE=CACHE_MODE_FUNC"
	@touch .isa_sim_obj.touchfile

$(COSIM_ROOT)/$(COSIM_BDIR)/%.o: $(COSIM_ROOT)/%.cpp $(COSIM_H) $(ISA_SIM_H)
	@echo "Building COSIM OBJ $@"
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -c $< -o $@ $(COSIM_INC) $(ISA_SIM_INC) -DDPI

-include $(DEPS)

cleancosim:
	rm -rf $(COSIM_BDIR_FULL)

cleanisa:
	$(MAKE) -C $(ISA_SIM_DIR) cleanbuild BDIR=$(ISA_SIM_BDIR)
	rm -f .isa_sim_obj.touchfile

.PHONY: cleancosim cleanisa
