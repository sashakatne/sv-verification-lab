import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_monitor extends uvm_monitor;
    `uvm_component_utils(systolic_array_monitor)

    virtual systolic_array_bfm bfm;
    systolic_array_transaction mon_tx;
    uvm_analysis_port #(systolic_array_transaction) monitor_port;

    function new(string name = "systolic_array_monitor", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual systolic_array_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
        monitor_port = new("monitor_port", this);
    endfunction : build_phase

    function void unpack_inputs(input logic [N*N*DATA_WIDTH-1:0] packed_bits,
                                ref logic signed [DATA_WIDTH-1:0] matrix [N][N]);
        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                matrix[row][col] = packed_bits[((row * N + col) * DATA_WIDTH) +: DATA_WIDTH];
    endfunction : unpack_inputs

    function void unpack_outputs(input logic [N*N*ACC_WIDTH-1:0] packed_bits,
                                 ref logic signed [ACC_WIDTH-1:0] matrix [N][N]);
        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                matrix[row][col] = packed_bits[((row * N + col) * ACC_WIDTH) +: ACC_WIDTH];
    endfunction : unpack_outputs

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            @(posedge bfm.done);
            mon_tx = systolic_array_transaction::type_id::create("mon_tx");
            mon_tx.start = bfm.start;
            mon_tx.clear = bfm.clear;
            mon_tx.done = bfm.done;
            mon_tx.busy = bfm.busy;
            mon_tx.latency = bfm.cycle_count;
            mon_tx.pe_active = bfm.pe_active;
            unpack_inputs(bfm.a_matrix, mon_tx.a);
            unpack_inputs(bfm.b_matrix, mon_tx.b);
            unpack_outputs(bfm.c_matrix, mon_tx.c);

            assert (!$isunknown(mon_tx.latency)) else `uvm_error(get_type_name(), "latency has unknowns")
            assert (!$isunknown(mon_tx.pe_active)) else `uvm_error(get_type_name(), "pe_active has unknowns")

            `uvm_info(get_type_name(), $sformatf("Monitor tx | %s", mon_tx.convert2string()), UVM_HIGH)
            monitor_port.write(mon_tx);
        end
    endtask : run_phase

endclass : systolic_array_monitor
