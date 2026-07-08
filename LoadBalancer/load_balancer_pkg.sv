// UVM package for the load_balancer verification environment.
//
// Holds the shared parameters (kept in lockstep with load_balancer.sv defaults),
// the runtime policy enum, and the include list for the UVM class hierarchy.
// The golden reference model (lb_ref.svh) is included first so every component
// can call it.
package load_balancer_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // must match load_balancer.sv parameter defaults
    parameter int N            = 4;
    parameter int ID_WIDTH     = 8;
    parameter int WEIGHT_WIDTH = 4;
    parameter int OCC_WIDTH    = 4;
    parameter int SEL_WIDTH    = 2;      // $clog2(N)
    parameter int MAX_OUTSTANDING = 12;  // occupancy clamp (matches DUT localparam)

    parameter int CYCLE_TIME = 10;       // ns clock period
    parameter int TX_COUNT   = 4000;     // cycles per random test

    // runtime policy select (2-bit, matches DUT localparam encoding)
    typedef enum bit [1:0] {
        POLICY_RR  = 2'b00,
        POLICY_WRR = 2'b01,
        POLICY_LL  = 2'b10
    } policy_e;

    `include "lb_ref.svh"
    `include "transaction.sv"
    `include "sequence.sv"
    `include "sequencer.sv"
    `include "driver.sv"
    `include "monitor.sv"
    `include "agent.sv"
    `include "scoreboard.sv"
    `include "coverage.sv"
    `include "environment.sv"
    `include "test.sv"

endpackage : load_balancer_pkg
