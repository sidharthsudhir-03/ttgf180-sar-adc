# GF180 Mixed-Signal Project

Template for SAR ADC style designs on GF180MCU (`gf180mcuD`: 5 metals, thick top metal, MIM cap).
Analog blocks: Xschem, ngspice, Magic, Netgen, KLayout. Digital logic: OpenROAD-flow-scripts.

## Every session

```bash
# Open Ubuntu (Windows Terminal), environment loads from ~/.bashrc
cd ~/projects/<project>
make check          # all tools and PDK files found?
make help           # list of targets
code .              # optional: VS Code via the WSL extension
```

Work only under `~` (Linux filesystem). From Windows Explorer the project is at
`\\wsl.localhost\Ubuntu\home\<user>\projects\<project>`.

## Layout

```
digital/rtl/        SAR logic RTL (Verilog)
digital/tb/         iverilog testbenches
digital/config.mk   ORFS config (die size, density, platform options)
digital/constraint.sdc
analog/xschem/      schematics (.sch) and symbols (.sym); xschemrc loads the PDK
analog/sim/         ngspice testbenches; models/ links to the PDK models
analog/mag/         Magic layouts (.mag)
analog/netlist/     generated netlists (schematic and extracted)
analog/gds/         GDS exports, including the hardened digital block
scripts/            Magic batch scripts used by the Makefile
build/              all generated output (safe to delete)
```

## Opening the tools

| Tool | Make target | Direct command |
|---|---|---|
| Xschem | `make xschem CELL=comparator` | `cd analog/xschem && xschem --rcfile xschemrc` |
| ngspice | `make sim TB=tb_inv CORNER=ss` | `cd analog/sim && ngspice tb_inv.spice` |
| Magic | `make magic CELL=comparator` | `cd analog/mag && magic -d XR -rcfile $MAGICRC` |
| KLayout | `make klayout GDS=analog/gds/x.gds` | `klayout -e -nn $KLAYOUT_LYT file.gds` |
| OpenROAD GUI | `make gui` (after `make flow`) | `make orfs-gui_place` for an intermediate stage |
| GTKWave | `make wave` (after `make rtl-sim`) | `gtkwave build/sim/*.vcd` |

GUIs open in their own windows (WSLg). Startup logs go to `build/logs/`.

## Analog cell flow (per block, e.g. comparator, CDAC unit, bootstrapped switch)

1. **Schematic**: `make xschem CELL=comparator`. Insert PDK devices with `Ins`
   (`nfet_03v3`, `pfet_03v3`, `cap_mim_*` for the CDAC, ...). Save as `analog/xschem/comparator.sch`.
2. **Simulate**: draw a testbench schematic and simulate from Xschem, or write
   `analog/sim/tb_comparator.spice` (copy `tb_inv.spice`) and run `make sim TB=tb_comparator`.
   Sweep corners with `CORNER=typical|ff|ss|fs|sf`.
3. **Layout**: `make magic CELL=comparator`. Generate devices from the PDK menu, draw, save.
4. **DRC**: `make drc CELL=comparator` (count printed, details in `build/drc/`).
5. **LVS**: `make lvs CELL=comparator`. Look for `Circuits match uniquely`.
   Pin names in the layout must match the schematic.
6. **GDS**: `make gds CELL=comparator`.

## Digital flow (SAR logic)

```bash
make rtl-sim        # behavioural check with an ideal comparator
make flow           # synth -> floorplan -> place -> cts -> route -> finish
make gui            # inspect the result
make digital-gds    # copy 6_final.gds to analog/gds/sar_logic.gds
```

Reports and logs: `build/orfs/{reports,logs}/gf180/sar_logic/base/`.
To re-run one stage: `make orfs-clean_place && make place`. Full reset: `make clean-digital`.

## Top-level integration

In Magic: `gds read ../gds/sar_logic.gds`, then place it as a subcell next to the
analog blocks and route. The digital block routes on Metal2-4 with Metal4 power straps
(no Metal5, as Tiny Tapeout requires), so plan analog routing around it.

## Tiny Tapeout

For submission, see `~/eda/TAPEOUT.md`. In a TT repo: `make tt-init`, `make tt-export`, `make precheck`.

## Starting a new project

```bash
new-project ~/projects/my_new_block
```
