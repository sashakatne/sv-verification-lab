import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// One clock cycle of load_balancer activity: the stimulus the driver applies
// plus the response the monitor captures. The scoreboard runs a shadow model
// over the stimulus fields and checks the response fields.
class lb_transaction extends uvm_sequence_item;
    `uvm_object_utils(lb_transaction)

    function new(string name = "lb_transaction");
        super.new(name);
    endfunction : new

    // stimulus (driven)
    rand policy_e            policy;
    rand bit [N-1:0]         be_ready;
    rand bit [N-1:0]         be_done;
    rand bit                 req_valid;
    rand bit [ID_WIDTH-1:0]  req_id;
    rand bit [WEIGHT_WIDTH-1:0] weight [N];

    // response (captured)
    bit [N-1:0]              be_valid;
    bit                      req_ready;
    bit [OCC_WIDTH-1:0]      occ [N];

    // Keep at least one backend ready most of the time so the request channel
    // makes progress; the backpressure test overrides this to stress stalls.
    constraint c_ready_dist {
        be_ready dist { '0 :/ 1, [1:(2**N)-1] :/ 9 };
    }

    // Weights span 0 (never-grant) through the max; 0 must be reachable so the
    // weight-0 exclusion property gets exercised.
    constraint c_weight {
        foreach (weight[i]) weight[i] inside {[0:(2**WEIGHT_WIDTH)-1]};
    }

    // pack the per-backend weight array into the DUT's flattened bus
    function bit [N*WEIGHT_WIDTH-1:0] weight_packed();
        bit [N*WEIGHT_WIDTH-1:0] p;
        foreach (weight[i]) p[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = weight[i];
        return p;
    endfunction : weight_packed

    function string convert2string();
        return $sformatf("policy=%s be_ready=%b be_done=%b req_valid=%b req_id=%h | be_valid=%b req_ready=%b",
                         policy.name(), be_ready, be_done, req_valid, req_id, be_valid, req_ready);
    endfunction : convert2string

endclass : lb_transaction
