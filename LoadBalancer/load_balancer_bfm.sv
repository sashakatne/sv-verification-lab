// Bus functional model for load_balancer: owns the clock, mirrors every DUT
// signal, and provides the reset task. The UVM driver/monitor reach the DUT
// only through this interface handle (passed via uvm_config_db).
interface load_balancer_bfm;
    import load_balancer_pkg::*;

    logic                      clk;
    logic                      rst_n;

    logic [1:0]                policy;
    logic [N*WEIGHT_WIDTH-1:0] weight;

    logic                      req_valid;
    logic [ID_WIDTH-1:0]       req_id;
    logic                      req_ready;

    logic [N-1:0]              be_ready;
    logic [N-1:0]              be_valid;
    logic [ID_WIDTH-1:0]       be_id;
    logic [N-1:0]              be_done;

    logic [N*OCC_WIDTH-1:0]    occ_flat;

    initial begin
        clk = 1'b0;
        forever #(CYCLE_TIME/2) clk = ~clk;
    end

    task reset_lb();
        @(negedge clk);
        rst_n     = 1'b0;
        policy    = POLICY_RR;
        weight    = '0;
        req_valid = 1'b0;
        req_id    = '0;
        be_ready  = '0;
        be_done   = '0;
        repeat (2) @(negedge clk);
        @(posedge clk);
        rst_n = 1'b1;
    endtask : reset_lb

endinterface
