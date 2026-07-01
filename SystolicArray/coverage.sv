import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_coverage extends uvm_subscriber #(systolic_array_transaction);
    `uvm_component_utils(systolic_array_coverage)

    systolic_array_transaction tx;
    real cov_matrix_cases;
    real cov_int8_values;
    real cov_results;

    covergroup matrix_cases;
        option.per_instance = 1;
        case_cp : coverpoint tx.matrix_case {
            bins zero = {CASE_ZERO};
            bins identity = {CASE_IDENTITY};
            bins signed_corners = {CASE_SIGNED_CORNERS};
            bins alternating = {CASE_ALTERNATING};
            bins random = {CASE_RANDOM};
        }
        latency_cp : coverpoint tx.latency {
            bins expected = {EXPECTED_LATENCY};
        }
        active_cp : coverpoint tx.pe_active {
            bins bottom_right_active = {16'h8000};
        }
    endgroup

    covergroup int8_values with function sample(int a_class, int b_class);
        option.per_instance = 1;
        a_cp : coverpoint a_class {
            bins min_neg = {0};
            bins max_pos = {1};
            bins zero = {2};
            bins plus_one = {3};
            bins minus_one = {4};
            bins mid = {5};
        }
        b_cp : coverpoint b_class {
            bins min_neg = {0};
            bins max_pos = {1};
            bins zero = {2};
            bins plus_one = {3};
            bins minus_one = {4};
            bins mid = {5};
        }
        value_cross : cross a_cp, b_cp;
    endgroup

    covergroup result_values with function sample(int position_class, int result_class);
        option.per_instance = 1;
        position_cp : coverpoint position_class {
            bins corner = {0};
            bins diagonal = {1};
            bins off_diagonal = {2};
        }
        result_cp : coverpoint result_class {
            bins zero = {0};
            bins positive = {1};
            bins negative = {2};
            bins large_positive = {3};
            bins large_negative = {4};
        }
    endgroup

    function new(string name = "systolic_array_coverage", uvm_component parent = null);
        super.new(name, parent);
        tx = systolic_array_transaction::type_id::create("tx");
        matrix_cases = new();
        int8_values = new();
        result_values = new();
    endfunction : new

    function int int8_class(input logic signed [DATA_WIDTH-1:0] value);
        if (value == -128)
            return 0;
        if (value == 127)
            return 1;
        if (value == 0)
            return 2;
        if (value == 1)
            return 3;
        if (value == -1)
            return 4;
        return 5;
    endfunction : int8_class

    function logic signed [DATA_WIDTH-1:0] corner_value(input int index);
        unique case (index % 8)
            0: return 8'sd0;
            1: return 8'sd1;
            2: return -8'sd1;
            3: return 8'sd127;
            4: return -8'sd128;
            5: return 8'sd42;
            6: return -8'sd64;
            default: return 8'sd7;
        endcase
    endfunction : corner_value

    function int position_class(input int row, input int col);
        if (((row == 0) || (row == N-1)) && ((col == 0) || (col == N-1)))
            return 0;
        if (row == col)
            return 1;
        return 2;
    endfunction : position_class

    function int result_class(input logic signed [ACC_WIDTH-1:0] value);
        if (value == 0)
            return 0;
        if (value > 1000)
            return 3;
        if (value < -1000)
            return 4;
        if (value > 0)
            return 1;
        return 2;
    endfunction : result_class

    function matrix_case_t classify_case(input systolic_array_transaction t);
        bit all_zero;
        bit identity_a;
        bit signed_corners;
        bit alternating;
        all_zero = 1'b1;
        identity_a = 1'b1;
        signed_corners = 1'b1;
        alternating = 1'b1;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                if ((t.a[row][col] != 0) || (t.b[row][col] != 0))
                    all_zero = 1'b0;
                if (t.a[row][col] != ((row == col) ? 8'sd1 : 8'sd0))
                    identity_a = 1'b0;
                if ((t.a[row][col] != corner_value(row * N + col))
                 || (t.b[row][col] != corner_value((row * N + col) + 3)))
                    signed_corners = 1'b0;
                if ((t.a[row][col] != (((row + col) % 2) ? -8'sd3 : 8'sd5))
                 || (t.b[row][col] != ((row == col) ? -8'sd2 : 8'sd4)))
                    alternating = 1'b0;
            end
        end

        if (all_zero)
            return CASE_ZERO;
        if (identity_a)
            return CASE_IDENTITY;
        if (signed_corners)
            return CASE_SIGNED_CORNERS;
        if (alternating)
            return CASE_ALTERNATING;
        return CASE_RANDOM;
    endfunction : classify_case

    virtual function void write(systolic_array_transaction t);
        tx = t;
        tx.matrix_case = classify_case(t);
        matrix_cases.sample();

        for (int ai = 0; ai < N; ai++)
            for (int aj = 0; aj < N; aj++)
                for (int bi = 0; bi < N; bi++)
                    for (int bj = 0; bj < N; bj++)
                        int8_values.sample(int8_class(t.a[ai][aj]), int8_class(t.b[bi][bj]));

        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                result_values.sample(position_class(row, col), result_class(t.c[row][col]));

        cov_matrix_cases = matrix_cases.get_coverage();
        cov_int8_values = int8_values.get_coverage();
        cov_results = result_values.get_coverage();

        `uvm_info(get_type_name(), $sformatf("Coverage matrix_cases: %f", cov_matrix_cases), UVM_HIGH)
        `uvm_info(get_type_name(), $sformatf("Coverage int8_values: %f", cov_int8_values), UVM_HIGH)
        `uvm_info(get_type_name(), $sformatf("Coverage result_values: %f", cov_results), UVM_HIGH)
    endfunction : write

endclass : systolic_array_coverage
