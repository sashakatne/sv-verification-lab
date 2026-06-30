module top;
    import mac_pe_pkg::*;
    import uvm_pkg::*;

    mac_pe_bfm bfm();

    mac_pe DUT (
        .clk(bfm.clk),
        .rst(bfm.rst),
        .mode(bfm.mode),
        .a(bfm.a),
        .b(bfm.b),
        .valid_in(bfm.valid_in),
        .clear(bfm.clear),
        .acc(bfm.acc),
        .sat_flag(bfm.sat_flag),
        .fp_flag(bfm.fp_flag),
        .valid_out(bfm.valid_out)
    );

    initial begin
        uvm_config_db #(virtual mac_pe_bfm)::set(null, "*", "bfm", bfm);
        uvm_top.finish_on_completion = 1;
        run_test("mac_pe_test");
    end

endmodule : top
