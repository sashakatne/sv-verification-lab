import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Environment: one active agent, the shadow scoreboard, the coverage subscriber.
// The monitor feeds both the scoreboard and coverage.
class lb_environment extends uvm_env;
    `uvm_component_utils(lb_environment)

    lb_agent      agent_h;
    lb_scoreboard scoreboard_h;
    lb_coverage   coverage_h;

    function new(string name = "lb_environment", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent_h      = lb_agent::type_id::create("agent_h", this);
        scoreboard_h = lb_scoreboard::type_id::create("scoreboard_h", this);
        coverage_h   = lb_coverage::type_id::create("coverage_h", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent_h.monitor_h.monitor_port.connect(scoreboard_h.scoreboard_port);
        agent_h.monitor_h.monitor_port.connect(coverage_h.analysis_export);
    endfunction : connect_phase

endclass : lb_environment
