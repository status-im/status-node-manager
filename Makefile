# verbosity level
V := 0
NIM_PARAMS := $(NIM_PARAMS) --verbosity:$(V)
HANDLE_OUTPUT :=
SILENT_TARGET_PREFIX := disabled
ifeq ($(V), 0)
  NIM_PARAMS := $(NIM_PARAMS) --hints:off
  # don't swallow stderr, in case it's important
  HANDLE_OUTPUT := >/dev/null
  SILENT_TARGET_PREFIX :=
endif

##################
##     RLN      ##
##################
.PHONY: librln

LIBRLN_BUILDDIR := $(CURDIR)/vendor/zerokit
LIBRLN_VERSION := v0.3.4

ifeq ($(OS),Windows_NT)
LIBRLN_FILE := rln.lib
else
LIBRLN_FILE := librln_$(LIBRLN_VERSION).a
endif

$(LIBRLN_FILE):
	echo -e $(BUILD_MSG) "$@" && \
		./scripts/build_rln.sh $(LIBRLN_BUILDDIR) $(LIBRLN_VERSION) $(LIBRLN_FILE)


librln: | $(LIBRLN_FILE)
	$(eval NIM_PARAMS += --passL:$(LIBRLN_FILE) --passL:-lm)

clean-librln:
	cargo clean --manifest-path vendor/zerokit/rln/Cargo.toml
	rm -f $(LIBRLN_FILE)

# Extend clean target
clean: | clean-librln

##################
##  WAKU UTILS  ##
##################

waku-utils: | librln
	nim wakuUtils $(NIM_PARAMS) status_node_manager.nims

waku-utils-example: | librln
	nim wakuUtilsExamples $(NIM_PARAMS) status_node_manager.nims
