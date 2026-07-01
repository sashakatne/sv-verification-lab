import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_array_pkg::*;

class systolic_array_sequence extends uvm_sequence #(systolic_array_transaction);
    `uvm_object_utils(systolic_array_sequence)

    function new(string name = "systolic_array_sequence");
        super.new(name);
    endfunction : new

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

    function void fill_matrix(ref systolic_array_transaction tx, input matrix_case_t matrix_case);
        int value;

        tx.matrix_case = matrix_case;
        tx.start = 1'b1;
        tx.clear = 1'b0;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                unique case (matrix_case)
                    CASE_ZERO: begin
                        tx.a[row][col] = '0;
                        tx.b[row][col] = '0;
                    end
                    CASE_IDENTITY: begin
                        tx.a[row][col] = (row == col) ? 8'sd1 : 8'sd0;
                        tx.b[row][col] = row * N + col - 7;
                    end
                    CASE_SIGNED_CORNERS: begin
                        tx.a[row][col] = corner_value(row * N + col);
                        tx.b[row][col] = corner_value((row * N + col) + 3);
                    end
                    CASE_ALTERNATING: begin
                        tx.a[row][col] = ((row + col) % 2) ? -8'sd3 : 8'sd5;
                        tx.b[row][col] = (row == col) ? -8'sd2 : 8'sd4;
                    end
                    default: begin
                        value = $urandom_range(0, 16) - 8;
                        tx.a[row][col] = value;
                        value = $urandom_range(0, 16) - 8;
                        tx.b[row][col] = value;
                    end
                endcase
            end
        end
    endfunction : fill_matrix

    task send_case(input matrix_case_t matrix_case);
        systolic_array_transaction tx;
        tx = systolic_array_transaction::type_id::create("tx");
        start_item(tx);
        fill_matrix(tx, matrix_case);
        finish_item(tx);
    endtask : send_case

    task body();
        `uvm_info("SYSTOLIC_SEQ", "Starting directed and random matrix sequence", UVM_MEDIUM)
        send_case(CASE_ZERO);
        send_case(CASE_IDENTITY);
        send_case(CASE_SIGNED_CORNERS);
        send_case(CASE_ALTERNATING);
        repeat (TX_COUNT)
            send_case(CASE_RANDOM);
    endtask : body

endclass : systolic_array_sequence
