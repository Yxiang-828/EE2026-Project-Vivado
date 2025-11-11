`timescale 1ns / 1ps

/*
 * CUBIC POLYNOMIAL SOLVER - FINAL FIXED VERSION
 *
 * EXPECTED: 36/38 PASSES
 *
 * KEY FIXES:
 * 1. HANDSHAKE: 1-cycle sqrt_start pulse (correctly latched by sqrt_iterative)
 * 2. ALGORITHM: Fixed NR_INIT for x^3=0 case
 * 3. NUMERICAL: Fixed discriminant calculation to match original unpipelined code
 *    - Original: disc = clip(b2^2) - clip(4*a2*c2)
 *    - Fixed: Calculate (a2<<2)*c2 BEFORE clipping
 * 4. DEFLATE: Properly checks fx_check (not fx) for retry logic
 *
 * KNOWN LIMITATIONS:
 * - Tests 20 & 34 timeout (precision limits, cannot fix)
 */

module poly_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg busy,
    output reg done,
    input wire signed [23:0] coeff_a,
    input wire signed [23:0] coeff_b,
    input wire signed [23:0] coeff_c,
    input wire signed [23:0] coeff_d,
    output reg signed [23:0] root1_real,
    output reg signed [23:0] root1_imag,
    output reg signed [23:0] root2_real,
    output reg signed [23:0] root2_imag,
    output reg signed [23:0] root3_real,
    output reg signed [23:0] root3_imag
);

parameter IO_BITS = 24;
parameter IO_FRAC = 6;
parameter INT_BITS = 32;
parameter INT_FRAC = 14;
parameter SHIFT_IO_TO_INT = INT_FRAC - IO_FRAC;
parameter SHIFT_INT_TO_IO = INT_FRAC - IO_FRAC;

reg signed [31:0] a, b, c, d;
reg signed [31:0] x, x2, x3;
reg signed [31:0] fx, fpx;
reg signed [31:0] three_a, two_b;
reg signed [31:0] x_new;
reg signed [31:0] a2, b2, c2;
reg signed [31:0] disc, sqrt_disc;
reg signed [31:0] neg_b2, two_a2;
reg signed [31:0] num1, num2;
reg signed [31:0] quad_result1, quad_result2;
reg [4:0] iter_count;
reg [3:0] norm_shift;
reg signed [31:0] a_temp;
reg [2:0] retry_attempt;
reg signed [31:0] fx_check;
parameter MAX_ITER = 20;

reg signed [63:0] pipe_mul_a, pipe_mul_b, pipe_mul_c;
reg signed [31:0] pipe_clip_a, pipe_clip_b, pipe_clip_c;

reg is_small_coeff;
reg is_large_coeff;
reg is_balanced;

reg [15:0] state_timeout;
parameter TIMEOUT_LIMIT = 16'd5000;

reg div_ip_start;
reg signed [63:0] div_ip_dividend;
reg signed [31:0] div_ip_divisor;
wire div_ip_done;
wire signed [95:0] div_ip_quotient_bus;
wire signed [31:0] div_ip_quotient_lower = $signed(div_ip_quotient_bus[63:32]);

reg main_fsm_div_req;
reg signed [63:0] main_fsm_dividend;
reg signed [31:0] main_fsm_divisor;
wire main_fsm_div_done;
wire signed [31:0] main_fsm_quotient;

wire sqrt_div_req;
wire signed [63:0] sqrt_dividend;
wire signed [31:0] sqrt_divisor;
wire sqrt_div_done;
wire signed [31:0] sqrt_quotient;

reg sqrt_start;
reg signed [31:0] sqrt_input;
wire signed [31:0] sqrt_output;
wire sqrt_done;

localparam IDLE = 0,
           NORMALIZE = 1,
           CLASSIFY_CALC = 2, CLASSIFY_PIPE = 3, CLASSIFY_EVAL = 4,
           NR_INIT = 5,
           NR_X2_CALC = 6, NR_X2_PIPE = 7, NR_X2_STORE = 8,
           NR_X3_CALC = 9, NR_X3_PIPE = 10, NR_X3_STORE = 11,
           NR_FX_CALC = 12, NR_FX_PIPE = 13, NR_FX_SUM = 14,
           NR_FPX_CALC = 15, NR_FPX_PIPE = 16, NR_FPX_SUM = 17,
           NR_DIV_REQ = 18, NR_DIV_WAIT = 19, NR_UPDATE = 20,
           DEFLATE_X2_CALC = 21, DEFLATE_X2_PIPE = 22, DEFLATE_X2_STORE = 23,
           DEFLATE_X3_CALC = 24, DEFLATE_X3_PIPE = 25, DEFLATE_X3_STORE = 26,
           DEFLATE_FX_CHECK_CALC = 27, DEFLATE_FX_CHECK_PIPE = 28, DEFLATE_FX_CHECK_SUM = 29,
           DEFLATE_COEFF_CALC = 30, DEFLATE_COEFF_PIPE = 31, DEFLATE_COEFF_SUM = 32,
           DEFLATE_EVAL = 33,
           QUAD_INIT_CALC = 34, QUAD_INIT_PIPE = 35, QUAD_INIT_SUM = 36,
           QUAD_SQRT_START = 37, QUAD_SQRT_WAIT = 38, QUAD_PREP = 39,
           QUAD_DIV1_REQ = 40, QUAD_DIV1_WAIT = 41,
           QUAD_DIV2_REQ = 42, QUAD_DIV2_WAIT = 43, QUAD_SOLVE = 44,
           OUTPUT = 45, ERROR = 46;

reg [5:0] state;

divider_generator_0 divider_generator_0_inst (
  .aclk(clk),
  .s_axis_dividend_tvalid(div_ip_start),
  .s_axis_dividend_tdata(div_ip_dividend),
  .s_axis_divisor_tvalid(div_ip_start),
  .s_axis_divisor_tdata(div_ip_divisor),
  .m_axis_dout_tvalid(div_ip_done),
  .m_axis_dout_tdata(div_ip_quotient_bus)
);

sqrt_iterative sqrt_inst(
    .clk(clk),
    .rst(!rst_n),
    .start(sqrt_start),
    .input_val(sqrt_input),
    .done(sqrt_done),
    .sqrt_out(sqrt_output),
    .div_req(sqrt_div_req),
    .div_dividend(sqrt_dividend),
    .div_divisor(sqrt_divisor),
    .div_done(sqrt_div_done),
    .div_quotient(sqrt_quotient)
);

localparam ARB_IDLE = 0, ARB_BUSY_MAIN = 1, ARB_BUSY_SQRT = 2;
reg [1:0] div_arb_state;
reg [7:0] arb_timeout;

assign main_fsm_div_done = div_ip_done && (div_arb_state == ARB_BUSY_MAIN);
assign sqrt_div_done = div_ip_done && (div_arb_state == ARB_BUSY_SQRT);
assign main_fsm_quotient = div_ip_quotient_lower;
assign sqrt_quotient = div_ip_quotient_lower;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_arb_state <= ARB_IDLE;
        div_ip_start <= 0;
        div_ip_dividend <= 0;
        div_ip_divisor <= 0;
        arb_timeout <= 0;
    end else begin
        div_ip_start <= 0;
        case (div_arb_state)
            ARB_IDLE: begin
                arb_timeout <= 0;
                if (main_fsm_div_req) begin
                    div_ip_dividend <= main_fsm_dividend;
                    div_ip_divisor <= main_fsm_divisor;
                    div_ip_start <= 1;
                    div_arb_state <= ARB_BUSY_MAIN;
                end else if (sqrt_div_req) begin
                    div_ip_dividend <= sqrt_dividend;
                    div_ip_divisor <= sqrt_divisor;
                    div_ip_start <= 1;
                    div_arb_state <= ARB_BUSY_SQRT;
                end
            end
            ARB_BUSY_MAIN: begin
                arb_timeout <= arb_timeout + 1;
                if (div_ip_done) div_arb_state <= ARB_IDLE;
                else if (arb_timeout > 200) div_arb_state <= ARB_IDLE;
            end
            ARB_BUSY_SQRT: begin
                arb_timeout <= arb_timeout + 1;
                if (div_ip_done) div_arb_state <= ARB_IDLE;
                else if (arb_timeout > 200) div_arb_state <= ARB_IDLE;
            end
        endcase
    end
end

function [3:0] calc_norm_shift;
    input signed [31:0] val;
    reg [31:0] abs_val;
    integer i;
    reg found;
    begin
        abs_val = (val[31]) ? -val : val;
        calc_norm_shift = 0;
        found = 0;
        for (i = 31; i >= INT_FRAC; i = i - 1) begin
            if (abs_val[i] && !found) begin
                calc_norm_shift = i - INT_FRAC;
                found = 1;
            end
        end
    end
endfunction

function signed [31:0] clip;
    input signed [63:0] val;
    begin
        if (val > 64'sh000000007FFFFFFF)
            clip = 32'sh7FFFFFFF;
        else if (val < -64'sh0000000080000000)
            clip = 32'sh80000000;
        else
            clip = val[31:0];
    end
endfunction

function signed [31:0] abs32;
    input signed [31:0] val;
    begin
        abs32 = (val[31]) ? -val : val;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        busy <= 0;
        sqrt_start <= 0;
        iter_count <= 0;
        norm_shift <= 0;
        retry_attempt <= 0;
        root1_real <= 24'h000000;
        root1_imag <= 24'h000000;
        root2_real <= 24'h000000;
        root2_imag <= 24'h000000;
        root3_real <= 24'h000000;
        root3_imag <= 24'h000000;
        is_small_coeff <= 0;
        is_large_coeff <= 0;
        is_balanced <= 0;
        main_fsm_div_req <= 0;
        state_timeout <= 0;
        pipe_mul_a <= 0;
        pipe_mul_b <= 0;
        pipe_mul_c <= 0;
        pipe_clip_a <= 0;
        pipe_clip_b <= 0;
        pipe_clip_c <= 0;
        a <= 0; b <= 0; c <= 0; d <= 0;
        x <= 0; x2 <= 0; x3 <= 0;
        fx <= 0; fpx <= 0;
        three_a <= 0; two_b <= 0;
        a2 <= 0; b2 <= 0; c2 <= 0;
        disc <= 0; neg_b2 <= 0; two_a2 <= 0;
    end else begin
        if (state != NR_DIV_WAIT && state != QUAD_DIV1_WAIT && state != QUAD_DIV2_WAIT) begin
            main_fsm_div_req <= 0;
        end

        // KEY FIX: 1-cycle pulse for sqrt_start
        if (state != QUAD_SQRT_START) begin
            sqrt_start <= 0;
        end

        state_timeout <= state_timeout + 1;
        if (state_timeout > TIMEOUT_LIMIT && state != IDLE && state != OUTPUT) begin
            state <= ERROR;
        end

        case (state)
            IDLE: begin
                busy <= 0;
                state_timeout <= 0;
                if (start) begin
                    done <= 0;
                    busy <= 1;
                    retry_attempt <= 0;
                    root1_real <= 24'h000000;
                    root1_imag <= 24'h000000;
                    root2_real <= 24'h000000;
                    root2_imag <= 24'h000000;
                    root3_real <= 24'h000000;
                    root3_imag <= 24'h000000;
                    state <= NORMALIZE;
                end
            end

            NORMALIZE: begin
                state_timeout <= 0;
                a_temp = $signed({{(INT_BITS - IO_BITS){coeff_a[IO_BITS-1]}}, coeff_a}) <<< SHIFT_IO_TO_INT;
                if (coeff_a == 0) begin
                    a <= 32'h00004000;
                    b <= $signed({{(INT_BITS - IO_BITS){coeff_b[IO_BITS-1]}}, coeff_b}) <<< SHIFT_IO_TO_INT;
                    c <= $signed({{(INT_BITS - IO_BITS){coeff_c[IO_BITS-1]}}, coeff_c}) <<< SHIFT_IO_TO_INT;
                    d <= $signed({{(INT_BITS - IO_BITS){coeff_d[IO_BITS-1]}}, coeff_d}) <<< SHIFT_IO_TO_INT;
                    norm_shift <= 0;
                end else begin
                    norm_shift <= calc_norm_shift(a_temp);
                    a <= a_temp >>> calc_norm_shift(a_temp);
                    b <= ($signed({{(INT_BITS - IO_BITS){coeff_b[IO_BITS-1]}}, coeff_b}) <<< SHIFT_IO_TO_INT) >>> calc_norm_shift(a_temp);
                    c <= ($signed({{(INT_BITS - IO_BITS){coeff_c[IO_BITS-1]}}, coeff_c}) <<< SHIFT_IO_TO_INT) >>> calc_norm_shift(a_temp);
                    d <= ($signed({{(INT_BITS - IO_BITS){coeff_d[IO_BITS-1]}}, coeff_d}) <<< SHIFT_IO_TO_INT) >>> calc_norm_shift(a_temp);
                end
                state <= CLASSIFY_CALC;
            end

            CLASSIFY_CALC: begin
                state_timeout <= 0;
                is_small_coeff <= (abs32(b) < 32'h00004000) && (abs32(c) < 32'h00004000) && (abs32(d) < 32'h00004000);
                is_large_coeff <= (abs32(b) > 32'h00028000) || (abs32(c) > 32'h00028000) || (abs32(d) > 32'h00028000);
                pipe_mul_a <= $signed(b) * $signed(b);
                pipe_mul_b <= $signed(3 * a) * $signed(c);
                state <= CLASSIFY_PIPE;
            end

            CLASSIFY_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                state <= CLASSIFY_EVAL;
            end

            CLASSIFY_EVAL: begin
                state_timeout <= 0;
                is_balanced <= (pipe_clip_a > pipe_clip_b);
                state <= NR_INIT;
            end

            NR_INIT: begin
                state_timeout <= 0;
                if (retry_attempt == 0) begin
                    // KEY FIX: Proper priority for x^3=0 case
                    if (is_balanced) x <= -(b >>> 1);
                    else if (is_large_coeff) x <= -b >>> 2;
                    else if (is_small_coeff) begin
                        if (b == 0 && c == 0 && d == 0)
                            x <= 32'h00000000;
                        else
                            x <= 32'h00001000;
                    end
                    else x <= 32'h00000000;
                end else if (retry_attempt == 1) x <= (c != 0 && abs32(c) > 32'h00000100) ? -(d >>> 2) : 32'h00002000;
                else if (retry_attempt == 2) x <= 32'hFFFFC000;
                else if (retry_attempt == 3) x <= 32'h00008000;
                else if (retry_attempt == 4) x <= 32'hFFFF8000;
                else x <= 32'h00000400;
                iter_count <= 0;
                state <= NR_X2_CALC;
            end

            NR_X2_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(x) * $signed(x);
                state <= NR_X2_PIPE;
            end

            NR_X2_PIPE: begin
                state_timeout <= 0;
                state <= NR_X2_STORE;
            end

            NR_X2_STORE: begin
                state_timeout <= 0;
                x2 <= clip(pipe_mul_a >>> INT_FRAC);
                state <= NR_X3_CALC;
            end

            NR_X3_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(x2) * $signed(x);
                three_a <= 3 * a;
                two_b <= 2 * b;
                state <= NR_X3_PIPE;
            end

            NR_X3_PIPE: begin
                state_timeout <= 0;
                state <= NR_X3_STORE;
            end

            NR_X3_STORE: begin
                state_timeout <= 0;
                x3 <= clip(pipe_mul_a >>> INT_FRAC);
                state <= NR_FX_CALC;
            end

            NR_FX_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(a) * $signed(x3);
                pipe_mul_b <= $signed(b) * $signed(x2);
                pipe_mul_c <= $signed(c) * $signed(x);
                state <= NR_FX_PIPE;
            end

            NR_FX_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                pipe_clip_c <= clip(pipe_mul_c >>> INT_FRAC);
                state <= NR_FX_SUM;
            end

            NR_FX_SUM: begin
                state_timeout <= 0;
                fx <= pipe_clip_a + pipe_clip_b + pipe_clip_c + d;
                state <= NR_FPX_CALC;
            end

            NR_FPX_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(three_a) * $signed(x2);
                pipe_mul_b <= $signed(two_b) * $signed(x);
                state <= NR_FPX_PIPE;
            end

            NR_FPX_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                state <= NR_FPX_SUM;
            end

            NR_FPX_SUM: begin
                state_timeout <= 0;
                fpx <= pipe_clip_a + pipe_clip_b + c;
                state <= NR_DIV_REQ;
            end

            NR_DIV_REQ: begin
                state_timeout <= 0;
                if (fx < 32'sh0002 && fx > -32'sh0002) begin
                    state <= DEFLATE_X2_CALC;
                end else if (fpx < 32'sh0002 && fpx > -32'sh0002) begin
                    state <= DEFLATE_X2_CALC;
                end else if (iter_count >= MAX_ITER - 1) begin
                    state <= DEFLATE_X2_CALC;
                end else begin
                    main_fsm_dividend <= {{INT_BITS{fx[INT_BITS-1]}}, fx} <<< INT_FRAC;
                    main_fsm_divisor <= fpx;
                    main_fsm_div_req <= 1;
                    state <= NR_DIV_WAIT;
                end
            end

            NR_DIV_WAIT: begin
                main_fsm_div_req <= 1;
                if (main_fsm_div_done) begin
                    main_fsm_div_req <= 0;
                    state_timeout <= 0;
                    state <= NR_UPDATE;
                end
            end

            NR_UPDATE: begin
                state_timeout <= 0;
                x_new = x - main_fsm_quotient;
                if (x_new > 32'sh00FF0000) x <= 32'sh00FF0000;
                else if (x_new < 32'shFF000000) x <= 32'shFF000000;
                else x <= x_new;
                iter_count <= iter_count + 1;
                state <= NR_X2_CALC;
            end

            DEFLATE_X2_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(x) * $signed(x);
                state <= DEFLATE_X2_PIPE;
            end

            DEFLATE_X2_PIPE: begin
                state_timeout <= 0;
                state <= DEFLATE_X2_STORE;
            end

            DEFLATE_X2_STORE: begin
                state_timeout <= 0;
                x2 <= clip(pipe_mul_a >>> INT_FRAC);
                state <= DEFLATE_X3_CALC;
            end

            DEFLATE_X3_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(x2) * $signed(x);
                state <= DEFLATE_X3_PIPE;
            end

            DEFLATE_X3_PIPE: begin
                state_timeout <= 0;
                state <= DEFLATE_X3_STORE;
            end

            DEFLATE_X3_STORE: begin
                state_timeout <= 0;
                x3 <= clip(pipe_mul_a >>> INT_FRAC);
                state <= DEFLATE_FX_CHECK_CALC;
            end

            DEFLATE_FX_CHECK_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(a) * $signed(x3);
                pipe_mul_b <= $signed(b) * $signed(x2);
                pipe_mul_c <= $signed(c) * $signed(x);
                state <= DEFLATE_FX_CHECK_PIPE;
            end

            DEFLATE_FX_CHECK_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                pipe_clip_c <= clip(pipe_mul_c >>> INT_FRAC);
                state <= DEFLATE_FX_CHECK_SUM;
            end

            DEFLATE_FX_CHECK_SUM: begin
                state_timeout <= 0;
                fx_check <= pipe_clip_a + pipe_clip_b + pipe_clip_c + d;
                state <= DEFLATE_COEFF_CALC;
            end

            DEFLATE_COEFF_CALC: begin
                state_timeout <= 0;
                a2 <= a;
                pipe_mul_a <= $signed(a) * $signed(x);
                pipe_mul_b <= $signed(b) * $signed(x);
                pipe_mul_c <= $signed(a) * $signed(x2);
                state <= DEFLATE_COEFF_PIPE;
            end

            DEFLATE_COEFF_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                pipe_clip_c <= clip(pipe_mul_c >>> INT_FRAC);
                state <= DEFLATE_COEFF_SUM;
            end

            DEFLATE_COEFF_SUM: begin
                state_timeout <= 0;
                b2 <= b + pipe_clip_a;
                c2 <= c + pipe_clip_b + pipe_clip_c;
                state <= DEFLATE_EVAL;
            end

            DEFLATE_EVAL: begin
                state_timeout <= 0;
                // KEY FIX: Check fx_check, not fx
                if ((abs32(fx_check) > 32'sh0010) && (retry_attempt < 5)) begin
                    retry_attempt <= retry_attempt + 1;
                    state <= NR_INIT;
                end else begin
                    root1_real <= x >>> SHIFT_INT_TO_IO;
                    root1_imag <= 24'h000000;
                    state <= QUAD_INIT_CALC;
                end
            end

            QUAD_INIT_CALC: begin
                state_timeout <= 0;
                pipe_mul_a <= $signed(b2) * $signed(b2);
                // KEY FIX: Calculate (a2<<2)*c2 BEFORE clipping to match original
                pipe_mul_b <= $signed(a2 << 2) * $signed(c2);
                neg_b2 <= -b2;
                two_a2 <= 2 * a2;
                state <= QUAD_INIT_PIPE;
            end

            QUAD_INIT_PIPE: begin
                state_timeout <= 0;
                pipe_clip_a <= clip(pipe_mul_a >>> INT_FRAC);
                pipe_clip_b <= clip(pipe_mul_b >>> INT_FRAC);
                state <= QUAD_INIT_SUM;
            end

            QUAD_INIT_SUM: begin
                state_timeout <= 0;
                disc <= pipe_clip_a - pipe_clip_b;
                state <= QUAD_SQRT_START;
            end

            QUAD_SQRT_START: begin
                state_timeout <= 0;
                sqrt_input <= (disc >= 0) ? disc : -disc;
                sqrt_start <= 1; // 1-cycle pulse
                state <= QUAD_SQRT_WAIT;
            end

            QUAD_SQRT_WAIT: begin
                if (sqrt_done) begin
                    state_timeout <= 0;
                    sqrt_disc <= sqrt_output;
                    state <= QUAD_PREP;
                end
            end

            QUAD_PREP: begin
                state_timeout <= 0;
                if (disc >= 0) begin
                    num1 <= neg_b2 + sqrt_disc;
                    num2 <= neg_b2 - sqrt_disc;
                end else begin
                    num1 <= neg_b2;
                    num2 <= sqrt_disc;
                end
                state <= QUAD_DIV1_REQ;
            end

            QUAD_DIV1_REQ: begin
                state_timeout <= 0;
                if (two_a2 == 0) begin
                    quad_result1 <= 0;
                    state <= QUAD_DIV2_REQ;
                end else begin
                    main_fsm_dividend <= {{INT_BITS{num1[INT_BITS-1]}}, num1} <<< INT_FRAC;
                    main_fsm_divisor <= two_a2;
                    main_fsm_div_req <= 1;
                    state <= QUAD_DIV1_WAIT;
                end
            end

            QUAD_DIV1_WAIT: begin
                main_fsm_div_req <= 1;
                if (main_fsm_div_done) begin
                    main_fsm_div_req <= 0;
                    state_timeout <= 0;
                    quad_result1 <= main_fsm_quotient;
                    state <= QUAD_DIV2_REQ;
                end
            end

            QUAD_DIV2_REQ: begin
                state_timeout <= 0;
                if (two_a2 == 0) begin
                    quad_result2 <= 0;
                    state <= QUAD_SOLVE;
                end else begin
                    main_fsm_dividend <= {{INT_BITS{num2[INT_BITS-1]}}, num2} <<< INT_FRAC;
                    main_fsm_divisor <= two_a2;
                    main_fsm_div_req <= 1;
                    state <= QUAD_DIV2_WAIT;
                end
            end

            QUAD_DIV2_WAIT: begin
                main_fsm_div_req <= 1;
                if (main_fsm_div_done) begin
                    main_fsm_div_req <= 0;
                    state_timeout <= 0;
                    quad_result2 <= main_fsm_quotient;
                    state <= QUAD_SOLVE;
                end
            end

            QUAD_SOLVE: begin
                state_timeout <= 0;
                if (disc >= 0) begin
                    root2_real <= quad_result2 >>> SHIFT_INT_TO_IO;
                    root3_real <= quad_result1 >>> SHIFT_INT_TO_IO;
                    root2_imag <= 24'h000000;
                    root3_imag <= 24'h000000;
                end else begin
                    root2_real <= quad_result1 >>> SHIFT_INT_TO_IO;
                    root3_real <= quad_result1 >>> SHIFT_INT_TO_IO;
                    root2_imag <= quad_result2 >>> SHIFT_INT_TO_IO;
                    root3_imag <= -(quad_result2 >>> SHIFT_INT_TO_IO);
                end
                state <= OUTPUT;
            end

            OUTPUT: begin
                done <= 1;
                busy <= 0;
                if (!start) state <= IDLE;
            end

            ERROR: begin
                done <= 1;
                busy <= 0;
                root1_real <= 24'h000000;
                root1_imag <= 24'h000000;
                root2_real <= 24'h000000;
                root2_imag <= 24'h000000;
                root3_real <= 24'h000000;
                root3_imag <= 24'h000000;
                if (!start) state <= IDLE;
            end

            default: state <= ERROR;
        endcase
    end
end

endmodule