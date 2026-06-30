import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_transaction extends uvm_sequence_item;
    `uvm_object_utils(mac_pe_transaction)

    function new(string name = "mac_pe_transaction");
        super.new(name);
    endfunction : new

    rand mac_mode_t mode;
    rand bit [DATA_WIDTH-1:0] a;
    rand bit [DATA_WIDTH-1:0] b;
    rand bit valid_in;
    rand bit clear;

    bit clk;
    bit rst;
    logic [RESULT_WIDTH-1:0] acc;
    logic sat_flag;
    logic fp_flag;
    logic valid_out;

    constraint int8_upper_zero_c {
        mode == MODE_INT8 -> a[15:8] == 8'h00;
        mode == MODE_INT8 -> b[15:8] == 8'h00;
    }

    function string mode_name();
        return (mode == MODE_INT8) ? "INT8" : "BF16";
    endfunction : mode_name

    function string convert2string();
        return $sformatf("mode: %s, a: %h, b: %h, valid_in: %b, clear: %b, valid_out: %b, acc: %h, sat: %b, fp: %b",
                         mode_name(), a, b, valid_in, clear, valid_out, acc, sat_flag, fp_flag);
    endfunction : convert2string

endclass : mac_pe_transaction
