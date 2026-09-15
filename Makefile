# ============================================================
# Toolchain
# ============================================================

TOOLCHAIN := /home/ubuntu/dev/tools/arm-gnu-toolchain-15.3.rel1-x86_64-arm-none-eabi
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

SRCS := \
$(CORE_DIR)/startup/startup_stm32f407vgtx.s \
$(CORE_DIR)/src/syscalls.c \
$(SRC_DIR)/main.c

# cppcheck can't parse assembly, so only feed it C sources
CPPCHECK_SRCS := $(filter %.c, $(SRCS))

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

$(ELF): $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@ \
	    > $(LOG_DIR)/build.log 2>&1

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

.PHONY: all dirs clean print flash cppcheck