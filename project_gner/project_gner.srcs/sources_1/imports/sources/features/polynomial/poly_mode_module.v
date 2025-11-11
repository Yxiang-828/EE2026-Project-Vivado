`timescale 1ns / 1ps

module poly_mode_module (
    input clk,
    input reset,
    input [4:0] btn,
    input [511:0] shared_buffer,  // Shared equation buffer (packed: 64 chars × 8 bits)
    input [6:0] shared_length,     // Current length
    input poly_key_strobe,
    input prev_poly_key_strobe,
    input [7:0] poly_ascii_char,
    output reg delete_signal,
    output reg clear_signal,
    output reg equal_signal,

    // VGA Interface
    input [9:0] vga_x,
    input [9:0] vga_y,
    output [11:0] vga_data,

    // Coefficient interface (upgraded to Q18.6 format - 24-bit signed)
    // coeff_a?_str driven from regs internally, so declare as reg outputs
    output reg signed [23:0] coeff_a3, coeff_a2, coeff_a1, coeff_a0,
    output reg [79:0] coeff_a3_str, coeff_a2_str, coeff_a1_str, coeff_a0_str,
    output reg solve_trigger,
    input solve_done,
    input signed [23:0] root_real_1, root_imag_1,
    input signed [23:0] root_real_2, root_imag_2,
    input signed [23:0] root_real_3, root_imag_3,
    input signed [23:0] root_real_5, root_imag_5
);

    // Mode constants
    localparam MODE_POLY = 3'b100;

    // ASCII constants
    localparam ASCII_C_UPPER = 8'h43;
    localparam ASCII_C_LOWER = 8'h63;
    localparam ASCII_D_UPPER = 8'h44;
    localparam ASCII_D_LOWER = 8'h64;
    localparam ASCII_EQUALS = 8'h3D;
    localparam ASCII_DIGIT_0 = 8'h30;
    localparam ASCII_DIGIT_9 = 8'h39;
    localparam ASCII_DOT = 8'h2E;
    localparam ASCII_MINUS = 8'h2D;
    localparam ASCII_SPACE = 8'h20;

    // Navigation states (cubic): active_coeff_index maps to A=a3, B=a2, C=a1, D=a0
    reg [1:0] active_coeff_index;  // 0=a3(A), 1=a2(B), 2=a1(C), 3=a0(D)
    reg [3:0] input_digit_index;   // 0-9 for digit position in coefficient
    reg [79:0] coeff_str [3:0];   // Strings for display (10 chars each)
    reg [3:0] coeff_lengths [3:0]; // Lengths of each coefficient
    reg signed [23:0] coeff_val [3:0];    // signed Q18.6 values (upgraded from Q8.8)

    // Smart input validation registers for 2.2 format (2 integer + 2 fractional digits)
    reg [3:0] has_dot [3:0];              // Track if dot has been entered for each coefficient
    reg [3:0] integer_digits [3:0];      // Track integer digits entered for each coefficient
    reg [3:0] fractional_digits [3:0];   // Track fractional digits entered for each coefficient

    // Coefficient storage (signed Q16.8 format - 24-bit)
    initial begin
    // Initialize cubic coefficients (a3..a0)
    coeff_a0 = 24'sh000000;
    coeff_a1 = 24'sh000000;
    coeff_a2 = 24'sh000000;
    coeff_a3 = 24'sh000000;
    coeff_str[0] = 80'h20202020202020202020; // A: a3
    coeff_str[1] = 80'h20202020202020202020; // B: a2
    coeff_str[2] = 80'h20202020202020202020; // C: a1
    coeff_str[3] = 80'h20202020202020202020; // D: a0
    coeff_lengths[0] <= 4'd0; coeff_lengths[1] <= 4'd0; coeff_lengths[2] <= 4'd0;
    coeff_lengths[3] <= 4'd0;
    coeff_val[0] <= 24'h000000; coeff_val[1] <= 24'h000000; coeff_val[2] <= 24'h000000;
    coeff_val[3] <= 24'h000000;
    active_coeff_index = 2'd0;  // Start with A (a3)
        input_digit_index = 4'd0;
        solve_trigger = 1'b0;
        delete_signal = 1'b0;
        clear_signal = 1'b0;
        equal_signal = 1'b0;
        // Initialize smart validation registers
        has_dot[0] = 4'd0; has_dot[1] = 4'd0; has_dot[2] = 4'd0; has_dot[3] = 4'd0;
        integer_digits[0] = 4'd0; integer_digits[1] = 4'd0; integer_digits[2] = 4'd0; integer_digits[3] = 4'd0;
        fractional_digits[0] = 4'd0; fractional_digits[1] = 4'd0; fractional_digits[2] = 4'd0; fractional_digits[3] = 4'd0;
    end

    // Drive reg string outputs from internal coeff_str (map cubic into the legacy 6-slot interface)
    always @* begin
        // Map cubic A..D to a3..a0 slots expected by drawer
        coeff_a3_str = coeff_str[0];
        coeff_a2_str = coeff_str[1];
        coeff_a1_str = coeff_str[2];
        coeff_a0_str = coeff_str[3];
    end

    // Drive Q8.8 outputs (map cubic values into legacy a3..a0 outputs)
    always @* begin
        coeff_a3 = coeff_val[0];
        coeff_a2 = coeff_val[1];
        coeff_a1 = coeff_val[2];
        coeff_a0 = coeff_val[3];
    end

    // Parse coefficient string to signed Q18.6 fixed-point value (24-bit)
    function signed [23:0] parse_coefficient;
        input [79:0] str;   // 10 chars
        input [3:0] len;
        integer i;
        reg signed [23:0] int_val, frac_val;
        reg is_negative;
        reg found_dot;
        reg [3:0] int_d0, int_d1, int_d2, int_d3, int_d4;  // Integer digits (up to 5 digits)
        reg [3:0] frac_d0, frac_d1, frac_d2;               // Fractional digits
    begin
        int_val = 24'sd0;
        frac_val = 24'sd0;
        is_negative = 1'b0;
        found_dot = 1'b0;
        i = 0;
        int_d0 = 0; int_d1 = 0; int_d2 = 0; int_d3 = 0; int_d4 = 0;
        frac_d0 = 0; frac_d1 = 0; frac_d2 = 0;

        // Check for negative sign
        if (i < len && str[i*8 +: 8] == ASCII_MINUS) begin
            is_negative = 1'b1;
            i = i + 1;
        end

        // Parse integer part - MANUAL UNROLL (5 digits max for ±32767)
        if (i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            int_d4 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            int_d0 = int_d1; int_d1 = int_d2; int_d2 = int_d3; int_d3 = int_d4;
            int_d4 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            int_d0 = int_d1; int_d1 = int_d2; int_d2 = int_d3; int_d3 = int_d4;
            int_d4 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            int_d0 = int_d1; int_d1 = int_d2; int_d2 = int_d3; int_d3 = int_d4;
            int_d4 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            int_d0 = int_d1; int_d1 = int_d2; int_d2 = int_d3; int_d3 = int_d4;
            int_d4 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        // Optimized: build value iteratively using shifts (10*x = 8x+2x)
        int_val = int_d0;
        int_val = (int_val << 3) + (int_val << 1) + int_d1;  // int_val = 10*d0 + d1
        int_val = (int_val << 3) + (int_val << 1) + int_d2;  // int_val = 10*(10*d0+d1) + d2
        int_val = (int_val << 3) + (int_val << 1) + int_d3;  // int_val = 10*(...) + d3
        int_val = (int_val << 3) + (int_val << 1) + int_d4;  // int_val = 10*(...) + d4

        // Check for decimal point
        if (i < len && str[i*8 +: 8] == ASCII_DOT) begin
            found_dot = 1'b1;
            i = i + 1;
        end

        // Parse fractional part (up to 3 digits)
        if (found_dot && i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            frac_d0 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (found_dot && i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            frac_d1 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end
        if (found_dot && i < len && str[i*8 +: 8] >= ASCII_DIGIT_0 && str[i*8 +: 8] <= ASCII_DIGIT_9) begin
            frac_d2 = str[i*8 +: 8] - ASCII_DIGIT_0;
            i = i + 1;
        end

        // Convert fractional digits to Q18.6 format - optimized with shift-add
        // Build fractional value: frac_val = d0*100 + d1*10 + d2
        frac_val = frac_d0;
        frac_val = (frac_val << 3) + (frac_val << 1) + frac_d1;  // 10*d0 + d1
        frac_val = (frac_val << 3) + (frac_val << 1) + frac_d2;  // 10*(10*d0+d1) + d2
        // Now convert to Q18.6: multiply by 64, divide by 1000
        // Optimize: 64/1000 ≈ 0.064 ≈ 1/16 (close enough for 3 decimal places)
        // Better: (val * 64) >> 10 (since 1000 ≈ 1024 = 2^10)
        frac_val = (frac_val << 6) >> 10;  // Multiply by 64, divide by ~1000

        // Combine integer and fractional parts (Q18.6: 18 int bits, 6 frac bits)
        parse_coefficient = (int_val << 6) | (frac_val & 24'h00003F);
        if (is_negative) parse_coefficient = -parse_coefficient;
    end
    endfunction

    // Simple key processing logic
    always @(posedge clk) begin
        if (reset) begin
            active_coeff_index <= 2'd0;
            input_digit_index <= 4'd0;
            solve_trigger <= 1'b0;
            coeff_str[0] <= 80'h20202020202020202020;
            coeff_str[1] <= 80'h20202020202020202020;
            coeff_str[2] <= 80'h20202020202020202020;
            coeff_str[3] <= 80'h20202020202020202020;
            coeff_lengths[0] <= 4'd0; coeff_lengths[1] <= 4'd0; coeff_lengths[2] <= 4'd0;
            coeff_lengths[3] <= 4'd0;
            coeff_val[0] <= 24'sh000000; coeff_val[1] <= 24'sh000000; coeff_val[2] <= 24'sh000000;
            coeff_val[3] <= 24'sh000000;
            delete_signal <= 1'b0;
            clear_signal <= 1'b0;
            equal_signal <= 1'b0;
            // Reset smart validation registers
            has_dot[0] <= 4'd0; has_dot[1] <= 4'd0; has_dot[2] <= 4'd0; has_dot[3] <= 4'd0;
            integer_digits[0] <= 4'd0; integer_digits[1] <= 4'd0; integer_digits[2] <= 4'd0; integer_digits[3] <= 4'd0;
            fractional_digits[0] <= 4'd0; fractional_digits[1] <= 4'd0; fractional_digits[2] <= 4'd0; fractional_digits[3] <= 4'd0;
        end else begin
            // Reset signals
            delete_signal <= 1'b0;
            clear_signal <= 1'b0;
            equal_signal <= 1'b0;
            solve_trigger <= 1'b0;

            // Process key events
            if (poly_key_strobe && !prev_poly_key_strobe) begin
                case (poly_ascii_char)
                    ASCII_C_UPPER, ASCII_C_LOWER: begin
                        // Clear cubic coefficients
                        coeff_str[0] <= 80'h20202020202020202020;
                        coeff_str[1] <= 80'h20202020202020202020;
                        coeff_str[2] <= 80'h20202020202020202020;
                        coeff_str[3] <= 80'h20202020202020202020;
                        coeff_lengths[0] <= 4'd0; coeff_lengths[1] <= 4'd0; coeff_lengths[2] <= 4'd0;
                        coeff_lengths[3] <= 4'd0;
                        coeff_val[0] <= 24'h000000; coeff_val[1] <= 24'h000000; coeff_val[2] <= 24'h000000;
                        coeff_val[3] <= 24'h000000;
                        active_coeff_index <= 2'd0;
                        input_digit_index <= 4'd0;
                        clear_signal <= 1'b1;
                        // Reset smart validation registers on clear
                        has_dot[0] <= 4'd0; has_dot[1] <= 4'd0; has_dot[2] <= 4'd0; has_dot[3] <= 4'd0;
                        integer_digits[0] <= 4'd0; integer_digits[1] <= 4'd0; integer_digits[2] <= 4'd0; integer_digits[3] <= 4'd0;
                        fractional_digits[0] <= 4'd0; fractional_digits[1] <= 4'd0; fractional_digits[2] <= 4'd0; fractional_digits[3] <= 4'd0;
                    end

                    ASCII_D_UPPER, ASCII_D_LOWER: begin
                        // Delete/backspace with smart validation register updates
                        if (input_digit_index > 0) begin
                            // Delete last character in current coefficient
                            coeff_str[active_coeff_index][(input_digit_index-1)*8 +:8] <= ASCII_SPACE;
                            coeff_lengths[active_coeff_index] <= coeff_lengths[active_coeff_index] - 1;
                            input_digit_index <= input_digit_index - 1;

                            // Update validation registers based on deleted character
                            if (coeff_str[active_coeff_index][(input_digit_index-1)*8 +:8] == ASCII_DOT) begin
                                // Deleted a dot
                                has_dot[active_coeff_index] <= 0;
                                fractional_digits[active_coeff_index] <= 0;
                            end else if (coeff_str[active_coeff_index][(input_digit_index-1)*8 +:8] == ASCII_MINUS) begin
                                // Deleted a minus sign - don't touch integer_digits
                                // (minus signs aren't counted as integer digits)
                            end else if (has_dot[active_coeff_index]) begin
                                // Deleted a fractional digit
                                fractional_digits[active_coeff_index] <= fractional_digits[active_coeff_index] - 1;
                            end else begin
                                // Deleted an integer digit
                                integer_digits[active_coeff_index] <= integer_digits[active_coeff_index] - 1;
                            end
                        end else if (active_coeff_index > 0) begin
                            // Move to previous coefficient
                            active_coeff_index <= active_coeff_index - 1;
                            input_digit_index <= coeff_lengths[active_coeff_index - 1];
                        end
                        delete_signal <= 1'b1;
                    end

                    ASCII_EQUALS: begin
                        // Parse current coeff_str to Q8.8 before advancing
                        coeff_val[active_coeff_index] <= parse_coefficient(
                            coeff_str[active_coeff_index],
                            coeff_lengths[active_coeff_index]
                        );
                        // Advance to next coefficient or trigger solve (cubic: 4 coeffs)
                        if (active_coeff_index < 3) begin
                            active_coeff_index <= active_coeff_index + 1;
                            input_digit_index <= 4'd0;
                            // Reset validation registers for next coefficient
                            has_dot[active_coeff_index + 1] <= 4'd0;
                            integer_digits[active_coeff_index + 1] <= 4'd0;
                            fractional_digits[active_coeff_index + 1] <= 4'd0;
                        end else begin
                            // All coefficients entered, trigger solve
                            solve_trigger <= 1'b1;
                        end
                        equal_signal <= 1'b1;
                    end

                    default: begin
                        // Smart input validation for 2.2 format (2 integer + 2 fractional digits)
                        if (poly_ascii_char == ASCII_MINUS &&
                            coeff_lengths[active_coeff_index] == 0 &&
                            integer_digits[active_coeff_index] == 0) begin
                            // Allow minus sign only at the very beginning
                            coeff_str[active_coeff_index][input_digit_index*8 +:8] <= poly_ascii_char;
                            coeff_lengths[active_coeff_index] <= coeff_lengths[active_coeff_index] + 1;
                            input_digit_index <= input_digit_index + 1;
                            // NOTE: Don't increment integer_digits for minus sign
                        end else if (poly_ascii_char >= ASCII_DIGIT_0 && poly_ascii_char <= ASCII_DIGIT_9) begin
                            // Digit input validation
                            if (!has_dot[active_coeff_index] && integer_digits[active_coeff_index] < 2) begin
                                // Integer part: allow up to 2 digits before decimal
                                coeff_str[active_coeff_index][input_digit_index*8 +:8] <= poly_ascii_char;
                                coeff_lengths[active_coeff_index] <= coeff_lengths[active_coeff_index] + 1;
                                input_digit_index <= input_digit_index + 1;
                                integer_digits[active_coeff_index] <= integer_digits[active_coeff_index] + 1;
                            end else if (has_dot[active_coeff_index] && fractional_digits[active_coeff_index] < 3) begin
                                // Fractional part: allow up to 3 digits after decimal (matches parser)
                                coeff_str[active_coeff_index][input_digit_index*8 +:8] <= poly_ascii_char;
                                coeff_lengths[active_coeff_index] <= coeff_lengths[active_coeff_index] + 1;
                                input_digit_index <= input_digit_index + 1;
                                fractional_digits[active_coeff_index] <= fractional_digits[active_coeff_index] + 1;
                            end
                            // Reject digits if format limits exceeded
                        end else if (poly_ascii_char == ASCII_DOT && !has_dot[active_coeff_index] && integer_digits[active_coeff_index] > 0) begin
                            // Allow decimal point only once, after at least one integer digit
                            coeff_str[active_coeff_index][input_digit_index*8 +:8] <= poly_ascii_char;
                            coeff_lengths[active_coeff_index] <= coeff_lengths[active_coeff_index] + 1;
                            input_digit_index <= input_digit_index + 1;
                            has_dot[active_coeff_index] <= 1;
                        end
                        // Reject all other characters (including extra dots, invalid positions)
                    end
                endcase
            end
        end
    end

    // VGA Display Module
    poly_drawer_vga poly_vga_inst (
        .clk(clk),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(vga_data),
        .active_coeff_index(active_coeff_index),
        .coeff_a3_str(coeff_a3_str),
        .coeff_a2_str(coeff_a2_str), .coeff_a1_str(coeff_a1_str), .coeff_a0_str(coeff_a0_str),
        .coeff_a3(coeff_a3),
        .coeff_a2(coeff_a2), .coeff_a1(coeff_a1), .coeff_a0(coeff_a0),
        .solve_done(solve_done),
        .root_real_1(root_real_1), .root_imag_1(root_imag_1),
        .root_real_2(root_real_2), .root_imag_2(root_imag_2),
        .root_real_3(root_real_3), .root_imag_3(root_imag_3),
        .input_digit_index(input_digit_index)
    );

endmodule