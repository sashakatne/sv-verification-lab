import uvm_pkg::*;
`include "uvm_macros.svh"
import mac_pe_pkg::*;

class mac_pe_coverage extends uvm_subscriber #(mac_pe_transaction);
    `uvm_component_utils(mac_pe_coverage)

    mac_pe_transaction tx;
    real cov_mode_ctrl;
    real cov_int8_corners;
    real cov_bf16_classes;

    function int int8_corner(bit [15:0] value);
        byte signed byte_value;
        byte_value = value[7:0];
        if (byte_value == -128)
            return 0;
        if (byte_value == 127)
            return 1;
        if (byte_value == 0)
            return 2;
        if (byte_value == 1)
            return 3;
        if (byte_value == -1)
            return 4;
        return 5;
    endfunction : int8_corner

    function int bf16_class(bit [15:0] value);
        if ((value[14:7] == 8'h00) && (value[6:0] == 7'h00))
            return 0;
        if ((value[14:7] == 8'h00) && (value[6:0] != 7'h00))
            return 1;
        if ((value[14:7] != 8'hff) && (value[14:7] != 8'h00))
            return 2;
        if ((value[14:7] == 8'hff) && (value[6:0] == 7'h00))
            return 3;
        return 4;
    endfunction : bf16_class

    covergroup mode_ctrl;
        option.per_instance = 1;
        mode_cp : coverpoint tx.mode {
            bins int8 = {MODE_INT8};
            bins bf16 = {MODE_BF16};
            bins int_to_bf16 = (MODE_INT8 => MODE_BF16);
            bins bf16_to_int = (MODE_BF16 => MODE_INT8);
            bins int8_run = (MODE_INT8 [*4:20]);
            bins bf16_run = (MODE_BF16 [*4:20]);
        }

        ctrl_cp : coverpoint {tx.valid_in, tx.clear} {
            bins mac = {2'b10};
            bins clr = {2'b01};
            bins clr_mac = {2'b11};
            bins mac_to_clear = (2'b10 => 2'b01);
            bins clear_to_mac = (2'b01 => 2'b10);
            ignore_bins idle = {2'b00};
        }
    endgroup

    covergroup int8_corners;
        option.per_instance = 1;
        a_cp : coverpoint int8_corner(tx.a) iff (tx.mode == MODE_INT8) {
            bins min_neg = {0};
            bins max_pos = {1};
            bins zero = {2};
            bins plus_one = {3};
            bins minus_one = {4};
            bins mid = {5};
        }
        b_cp : coverpoint int8_corner(tx.b) iff (tx.mode == MODE_INT8) {
            bins min_neg = {0};
            bins max_pos = {1};
            bins zero = {2};
            bins plus_one = {3};
            bins minus_one = {4};
            bins mid = {5};
        }
        sat_cp : coverpoint tx.sat_flag iff (tx.mode == MODE_INT8) {
            bins clear = {0};
            bins hit = {1};
        }
        corner_cross : cross a_cp, b_cp {
            bins maxpos_maxpos = binsof(a_cp.max_pos) && binsof(b_cp.max_pos);
            bins minneg_minneg = binsof(a_cp.min_neg) && binsof(b_cp.min_neg);
            bins zero_product = binsof(a_cp.zero) || binsof(b_cp.zero);
            bins signed_mix = binsof(a_cp.minus_one) && binsof(b_cp.plus_one);
        }
    endgroup

    covergroup bf16_classes;
        option.per_instance = 1;
        a_class : coverpoint bf16_class(tx.a) iff (tx.mode == MODE_BF16) {
            bins zero = {0};
            bins denorm = {1};
            bins normal = {2};
            bins inf = {3};
            bins nan = {4};
        }
        b_class : coverpoint bf16_class(tx.b) iff (tx.mode == MODE_BF16) {
            bins zero = {0};
            bins denorm = {1};
            bins normal = {2};
            bins inf = {3};
            bins nan = {4};
        }
        fp_cp : coverpoint tx.fp_flag iff (tx.mode == MODE_BF16) {
            bins clear = {0};
            bins hit = {1};
        }
        class_cross : cross a_class, b_class {
            bins nan_normal = binsof(a_class.nan) && binsof(b_class.normal);
            bins inf_zero = binsof(a_class.inf) && binsof(b_class.zero);
            bins inf_inf = binsof(a_class.inf) && binsof(b_class.inf);
            bins normal_normal = binsof(a_class.normal) && binsof(b_class.normal);
            bins denorm_normal = binsof(a_class.denorm) && binsof(b_class.normal);
        }
    endgroup

    function new(string name = "mac_pe_coverage", uvm_component parent = null);
        super.new(name, parent);
        tx = mac_pe_transaction::type_id::create("tx");
        mode_ctrl = new();
        int8_corners = new();
        bf16_classes = new();
    endfunction : new

    virtual function void write(mac_pe_transaction t);
        tx = t;
        mode_ctrl.sample();
        int8_corners.sample();
        bf16_classes.sample();

        cov_mode_ctrl = mode_ctrl.get_coverage();
        cov_int8_corners = int8_corners.get_coverage();
        cov_bf16_classes = bf16_classes.get_coverage();

        `uvm_info(get_type_name(), $sformatf("Coverage mode_ctrl: %f", cov_mode_ctrl), UVM_HIGH)
        `uvm_info(get_type_name(), $sformatf("Coverage int8_corners: %f", cov_int8_corners), UVM_HIGH)
        `uvm_info(get_type_name(), $sformatf("Coverage bf16_classes: %f", cov_bf16_classes), UVM_HIGH)
    endfunction : write

endclass : mac_pe_coverage
