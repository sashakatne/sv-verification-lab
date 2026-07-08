import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Functional coverage. Closure over this model is what makes the "100.00%"
// evidence meaningful: it proves the random sequences actually exercised every
// policy, every backend-ready pattern, both handshake states, and a spread of
// occupancy levels - not just that no error fired.
class lb_coverage extends uvm_subscriber #(lb_transaction);
    `uvm_component_utils(lb_coverage)

    lb_transaction tx;
    real cov_policy_ready;
    real cov_handshake;

    // occupancy bucket of the granted backend (0, low, mid, saturated)
    function int occ_bin(lb_transaction t);
        int idx;
        idx = -1;
        for (int i = 0; i < N; i++) if (t.be_valid[i]) idx = i;
        if (idx < 0)                                    return 0; // no dispatch
        if (t.occ[idx] == 0)                            return 1;
        if (t.occ[idx] >= OCC_WIDTH'(MAX_OUTSTANDING))  return 4;
        if (t.occ[idx] <= OCC_WIDTH'(MAX_OUTSTANDING/2)) return 2;
        return 3;
    endfunction : occ_bin

    // policy crossed with the backend-ready pattern and occupancy bucket
    covergroup policy_ready_cg;
        option.per_instance = 1;

        policy_cp : coverpoint tx.policy {
            bins rr  = {POLICY_RR};
            bins wrr = {POLICY_WRR};
            bins ll  = {POLICY_LL};
        }

        // all 16 ready masks for N=4, folded into meaningful groups
        ready_cp : coverpoint tx.be_ready {
            bins none      = {4'b0000};
            bins one_hot[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins some      = {[4'b0011:4'b1110]};
            bins all       = {4'b1111};
        }

        occ_cp : coverpoint occ_bin(tx) {
            bins no_dispatch = {0};
            bins fresh       = {1};
            bins low         = {2};
            bins high        = {3};
            bins saturated   = {4};
        }

        // every policy must be seen against every ready group
        policy_x_ready : cross policy_cp, ready_cp;
    endgroup

    // upstream/downstream handshake states
    covergroup handshake_cg;
        option.per_instance = 1;

        // {req_valid, req_ready}: accept, stall (valid but no ready backend), idle
        req_cp : coverpoint {tx.req_valid, tx.req_ready} {
            bins accept = {2'b11};
            bins stall  = {2'b10};
            bins idle   = {2'b00};
            ignore_bins impossible = {2'b01}; // ready without valid is not a dispatch
        }

        // any backend draining (be_done) vs full backpressure (no backend ready)
        drain_cp : coverpoint (|tx.be_done) {
            bins draining = {1};
            bins quiet    = {0};
        }
        bp_cp : coverpoint (tx.be_ready == '0) {
            bins backpressure = {1};
            bins open         = {0};
        }
    endgroup

    function new(string name = "lb_coverage", uvm_component parent = null);
        super.new(name, parent);
        tx = lb_transaction::type_id::create("tx");
        policy_ready_cg = new();
        handshake_cg    = new();
    endfunction : new

    virtual function void write(lb_transaction t);
        tx = t;
        policy_ready_cg.sample();
        handshake_cg.sample();
        cov_policy_ready = policy_ready_cg.get_coverage();
        cov_handshake    = handshake_cg.get_coverage();
    endfunction : write

endclass : lb_coverage
