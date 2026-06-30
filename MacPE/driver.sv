import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_driver extends uvm_driver #(mac_pe_transaction);
    `uvm_component_utils(mac_pe_driver)

    virtual mac_pe_bfm bfm;
    mac_pe_transaction tx;

    function new(string name = "mac_pe_driver", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mac_pe_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        bfm.reset_mac_pe();

        forever begin
            seq_item_port.get_next_item(tx);

            repeat (IDLE_CYCLES) @(negedge bfm.clk);
            bfm.mode     <= tx.mode;
            bfm.a        <= tx.a;
            bfm.b        <= tx.b;
            bfm.valid_in <= tx.valid_in;
            bfm.clear    <= tx.clear;

            assert (!$isunknown(tx.mode)) else `uvm_error(get_type_name(), "mode has unknowns")
            assert (!$isunknown(tx.a)) else `uvm_error(get_type_name(), "a has unknowns")
            assert (!$isunknown(tx.b)) else `uvm_error(get_type_name(), "b has unknowns")
            assert (!$isunknown(tx.valid_in)) else `uvm_error(get_type_name(), "valid_in has unknowns")
            assert (!$isunknown(tx.clear)) else `uvm_error(get_type_name(), "clear has unknowns")

            @(posedge bfm.clk);
            if (tx.clear || tx.valid_in)
                wait (bfm.valid_out == 1'b1);

            @(negedge bfm.clk);
            bfm.valid_in <= 1'b0;
            bfm.clear    <= 1'b0;

            `uvm_info(get_type_name(), $sformatf("Driver tx | %s", tx.convert2string()), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : mac_pe_driver
