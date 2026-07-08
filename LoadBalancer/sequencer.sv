import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Standard sequencer for lb_transaction.
class lb_sequencer extends uvm_sequencer #(lb_transaction);
    `uvm_component_utils(lb_sequencer)

    function new(string name = "lb_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction : new

endclass : lb_sequencer
