package systolic_array_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int N = 4;
    parameter int DATA_WIDTH = 8;
    parameter int ACC_WIDTH = 32;
    parameter real CYCLE_TIME = 10.0;
    parameter int TX_COUNT = 300;
    parameter int IDLE_CYCLES = 1;
    parameter int EXPECTED_LATENCY = (3 * N) - 3;

    typedef enum int {
        CASE_ZERO,
        CASE_IDENTITY,
        CASE_SIGNED_CORNERS,
        CASE_ALTERNATING,
        CASE_RANDOM
    } matrix_case_t;

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

endpackage : systolic_array_pkg
