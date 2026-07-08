import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Single UVM test running all five sequences in turn: one per policy, a mixed
// policy stream, and a backpressure stress. After each sequence it drains the
// scoreboard and prints a machine-parseable
//   TEST <name>: cycles=<n> mismatched=<m>
// line (consumed by formal/check_evidence.sh), then emits the repo-standard
// verdict on report_phase (stdout + load_balancer_verdict.txt, needed because
// run.do sets NoQuitOnFinish).
class load_balancer_test extends uvm_test;
    `uvm_component_utils(load_balancer_test)

    lb_environment env_h;

    function new(string name = "load_balancer_test", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_h = lb_environment::type_id::create("env_h", this);
    endfunction : build_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    // run one sequence, let the scoreboard drain, print its TEST line
    task run_named(uvm_sequence #(lb_transaction) seq, string test_name);
        longint unsigned before_checks;
        longint unsigned after_checks;
        longint unsigned mm;
        env_h.scoreboard_h.clear_mismatches();
        before_checks = env_h.scoreboard_h.checks;
        seq.start(env_h.agent_h.sequencer_h);
        // let the last driven cycles propagate through monitor + scoreboard
        repeat (8) @(negedge env_h.agent_h.monitor_h.bfm.clk);
        after_checks = env_h.scoreboard_h.checks;
        mm = env_h.scoreboard_h.snapshot_mismatches();
        $display("TEST %s: cycles=%0d mismatched=%0d", test_name,
                 (after_checks - before_checks), mm);
    endtask : run_named

    task run_phase(uvm_phase phase);
        lb_rr_sequence            rr_seq;
        lb_wrr_sequence           wrr_seq;
        lb_ll_sequence            ll_seq;
        lb_mixed_random_sequence  mixed_seq;
        lb_backpressure_sequence  bp_seq;

        super.run_phase(phase);
        phase.raise_objection(this);

        rr_seq    = lb_rr_sequence::type_id::create("rr_seq");
        wrr_seq   = lb_wrr_sequence::type_id::create("wrr_seq");
        ll_seq    = lb_ll_sequence::type_id::create("ll_seq");
        mixed_seq = lb_mixed_random_sequence::type_id::create("mixed_seq");
        bp_seq    = lb_backpressure_sequence::type_id::create("bp_seq");

        run_named(rr_seq,    "lb_rr_test");
        run_named(wrr_seq,   "lb_wrr_test");
        run_named(ll_seq,    "lb_ll_test");
        run_named(mixed_seq, "lb_mixed_random_test");
        run_named(bp_seq,    "lb_backpressure_test");

        phase.drop_objection(this);
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int err_count;
        int verdict_fd;
        string verdict;
        super.report_phase(phase);
        svr = uvm_report_server::get_server();
        err_count = svr.get_severity_count(UVM_ERROR)
                  + svr.get_severity_count(UVM_FATAL);
        if (err_count == 0)
            verdict = "No errors -- passed testbench";
        else
            verdict = "Failed testbench";

        $display("%s", verdict);
        verdict_fd = $fopen("load_balancer_verdict.txt", "w");
        if (verdict_fd != 0) begin
            $fdisplay(verdict_fd, "%s", verdict);
            $fclose(verdict_fd);
        end
    endfunction : report_phase

endclass : load_balancer_test
