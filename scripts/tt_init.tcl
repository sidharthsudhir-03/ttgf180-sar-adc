# tt_init.tcl: create the Tiny Tapeout top cell from the official DEF pin template.
# Env: DEF (template path), TOP (tt_um_... name). Run via: make tt-init
# The magicrc's "scalegrid 1 10" is required so the die size (346.64 um, ...) stays exact.
def read $::env(DEF)
cellname rename tt_um_template $::env(TOP)
save $::env(TOP)
puts "TT_INIT $::env(TOP) FIXED_BBOX [property FIXED_BBOX]"
quit -noprompt
