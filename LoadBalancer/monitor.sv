import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Samples the DUT once per clock at negedge, when the driven inputs, the
// combinational response (be_valid/req_ready), and the registered occupancy
// (the state this cycle's decision was made against) are all stable. Emits one
// lb_transaction per active cycle to the scoreboard and coverage.
class lb_monitor extends uvm_monitor;
    `uvm_component_utils(lb_monitor)

    virtual load_balancer_bfm bfm;
    lb_transaction mon_tx;
    uvm_analysis_port #(lb_transaction) monitor_port;

    function new(string name = "lb_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual load_balancer_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
        monitor_port = new("monitor_port", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        @(posedge bfm.rst_n);   // start after reset deasserts

        forever begin
            @(negedge bfm.clk);
            if (!bfm.rst_n)
                continue;

            mon_tx = lb_transaction::type_id::create("mon_tx");
            mon_tx.policy    = policy_e'(bfm.policy);
            mon_tx.be_ready  = bfm.be_ready;
            mon_tx.be_done   = bfm.be_done;
            mon_tx.req_valid = bfm.req_valid;
            mon_tx.req_id    = bfm.req_id;
            foreach (mon_tx.weight[i])
                mon_tx.weight[i] = bfm.weight[i*WEIGHT_WIDTH +: WEIGHT_WIDTH];

            mon_tx.be_valid  = bfm.be_valid;
            mon_tx.req_ready = bfm.req_ready;
            foreach (mon_tx.occ[i])
                mon_tx.occ[i] = bfm.occ_flat[i*OCC_WIDTH +: OCC_WIDTH];

            assert (!$isunknown(mon_tx.be_valid)) else `uvm_error(get_type_name(), "be_valid has unknowns")
            assert (!$isunknown(mon_tx.req_ready)) else `uvm_error(get_type_name(), "req_ready has unknowns")

            `uvm_info(get_type_name(), $sformatf("Monitor tx | %s", mon_tx.convert2string()), UVM_HIGH)
            monitor_port.write(mon_tx);
        end
    endtask : run_phase

endclass : lb_monitor
