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
RTL_SRCS   := video_clock.v raster.v pattern.v tmds_encoder.v hdmi_tx.v top.v
SIM_PRIMS  := sim_gowin_primitives.v

.PHONY: all test synth pnr bitstream stats flash flash-persist detect wave wave-tx clean

all: test bitstream

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

test: $(BUILD_DIR)
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/tmds_encoder.vvp tmds_encoder.v tmds_encoder_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/tmds_encoder.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/hdmi_tx.vvp $(SIM_PRIMS) video_clock.v tmds_encoder.v hdmi_tx.v hdmi_tx_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/hdmi_tx.vvp
	$(BIN_PREFIX)iverilog -g2012 -Wall -o $(BUILD_DIR)/top.vvp $(SIM_PRIMS) $(RTL_SRCS) top_tb.v
	$(BIN_PREFIX)vvp $(BUILD_DIR)/top.vvp

synth: $(BUILD_DIR)
	$(BIN_PREFIX)yosys -q -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE) -json $(BUILD_DIR)/top.json"

pnr: synth
	$(BIN_PREFIX)nextpnr-himbaechel --quiet --device GW2AR-LV18QN88C8/I7 --json $(BUILD_DIR)/top.json --write $(BUILD_DIR)/top_pnr.json --vopt family=GW2A-18C --vopt cst=$(CST_FILE)

bitstream: pnr
	$(BIN_PREFIX)gowin_pack -d GW2A-18C -o $(BUILD_DIR)/top.fs $(BUILD_DIR)/top_pnr.json

stats:
	$(BIN_PREFIX)yosys -p "read_verilog tmds_encoder.v; synth_gowin -top tmds_encoder; stat"
	$(BIN_PREFIX)yosys -p "read_verilog $(RTL_SRCS); synth_gowin -top $(TOP_MODULE); stat"

flash: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k $(BUILD_DIR)/top.fs

flash-persist: bitstream
	$(BIN_PREFIX)openFPGALoader -b tangnano20k -f $(BUILD_DIR)/top.fs

detect:
	$(BIN_PREFIX)openFPGALoader --detect

wave:
	surfer $(BUILD_DIR)/tmds_encoder.vcd

wave-tx:
	surfer $(BUILD_DIR)/hdmi_tx.vcd

clean:
	rm -rf $(BUILD_DIR)
