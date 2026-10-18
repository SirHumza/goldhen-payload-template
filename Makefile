# GoldHEN payload template
#
# Point PS4_PAYLOAD_SDK at a ps4-payload-dev SDK that was built from git
# (scripts/setup_sdk.sh). The SDK's toolchain/orbis.mk supplies CC, LD and the
# default daemon-world libraries (-lkernel_web -lSceLibcInternal -lSceNet).

PS4_PAYLOAD_SDK ?= $(HOME)/ps4-payload-sdk
PS4_HOST        ?= 192.168.1.136
PS4_PORT        ?= 9021

include $(PS4_PAYLOAD_SDK)/toolchain/orbis.mk

BUILD := build
ELF   := $(BUILD)/payload.elf
SRC   := src/main.c

CFLAGS := -Wall -Wextra -O2 -g

.PHONY: all clean deploy check

all: $(ELF)

$(ELF): $(SRC)
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -rf $(BUILD)

# Fail loudly if an app-world library sneaks into the import set. These are the
# libraries that make a spawned payload die before main(), silently.
check: $(ELF)
	@if llvm-readelf -d $(ELF) | grep -q 'libkernel\.so'; then \
		echo "FAIL: payload imports libkernel.so (app-world); it will not run"; exit 1; \
	fi
	@echo "NEEDED:"; llvm-readelf -d $(ELF) | grep NEEDED | sed 's/^/  /'

# Fire blindly: on port 9020 an empty connect burns the one-shot arm.
deploy: $(ELF)
	$(PS4_DEPLOY) -h $(PS4_HOST) -p $(PS4_PORT) $(ELF)
