import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;
`uvm_analysis_imp_decl(_port)

class mac_pe_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mac_pe_scoreboard)

    uvm_analysis_imp_port #(mac_pe_transaction, mac_pe_scoreboard) scoreboard_port;
    mac_pe_transaction tx_stack[$];

    longint signed int_shadow;
    bit int_sat_shadow;
    shortreal bf16_shadow;
    bit fp_flag_shadow;

    localparam longint signed INT32_MAX_VALUE = 64'sd2147483647;
    localparam longint signed INT32_MIN_VALUE = (-64'sd2147483647 - 64'sd1);

    function new(string name = "mac_pe_scoreboard", uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), $sformatf("Constructing %s", get_full_name()), UVM_HIGH)
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard_port = new("scoreboard_port", this);
        int_shadow = 0;
        int_sat_shadow = 1'b0;
        bf16_shadow = 0.0;
        fp_flag_shadow = 1'b0;
    endfunction : build_phase

    function bit [31:0] bf16_to_fp32_bits(bit [15:0] value);
        if (value[14:7] == 8'h00)
            return {value[15], 31'h00000000};
        return {value, 16'h0000};
    endfunction : bf16_to_fp32_bits

    function bit is_nan32(bit [31:0] value);
        return (value[30:23] == 8'hff) && (value[22:0] != 23'h000000);
    endfunction : is_nan32

    function bit is_inf32(bit [31:0] value);
        return (value[30:23] == 8'hff) && (value[22:0] == 23'h000000);
    endfunction : is_inf32

    function bit is_special_bf16(bit [15:0] value);
        return ((value[14:7] == 8'h00) && (value[6:0] != 7'h00)) || (value[14:7] == 8'hff);
    endfunction : is_special_bf16

    function longint unsigned ordered_float_bits(bit [31:0] value);
        if (value[31])
            return longint'({32'h00000000, ~value});
        return longint'({32'h00000000, (value | 32'h80000000)});
    endfunction : ordered_float_bits

    function longint unsigned ulp_distance(bit [31:0] expected, bit [31:0] received);
        longint unsigned ordered_expected;
        longint unsigned ordered_received;
        ordered_expected = ordered_float_bits(expected);
        ordered_received = ordered_float_bits(received);
        if (ordered_expected > ordered_received)
            return ordered_expected - ordered_received;
        return ordered_received - ordered_expected;
    endfunction : ulp_distance

    function void check_int8(mac_pe_transaction tx);
        byte signed a_s;
        byte signed b_s;
        longint signed product;
        longint signed next_value;
        bit [31:0] expected_bits;

        if (tx.clear) begin
            int_shadow = 0;
            int_sat_shadow = 1'b0;
        end else begin
            a_s = tx.a[7:0];
            b_s = tx.b[7:0];
            product = longint'(int'(a_s)) * longint'(int'(b_s));
            next_value = int_shadow + product;
            if (next_value > INT32_MAX_VALUE) begin
                int_shadow = INT32_MAX_VALUE;
                int_sat_shadow = 1'b1;
            end else if (next_value < INT32_MIN_VALUE) begin
                int_shadow = INT32_MIN_VALUE;
                int_sat_shadow = 1'b1;
            end else begin
                int_shadow = next_value;
            end
        end

        expected_bits = int_shadow[31:0];
        if ((tx.acc !== expected_bits) || (tx.sat_flag !== int_sat_shadow)) begin
            `uvm_error("SCOREBOARD", $sformatf("INT8 mismatch: a=%h b=%h clear=%b expected_acc=%h got_acc=%h expected_sat=%b got_sat=%b",
                                              tx.a, tx.b, tx.clear, expected_bits, tx.acc, int_sat_shadow, tx.sat_flag))
        end else begin
            `uvm_info("SCOREBOARD", $sformatf("INT8 match: a=%h b=%h clear=%b expected_acc=%h got_acc=%h sat=%b",
                                             tx.a, tx.b, tx.clear, expected_bits, tx.acc, tx.sat_flag), UVM_MEDIUM)
        end
    endfunction : check_int8

    function void check_bf16(mac_pe_transaction tx);
        shortreal a_sr;
        shortreal b_sr;
        shortreal product_sr;
        bit [31:0] expected_bits;
        longint unsigned ulp;

        if (tx.clear) begin
            bf16_shadow = 0.0;
            fp_flag_shadow = 1'b0;
        end else begin
            a_sr = $bitstoshortreal(bf16_to_fp32_bits(tx.a));
            b_sr = $bitstoshortreal(bf16_to_fp32_bits(tx.b));
            product_sr = a_sr * b_sr;
            bf16_shadow = bf16_shadow + product_sr;
            if (is_special_bf16(tx.a) || is_special_bf16(tx.b))
                fp_flag_shadow = 1'b1;
        end

        expected_bits = $shortrealtobits(bf16_shadow);
        if (is_nan32(expected_bits))
            fp_flag_shadow = 1'b1;
        if (is_inf32(expected_bits))
            fp_flag_shadow = 1'b1;

        if (is_nan32(expected_bits)) begin
            if (!is_nan32(tx.acc)) begin
                `uvm_error("SCOREBOARD", $sformatf("BF16 NaN mismatch: a=%h b=%h expected NaN got_acc=%h", tx.a, tx.b, tx.acc))
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("BF16 NaN class match: a=%h b=%h got_acc=%h fp=%b", tx.a, tx.b, tx.acc, tx.fp_flag), UVM_MEDIUM)
            end
        end else if (is_inf32(expected_bits)) begin
            if (!is_inf32(tx.acc) || (tx.acc[31] !== expected_bits[31])) begin
                `uvm_error("SCOREBOARD", $sformatf("BF16 Inf mismatch: a=%h b=%h expected=%h got_acc=%h", tx.a, tx.b, expected_bits, tx.acc))
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("BF16 Inf match: a=%h b=%h expected=%h got_acc=%h fp=%b", tx.a, tx.b, expected_bits, tx.acc, tx.fp_flag), UVM_MEDIUM)
            end
        end else begin
            ulp = ulp_distance(expected_bits, tx.acc);
            if (ulp > 1) begin
                `uvm_error("SCOREBOARD", $sformatf("BF16 mismatch: a=%h b=%h expected=%h got_acc=%h ulp=%0d", tx.a, tx.b, expected_bits, tx.acc, ulp))
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("BF16 match: a=%h b=%h expected=%h got_acc=%h ulp=%0d fp=%b", tx.a, tx.b, expected_bits, tx.acc, ulp, tx.fp_flag), UVM_MEDIUM)
            end
        end

        if (tx.fp_flag !== fp_flag_shadow) begin
            `uvm_error("SCOREBOARD", $sformatf("BF16 flag mismatch: a=%h b=%h expected_fp=%b got_fp=%b", tx.a, tx.b, fp_flag_shadow, tx.fp_flag))
        end
    endfunction : check_bf16

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            mac_pe_transaction current_tx;
            wait (tx_stack.size() > 0);
            current_tx = tx_stack.pop_front();
            if (current_tx.mode == MODE_INT8)
                check_int8(current_tx);
            else
                check_bf16(current_tx);
        end
    endtask : run_phase

    function void write_port(mac_pe_transaction mon_tx);
        tx_stack.push_back(mon_tx);
        `uvm_info(get_type_name(), $sformatf("Scoreboard rx | %s", mon_tx.convert2string()), UVM_HIGH)
    endfunction : write_port

endclass : mac_pe_scoreboard
