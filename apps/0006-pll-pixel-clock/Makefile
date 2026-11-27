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
RTL_SRCS   := video_clock.v clock_blink.v top.v
SIM_PRIMS  := sim_gowin_primitives.v

.PHONY: all test synth pnr bitstream stats flash flash-persist detect wave wave-top clean

all: test bitstream

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

test: $(BUILD_DIR)
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/video_clock.vvp $(SIM_PRIMS) video_clock.v video_clock_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/video_clock.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/top.vvp $(SIM_PRIMS) $(RTL_SRCS) top_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/top.vvp

synth: $(BUILD_DIR)
	$(BIN_PREFIX)yosys -q -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE) -json $(BUILD_DIR)/top.json"

pnr: synth
	$(BIN_PREFIX)nextpnr-himbaechel --quiet --device GW2AR-LV18QN88C8/I7 --json $(BUILD_DIR)/top.json --write $(BUILD_DIR)/top_pnr.json --vopt family=GW2A-18C --vopt cst=$(CST_FILE)

bitstream: pnr
	$(BIN_PREFIX)gowin_pack -d GW2A-18C -o $(BUILD_DIR)/top.fs $(BUILD_DIR)/top_pnr.json

stats:
	$(BIN_PREFIX)yosys -p "read_verilog video_clock.v; synth_gowin -top video_clock; stat"
	$(BIN_PREFIX)yosys -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE); stat"

flash: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k $(BUILD_DIR)/top.fs

flash-persist: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k -f $(BUILD_DIR)/top.fs

detect:
	$(BIN_PREFIX)openFPGALoader --detect

wave:
	surfer $(BUILD_DIR)/video_clock.vcd

wave-top:
	surfer $(BUILD_DIR)/top.vcd

clean:
	rm -rf $(BUILD_DIR)
