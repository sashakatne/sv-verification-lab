import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_base_sequence extends uvm_sequence #(mac_pe_transaction);
    `uvm_object_utils(mac_pe_base_sequence)

    function new(string name = "mac_pe_base_sequence");
        super.new(name);
    endfunction : new

    task send_tx(mac_mode_t tx_mode, bit [15:0] tx_a, bit [15:0] tx_b, bit tx_valid, bit tx_clear);
        mac_pe_transaction tx;
        tx = mac_pe_transaction::type_id::create("tx");
        start_item(tx);
        tx.mode = tx_mode;
        tx.a = tx_a;
        tx.b = tx_b;
        tx.valid_in = tx_valid;
        tx.clear = tx_clear;
        finish_item(tx);
    endtask : send_tx

    function bit [15:0] random_bf16_normal();
        bit sign;
        bit [7:0] exp;
        bit [6:0] frac;
        sign = bit'($urandom_range(0, 1));
        exp = bit'(8'($urandom_range(126, 128)));
        frac = bit'(7'($urandom_range(0, 127)));
        return {sign, exp, frac};
    endfunction : random_bf16_normal

    function bit [15:0] random_bf16_value();
        int choice;
        bit sign;
        choice = $urandom_range(0, 19);
        sign = bit'($urandom_range(0, 1));
        if (choice < 14)
            return random_bf16_normal();
        if (choice < 16)
            return {sign, 15'h0000};
        if (choice < 18)
            return {sign, 8'h00, bit'(7'($urandom_range(1, 127)))};
        if (choice == 18)
            return {sign, 8'hff, 7'h00};
        return {sign, 8'hff, 7'h40};
    endfunction : random_bf16_value

endclass : mac_pe_base_sequence

class mac_pe_directed_int8_sequence extends mac_pe_base_sequence;
    `uvm_object_utils(mac_pe_directed_int8_sequence)

    function new(string name = "mac_pe_directed_int8_sequence");
        super.new(name);
    endfunction : new

    task body();
        int index;
        bit [15:0] corners[6];

        corners[0] = 16'h0080;
        corners[1] = 16'h007f;
        corners[2] = 16'h0000;
        corners[3] = 16'h0001;
        corners[4] = 16'h00ff;
        corners[5] = 16'h0042;

        `uvm_info("MAC_PE_INT8_SEQ", "Starting directed INT8 sequence", UVM_MEDIUM)
        send_tx(MODE_INT8, 16'h0000, 16'h0000, 1'b0, 1'b1);
        for (int a_index = 0; a_index < 6; a_index++)
            for (int b_index = 0; b_index < 6; b_index++)
                send_tx(MODE_INT8, corners[a_index], corners[b_index], 1'b1, 1'b0);

        for (index = 0; index < INT8_SAT_REPS; index++)
            send_tx(MODE_INT8, 16'h007f, 16'h007f, 1'b1, 1'b0);

        send_tx(MODE_INT8, 16'h0010, 16'h0010, 1'b0, 1'b1);
        send_tx(MODE_INT8, 16'h0001, 16'h0001, 1'b1, 1'b1);
    endtask : body

endclass : mac_pe_directed_int8_sequence

class mac_pe_directed_bf16_sequence extends mac_pe_base_sequence;
    `uvm_object_utils(mac_pe_directed_bf16_sequence)

    function new(string name = "mac_pe_directed_bf16_sequence");
        super.new(name);
    endfunction : new

    task body();
        `uvm_info("MAC_PE_BF16_SEQ", "Starting directed BF16 sequence", UVM_MEDIUM)
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        send_tx(MODE_BF16, 16'h3f80, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f80, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f00, 16'h4000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'hbf80, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);

        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h7f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h7fc0, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        send_tx(MODE_BF16, 16'h0001, 16'h0000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0001, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0001, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0001, 16'h7f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0001, 16'h7fc0, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        send_tx(MODE_BF16, 16'h3f80, 16'h0000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f80, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f80, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f80, 16'h7f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h3f80, 16'h7fc0, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        send_tx(MODE_BF16, 16'h7f80, 16'h0000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7f80, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7f80, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7f80, 16'h7f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7f80, 16'h7fc0, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        send_tx(MODE_BF16, 16'h7fc0, 16'h0000, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7fc0, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7fc0, 16'h3f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7fc0, 16'h7f80, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h7fc0, 16'h7fc0, 1'b1, 1'b0);
    endtask : body

endclass : mac_pe_directed_bf16_sequence

class mac_pe_random_sequence extends mac_pe_base_sequence;
    `uvm_object_utils(mac_pe_random_sequence)

    function new(string name = "mac_pe_random_sequence");
        super.new(name);
    endfunction : new

    task body();
        int index;

        `uvm_info("MAC_PE_RANDOM_SEQ", "Starting constrained-random mixed-mode sequence", UVM_MEDIUM)
        send_tx(MODE_INT8, 16'h0000, 16'h0000, 1'b0, 1'b1);
        for (index = 0; index < (TX_COUNT/2); index++)
            send_tx(MODE_INT8, {8'h00, bit'(8'($urandom_range(0, 255)))},
                              {8'h00, bit'(8'($urandom_range(0, 255)))}, 1'b1, 1'b0);

        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        for (index = 0; index < (TX_COUNT/2); index++)
            send_tx(MODE_BF16, random_bf16_value(), random_bf16_value(), 1'b1, 1'b0);

        send_tx(MODE_INT8, 16'h0000, 16'h0000, 1'b0, 1'b1);
        repeat (8)
            send_tx(MODE_INT8, 16'h0001, 16'h0001, 1'b1, 1'b0);
        send_tx(MODE_BF16, 16'h0000, 16'h0000, 1'b0, 1'b1);
        repeat (8)
            send_tx(MODE_BF16, 16'h3f80, 16'h3f80, 1'b1, 1'b0);
    endtask : body

endclass : mac_pe_random_sequence
