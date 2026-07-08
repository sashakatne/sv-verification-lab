import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Active agent: sequencer + driver + monitor.
class lb_agent extends uvm_agent;
    `uvm_component_utils(lb_agent)

    lb_sequencer sequencer_h;
    lb_monitor   monitor_h;
    lb_driver    driver_h;

    function new(string name = "lb_agent", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer_h = lb_sequencer::type_id::create("sequencer_h", this);
        monitor_h   = lb_monitor::type_id::create("monitor_h", this);
        driver_h    = lb_driver::type_id::create("driver_h", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver_h.seq_item_port.connect(sequencer_h.seq_item_export);
    endfunction : connect_phase

endclass : lb_agent
