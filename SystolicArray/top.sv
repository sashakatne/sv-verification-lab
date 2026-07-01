module top;
    import systolic_array_pkg::*;
    import uvm_pkg::*;

    systolic_array_bfm bfm();

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) DUT (
        .clk(bfm.clk),
        .rst(bfm.rst),
        .start(bfm.start),
        .clear(bfm.clear),
        .a_matrix(bfm.a_matrix),
        .b_matrix(bfm.b_matrix),
        .c_matrix(bfm.c_matrix),
        .busy(bfm.busy),
        .done(bfm.done),
        .cycle_count(bfm.cycle_count),
        .pe_active(bfm.pe_active)
    );

    initial begin
        uvm_config_db #(virtual systolic_array_bfm)::set(null, "*", "bfm", bfm);
        uvm_top.finish_on_completion = 1;
        run_test("systolic_array_test");
    end

endmodule : top
