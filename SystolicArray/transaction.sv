import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_transaction extends uvm_sequence_item;
    `uvm_object_utils(systolic_array_transaction)

    matrix_case_t matrix_case;
    bit start;
    bit clear;
    logic signed [DATA_WIDTH-1:0] a [N][N];
    logic signed [DATA_WIDTH-1:0] b [N][N];
    logic signed [ACC_WIDTH-1:0] c [N][N];
    bit done;
    bit busy;
    bit [7:0] latency;
    bit [N*N-1:0] pe_active;

    function new(string name = "systolic_array_transaction");
        super.new(name);
    endfunction : new

    function string case_name();
        unique case (matrix_case)
            CASE_ZERO: return "ZERO";
            CASE_IDENTITY: return "IDENTITY";
            CASE_SIGNED_CORNERS: return "SIGNED_CORNERS";
            CASE_ALTERNATING: return "ALTERNATING";
            CASE_RANDOM: return "RANDOM";
            default: return "UNKNOWN";
        endcase
    endfunction : case_name

    function string convert2string();
        return $sformatf("case=%s start=%b clear=%b done=%b latency=%0d c00=%0d c33=%0d active=%h",
                         case_name(), start, clear, done, latency, c[0][0], c[N-1][N-1], pe_active);
    endfunction : convert2string

endclass : systolic_array_transaction
