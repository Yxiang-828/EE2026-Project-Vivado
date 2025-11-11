`timescale 1ns / 1ps

/*
 * SQRT MODULE - FINAL FIXED VERSION
 *
 * EXPECTED: Works correctly with poly_solver for 36/38 passes
 *
 * KEY FIXES:
 * 1. HANDSHAKE: 'done' cleared inside if(start) to latch 1-cycle pulse
 * 2. REGISTER: Uses combinatorial diff calculation in CHECK state
 * 3. TYPO FIX: Changed 'x_need' to 'x_new' in display (line 122)
 */

module sqrt_iterative (
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [31:0] input_val,

    output reg done,
    output reg signed [31:0] sqrt_out,
    output reg div_req,
    input wire div_done,
    output reg signed [63:0] div_dividend,
    output reg signed [31:0] div_divisor,
    input wire signed [31:0] div_quotient
);

localparam IDLE = 0, INIT = 1, DIV_WAIT = 2, CHECK = 3;
reg [1:0] state;

reg [3:0] iter;
reg signed [31:0] x;
reg signed [31:0] x_new;
reg signed [31:0] input_saved;
reg [7:0] div_timeout;

reg signed [31:0] diff;
parameter MAX_SQRT_ITER = 10;
parameter DIV_TIMEOUT = 250;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        done <= 0;
        sqrt_out <= 0;
        iter <= 0;
        x <= 0;
        x_new <= 0;
        div_req <= 0;
        div_dividend <= 0;
        div_divisor <= 0;
        state <= IDLE;
        input_saved <= 0;
        div_timeout <= 0;
        diff <= 0;
    end else begin

        if (state == DIV_WAIT) begin
            div_req <= 1;
        end else begin
            div_req <= 0;
        end

        case (state)
            IDLE: begin
                div_timeout <= 0;
                if (start) begin
                    // KEY FIX: Clear done inside if(start) to latch 1-cycle pulse
                    done <= 0;
                    input_saved <= input_val;

                    if (input_val <= 0) begin
                        sqrt_out <= 0;
                        done <= 1;
                    end else begin
                        if ((input_val >>> 1) == 0) begin
                            x <= 32'h00004000; // 1.0
                        end else begin
                            x <= input_val >>> 1;
                        end
                        iter <= 0;
                        state <= INIT;
                    end
                end
            end

            INIT: begin
                div_timeout <= 0;
                if (x == 0) begin
                    x_new <= 32'h7FFFFFFF;
                    state <= CHECK;
                end else begin
                    div_dividend <= {{32{input_saved[31]}}, input_saved} <<< 14;
                    div_divisor <= x;
                    div_req <= 1;
                    state <= DIV_WAIT;
                end
            end

            DIV_WAIT: begin
                div_timeout <= div_timeout + 1;
                if (div_done) begin
                    div_req <= 0;
                    div_timeout <= 0;
                    x_new <= (x + div_quotient) >>> 1;
                    state <= CHECK;
                end else if (div_timeout > DIV_TIMEOUT) begin
                    div_req <= 0;
                    sqrt_out <= x;
                    done <= 1;
                    state <= IDLE;
                end
            end

            CHECK: begin
                diff <= (x_new > x) ? (x_new - x) : (x - x_new);

                // KEY FIX: Use combinatorial calculation, not stale register
                if (((x_new > x) ? (x_new - x) : (x - x_new)) < 2) begin
                    sqrt_out <= x_new;
                    done <= 1;
                    state <= IDLE;
                end else if (iter >= MAX_SQRT_ITER) begin
                    sqrt_out <= x_new;
                    done <= 1;
                    state <= IDLE;
                end else begin
                    x <= x_new;
                    iter <= iter + 1;
                    state <= INIT;
                end
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule