// Compile list for the VC Formal FPV run: the synthesizable DUT, the SVA
// checker, and the bind file that attaches the checker to the DUT. Paths are
// relative to this formal/ directory. The DUT is read with whatever BUG_*
// define the tcl passes on the command line (clean run passes none).
../load_balancer.sv
../load_balancer_sva.sva
bind_load_balancer_sva.sva
