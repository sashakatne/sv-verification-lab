catch {vdel -all}

vlib work

vlog -source -lint mac_pe.sv
# vlog -source -lint +define+SAT_SKIP_BUG mac_pe.sv

vlog -source -lint mac_pe_pkg.sv

vlog -source -lint top.sv

vlog -source -lint test.sv
vlog -source -lint driver.sv
vlog -source -lint environment.sv
vlog -source -lint mac_pe_bfm.sv
vlog -source -lint agent.sv
vlog -source -lint scoreboard.sv
vlog -source -lint sequence.sv
vlog -source -lint sequencer.sv
vlog -source -lint coverage.sv
vlog -source -lint monitor.sv

vopt top -o top_optimized +acc +cover=sbfec+mac_pe(rtl).

vsim top_optimized -coverage

set NoQuitOnFinish 1
onbreak {resume}
log /* -r
vcd file mac_pe_waveforms.vcd
vcd add -r /top/*
run -all

coverage save mac_pe.ucdb
vcover report mac_pe.ucdb
vcover report mac_pe.ucdb -cvg -details

add wave -position insertpoint sim:/top/DUT/*

if {[file exists mac_pe_verdict.txt]} {
    set verdict_file [open mac_pe_verdict.txt r]
    puts [string trim [read $verdict_file]]
    close $verdict_file
}
