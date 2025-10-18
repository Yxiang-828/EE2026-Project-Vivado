`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Simple Key to ASCII Converter
//
// Maps 5-bit key codes to ASCII characters for calculator/graph modes.
// This replaces the complex data_parser_accumulator for basic equation building.
//////////////////////////////////////////////////////////////////////////////////

module key_to_ascii_converter(
    input clk,
    input rst,

    // Keypad input
    input [4:0] key_code,
    input key_valid,

    // ASCII output
    output reg [7:0] ascii_char,
    output reg char_valid
);

    // Key code to ASCII mapping (from oled_keypad.v constants)
    localparam KEY_0 = 5'd0, KEY_1 = 5'd1, KEY_2 = 5'd2, KEY_3 = 5'd3;
    localparam KEY_4 = 5'd4, KEY_5 = 5'd5, KEY_6 = 5'd6, KEY_7 = 5'd7;
    localparam KEY_8 = 5'd8, KEY_9 = 5'd9;
    localparam KEY_ADD = 5'd10, KEY_SUB = 5'd11, KEY_MUL = 5'd12, KEY_DIV = 5'd13;
    localparam KEY_POW = 5'd14;
    localparam KEY_SIN = 5'd15, KEY_COS = 5'd16, KEY_TAN = 5'd17, KEY_LN = 5'd18;
    localparam KEY_SQRT = 5'd19;
    localparam KEY_PI = 5'd20, KEY_E = 5'd21;
    localparam KEY_DOT = 5'd22, KEY_EQUAL = 5'd23, KEY_CLEAR = 5'd24;
    localparam KEY_LPAREN = 5'd25, KEY_RPAREN = 5'd26;
    localparam KEY_DELETE = 5'd27, KEY_FACTORIAL = 5'd28;

    always @(posedge clk) begin
        if (rst) begin
            ascii_char <= 8'h00;
            char_valid <= 0;
        end else begin
            char_valid <= 0;  // Default: clear pulse

            if (key_valid) begin
                char_valid <= 1;  // Pulse for 1 cycle

                case (key_code)
                    // Digits
                    KEY_0: ascii_char <= 8'h30;  // '0'
                    KEY_1: ascii_char <= 8'h31;  // '1'
                    KEY_2: ascii_char <= 8'h32;  // '2'
                    KEY_3: ascii_char <= 8'h33;  // '3'
                    KEY_4: ascii_char <= 8'h34;  // '4'
                    KEY_5: ascii_char <= 8'h35;  // '5'
                    KEY_6: ascii_char <= 8'h36;  // '6'
                    KEY_7: ascii_char <= 8'h37;  // '7'
                    KEY_8: ascii_char <= 8'h38;  // '8'
                    KEY_9: ascii_char <= 8'h39;  // '9'

                    // Operators
                    KEY_ADD: ascii_char <= 8'h2B;     // '+'
                    KEY_SUB: ascii_char <= 8'h2D;     // '-'
                    KEY_MUL: ascii_char <= 8'h2A;     // '*'
                    KEY_DIV: ascii_char <= 8'h2F;     // '/'
                    KEY_POW: ascii_char <= 8'h5E;     // '^'
                    KEY_DOT: ascii_char <= 8'h2E;     // '.'
                    KEY_EQUAL: ascii_char <= 8'h3D;   // '='
                    KEY_LPAREN: ascii_char <= 8'h28;  // '('
                    KEY_RPAREN: ascii_char <= 8'h29;  // ')'

                    // Functions (multi-char, but we'll use single symbols for now)
                    KEY_SIN: ascii_char <= 8'h73;     // 's' (for sin)
                    KEY_COS: ascii_char <= 8'h63;     // 'c' (for cos)
                    KEY_TAN: ascii_char <= 8'h74;     // 't' (for tan)
                    KEY_LN: ascii_char <= 8'h6C;      // 'l' (for ln)
                    KEY_SQRT: ascii_char <= 8'hFB;    // '√' (square root)
                    KEY_PI: ascii_char <= 8'hE3;      // 'π' (pi)
                    KEY_E: ascii_char <= 8'h65;       // 'e' (Euler's number)

                    // Control
                    KEY_CLEAR: ascii_char <= 8'h43;   // 'C'
                    KEY_DELETE: ascii_char <= 8'h44;  // 'D'
                    KEY_FACTORIAL: ascii_char <= 8'h21; // '!' (factorial)

                    default: ascii_char <= 8'h3F;     // '?' for unknown
                endcase
            end
        end
    end

endmodule