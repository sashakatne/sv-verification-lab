// Simulation top: BFM + DUT, the SVA checker bound onto the DUT, and the UVM
// bootstrap. The bind makes the assertions observe the DUT's internal grant /
// accept / occupancy without any assertion code living in the synthesizable
// RTL (repo convention, see ArbiterAssertions/top.sv).
module top;
    import load_balancer_pkg::*;
    import uvm_pkg::*;

    load_balancer_bfm bfm();

    load_balancer #(
        .N            (N),
        .ID_WIDTH     (ID_WIDTH),
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .OCC_WIDTH    (OCC_WIDTH)
    ) DUT (
        .clk       (bfm.clk),
        .rst_n     (bfm.rst_n),
        .policy    (bfm.policy),
        .weight    (bfm.weight),
        .req_valid (bfm.req_valid),
        .req_id    (bfm.req_id),
        .req_ready (bfm.req_ready),
        .be_ready  (bfm.be_ready),
        .be_valid  (bfm.be_valid),
        .be_id     (bfm.be_id),
        .be_done   (bfm.be_done),
        .occ_flat  (bfm.occ_flat)
    );

    // bind the SVA checker onto the DUT (.* connects ports + internal grant/accept)
    bind load_balancer load_balancer_sva #(
        .N            (N),
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .OCC_WIDTH    (OCC_WIDTH)
    ) sva_inst (.*);

    initial begin
        uvm_config_db #(virtual load_balancer_bfm)::set(null, "*", "bfm", bfm);
        uvm_top.finish_on_completion = 1;
        run_test("load_balancer_test");
    end

endmodule : top
