import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_agent extends uvm_agent;
    `uvm_component_utils(systolic_array_agent)

    systolic_array_sequencer sequencer_h;
    systolic_array_monitor monitor_h;
    systolic_array_driver driver_h;

    function new(string name = "systolic_array_agent", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer_h = systolic_array_sequencer::type_id::create("sequencer_h", this);
        monitor_h = systolic_array_monitor::type_id::create("monitor_h", this);
        driver_h = systolic_array_driver::type_id::create("driver_h", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver_h.seq_item_port.connect(sequencer_h.seq_item_export);
    endfunction : connect_phase

endclass : systolic_array_agent
