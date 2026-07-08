import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Stimulus sequences. Each produces one lb_transaction per clock cycle. The
// five sequences map to the five "tests" in the plan: one per policy, a mixed
// policy stream, and a backpressure-stall stress. All run inside the single
// load_balancer_test (mirrors MacPE running several sequences per run).

class lb_base_sequence extends uvm_sequence #(lb_transaction);
    `uvm_object_utils(lb_base_sequence)

    int n_cycles = TX_COUNT;

    function new(string name = "lb_base_sequence");
        super.new(name);
    endfunction : new

    // one constrained-random cycle pinned to a policy
    task send_policy(policy_e pol);
        lb_transaction tx;
        tx = lb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize() with { policy == pol; })
            `uvm_fatal("LB_SEQ", "randomize failed")
        finish_item(tx);
    endtask : send_policy

    // one cycle with all backends stalled and a live request (backpressure)
    task send_stalled(policy_e pol);
        lb_transaction tx;
        tx = lb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize() with { policy == pol; be_ready == '0; req_valid == 1'b1; })
            `uvm_fatal("LB_SEQ", "randomize failed")
        finish_item(tx);
    endtask : send_stalled

    // one cycle that keeps a single backend the only eligible target and never
    // completes it, so its occupancy climbs. Used to drive a backend to
    // saturation (occ == MAX_OUTSTANDING) - a corner random traffic won't reach.
    task send_pileup(int target);
        lb_transaction tx;
        tx = lb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize() with {
                policy   == POLICY_LL;
                be_ready == (1 << target);   // only the target is ready
                be_done  == '0;              // never drain it
                req_valid == 1'b1;
            })
            `uvm_fatal("LB_SEQ", "randomize failed")
        finish_item(tx);
    endtask : send_pileup

endclass : lb_base_sequence

class lb_rr_sequence extends lb_base_sequence;
    `uvm_object_utils(lb_rr_sequence)
    function new(string name = "lb_rr_sequence"); super.new(name); endfunction
    task body();
        `uvm_info("LB_RR_SEQ", "Starting round-robin sequence", UVM_MEDIUM)
        for (int i = 0; i < n_cycles; i++) send_policy(POLICY_RR);
    endtask : body
endclass : lb_rr_sequence

class lb_wrr_sequence extends lb_base_sequence;
    `uvm_object_utils(lb_wrr_sequence)
    function new(string name = "lb_wrr_sequence"); super.new(name); endfunction
    task body();
        `uvm_info("LB_WRR_SEQ", "Starting weighted round-robin sequence", UVM_MEDIUM)
        for (int i = 0; i < n_cycles; i++) send_policy(POLICY_WRR);
    endtask : body
endclass : lb_wrr_sequence

class lb_ll_sequence extends lb_base_sequence;
    `uvm_object_utils(lb_ll_sequence)
    function new(string name = "lb_ll_sequence"); super.new(name); endfunction
    task body();
        `uvm_info("LB_LL_SEQ", "Starting least-loaded sequence", UVM_MEDIUM)
        for (int i = 0; i < n_cycles; i++) send_policy(POLICY_LL);
    endtask : body
endclass : lb_ll_sequence

class lb_mixed_random_sequence extends lb_base_sequence;
    `uvm_object_utils(lb_mixed_random_sequence)
    function new(string name = "lb_mixed_random_sequence"); super.new(name); endfunction
    task body();
        policy_e pol;
        `uvm_info("LB_MIXED_SEQ", "Starting mixed-policy random sequence", UVM_MEDIUM)
        for (int i = 0; i < n_cycles; i++) begin
            // switch policy in bursts so the carried state (credits, rr_ptr) is
            // exercised across policy changes
            if ((i % 32) == 0)
                pol = policy_e'($urandom_range(0, 2));
            send_policy(pol);
        end
    endtask : body
endclass : lb_mixed_random_sequence

class lb_backpressure_sequence extends lb_base_sequence;
    `uvm_object_utils(lb_backpressure_sequence)
    function new(string name = "lb_backpressure_sequence"); super.new(name); endfunction
    task body();
        `uvm_info("LB_BP_SEQ", "Starting backpressure-stress sequence", UVM_MEDIUM)
        // First drive backend 0 to saturation (occ == MAX_OUTSTANDING): grant it
        // every cycle and never complete it. Closes the occ_cp.saturated bin,
        // which random traffic (with random be_done draining) does not reach.
        repeat (MAX_OUTSTANDING + 4) send_pileup(0);
        for (int i = 0; i < n_cycles; i++) begin
            // alternate stretches of full stall against normal traffic so the
            // request channel sees sustained req_ready=0 then recovers
            if ((i % 8) < 5) send_stalled(POLICY_RR);
            else             send_policy(POLICY_RR);
        end
    endtask : body
endclass : lb_backpressure_sequence
