interface systolic_array_bfm;
    import systolic_array_pkg::*;

    logic clk, rst;
    logic start;
    logic clear;
    logic [N*N*DATA_WIDTH-1:0] a_matrix;
    logic [N*N*DATA_WIDTH-1:0] b_matrix;
    logic [N*N*ACC_WIDTH-1:0] c_matrix;
    logic busy;
    logic done;
    logic [7:0] cycle_count;
    logic [N*N-1:0] pe_active;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        forever #(CYCLE_TIME/2.0) clk = ~clk;
    end

    task reset_systolic_array();
        @(negedge clk);
        rst      = 1'b1;
        start    = 1'b0;
        clear    = 1'b0;
        a_matrix = '0;
        b_matrix = '0;
        repeat (2) @(negedge clk);
        @(posedge clk);
        rst = 1'b0;
    endtask : reset_systolic_array

endinterface : systolic_array_bfm
