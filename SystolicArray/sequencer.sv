import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_sequencer extends uvm_sequencer #(systolic_array_transaction);
    `uvm_component_utils(systolic_array_sequencer)

    function new(string name = "systolic_array_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction : new

endclass : systolic_array_sequencer
