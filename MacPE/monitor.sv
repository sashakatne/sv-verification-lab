import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_monitor extends uvm_monitor;
    `uvm_component_utils(mac_pe_monitor)

    virtual mac_pe_bfm bfm;
    mac_pe_transaction mon_tx;
    uvm_analysis_port #(mac_pe_transaction) monitor_port;

    function new(string name = "mac_pe_monitor", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_DEBUG)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mac_pe_bfm)::get(this, "", "bfm", bfm))
            `uvm_fatal("NOBFM", {"bfm not defined for ", get_full_name(), "."})
        monitor_port = new("monitor_port", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            @(posedge bfm.valid_out);
            mon_tx = mac_pe_transaction::type_id::create("mon_tx");
            mon_tx.mode      = mac_mode_t'(bfm.mode);
            mon_tx.a         = bfm.a;
            mon_tx.b         = bfm.b;
            mon_tx.valid_in  = bfm.valid_in;
            mon_tx.clear     = bfm.clear;
            mon_tx.valid_out = bfm.valid_out;
            mon_tx.acc       = bfm.acc;
            mon_tx.sat_flag  = bfm.sat_flag;
            mon_tx.fp_flag   = bfm.fp_flag;

            assert (!$isunknown(mon_tx.acc)) else `uvm_error(get_type_name(), "acc has unknowns")
            assert (!$isunknown(mon_tx.sat_flag)) else `uvm_error(get_type_name(), "sat_flag has unknowns")
            assert (!$isunknown(mon_tx.fp_flag)) else `uvm_error(get_type_name(), "fp_flag has unknowns")

            `uvm_info(get_type_name(), $sformatf("Monitor tx | %s", mon_tx.convert2string()), UVM_HIGH)
            monitor_port.write(mon_tx);
        end
    endtask : run_phase

endclass : mac_pe_monitor
