# magic_extract.tcl: layout -> SPICE netlist for LVS. Env: CELL, OUT
set cell $::env(CELL)

load $cell
select top cell
extract do local
extract all
ext2spice lvs
ext2spice -o $::env(OUT)
quit -noprompt
