# Copyright 2025 The ChromiumOS Authors
# Distributed under the terms of the GNU General Public License v2
#
# Script to build multiple depthcharge boards in parallel

.DELETE_ON_ERROR:
.SUFFIXES:
.PRECIOUS: %/depthcharge.config
SHELL := /bin/bash

.PHONY: all FORCE

# Export all parameters
export

%/depthcharge.config: %/depthcharge.defconfig
	if ! $(MAKE) obj="$(dir $@)" DOTCONFIG="$@" KBUILD_DEFCONFIG="$<" defconfig &>"$@.log"; then \
		cat "$@.log"; \
		exit 1; \
	fi

%/depthcharge.elf: %/depthcharge.config
	if ! $(MAKE) obj="$(dir $@)" DOTCONFIG="$<" \
			LIBPAYLOAD_DIR="$(dir $@)libpayload/libpayload" \
			depthcharge &>"$(dir $@)depthcharge.build.log"; then \
		cat "$(dir $@)depthcharge.build.log"; \
		exit 1; \
	fi

# Depend on depthcharge.elf to serialize the invocations since it's just an
# additive build.
%/dev.elf: %/depthcharge.config %/depthcharge.elf
	# Reuse objects from above, with libpayload.gdb.
	if ! $(MAKE) obj="$(dir $@)" DOTCONFIG="$<" \
			LIBPAYLOAD_DIR="$(dir $@)libpayload.gdb/libpayload" \
			dev &>"$(dir $@)dev.build.log"; then \
		cat "$(dir $@)dev.build.log"; \
		exit 1; \
	fi

# Depend on dev.elf for the same reason as above.
%/netboot.elf: %/depthcharge.config %/dev.elf
	# Reuse objects from above, with libpayload.gdb.
	if ! $(MAKE) obj="$(dir $@)" DOTCONFIG="$<" \
			LIBPAYLOAD_DIR="$(dir $@)libpayload.gdb/libpayload" \
			netboot &>"$(dir $@)netboot.build.log"; then \
		cat "$(dir $@)netboot.build.log"; \
		exit 1; \
	fi
