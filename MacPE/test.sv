import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_test extends uvm_test;
    `uvm_component_utils(mac_pe_test)

    mac_pe_environment environment_h;
    mac_pe_directed_int8_sequence int8_sequence_h;
    mac_pe_directed_bf16_sequence bf16_sequence_h;
    mac_pe_random_sequence random_sequence_h;

    function new(string name = "mac_pe_test", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_HIGH)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        environment_h = mac_pe_environment::type_id::create("environment_h", this);
    endfunction : build_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);

        int8_sequence_h = mac_pe_directed_int8_sequence::type_id::create("int8_sequence_h");
        bf16_sequence_h = mac_pe_directed_bf16_sequence::type_id::create("bf16_sequence_h");
        random_sequence_h = mac_pe_random_sequence::type_id::create("random_sequence_h");

        int8_sequence_h.start(environment_h.agent_h.sequencer_h);
        bf16_sequence_h.start(environment_h.agent_h.sequencer_h);
        random_sequence_h.start(environment_h.agent_h.sequencer_h);

        phase.drop_objection(this);
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int err_count;
        int verdict_fd;
        string verdict;
        super.report_phase(phase);
        svr = uvm_report_server::get_server();
        err_count = svr.get_severity_count(UVM_ERROR)
                  + svr.get_severity_count(UVM_FATAL);
        if (err_count == 0)
            verdict = "No errors -- passed testbench";
        else
            verdict = "Failed testbench";

        $display("%s", verdict);
        verdict_fd = $fopen("mac_pe_verdict.txt", "w");
        if (verdict_fd != 0) begin
            $fdisplay(verdict_fd, "%s", verdict);
            $fclose(verdict_fd);
        end
    endfunction : report_phase

endclass : mac_pe_test
