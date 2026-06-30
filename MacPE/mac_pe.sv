module mac_pe (
    input  logic        clk,
    input  logic        rst,
    input  logic        mode,
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic        valid_in,
    input  logic        clear,
    output logic [31:0] acc,
    output logic        sat_flag,
    output logic        fp_flag,
    output logic        valid_out
);

    always_ff @(posedge clk) begin
        if (rst) begin
            acc       <= 32'h00000000;
            sat_flag  <= 1'b0;
            fp_flag   <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (clear || valid_in) begin
                acc       <= 32'h00000000;
                sat_flag  <= 1'b0;
                fp_flag   <= 1'b0;
                valid_out <= 1'b1;
            end
        end
    end

endmodule
