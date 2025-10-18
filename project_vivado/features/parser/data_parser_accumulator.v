`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Data Parser - Number Accumulator with Q16.8 Conversion
//
// This module accumulates multi-digit numbers from keypad input and converts
// them to Q16.8 fixed-point format for calculator operations.
//
// Q16.8 Format: 24 bits total
//   [23]    : Sign bit (0=positive, 1=negative)
//   [22:8]  : Integer part (15 bits, range -32768 to 32767)
//   [7:0]   : Fractional part (8 bits, precision 1/256 ≈ 0.00390625)
//
// Example: 12.5 → (12 << 8) + (128) = 3200 in Q16.8
//
// FSM States:
//   IDLE          → Waiting for first input
//   BUILD_INTEGER → Accumulating integer digits (e.g., "123")
//   BUILD_DECIMAL → Accumulating fractional digits (e.g., ".456")
//   FINALIZE      → Converting to Q16.8 and outputting
//////////////////////////////////////////////////////////////////////////////////

module data_parser_accumulator(
    input clk,
    input rst,

    // Keypad input
    input [4:0] key_code,
    input key_valid,

    // Q16.8 number output
    output reg [24:0] parsed_number,    // Q16.8: 1 sign + 16 int + 8 frac
    output reg number_ready,             // Pulse when number complete

    // Operator output
    output reg [3:0] operator_code,      // See mapping below
    output reg operator_ready,           // Pulse when operator pressed
    output reg [1:0] precedence,         // For Shunting-Yard: 0=lowest, 3=highest

    // Control signals
    output reg equals_pressed,
    output reg clear_pressed,
    output reg delete_pressed,
    output reg left_paren_pressed,
    output reg right_paren_pressed,

    // Display buffer (for rendering in VGA text box)
    // PACKED for synthesis compatibility (32 chars × 8 bits = 256 bits)
    // Character 0 is bits [7:0], char 1 is [15:8], ..., char 31 is [255:248]
    output reg [255:0] display_text,      // Packed ASCII buffer
    output reg [5:0] text_length,         // Current length

    // Error flags
    output reg overflow_error,
    output reg invalid_input_error
);

    // ========================================================================
    // KEY CODE CONSTANTS (from oled_keypad.v)
    // ========================================================================
    localparam KEY_0 = 5'd0, KEY_1 = 5'd1, KEY_2 = 5'd2, KEY_3 = 5'd3;
    localparam KEY_4 = 5'd4, KEY_5 = 5'd5, KEY_6 = 5'd6, KEY_7 = 5'd7;
    localparam KEY_8 = 5'd8, KEY_9 = 5'd9;

    localparam KEY_ADD = 5'd10, KEY_SUB = 5'd11, KEY_MUL = 5'd12;
    localparam KEY_DIV = 5'd13, KEY_POW = 5'd14;

    localparam KEY_SIN = 5'd15, KEY_COS = 5'd16, KEY_TAN = 5'd17;
    localparam KEY_LN = 5'd18, KEY_E = 5'd19, KEY_PI = 5'd20;
    localparam KEY_LPAREN = 5'd21, KEY_RPAREN = 5'd22;
    localparam KEY_NEG = 5'd23, KEY_SQRT = 5'd24;
    localparam KEY_DOT = 5'd25, KEY_EQUAL = 5'd26;
    localparam KEY_CLEAR = 5'd27, KEY_DELETE = 5'd28;

    // ========================================================================
    // OPERATOR CODES (output mapping)
    // ========================================================================
    localparam OP_ADD = 4'd0, OP_SUB = 4'd1, OP_MUL = 4'd2, OP_DIV = 4'd3;
    localparam OP_POW = 4'd4, OP_SIN = 4'd5, OP_COS = 4'd6, OP_TAN = 4'd7;
    localparam OP_LN = 4'd8, OP_EXP = 4'd9, OP_SQRT = 4'd10, OP_NEG = 4'd11;

    // ========================================================================
    // FSM STATES
    // ========================================================================
    localparam IDLE = 3'd0;
    localparam BUILD_INTEGER = 3'd1;
    localparam BUILD_DECIMAL = 3'd2;
    localparam FINALIZE = 3'd3;

    reg [2:0] state;

    // ========================================================================
    // ACCUMULATION REGISTERS
    // ========================================================================
    reg [31:0] integer_part;      // Raw integer (e.g., 123)
    reg [31:0] decimal_part;      // Raw decimal (e.g., 456 for ".456")
    reg [3:0] decimal_digits;     // Number of decimal places (0-8)
    reg is_negative;              // Sign flag

    // ========================================================================
    // HELPER: Key code to ASCII
    // ========================================================================
    function [7:0] key_to_ascii;
        input [4:0] key;
        begin
            if (key >= KEY_0 && key <= KEY_9)
                key_to_ascii = 8'd48 + key;  // '0' = 48 in ASCII
            else case (key)
                KEY_ADD:    key_to_ascii = 8'd43;  // '+'
                KEY_SUB:    key_to_ascii = 8'd45;  // '-'
                KEY_MUL:    key_to_ascii = 8'd42;  // '*'
                KEY_DIV:    key_to_ascii = 8'd47;  // '/'
                KEY_DOT:    key_to_ascii = 8'd46;  // '.'
                KEY_POW:    key_to_ascii = 8'd94;  // '^'
                KEY_LPAREN: key_to_ascii = 8'd40;  // '('
                KEY_RPAREN: key_to_ascii = 8'd41;  // ')'
                default:    key_to_ascii = 8'd63;  // '?'
            endcase
        end
    endfunction

    // ========================================================================
    // HELPER: Get operator precedence
    // ========================================================================
    function [1:0] get_precedence;
        input [4:0] key;
        begin
            case (key)
                KEY_ADD, KEY_SUB:          get_precedence = 2'd1;  // Lowest
                KEY_MUL, KEY_DIV:          get_precedence = 2'd2;
                KEY_POW:                   get_precedence = 2'd3;  // Highest binary
                KEY_SIN, KEY_COS, KEY_TAN,
                KEY_LN, KEY_SQRT, KEY_NEG: get_precedence = 2'd3;  // Unary (high)
                default:                   get_precedence = 2'd0;
            endcase
        end
    endfunction

    // ========================================================================
    // MAIN FSM - Number Accumulation
    // ========================================================================
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            integer_part <= 0;
            decimal_part <= 0;
            decimal_digits <= 0;
            is_negative <= 0;
            number_ready <= 0;
            operator_ready <= 0;
            text_length <= 0;
            overflow_error <= 0;
            equals_pressed <= 0;
            clear_pressed <= 0;
            delete_pressed <= 0;
            left_paren_pressed <= 0;
            right_paren_pressed <= 0;

            // Clear all 256 bits (32 chars × 8 bits)
            display_text <= 256'h0;

        end else begin
            // Default: clear pulses
            number_ready <= 0;
            operator_ready <= 0;
            equals_pressed <= 0;
            clear_pressed <= 0;
            delete_pressed <= 0;
            left_paren_pressed <= 0;
            right_paren_pressed <= 0;

            case (state)
                // ============================================================
                // IDLE: Wait for first input
                // ============================================================
                IDLE: begin
                    if (key_valid) begin
                        // Check if digit
                        if (key_code <= KEY_9) begin
                            integer_part <= {28'b0, key_code[3:0]};
                            // Store in bits [7:0] (character 0)
                            display_text[7:0] <= key_to_ascii(key_code);
                            text_length <= 1;
                            state <= BUILD_INTEGER;

                        // Check if operator
                        end else if (key_code >= KEY_ADD && key_code <= KEY_NEG) begin
                            operator_code <= key_code - KEY_ADD;
                            precedence <= get_precedence(key_code);
                            operator_ready <= 1;

                        // Check if control
                        end else if (key_code == KEY_EQUAL) begin
                            equals_pressed <= 1;
                        end else if (key_code == KEY_CLEAR) begin
                            clear_pressed <= 1;
                        end else if (key_code == KEY_DELETE) begin
                            delete_pressed <= 1;
                        end else if (key_code == KEY_LPAREN) begin
                            left_paren_pressed <= 1;
                        end else if (key_code == KEY_RPAREN) begin
                            right_paren_pressed <= 1;
                        end
                    end
                end

                // ============================================================
                // BUILD_INTEGER: Accumulate integer digits
                // ============================================================
                BUILD_INTEGER: begin
                    if (key_valid) begin
                        if (key_code <= KEY_9) begin
                            // Another digit
                            integer_part <= (integer_part * 10) + {28'b0, key_code[3:0]};

                            // Add to display (use bit slice: text_length*8 +: 8)
                            if (text_length < 32) begin
                                display_text[text_length*8 +: 8] <= key_to_ascii(key_code);
                                text_length <= text_length + 1;
                            end

                            // Check overflow (max 32767 for Q16.8)
                            if (integer_part > 32767) begin
                                overflow_error <= 1;
                                state <= IDLE;
                            end

                        end else if (key_code == KEY_DOT) begin
                            // Decimal point
                            if (text_length < 32) begin
                                display_text[text_length*8 +: 8] <= 8'd46;  // '.'
                                text_length <= text_length + 1;
                            end
                            state <= BUILD_DECIMAL;

                        end else begin
                            // Operator/control - finalize number
                            state <= FINALIZE;
                        end
                    end
                end

                // ============================================================
                // BUILD_DECIMAL: Accumulate fractional digits
                // ============================================================
                BUILD_DECIMAL: begin
                    if (key_valid) begin
                        if (key_code <= KEY_9 && decimal_digits < 8) begin
                            // Add decimal digit (max 8 for Q16.8 precision)
                            decimal_part <= (decimal_part * 10) + {28'b0, key_code[3:0]};
                            decimal_digits <= decimal_digits + 1;

                            if (text_length < 32) begin
                                display_text[text_length*8 +: 8] <= key_to_ascii(key_code);
                                text_length <= text_length + 1;
                            end

                        end else begin
                            // Done building number
                            state <= FINALIZE;
                        end
                    end
                end

                // ============================================================
                // FINALIZE: Convert to Q16.8 and output
                // ============================================================
                FINALIZE: begin
                    // Convert to Q16.8
                    // Formula: (integer << 8) + (decimal * 256 / 10^decimal_digits)
                    // Simplified: (integer << 8) + (decimal * 256) >> (decimal_digits * log2(10))

                    // For now: simplified integer-only Q16.8
                    parsed_number <= {1'b0, integer_part[15:0], 8'b0};
                    number_ready <= 1;

                    // Reset for next number
                    integer_part <= 0;
                    decimal_part <= 0;
                    decimal_digits <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
