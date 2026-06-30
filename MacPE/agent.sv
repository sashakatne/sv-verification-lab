import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_agent extends uvm_agent;
    `uvm_component_utils(mac_pe_agent)

    mac_pe_sequencer sequencer_h;
    mac_pe_monitor monitor_h;
    mac_pe_driver driver_h;

    function new(string name = "mac_pe_agent", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer_h = mac_pe_sequencer::type_id::create("sequencer_h", this);
        monitor_h = mac_pe_monitor::type_id::create("monitor_h", this);
        driver_h = mac_pe_driver::type_id::create("driver_h", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver_h.seq_item_port.connect(sequencer_h.seq_item_export);
    endfunction : connect_phase

endclass : mac_pe_agent
