catch {vdel -all}

vlib work

# Clean build. To produce the negative (bug-injected) transcript, comment the
# first DUT compile below and uncomment ONE of the +define+BUG_* lines, then
# re-run; the scoreboard/assertions will trip and the verdict flips to FAIL.
vlog -source -lint load_balancer.sv
# vlog -source -lint +define+BUG_DOUBLE_GRANT   load_balancer.sv
# vlog -source -lint +define+BUG_GRANT_NOTREADY load_balancer.sv
# vlog -source -lint +define+BUG_OCC_OVERFLOW   load_balancer.sv
# vlog -source -lint +define+BUG_WRR_ZERO       load_balancer.sv
# vlog -source -lint +define+BUG_LL_NOTMIN      load_balancer.sv
# vlog -source -lint +define+BUG_RR_STUCK       load_balancer.sv

# Package (includes the UVM class files) must compile before the standalone
# class compiles below, which import it for per-file linting.
vlog -source -lint load_balancer_pkg.sv

# .sva is not auto-detected as SystemVerilog by vlog; force the dialect with -sv
vlog -source -lint -sv load_balancer_sva.sva
vlog -source -lint load_balancer_bfm.sv
vlog -source -lint top.sv

vlog -source -lint transaction.sv
vlog -source -lint sequence.sv
vlog -source -lint sequencer.sv
vlog -source -lint driver.sv
vlog -source -lint monitor.sv
vlog -source -lint agent.sv
vlog -source -lint scoreboard.sv
vlog -source -lint coverage.sv
vlog -source -lint environment.sv
vlog -source -lint test.sv

vopt top -o top_optimized +acc +cover=sbfec+load_balancer(rtl).

vsim top_optimized -coverage

set NoQuitOnFinish 1
onbreak {resume}
log /* -r
vcd file load_balancer_waveforms.vcd
vcd add -r /top/*
run -all

coverage save load_balancer.ucdb
vcover report load_balancer.ucdb
vcover report load_balancer.ucdb -cvg -details

add wave -position insertpoint sim:/top/DUT/*

if {[file exists load_balancer_verdict.txt]} {
    set verdict_file [open load_balancer_verdict.txt r]
    puts [string trim [read $verdict_file]]
    close $verdict_file
}
