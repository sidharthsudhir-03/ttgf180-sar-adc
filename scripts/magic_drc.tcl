# magic_drc.tcl: batch DRC. Env: CELL, REPORT. Run via: make drc CELL=<cell>
set cell   $::env(CELL)
set report $::env(REPORT)

load $cell
select top cell
drc euclidean on
catch {drc style drc(full)}
drc check
drc catchup

set total 0
set f [open $report w]
foreach {rule boxes} [drc listall why] {
    puts $f "$rule ([llength $boxes])"
    foreach b $boxes { puts $f "    $b" }
    incr total [llength $boxes]
}
close $f
puts "DRC_RESULT $cell $total"
quit -noprompt
