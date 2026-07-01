module systolic_array #(
    parameter int N = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         start,
    input  logic                         clear,
    input  logic [N*N*DATA_WIDTH-1:0]    a_matrix,
    input  logic [N*N*DATA_WIDTH-1:0]    b_matrix,
    output logic [N*N*ACC_WIDTH-1:0]     c_matrix,
    output logic                         busy,
    output logic                         done,
    output logic [7:0]                   cycle_count,
    output logic [N*N-1:0]               pe_active
);

    always_ff @(posedge clk) begin
        if (rst || clear) begin
            c_matrix    <= '0;
            busy        <= 1'b0;
            done        <= 1'b0;
            cycle_count <= 8'h00;
            pe_active   <= '0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                c_matrix    <= '0;
                busy        <= 1'b1;
                cycle_count <= 8'h00;
                pe_active   <= '1;
            end else if (busy) begin
                cycle_count <= cycle_count + 8'h01;
                pe_active   <= '0;
                busy        <= 1'b0;
                done        <= 1'b1;
            end
        end
    end

endmodule
