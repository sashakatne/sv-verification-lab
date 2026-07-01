import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_driver extends uvm_driver #(systolic_array_transaction);
    `uvm_component_utils(systolic_array_driver)

    virtual systolic_array_bfm bfm;
    systolic_array_transaction tx;

    function new(string name = "systolic_array_driver", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual systolic_array_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
    endfunction : build_phase

    function logic [N*N*DATA_WIDTH-1:0] pack_inputs(input logic signed [DATA_WIDTH-1:0] matrix [N][N]);
        logic [N*N*DATA_WIDTH-1:0] packed_bits;
        packed_bits = '0;
        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                packed_bits[((row * N + col) * DATA_WIDTH) +: DATA_WIDTH] = matrix[row][col];
        return packed_bits;
    endfunction : pack_inputs

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        bfm.reset_systolic_array();

        forever begin
            seq_item_port.get_next_item(tx);

            repeat (IDLE_CYCLES) @(negedge bfm.clk);
            bfm.a_matrix <= pack_inputs(tx.a);
            bfm.b_matrix <= pack_inputs(tx.b);
            bfm.clear    <= tx.clear;
            bfm.start    <= tx.start;

            @(posedge bfm.clk);
            @(negedge bfm.clk);
            bfm.start <= 1'b0;
            bfm.clear <= 1'b0;

            if (tx.start)
                wait (bfm.done == 1'b1);

            `uvm_info(get_type_name(), $sformatf("Driver tx | %s", tx.convert2string()), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : systolic_array_driver
