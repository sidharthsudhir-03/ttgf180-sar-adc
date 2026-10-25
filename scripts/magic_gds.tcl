# magic_gds.tcl: write layout to GDS. Env: CELL, OUT
load $::env(CELL)
select top cell
gds write $::env(OUT)
quit -noprompt
