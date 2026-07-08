import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Applies one transaction per clock cycle. Stimulus is driven with non-blocking
// assignment at posedge so it is stable for the whole cycle; the DUT's
// combinational grant settles within the cycle and its state registers at the
// next posedge.
class lb_driver extends uvm_driver #(lb_transaction);
    `uvm_component_utils(lb_driver)

    virtual load_balancer_bfm bfm;
    lb_transaction tx;

    function new(string name = "lb_driver", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual load_balancer_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        bfm.reset_lb();

        forever begin
            seq_item_port.get_next_item(tx);

            @(posedge bfm.clk);
            bfm.policy    <= tx.policy;
            bfm.weight    <= tx.weight_packed();
            bfm.be_ready  <= tx.be_ready;
            bfm.be_done   <= tx.be_done;
            bfm.req_valid <= tx.req_valid;
            bfm.req_id    <= tx.req_id;

            `uvm_info(get_type_name(), $sformatf("Driver tx | %s", tx.convert2string()), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : lb_driver
