define get_sources_d
$(foreach file,$(shell cat $(1) | grep -v -- '--include' | grep 'src' | grep -oP '"\K[^"]+' | sed 's/\\//g'),$(shell echo $(file)))
endef

define get_sources_v
$(foreach file,$(shell cat $(1) | grep -v -- '--include' | grep 'verif' | grep -oP '"\K[^"]+' | sed 's/\\//g'),$(shell echo $(file)))
endef

define get_include_dirs
$(foreach file,$(shell cat $(1) | grep -- '--include' | grep -oP '"\K[^"]+' | sed 's/\\//g'),$(shell echo $(file)))
endef

SOURCE_FILES := $(REPO_ROOT)/sources.f
SRC_VERIF := $(call get_sources_v,$(SOURCE_FILES))
SRC_DESIGN := $(call get_sources_d,$(SOURCE_FILES))
INC_DIRS := $(call get_include_dirs,$(SOURCE_FILES))
SRC_INC := $(foreach dir,$(INC_DIRS),$(shell echo $(dir))/*)
PLUS_INCDIR := $(foreach dir,$(INC_DIRS),$(shell echo +incdir+$(dir)))

# because ORFS hangs if functions are still defined
# due to some expansions done in the OpenROAD-flow-scripts/flow/util/utils.mk
get_sources_d =
get_sources_v =
get_include_dirs =

# color coding
GREEN  := $(shell printf "\033[0;32m")
RED    := $(shell printf "\033[0;31m")
YELLOW := $(shell printf "\033[0;33m")
NC     := $(shell printf "\033[0m")
