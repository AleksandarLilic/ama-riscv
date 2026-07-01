PARSE_FILELIST := $(REPO_ROOT)/script/parse_filelist.py

SOURCE_FILES ?= $(REPO_ROOT)/filelist/sources_sim.f

# if SIM_ONLY, ignore getting sources so it doesn't trigger rebuilds
SIM_ONLY ?= 0
ifeq ($(strip $(SIM_ONLY)), 1)
SRC_VERIF :=
SRC_DESIGN :=
INC_DIRS :=
SRC_INC :=
PLUS_INCDIR :=
else
SRC_DESIGN := $(shell $(PARSE_FILELIST) design $(SOURCE_FILES))
SRC_VERIF := $(shell $(PARSE_FILELIST) verif $(SOURCE_FILES))
INC_DIRS := $(shell $(PARSE_FILELIST) include-dirs $(SOURCE_FILES))
SRC_INC := $(foreach dir,$(INC_DIRS),$(dir)/*)
PLUS_INCDIR := $(addprefix +incdir+,$(INC_DIRS))
endif

RTL_DEFINES_LIST := $(shell $(PARSE_FILELIST) defines $(SOURCE_FILES))
# -D style defines for slang & verilator
RTL_DEFINES_CS := $(addprefix -D,$(RTL_DEFINES_LIST))

WORKLIB := $(shell $(PARSE_FILELIST) worklib $(SOURCE_FILES))

# color coding
GREEN  := $(shell printf "\033[0;32m")
RED    := $(shell printf "\033[0;31m")
YELLOW := $(shell printf "\033[0;33m")
NC     := $(shell printf "\033[0m")
