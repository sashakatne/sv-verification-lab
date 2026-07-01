import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;
`uvm_analysis_imp_decl(_port)

class systolic_array_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(systolic_array_scoreboard)

    uvm_analysis_imp_port #(systolic_array_transaction, systolic_array_scoreboard) scoreboard_port;
    systolic_array_transaction tx_stack[$];

    function new(string name = "systolic_array_scoreboard", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_HIGH)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard_port = new("scoreboard_port", this);
    endfunction : build_phase

    function matrix_case_t classify_case(input systolic_array_transaction tx);
        bit all_zero;
        bit identity_a;
        all_zero = 1'b1;
        identity_a = 1'b1;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                if ((tx.a[row][col] != 0) || (tx.b[row][col] != 0))
                    all_zero = 1'b0;
                if (tx.a[row][col] != ((row == col) ? 8'sd1 : 8'sd0))
                    identity_a = 1'b0;
            end
        end

        if (all_zero)
            return CASE_ZERO;
        if (identity_a)
            return CASE_IDENTITY;
        return CASE_RANDOM;
    endfunction : classify_case

    function void check_matrix(input systolic_array_transaction tx);
        int signed expected [N][N];
        logic signed [ACC_WIDTH-1:0] expected_value;
        bit mismatch;
        int first_row;
        int first_col;

        mismatch = 1'b0;
        first_row = 0;
        first_col = 0;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                expected[row][col] = 0;
                for (int k = 0; k < N; k++)
                    expected[row][col] += int'(tx.a[row][k]) * int'(tx.b[k][col]);

                expected_value = expected[row][col];
                if (tx.c[row][col] !== expected_value) begin
                    if (!mismatch) begin
                        first_row = row;
                        first_col = col;
                    end
                    mismatch = 1'b1;
                end
            end
        end

        if (tx.latency != EXPECTED_LATENCY) begin
            `uvm_error("SCOREBOARD", $sformatf("Latency mismatch: expected=%0d got=%0d", EXPECTED_LATENCY, tx.latency))
        end else if (mismatch) begin
            expected_value = expected[first_row][first_col];
            `uvm_error("SCOREBOARD", $sformatf("Matrix mismatch: case=%s first_bad=[%0d,%0d] expected=%0d got=%0d",
                                               tx.case_name(), first_row, first_col,
                                               expected_value, tx.c[first_row][first_col]))
        end else begin
            `uvm_info("SCOREBOARD", $sformatf("Matrix match: case=%s latency=%0d c00=%0d c33=%0d",
                                             tx.case_name(), tx.latency, tx.c[0][0], tx.c[N-1][N-1]), UVM_MEDIUM)
        end
    endfunction : check_matrix

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            systolic_array_transaction current_tx;
            wait (tx_stack.size() > 0);
            current_tx = tx_stack.pop_front();
            current_tx.matrix_case = classify_case(current_tx);
            check_matrix(current_tx);
        end
    endtask : run_phase

    function void write_port(systolic_array_transaction mon_tx);
        tx_stack.push_back(mon_tx);
        `uvm_info(get_type_name(), $sformatf("Scoreboard rx | %s", mon_tx.convert2string()), UVM_HIGH)
    endfunction : write_port

endclass : systolic_array_scoreboard
