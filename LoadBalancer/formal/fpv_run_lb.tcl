# VC Formal FPV: prove the load_balancer SVA properties on the clean DUT.
# Sequential DUV with a real clock and active-low reset (no virtual clock, unlike
# a combinational core). Expected: all assertions proven non-vacuous, all covers
# reached, 0 falsified.
set_fml_appmode FPV
set design load_balancer

read_file -top $design -format sverilog -sva -vcs {-f filelist.f}

create_clock clk -period 100
create_reset rst_n -low
sim_run -stable
sim_save_reset

check_fv -block
report_fv -list

puts "FPV_RUN_LB_DONE"
quit -f
