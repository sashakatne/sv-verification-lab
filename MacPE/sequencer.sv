import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_sequencer extends uvm_sequencer #(mac_pe_transaction);
    `uvm_component_utils(mac_pe_sequencer)

    function new(string name = "mac_pe_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction : new

endclass : mac_pe_sequencer
