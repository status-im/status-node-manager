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
## Dependencies ##
##################
.PHONY: deps libbacktrace

### nim-libbacktrace

# "-d:release" implies "--stacktrace:off" and it cannot be added to config.nims
ifeq ($(USE_LIBBACKTRACE), 0)
NIM_PARAMS := $(NIM_PARAMS) -d:debug -d:disable_libbacktrace
else
NIM_PARAMS := $(NIM_PARAMS) -d:release
endif

libbacktrace:
	+ $(MAKE) -C nimble_develop/nim-libbacktrace --no-print-directory BUILD_CXX_LIB=0

clean-libbacktrace:
	+ $(MAKE) -C nimble_develop/nim-libbacktrace clean $(HANDLE_OUTPUT)

# # Extend deps and clean targets
# ifneq ($(USE_LIBBACKTRACE), 0)
# deps: | libbacktrace
# endif

clean: | clean-libbacktrace

##################
##     RLN      ##
##################
.PHONY: librln

LIBRLN_BUILDDIR := $(CURDIR)/vendor/zerokit
LIBRLN_VERSION := v0.3.7

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

waku-utils: | deps librln
	nim wakuUtils $(NIM_PARAMS) status_node_manager.nims

waku-utils-example: | deps librln
	nim wakuUtilsExamples $(NIM_PARAMS) status_node_manager.nims


###########################
##  STATUS NODE MANAGER  ##
###########################

status-node-manager: | deps librln
	nim statusNodeManager $(NIM_PARAMS) status_node_manager.nims

test: | deps librln
	nim test $(NIM_PARAMS) status_node_manager.nims
