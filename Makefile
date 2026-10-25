# GF180 mixed-signal project Makefile.  Run `make help`.
# Requires ~/eda/eda_env.sh to be sourced (done automatically by ~/.bashrc).
#
##Setup
##  make check                 tool + PDK sanity check
##  make setup                 create build dirs and the analog/sim/models link
##Digital (SAR logic, OpenROAD-flow-scripts)
##  make rtl-sim               iverilog testbench (digital/tb)
##  make wave                  open last VCD in GTKWave
##  make synth|floorplan|place|cts|route
##  make flow                  full RTL -> GDS
##  make gui                   OpenROAD GUI on the final layout
##  make digital-gds           copy final GDS to analog/gds/ for top-level integration
##  make orfs-<target>         any ORFS target, e.g. orfs-clean_all, orfs-gui_place
##Analog (CELL=sar_adc by default)
##  make xschem [CELL=x]       schematic editor
##  make netlist CELL=x        xschem -> analog/netlist/x.spice (LVS-style)
##  make sim [TB=tb_inv]       ngspice batch run of analog/sim/TB.spice
##  make sim-i [TB=tb_inv]     ngspice interactive
##  make magic [CELL=x]        layout editor (runs in analog/mag)
##  make klayout [GDS=file]    KLayout viewer with GF180 tech
##  make drc CELL=x            Magic DRC, report in build/drc/
##  make extract CELL=x        layout -> analog/netlist/x.lay.spice
##  make lvs CELL=x            extract + netlist + Netgen LVS, report in build/lvs/
##  make gds CELL=x            Magic layout -> analog/gds/x.gds
##Tiny Tapeout (inside a repo made from ttgf-analog-template, see TAPEOUT.md)
##  make tt-init               create analog/mag/<top_module>.mag from the TT pin template
##  make magic CELL=<top>      edit the top cell (pins, power stripes, wiring)
##  make tt-export             write gds/<top>.gds and lef/<top>.lef
##  make precheck              run Tiny Tapeout's precheck locally (same checks as GitHub CI)
##  make tt-view               open gds/<top>.gds in KLayout
##Housekeeping
##  make clean                 remove build/ and simulator outputs

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eo pipefail -c

PROJ  := $(CURDIR)
BUILD := $(PROJ)/build

# ---- User knobs (override on the command line: make drc CELL=comparator) ----
CELL   ?= sar_adc
TB     ?= tb_inv
GDS    ?=
CORNER ?= typical
MAGIC_DISPLAY ?= X11

# ---- Digital (ORFS) --------------------------------------------------------
DIG_CONFIG := $(PROJ)/digital/config.mk
DIG_NICK   := $(shell sed -n 's/^export DESIGN_NICKNAME *= *\([^ ]*\).*/\1/p' $(DIG_CONFIG))
ORFS_WORK  := $(BUILD)/orfs
ORFS_MAKE   = $(MAKE) --no-print-directory -C $(FLOW_HOME) DESIGN_CONFIG=$(DIG_CONFIG) WORK_HOME=$(ORFS_WORK)
DIG_GDS     = $(ORFS_WORK)/results/gf180/$(DIG_NICK)/base/6_final.gds

# ---- Analog paths ----------------------------------------------------------
XSCH_DIR := $(PROJ)/analog/xschem
MAG_DIR  := $(PROJ)/analog/mag
SIM_DIR  := $(PROJ)/analog/sim
NET_DIR  := $(PROJ)/analog/netlist
GDS_DIR  := $(PROJ)/analog/gds
MAGIC_B   = magic -dnull -noconsole -rcfile $(MAGICRC)

# ---- Tiny Tapeout (values read from info.yaml) -----------------------------
TT_TOOLS ?= $(EDA_ROOT)/tt-support-tools
TT_VENV  ?= $(EDA_ROOT)/tt-venv
TOP      := $(shell sed -n 's/^ *top_module: *"\([^"]*\)".*/\1/p' $(PROJ)/info.yaml 2>/dev/null)
TILES    := $(shell sed -n 's/^ *tiles: *"\([^"]*\)".*/\1/p' $(PROJ)/info.yaml 2>/dev/null)
VAPWR    := $(shell sed -n 's/^ *uses_vapwr: *\([a-z]*\).*/\1/p' $(PROJ)/info.yaml 2>/dev/null)
TT_DEF    = $(TT_TOOLS)/tech/gf180mcuD/def/analog/tt_analog_$(TILES)$(if $(filter true,$(VAPWR)),_pgvaa).def
TT_SUB   := $(BUILD)/tt_submission

.PHONY: help check setup env \
        rtl-sim wave synth floorplan place cts route flow gui orfs-% digital-gds clean-digital \
        xschem netlist sim sim-i magic klayout drc extract lvs gds clean \
        tt-guard tt-init tt-export precheck tt-view

help:
	@sed -n 's/^## \{0,1\}//p' $(firstword $(MAKEFILE_LIST))

# ---- Environment guards ----------------------------------------------------
env:
	@[ -n "$$PDK_ROOT" ] || { echo "PDK_ROOT not set. Run: source ~/eda/eda_env.sh"; exit 1; }
	mkdir -p $(BUILD)/{sim,drc,lvs,logs} $(NET_DIR) $(GDS_DIR)
	[ -d "$$PDK_ROOT/$$PDK" ] || { echo "PDK not found at $$PDK_ROOT/$$PDK"; exit 1; }

check: env
	@for t in openroad yosys klayout magic netgen xschem ngspice iverilog gtkwave; do
	  printf "  %-9s %s\n" "$$t" "$$(command -v $$t || echo MISSING)"; done
	for f in "$$MAGICRC" "$$NETGEN_SETUP" "$$XSCHEMRC_PDK" "$$SPICE_MODELS"; do
	  [ -e "$$f" ] && echo "  ok       $$f" || echo "  MISSING  $$f"; done
	echo "  FLOW_HOME $${FLOW_HOME:-MISSING}"

setup: env
	@mkdir -p $(BUILD)/{sim,drc,lvs,logs} $(NET_DIR) $(GDS_DIR) $(MAG_DIR)
	ln -sfn "$$SPICE_MODELS" $(SIM_DIR)/models
	echo "setup done (models -> $$SPICE_MODELS)"

# ---- Digital ---------------------------------------------------------------
rtl-sim:
	@mkdir -p $(BUILD)/sim && cd $(BUILD)/sim
	iverilog -g2012 -o tb.vvp $(PROJ)/digital/tb/*.v $(PROJ)/digital/rtl/*.v
	vvp -n tb.vvp

wave:
	@mkdir -p $(BUILD)/logs && cd $(BUILD)/sim && (gtkwave *.vcd > $(BUILD)/logs/gtkwave.log 2>&1 &)

synth floorplan place cts route: env
	$(ORFS_MAKE) $@

flow: env
	$(ORFS_MAKE)
	@echo "Final GDS: $(DIG_GDS)"

gui: env
	$(ORFS_MAKE) gui_final

orfs-%: env
	$(ORFS_MAKE) $*

digital-gds:
	@cp $(DIG_GDS) $(GDS_DIR)/$(DIG_NICK).gds && echo "-> $(GDS_DIR)/$(DIG_NICK).gds"

clean-digital:
	rm -rf $(ORFS_WORK)

# ---- Analog ----------------------------------------------------------------
xschem: env
	@cd $(XSCH_DIR)
	f=$(CELL).sch; [ -f $$f ] || f=
	(xschem --rcfile xschemrc $$f > $(BUILD)/logs/xschem.log 2>&1 &)

netlist: env
	@cd $(XSCH_DIR)
	xschem --rcfile xschemrc --tcl 'set lvs_netlist 1; set top_subckt 1' \
	  -n -s -q -x -o $(NET_DIR) $(CELL).sch
	echo "-> $(NET_DIR)/$(CELL).spice"

sim: env
	@cd $(SIM_DIR)
	sed 's/\(\.lib .*sm141064\.ngspice\) *[a-z]*/\1 $(CORNER)/' $(TB).spice > $(BUILD)/sim/$(TB).$(CORNER).spice
	ngspice -b $(BUILD)/sim/$(TB).$(CORNER).spice 2>&1 | tee $(BUILD)/sim/$(TB).$(CORNER).log | grep -iE "error|warning|^ *[a-z_0-9]+ *= " || true
	echo "log: $(BUILD)/sim/$(TB).$(CORNER).log"

sim-i: env
	@cd $(SIM_DIR) && ngspice $(TB).spice

magic: env
	@cd $(MAG_DIR)
	(magic -d $(MAGIC_DISPLAY) -rcfile $(MAGICRC) $(CELL) > $(BUILD)/logs/magic.log 2>&1 &)

klayout: env
	@g=$(GDS); [ -n "$$g" ] || g=$$(ls $(GDS_DIR)/*.gds 2>/dev/null | head -1)
	(klayout -e $${KLAYOUT_LYT:+-nn $$KLAYOUT_LYT} $$g > $(BUILD)/logs/klayout.log 2>&1 &)

drc: env
	@cd $(MAG_DIR)
	CELL=$(CELL) REPORT=$(BUILD)/drc/$(CELL).drc.txt $(MAGIC_B) $(PROJ)/scripts/magic_drc.tcl | grep DRC_RESULT
	echo "report: $(BUILD)/drc/$(CELL).drc.txt"

extract: env
	@cd $(MAG_DIR)
	CELL=$(CELL) OUT=$(NET_DIR)/$(CELL).lay.spice $(MAGIC_B) $(PROJ)/scripts/magic_extract.tcl > $(BUILD)/logs/extract.log
	echo "-> $(NET_DIR)/$(CELL).lay.spice"

lvs: extract netlist
	@cd $(BUILD)/lvs
	netgen -batch lvs "$(NET_DIR)/$(CELL).lay.spice $(CELL)" "$(NET_DIR)/$(CELL).spice $(CELL)" \
	  $(NETGEN_SETUP) $(CELL).lvs.out > $(CELL).lvs.log
	grep -E "Circuits match uniquely|Netlists do not match|Final result" $(CELL).lvs.out || true
	echo "report: $(BUILD)/lvs/$(CELL).lvs.out"

gds: env
	@cd $(MAG_DIR)
	CELL=$(CELL) OUT=$(GDS_DIR)/$(CELL).gds $(MAGIC_B) $(PROJ)/scripts/magic_gds.tcl > $(BUILD)/logs/gds.log
	echo "-> $(GDS_DIR)/$(CELL).gds"

# ---- Tiny Tapeout ----------------------------------------------------------
tt-guard: env
	@[ -f $(PROJ)/info.yaml ] || { echo "No info.yaml: run this inside your Tiny Tapeout repo (see TAPEOUT.md)"; exit 1; }
	case "$(TOP)" in tt_um_example|"") echo "Set project.top_module in info.yaml (tt_um_<github user>_<name>)"; exit 1;; tt_um_*) ;; \
	  *) echo "top_module must start with tt_um_"; exit 1;; esac
	[ -f "$(TT_DEF)" ] || { echo "Template $(TT_DEF) not found. Check tiles in info.yaml, or run: ./install_eda.sh tt"; exit 1; }
	echo "TT: top=$(TOP) tiles=$(TILES) vapwr=$(or $(VAPWR),false)"

tt-init: tt-guard
	@mkdir -p $(MAG_DIR) && cd $(MAG_DIR)
	[ ! -e $(TOP).mag ] || { echo "$(MAG_DIR)/$(TOP).mag already exists; delete it to start over"; exit 1; }
	DEF=$(TT_DEF) TOP=$(TOP) $(MAGIC_B) $(PROJ)/scripts/tt_init.tcl | grep TT_INIT
	echo "-> $(MAG_DIR)/$(TOP).mag   next: make magic CELL=$(TOP)"

tt-export: tt-guard
	@mkdir -p $(PROJ)/gds $(PROJ)/lef && cd $(MAG_DIR)
	TOP=$(TOP) GDS_OUT=$(PROJ)/gds/$(TOP).gds LEF_OUT=$(PROJ)/lef/$(TOP).lef \
	  $(MAGIC_B) $(PROJ)/scripts/tt_export.tcl > $(BUILD)/logs/tt_export.log 2>&1
	grep -iE "error" $(BUILD)/logs/tt_export.log || true
	ls -l $(PROJ)/gds/$(TOP).gds $(PROJ)/lef/$(TOP).lef

precheck: tt-guard
	@[ -x $(TT_VENV)/bin/python ] || { echo "Precheck not installed. Run: ~/eda-setup/install_eda.sh tt"; exit 1; }
	[ -f $(PROJ)/gds/$(TOP).gds ] || { echo "No gds/$(TOP).gds. Run: make tt-export"; exit 1; }
	rm -rf $(TT_SUB) && mkdir -p $(TT_SUB)
	cp $(PROJ)/gds/$(TOP).gds $(PROJ)/lef/$(TOP).lef $(TT_SUB)/
	cp $(PROJ)/src/project.v $(TT_SUB)/$(TOP).v
	cd $(TT_TOOLS)/precheck
	$(TT_VENV)/bin/python precheck.py --gds $(TT_SUB)/$(TOP).gds --tech gf180mcuD 2>&1 | tee $(BUILD)/logs/precheck.log
	echo "reports: $(TT_TOOLS)/precheck/reports/"

tt-view: env
	@(klayout -e $${KLAYOUT_LYT:+-nn $$KLAYOUT_LYT} $(PROJ)/gds/$(TOP).gds > $(BUILD)/logs/klayout.log 2>&1 &)

clean:
	rm -rf $(BUILD)
	rm -f $(SIM_DIR)/*.raw $(SIM_DIR)/*.txt $(MAG_DIR)/*.ext
