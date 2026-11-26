OSS_CAD_DIR ?= $(HOME)/oss-cad-suite
ifneq ($(wildcard $(OSS_CAD_DIR)/bin),)
BIN_PREFIX := $(OSS_CAD_DIR)/bin/
export PATH := $(OSS_CAD_DIR)/bin:$(OSS_CAD_DIR)/py3bin:$(PATH)
else
BIN_PREFIX :=
endif

TOP_MODULE ?= top
CST_FILE   ?= tangnano20k.cst
BUILD_DIR  := build
RTL_SRCS   := timer.v counter.v scanner.v top.v

.PHONY: all test synth pnr bitstream stats flash flash-persist detect wave wave-register wave-counter wave-timer wave-top clean

all: test bitstream

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

test: $(BUILD_DIR)
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/register.vvp register.v register_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/register.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/counter.vvp counter.v counter_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/counter.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/timer.vvp timer.v timer_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/timer.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/scanner.vvp scanner.v scanner_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/scanner.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/top.vvp $(RTL_SRCS) top_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/top.vvp

synth: $(BUILD_DIR)
	$(BIN_PREFIX)yosys -q -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE) -json $(BUILD_DIR)/top.json"

pnr: synth
	$(BIN_PREFIX)nextpnr-himbaechel --quiet --device GW2AR-LV18QN88C8/I7 --json $(BUILD_DIR)/top.json --write $(BUILD_DIR)/top_pnr.json --vopt family=GW2A-18C --vopt cst=$(CST_FILE)

bitstream: pnr
	$(BIN_PREFIX)gowin_pack -d GW2A-18C -o $(BUILD_DIR)/top.fs $(BUILD_DIR)/top_pnr.json

stats:
	$(BIN_PREFIX)yosys -p "read_verilog register.v; synth_gowin -top register; stat"
	$(BIN_PREFIX)yosys -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE); stat"

flash: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k $(BUILD_DIR)/top.fs

flash-persist: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k -f $(BUILD_DIR)/top.fs

detect:
	$(BIN_PREFIX)openFPGALoader --detect

wave:
	surfer $(BUILD_DIR)/scanner.vcd

wave-register:
	surfer $(BUILD_DIR)/register.vcd

wave-counter:
	surfer $(BUILD_DIR)/counter.vcd

wave-timer:
	surfer $(BUILD_DIR)/timer.vcd

wave-top:
	surfer $(BUILD_DIR)/top.vcd

clean:
	rm -rf $(BUILD_DIR)
