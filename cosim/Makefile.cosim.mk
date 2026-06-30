# meant to be included in the <repo_root>/Makefile

# ISA SIM
CXX ?= g++
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
ISA_SIM_BDIR ?= build_obj_for_cosim
$(shell mkdir -p $(ISA_SIM_DIR)/$(ISA_SIM_BDIR))

SIMD ?= 1 # RTL's equivalent is '--define CPU_SIMD_EN=1' in filelist
RV32C ?= 0 # unsupported by RTL

ISA_SIM_SRC_ROOT := $(ISA_SIM_DIR)
ISA_SIM_OBJ_ROOT := $(ISA_SIM_DIR)/$(ISA_SIM_BDIR)
ISA_SIM_SRC_MK := $(ISA_SIM_DIR)/Makefile.isa_sim_sources.mk
include $(ISA_SIM_SRC_MK)

ISA_SIM_COSIM_MAKE_ARGS := BDIR=$(ISA_SIM_BDIR)
ISA_SIM_COSIM_MAKE_ARGS += DPI=1 UART_IN=1 SIMD=$(SIMD) RV32C=$(RV32C)
ISA_SIM_COSIM_MAKE_ARGS += PROFILERS=0 HW_MODELS=0 DASM=0

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
COSIM_OBJS := $(patsubst $(COSIM_ROOT)/%.cpp, $(COSIM_ROOT)/$(COSIM_BDIR)/%.o, $(COSIM_SRCS))
COSIM_DEPS := $(patsubst $(COSIM_ROOT)/%.cpp, $(COSIM_ROOT)/$(COSIM_BDIR)/%.d, $(COSIM_SRCS))

COSIM_INC := -I$(VIVADO_ROOT)/data/xsim/include
COSIM_INC += -I$(COSIM_ROOT)
DPI_LINK_LIB := -L$(VIVADO_ROOT)/tps/lnx64/gcc-9.3.0/lib64/

ISA_SIM_INC_EXTRA := -I$(COSIM_ROOT_ABS)
ISA_SIM_INC_EXTRA += -I$(VIVADO_ROOT)/data/xsim/include

# log stdout
COSIM_LOG_ARG :=
# 'TO_LOG' and 'LOG_NAME' from RTL makefile
ifeq ($(strip $(TO_LOG)),1)
    COSIM_LOG_ARG := >> $(LOG_NAME) 2>&1
endif

# TARGETS
cosim_target: $(COSIM_TARGET)

cosim_obj: $(COSIM_OBJS)

$(COSIM_TARGET): .isa_sim_obj.touchfile $(COSIM_OBJS)
	@echo "Building COSIM SO" $(COSIM_LOG_ARG)
	@$(CXX) $(CXXFLAGS) -o $(COSIM_TARGET) $(COSIM_OBJS) $(ISA_SIM_COSIM_OBJS) \
		$(DPI_LINK_LIB) $(COSIM_LOG_ARG)
	@echo "Building COSIM SO done" $(COSIM_LOG_ARG)

# recipe calls isa sim's make which builds all isa sim objects
# even though not all objects may be strictly required for cosim
isa_sim_obj: .isa_sim_obj.touchfile
.isa_sim_obj.touchfile: $(ISA_SIM_COSIM_SRCS) $(ISA_SIM_H) $(COSIM_H) \
		$(ISA_SIM_DIR)/Makefile $(ISA_SIM_SRC_MK)
	@echo "Building ISA SIM" $(COSIM_LOG_ARG)
	@$(MAKE) -C $(ISA_SIM_DIR) obj_for_cosim $(ISA_SIM_COSIM_MAKE_ARGS) \
		INC_EXTRA="$(ISA_SIM_INC_EXTRA)" CXX="$(CXX)" $(COSIM_LOG_ARG)
	@touch .isa_sim_obj.touchfile
	@echo "Building ISA SIM done" $(COSIM_LOG_ARG)

$(COSIM_ROOT)/$(COSIM_BDIR)/%.o: $(COSIM_ROOT)/%.cpp $(COSIM_H) $(ISA_SIM_H)
	@echo "Building COSIM OBJ $@" $(COSIM_LOG_ARG)
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -MMD -c $< -o $@ $(COSIM_INC) $(ISA_SIM_INC) -DDPI \
		$(COSIM_LOG_ARG)
	@echo "Building COSIM OBJ $@ done" $(COSIM_LOG_ARG)

-include $(DEPS)

cleancosim:
	rm -rf $(COSIM_BDIR_FULL)

cleanisa:
	$(MAKE) -C $(ISA_SIM_DIR) clean BDIR=$(ISA_SIM_BDIR)
	rm -f .isa_sim_obj.touchfile

.PHONY: cleancosim cleanisa
