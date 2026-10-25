# tt_export.tcl: write the Tiny Tapeout deliverables (hierarchical GDS + pin-only LEF).
# Env: TOP, GDS_OUT, LEF_OUT. Run via: make tt-export
load $::env(TOP)
select top cell
lef write $::env(LEF_OUT) -pinonly
gds write $::env(GDS_OUT)
quit -noprompt
