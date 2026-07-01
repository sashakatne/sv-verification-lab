catch {vdel -all}

vlib work

vlog -source -lint systolic_array.sv
# vlog -source -lint +define+SKIP_PE_BUG systolic_array.sv

vlog -source -lint systolic_array_pkg.sv

vlog -source -lint top.sv

vlog -source -lint test.sv
vlog -source -lint driver.sv
vlog -source -lint environment.sv
vlog -source -lint systolic_array_bfm.sv
vlog -source -lint agent.sv
vlog -source -lint scoreboard.sv
vlog -source -lint sequence.sv
vlog -source -lint sequencer.sv
vlog -source -lint coverage.sv
vlog -source -lint monitor.sv

vopt top -o top_optimized +acc +cover=sbfec+systolic_array(rtl).

vsim top_optimized -coverage

set NoQuitOnFinish 1
onbreak {resume}
log /* -r
vcd file systolic_array_waveforms.vcd
vcd add -r /top/*
run -all

coverage save systolic_array.ucdb
vcover report systolic_array.ucdb
vcover report systolic_array.ucdb -cvg -details

add wave -position insertpoint sim:/top/DUT/*

if {[file exists systolic_array_verdict.txt]} {
    set verdict_file [open systolic_array_verdict.txt r]
    puts [string trim [read $verdict_file]]
    close $verdict_file
}
