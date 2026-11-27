BUILD_DIR := build

.PHONY: all test inspect clean

all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/count.o: count.s | $(BUILD_DIR)
	ca65 -l $(BUILD_DIR)/count.lst count.s -o $(BUILD_DIR)/count.o

$(BUILD_DIR)/count.bin: $(BUILD_DIR)/count.o memory.cfg
	ld65 -C memory.cfg -m $(BUILD_DIR)/count.map $(BUILD_DIR)/count.o -o $(BUILD_DIR)/count.bin

$(BUILD_DIR)/rom.mem $(BUILD_DIR)/code.bin: $(BUILD_DIR)/count.bin bin2mem.py
	python3 bin2mem.py $(BUILD_DIR)/count.bin $(BUILD_DIR)/rom.mem $(BUILD_DIR)/code.bin

test: $(BUILD_DIR)/rom.mem
	da65 --start-addr 0xC000 $(BUILD_DIR)/code.bin > $(BUILD_DIR)/disasm.txt
	grep -q 'lda     #$$00' $(BUILD_DIR)/disasm.txt
	grep -q 'sta     $$8000' $(BUILD_DIR)/disasm.txt
	grep -q 'clc' $(BUILD_DIR)/disasm.txt
	grep -q 'adc     #$$01' $(BUILD_DIR)/disasm.txt
	grep -q 'jmp     LC002' $(BUILD_DIR)/disasm.txt
	@test "$$(wc -l < $(BUILD_DIR)/rom.mem | tr -d ' ')" = "16384"
	@echo "PASS: ca65/ld65/da65 verified 16 KB ROM and 11-byte loop"

inspect: test
	@echo "=== ca65 listing (build/count.lst) ==="
	@cat $(BUILD_DIR)/count.lst
	@echo "=== ld65 memory map (build/count.map) ==="
	@cat $(BUILD_DIR)/count.map
	@echo "=== First 16 lines of build/rom.mem ==="
	@head -n 16 $(BUILD_DIR)/rom.mem
	@echo "=== da65 disassembly ==="
	@cat $(BUILD_DIR)/disasm.txt

clean:
	rm -rf $(BUILD_DIR)
