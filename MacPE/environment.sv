import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_environment extends uvm_env;
    `uvm_component_utils(mac_pe_environment)

    mac_pe_agent agent_h;
    mac_pe_scoreboard scoreboard_h;
    mac_pe_coverage coverage_h;

    function new(string name = "mac_pe_environment", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent_h = mac_pe_agent::type_id::create("agent_h", this);
        scoreboard_h = mac_pe_scoreboard::type_id::create("scoreboard_h", this);
        coverage_h = mac_pe_coverage::type_id::create("coverage_h", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent_h.monitor_h.monitor_port.connect(scoreboard_h.scoreboard_port);
        agent_h.monitor_h.monitor_port.connect(coverage_h.analysis_export);
    endfunction : connect_phase

endclass : mac_pe_environment
