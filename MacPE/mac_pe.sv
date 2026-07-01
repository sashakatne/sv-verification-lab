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

    localparam logic [31:0] FP32_QNAN = 32'h7fc00000;
    localparam logic [31:0] FP32_PINF = 32'h7f800000;
    localparam logic signed [32:0] INT32_MAX_33 = 33'sd2147483647;
    localparam logic signed [32:0] INT32_MIN_33 = (-33'sd2147483647 - 33'sd1);

    function automatic bit bf16_is_denorm(input logic [15:0] value);
        return (value[14:7] == 8'h00) && (value[6:0] != 7'h00);
    endfunction : bf16_is_denorm

    function automatic bit bf16_is_zero(input logic [15:0] value);
        return (value[14:7] == 8'h00) && (value[6:0] == 7'h00);
    endfunction : bf16_is_zero

    function automatic bit bf16_is_nan(input logic [15:0] value);
        return (value[14:7] == 8'hff) && (value[6:0] != 7'h00);
    endfunction : bf16_is_nan

    function automatic bit bf16_is_inf(input logic [15:0] value);
        return (value[14:7] == 8'hff) && (value[6:0] == 7'h00);
    endfunction : bf16_is_inf

    function automatic bit fp32_is_zero(input logic [31:0] value);
        return (value[30:23] == 8'h00) && (value[22:0] == 23'h000000);
    endfunction : fp32_is_zero

    function automatic bit fp32_is_nan(input logic [31:0] value);
        return (value[30:23] == 8'hff) && (value[22:0] != 23'h000000);
    endfunction : fp32_is_nan

    function automatic bit fp32_is_inf(input logic [31:0] value);
        return (value[30:23] == 8'hff) && (value[22:0] == 23'h000000);
    endfunction : fp32_is_inf

    function automatic logic [63:0] shift_right_sticky(
        input logic [63:0] value,
        input int unsigned shift
    );
        logic [63:0] shifted;
        bit sticky;

        if (shift == 0)
            return value;

        if (shift >= 64) begin
            if (value != 64'h0000000000000000)
                return 64'h0000000000000001;
            return 64'h0000000000000000;
        end

        shifted = value >> shift;
        sticky = 1'b0;
        for (int index = 0; index < 64; index++) begin
            if (index < shift)
                sticky |= value[index];
        end
        shifted[0] = shifted[0] | sticky;
        return shifted;
    endfunction : shift_right_sticky

    function automatic logic [32:0] int8_accumulate(
        input logic [31:0] acc_in,
        input logic [7:0]  a_in,
        input logic [7:0]  b_in
    );
        logic signed [7:0] a_s;
        logic signed [7:0] b_s;
        logic signed [15:0] product;
        logic signed [32:0] acc_ext;
        logic signed [32:0] product_ext;
        logic signed [32:0] sum;

        a_s = a_in;
        b_s = b_in;
        product = a_s * b_s;
        acc_ext = {acc_in[31], acc_in};
        product_ext = {{17{product[15]}}, product};
        sum = acc_ext + product_ext;

`ifdef SAT_SKIP_BUG
        return {1'b0, sum[31:0]};
`else
        if (sum > INT32_MAX_33)
            return {1'b1, 32'h7fffffff};
        if (sum < INT32_MIN_33)
            return {1'b1, 32'h80000000};
        return {1'b0, sum[31:0]};
`endif
    endfunction : int8_accumulate

    function automatic logic [32:0] bf16_mul_to_fp32(
        input logic [15:0] a_in,
        input logic [15:0] b_in
    );
        bit flag;
        bit sign;
        int signed exp_unbiased;
        int signed exp_field;
        logic [7:0] mant_a;
        logic [7:0] mant_b;
        logic [15:0] product;
        logic [23:0] significand;

        flag = bf16_is_denorm(a_in) || bf16_is_denorm(b_in) ||
               bf16_is_nan(a_in) || bf16_is_nan(b_in) ||
               bf16_is_inf(a_in) || bf16_is_inf(b_in);
        sign = a_in[15] ^ b_in[15];

        if (bf16_is_nan(a_in) || bf16_is_nan(b_in))
            return {1'b1, FP32_QNAN};

        if ((bf16_is_inf(a_in) && (bf16_is_zero(b_in) || bf16_is_denorm(b_in))) ||
            (bf16_is_inf(b_in) && (bf16_is_zero(a_in) || bf16_is_denorm(a_in))))
            return {1'b1, FP32_QNAN};

        if (bf16_is_inf(a_in) || bf16_is_inf(b_in))
            return {1'b1, {sign, FP32_PINF[30:0]}};

        if (bf16_is_zero(a_in) || bf16_is_zero(b_in) ||
            bf16_is_denorm(a_in) || bf16_is_denorm(b_in))
            return {flag, {sign, 31'h00000000}};

        mant_a = {1'b1, a_in[6:0]};
        mant_b = {1'b1, b_in[6:0]};
        product = mant_a * mant_b;
        exp_unbiased = (int'(a_in[14:7]) - 127) + (int'(b_in[14:7]) - 127);

        if (product[15]) begin
            significand = product << 8;
            exp_field = exp_unbiased + 1 + 127;
        end else begin
            significand = product << 9;
            exp_field = exp_unbiased + 127;
        end

        if (exp_field >= 255)
            return {1'b1, {sign, 8'hff, 23'h000000}};

        if (exp_field <= 0)
            return {1'b1, {sign, 31'h00000000}};

        return {flag, {sign, exp_field[7:0], significand[22:0]}};
    endfunction : bf16_mul_to_fp32

    function automatic logic [32:0] fp32_add_rne(
        input logic [31:0] left,
        input logic [31:0] right
    );
        bit flag;
        bit result_sign;
        bit sign_a;
        bit sign_b;
        int signed exp_a;
        int signed exp_b;
        int signed exp_result;
        int unsigned shift;
        logic [23:0] mant_a;
        logic [23:0] mant_b;
        logic [63:0] mant_a_ext;
        logic [63:0] mant_b_ext;
        logic [63:0] big_ext;
        logic [63:0] small_ext;
        logic [63:0] sum_ext;
        logic [23:0] mant_main;
        logic [24:0] rounded;
        bit guard_bit;
        bit round_bit;
        bit sticky_bit;

        flag = fp32_is_nan(left) || fp32_is_nan(right) ||
               fp32_is_inf(left) || fp32_is_inf(right);
        sign_a = left[31];
        sign_b = right[31];
        exp_a = int'(left[30:23]);
        exp_b = int'(right[30:23]);

        if (fp32_is_nan(left) || fp32_is_nan(right))
            return {1'b1, FP32_QNAN};

        if (fp32_is_inf(left) && fp32_is_inf(right) && (sign_a != sign_b))
            return {1'b1, FP32_QNAN};

        if (fp32_is_inf(left))
            return {1'b1, left};

        if (fp32_is_inf(right))
            return {1'b1, right};

        if ((left[30:23] == 8'h00) && (left[22:0] != 23'h000000)) begin
            flag = 1'b1;
            left = {left[31], 31'h00000000};
        end

        if ((right[30:23] == 8'h00) && (right[22:0] != 23'h000000)) begin
            flag = 1'b1;
            right = {right[31], 31'h00000000};
        end

        if (fp32_is_zero(left) && fp32_is_zero(right))
            return {flag, 32'h00000000};

        if (fp32_is_zero(left))
            return {flag, right};

        if (fp32_is_zero(right))
            return {flag, left};

        sign_a = left[31];
        sign_b = right[31];
        exp_a = int'(left[30:23]);
        exp_b = int'(right[30:23]);
        mant_a = {1'b1, left[22:0]};
        mant_b = {1'b1, right[22:0]};
        mant_a_ext = {37'h0000000000, mant_a, 3'b000};
        mant_b_ext = {37'h0000000000, mant_b, 3'b000};

        if ((exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b))) begin
            shift = exp_a - exp_b;
            big_ext = mant_a_ext;
            small_ext = shift_right_sticky(mant_b_ext, shift);
            exp_result = exp_a;
            result_sign = sign_a;
        end else begin
            shift = exp_b - exp_a;
            big_ext = mant_b_ext;
            small_ext = shift_right_sticky(mant_a_ext, shift);
            exp_result = exp_b;
            result_sign = sign_b;
        end

        if (sign_a == sign_b) begin
            sum_ext = big_ext + small_ext;
            result_sign = sign_a;
            if (sum_ext[27]) begin
                sum_ext = shift_right_sticky(sum_ext, 1);
                exp_result++;
            end
        end else begin
            if (big_ext == small_ext)
                return {flag, 32'h00000000};

            sum_ext = big_ext - small_ext;
            while ((exp_result > 0) && (sum_ext[26] == 1'b0)) begin
                sum_ext = sum_ext << 1;
                exp_result--;
            end
        end

        guard_bit = sum_ext[2];
        round_bit = sum_ext[1];
        sticky_bit = sum_ext[0];
        mant_main = sum_ext[26:3];
        rounded = {1'b0, mant_main};

        if (guard_bit && (round_bit || sticky_bit || mant_main[0]))
            rounded = rounded + 25'h0000001;

        if (rounded[24]) begin
            mant_main = rounded[24:1];
            exp_result++;
        end else begin
            mant_main = rounded[23:0];
        end

        if (exp_result >= 255)
            return {1'b1, {result_sign, 8'hff, 23'h000000}};

        if (exp_result <= 0)
            return {1'b1, {result_sign, 31'h00000000}};

        return {flag, {result_sign, exp_result[7:0], mant_main[22:0]}};
    endfunction : fp32_add_rne

    always_ff @(posedge clk) begin
        logic [32:0] int_result;
        logic [32:0] product_result;
        logic [32:0] fp_result;

        if (rst) begin
            acc       <= 32'h00000000;
            sat_flag  <= 1'b0;
            fp_flag   <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;

            if (clear) begin
                acc       <= 32'h00000000;
                sat_flag  <= 1'b0;
                fp_flag   <= 1'b0;
                valid_out <= 1'b1;
            end else if (valid_in) begin
                valid_out <= 1'b1;
                if (mode == 1'b0) begin
                    int_result = int8_accumulate(acc, a[7:0], b[7:0]);
                    acc <= int_result[31:0];
                    sat_flag <= sat_flag | int_result[32];
                end else begin
                    product_result = bf16_mul_to_fp32(a, b);
                    fp_result = fp32_add_rne(acc, product_result[31:0]);
                    acc <= fp_result[31:0];
                    fp_flag <= fp_flag | product_result[32] | fp_result[32];
                end
            end
        end
    end

endmodule
