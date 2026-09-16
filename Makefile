# ============================================================
# Shell
# ============================================================
# bash + pipefail so that `$(CC) ... | tee log` below still fails the
# build when $(CC) fails, instead of only reflecting tee's exit status.

SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

# ============================================================
# Toolchain
# ============================================================

TOOLCHAIN ?= /home/ubuntu/dev/tools/arm-gnu-toolchain-15.3.rel1-x86_64-arm-none-eabi
TOOLBIN  := $(TOOLCHAIN)/bin

CC      := $(TOOLBIN)/arm-none-eabi-gcc
OBJCOPY := $(TOOLBIN)/arm-none-eabi-objcopy

# ============================================================
# Project
# ============================================================

TARGET      := firmware
SRC_DIR     := codebase/app
CORE_DIR    := core
CPPCHECK    := cppcheck
FORMAT     := clang-format-21

SRCS := \
$(CORE_DIR)/startup/startup_stm32f407vgtx.s \
$(CORE_DIR)/src/syscalls.c \
$(SRC_DIR)/main.c

# NOTE: if main.c or the startup file call any HAL functions (very likely,
# given USE_HAL_DRIVER is defined below) or SystemInit(), you also need the
# relevant stm32f4xx_hal_*.c sources and system_stm32f4xx.c in this list,
# or the link step will fail with "undefined reference" errors.

# cppcheck and clang-format can't parse assembly, so only feed them C sources
CPPCHECK_SRCS := $(filter %.c, $(SRCS))
FORMAT_SRCS   := $(filter %.c, $(SRCS))

# ============================================================
# Output directories
# ============================================================

BUILD_DIR := _builds
BIN_DIR   := $(BUILD_DIR)/_bin
LOG_DIR   := $(BUILD_DIR)/_logs

ELF     := $(BIN_DIR)/$(TARGET).elf
FW_BIN  := $(BIN_DIR)/$(TARGET).bin
MAP     := $(BIN_DIR)/$(TARGET).map

# ============================================================
# CPU / MCU Settings
# ============================================================

CPUFLAGS := \
    -mcpu=cortex-m4 \
    -mfpu=fpv4-sp-d16 \
    -mfloat-abi=hard \
    -mthumb

# ============================================================
# Include Paths
# ============================================================
# NOTE: verify these actually exist relative to the project root.
# Run `ls core/Inc` and `ls Drivers` from the project root — if they
# don't exist, fix these paths to match your real folder layout
# (case-sensitive on Linux, e.g. "Core" vs "core").

INCLUDES := \
    -I$(SRC_DIR) \
    -I$(CORE_DIR)/Inc \
    -IDrivers/STM32F4xx_HAL_Driver/Inc \
    -IDrivers/STM32F4xx_HAL_Driver/Inc/Legacy \
    -IDrivers/CMSIS/Device/ST/STM32F4xx/Include \
    -IDrivers/CMSIS/Include

# ============================================================
# Compiler Flags
# ============================================================

CFLAGS := \
$(CPUFLAGS) \
    -std=gnu11 \
    -g3 \
    -O0 \
    -DDEBUG \
    -DUSE_HAL_DRIVER \
    -DSTM32F407xx \
    -ffunction-sections \
    -fdata-sections \
    -fstack-usage \
    -Wall \
$(INCLUDES)

# ============================================================
# Linker Flags
# ============================================================

LDFLAGS := \
$(CPUFLAGS) \
    -TSTM32F407VGTX_FLASH.ld \
    --specs=nano.specs \
    --specs=nosys.specs \
    -Wl,-Map=$(MAP) \
    -Wl,--gc-sections

# ============================================================
# Build Rules
# ============================================================

all: dirs $(ELF) $(FW_BIN)

dirs:
	mkdir -p $(BIN_DIR) $(LOG_DIR)

# Order-only prerequisite on `dirs` (the "| dirs") guarantees $(LOG_DIR)
# exists before the log redirection below runs, even if $(ELF) is built
# directly (e.g. `make _builds/_bin/firmware.elf`) or with `make -j`.
$(ELF): $(SRCS) | dirs
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@ \
	    2>&1 | tee $(LOG_DIR)/build.log

$(FW_BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

# ============================================================
# Utilities
# ============================================================

clean:
	rm -rf $(BUILD_DIR)

print:
	@echo "ELF : $(ELF)"
	@echo "BIN : $(FW_BIN)"
	@echo "MAP : $(MAP)"

flash: all
	st-flash write $(FW_BIN) 0x08000000

# ============================================================
# Static Analysis
# ============================================================
# First pass: bug-relevant categories only, fails the build on findings.
# Second pass: style hints only, informational, never fails the build.

cppcheck:
	@$(CPPCHECK) --quiet --enable=warning,performance,portability \
	    --error-exitcode=1 \
	    --inline-suppr \
	    --suppress=missingIncludeSystem \
	    $(INCLUDES) \
	    $(CPPCHECK_SRCS) \
	    -i external/printf
	@$(CPPCHECK) --quiet --enable=style \
	    --inline-suppr \
	    --suppress=missingIncludeSystem \
	    --suppress=unusedFunction \
	    $(INCLUDES) \
	    $(CPPCHECK_SRCS) \
	    -i external/printf

format:
	@$(FORMAT) -i $(FORMAT_SRCS)

.PHONY: all dirs clean print flash cppcheck format