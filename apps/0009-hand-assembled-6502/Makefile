BUILD_DIR := build

.PHONY: all test disasm clean

all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

test: $(BUILD_DIR)
	python3 verify_hand_asm.py
	da65 --start-addr 0xC000 $(BUILD_DIR)/hand_assembled.bin > $(BUILD_DIR)/disasm.txt
	grep -q 'lda     #$$00' $(BUILD_DIR)/disasm.txt
	grep -q 'sta     $$8000' $(BUILD_DIR)/disasm.txt
	grep -q 'clc' $(BUILD_DIR)/disasm.txt
	grep -q 'adc     #$$01' $(BUILD_DIR)/disasm.txt
	grep -q 'jmp     LC002' $(BUILD_DIR)/disasm.txt
	@echo "PASS: da65 verified all 5 instructions at \$$C000"

disasm: test
	da65 --start-addr 0xC000 $(BUILD_DIR)/hand_assembled.bin

clean:
	rm -rf $(BUILD_DIR)
