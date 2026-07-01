import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_test extends uvm_test;
    `uvm_component_utils(systolic_array_test)

    systolic_array_environment environment_h;
    systolic_array_sequence sequence_h;

    function new(string name = "systolic_array_test", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_HIGH)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        environment_h = systolic_array_environment::type_id::create("environment_h", this);
    endfunction : build_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        sequence_h = systolic_array_sequence::type_id::create("sequence_h");
        sequence_h.start(environment_h.agent_h.sequencer_h);
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
        verdict_fd = $fopen("systolic_array_verdict.txt", "w");
        if (verdict_fd != 0) begin
            $fdisplay(verdict_fd, "%s", verdict);
            $fclose(verdict_fd);
        end
    endfunction : report_phase

endclass : systolic_array_test
