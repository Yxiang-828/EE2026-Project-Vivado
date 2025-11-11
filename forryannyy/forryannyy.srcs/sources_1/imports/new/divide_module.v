`timescale 1ns / 1ps

module divider_module(
    input clk,
    input clr,
    input signed [24:0] a,
    input signed [24:0] b,
    output reg signed [24:0] val,
    output reg done,
    output reg overflow
);
    reg [24:0] a_reg, b_reg;
    wire [24:0] abs_a, abs_b;
    wire a_overflow, b_overflow;
    reg [24:0] quotient_reg;
    reg sign_reg;
    reg next_ovf;
    wire [24:0] sm_result;
    wire [24:0] tc_result;

    // Sequential division state
    reg [31:0] dividend_reg;
    reg [31:0] remainder_reg;
    reg [31:0] quotient_temp;
    reg [5:0] bit_counter; // 0-31 for 32 iterations
    reg [23:0] divisor_reg;

    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CALCULATION = 3'b010;
    localparam DONE_STATE = 3'b011;

    twos_complement_to_sign_magnitude twos_complement_to_sign_magnitude_a (
        .in_num(a_reg),
        .out_num(abs_a),
        .overflow(a_overflow)
    );

    twos_complement_to_sign_magnitude twos_complement_to_sign_magnitude_b (
        .in_num(b_reg),
        .out_num(abs_b),
        .overflow(b_overflow)
    );

    assign sm_result = {sign_reg, quotient_reg[23:0]};
    sign_magnitude_to_twos_complement conv_result(
        .in_num(sm_result),
        .out_num(tc_result)
    );
    
    reg [31:0] new_remainder;
    reg [31:0] new_quotient;

    always @(posedge clk or posedge clr) begin
        if (clr) begin
            val <= 25'b0;
            overflow <= 1'b0;
            done <= 1'b0;
            quotient_reg <= 25'b0;
            sign_reg <= 1'b0;
            a_reg <= 25'b0;
            b_reg <= 25'b0;
            state <= IDLE;
            next_ovf <= 1'b0;
            dividend_reg <= 32'b0;
            remainder_reg <= 32'b0;
            quotient_temp <= 32'b0;
            bit_counter <= 6'd0;
            divisor_reg <= 24'b0;
        end else begin
            case (state)
            
                IDLE: 
                begin
                    done <= 1'b0;
                    a_reg <= a;
                    b_reg <= b;
                    state <= SETUP;
                end

                SETUP:
                begin
                    // Check for error conditions
                    if (b_reg == 25'd0 || a_overflow || b_overflow) begin
                        quotient_reg <= 25'd0;
                        sign_reg <= 1'b0;
                        next_ovf <= 1'b1;
                        state <= DONE_STATE;
                    end else if (a_reg == 25'd0) begin
                        quotient_reg <= 25'd0;
                        sign_reg <= 1'b0;
                        next_ovf <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Initialize division variables
                        dividend_reg <= abs_a[23:0] << 8;
                        divisor_reg <= abs_b[23:0];
                        quotient_temp <= 32'b0;
                        remainder_reg <= 32'b0;
                        bit_counter <= 6'd31; // Start from bit 31, count down to 0
                        sign_reg <= a_reg[24] ^ b_reg[24];
                        next_ovf <= 1'b0;
                        state <= CALCULATION;
                    end
                end

                CALCULATION: 
                begin
                    // Process one bit per clock cycle
                    // Compute new remainder by shifting left and bringing in next bit from dividend
                    
                    
                    new_remainder = (remainder_reg << 1) | ((dividend_reg >> bit_counter) & 1);
                    new_quotient = quotient_temp;
                    
                    // Check if we can subtract
                    if (new_remainder >= divisor_reg) begin
                        remainder_reg <= new_remainder - divisor_reg;
                        new_quotient = quotient_temp | (1 << bit_counter);
                    end else begin
                        remainder_reg <= new_remainder;
                    end
                    
                    quotient_temp <= new_quotient;
                    
                    // Check if we're done with all bits
                    if (bit_counter == 6'd0) begin
                        // Check for overflow: if any bits above bit 23 are set
                        if (new_quotient[31:24] != 8'b0) begin
                            quotient_reg <= 25'd0;
                            next_ovf <= 1'b1;
                        end else begin
                            quotient_reg <= new_quotient[23:0];
                            next_ovf <= 1'b0;
                        end
                        state <= DONE_STATE;
                    end else begin
                        bit_counter <= bit_counter - 1;
                    end
                end

                DONE_STATE:
                begin
                    val <= tc_result;
                    overflow <= next_ovf;
                    done <= 1'b1;
                    state <= IDLE; // Ready for next operation
                end

            endcase
        end
    end
endmodule