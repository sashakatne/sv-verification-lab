package mac_pe_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter DATA_WIDTH = 16;
    parameter RESULT_WIDTH = 32;
    parameter CYCLE_TIME = 10;
    parameter TX_COUNT = 10000;
    parameter IDLE_CYCLES = 1;
    parameter INT8_SAT_REPS = 134000;

    typedef enum bit {MODE_INT8 = 1'b0, MODE_BF16 = 1'b1} mac_mode_t;

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

endpackage : mac_pe_pkg
