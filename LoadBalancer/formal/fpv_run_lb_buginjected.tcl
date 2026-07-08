# VC Formal FPV: bug-injected proof. Reads the DUT with one BUG_* define active
# (passed via the LB_BUG env var, default BUG_RR_STUCK) and expects the mapped
# property to be FALSIFIED - proving the assertion actually catches the fault.
# capture_evidence.sh sweeps every bug by setting LB_BUG per invocation.
set_fml_appmode FPV
set design load_balancer

set bug $::env(LB_BUG)
puts "LB_BUG_INJECTED: $bug"

read_file -top $design -format sverilog -sva -vcs "+define+$bug -f filelist.f"

create_clock clk -period 100
create_reset rst_n -low
sim_run -stable
sim_save_reset

check_fv -block
report_fv -list

puts "FPV_RUN_LB_BUG_DONE"
quit -f
