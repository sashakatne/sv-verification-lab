module systolic_pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
) (
    input  logic                          clk,
    input  logic                          rst,
    input  logic                          clear_acc,
    input  logic                          mac_enable,
    input  logic signed [DATA_WIDTH-1:0]  a_in,
    input  logic signed [DATA_WIDTH-1:0]  b_in,
    output logic signed [DATA_WIDTH-1:0]  a_out,
    output logic signed [DATA_WIDTH-1:0]  b_out,
    output logic signed [ACC_WIDTH-1:0]   acc
);

    always_ff @(posedge clk) begin
        if (rst || clear_acc) begin
            a_out <= '0;
            b_out <= '0;
            acc   <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (mac_enable)
                acc <= acc + (ACC_WIDTH'(a_in) * ACC_WIDTH'(b_in));
        end
    end

endmodule : systolic_pe

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

    localparam int LAST_CYCLE = (3 * N) - 3;

    logic signed [DATA_WIDTH-1:0] a_store [N][N];
    logic signed [DATA_WIDTH-1:0] b_store [N][N];
    logic signed [DATA_WIDTH-1:0] a_feed [N];
    logic signed [DATA_WIDTH-1:0] b_feed [N];
    logic signed [DATA_WIDTH-1:0] a_pipe [N][N];
    logic signed [DATA_WIDTH-1:0] b_pipe [N][N];
    logic signed [ACC_WIDTH-1:0]  pe_acc [N][N];
    logic [N*N-1:0]               pe_enable;
    logic                         clear_acc;
    logic                         done_pending;

    assign clear_acc = clear || (start && !busy);

    always_comb begin
        c_matrix = '0;
        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                c_matrix[((row * N + col) * ACC_WIDTH) +: ACC_WIDTH] = pe_acc[row][col];
    end

    always_comb begin
        for (int row = 0; row < N; row++) begin
            a_feed[row] = '0;
            for (int k = 0; k < N; k++) begin
                if (busy && (cycle_count == (row + k)))
                    a_feed[row] = a_store[row][k];
            end
        end

        for (int col = 0; col < N; col++) begin
            b_feed[col] = '0;
            for (int k = 0; k < N; k++) begin
                if (busy && (cycle_count == (col + k)))
                    b_feed[col] = b_store[k][col];
            end
        end

        pe_enable = '0;
        for (int row = 0; row < N; row++)
            for (int col = 0; col < N; col++)
                for (int k = 0; k < N; k++)
                    if (busy && (cycle_count == (row + col + k)))
                        pe_enable[row * N + col] = 1'b1;
    end

    genvar pe_row;
    genvar pe_col;
    generate
        for (pe_row = 0; pe_row < N; pe_row++) begin : row_gen
            for (pe_col = 0; pe_col < N; pe_col++) begin : col_gen
                logic signed [DATA_WIDTH-1:0] a_in;
                logic signed [DATA_WIDTH-1:0] b_in;
                logic                         enable;

                if (pe_col == 0) begin : west_input
                    assign a_in = a_feed[pe_row];
                end else begin : east_input
                    assign a_in = a_pipe[pe_row][pe_col - 1];
                end

                if (pe_row == 0) begin : north_input
                    assign b_in = b_feed[pe_col];
                end else begin : south_input
                    assign b_in = b_pipe[pe_row - 1][pe_col];
                end

`ifdef SKIP_PE_BUG
                assign enable = pe_enable[pe_row * N + pe_col]
                              && !((pe_row == N-1) && (pe_col == N-1));
`else
                assign enable = pe_enable[pe_row * N + pe_col];
`endif

                systolic_pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_i (
                    .clk(clk),
                    .rst(rst),
                    .clear_acc(clear_acc),
                    .mac_enable(enable),
                    .a_in(a_in),
                    .b_in(b_in),
                    .a_out(a_pipe[pe_row][pe_col]),
                    .b_out(b_pipe[pe_row][pe_col]),
                    .acc(pe_acc[pe_row][pe_col])
                );
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst || clear) begin
            busy        <= 1'b0;
            done        <= 1'b0;
            done_pending <= 1'b0;
            cycle_count <= 8'h00;
            pe_active   <= '0;
            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    a_store[row][col] <= '0;
                    b_store[row][col] <= '0;
                end
            end
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy        <= 1'b1;
                done_pending <= 1'b0;
                cycle_count <= 8'h00;
                pe_active   <= '0;
                for (int row = 0; row < N; row++) begin
                    for (int col = 0; col < N; col++) begin
                        a_store[row][col] <= a_matrix[((row * N + col) * DATA_WIDTH) +: DATA_WIDTH];
                        b_store[row][col] <= b_matrix[((row * N + col) * DATA_WIDTH) +: DATA_WIDTH];
                    end
                end
            end else if (done_pending) begin
                done_pending <= 1'b0;
                done         <= 1'b1;
            end else if (busy) begin
                pe_active <= pe_enable;
                if (cycle_count == LAST_CYCLE[7:0]) begin
                    busy         <= 1'b0;
                    done_pending <= 1'b1;
                end else begin
                    cycle_count <= cycle_count + 8'h01;
                end
            end else begin
                pe_active <= '0;
            end
        end
    end

endmodule : systolic_array
