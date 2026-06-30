interface mac_pe_bfm;
    import mac_pe_pkg::*;

    logic clk, rst;
    logic mode;
    logic [DATA_WIDTH-1:0] a, b;
    logic valid_in;
    logic clear;
    logic [RESULT_WIDTH-1:0] acc;
    logic sat_flag;
    logic fp_flag;
    logic valid_out;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        forever #(CYCLE_TIME/2) clk = ~clk;
    end

    task reset_mac_pe();
        @(negedge clk);
        rst      = 1'b1;
        mode     = MODE_INT8;
        a        = '0;
        b        = '0;
        valid_in = 1'b0;
        clear    = 1'b0;
        repeat (2) @(negedge clk);
        @(posedge clk);
        rst = 1'b0;
    endtask : reset_mac_pe

endinterface
