`timescale 1ns / 1ps

// ============================================================================
// DATA PARSER - Phase 1 (Passthrough)
// ============================================================================
// Author: Team
// Description: Converts 5-bit key codes from OLED keypad into digit/operator
//              outputs for the calculator core.
//
// Phase 1 Scope: PASSTHROUGH ONLY
// - No multi-digit accumulation
// - No state machine
// - Just decode key_code to digit_value and operator_code
// - Single-cycle combinational logic
//
// Key Code Mapping (from oled_keypad.v):
//   0-9:   Digits (KEY_0 through KEY_9)
//   10:    Addition (KEY_ADD)
//   11:    Subtraction (KEY_SUB)
//   12:    Multiplication (KEY_MUL)
//   13:    Division (KEY_DIV)
//   14:    Power (KEY_POW)
//   15-20: Functions (SIN, COS, TAN, LN, E, PI)
//   21-22: Parentheses (LPAREN, RPAREN)
//   23:    Negation (KEY_NEG)
//   24:    Square root (KEY_SQRT)
//   25:    Decimal point (KEY_DOT)
//   26:    Equals (KEY_EQUAL)
//   27:    Clear (KEY_CLEAR)
//   28:    Delete (KEY_DELETE)
//
// Output Mapping:
//   digit_value[3:0]: 0-9 for digit keys, else 0
//   digit_valid: 1 if key_code was 0-9, else 0
//   operator_code[3:0]:
//     0: Add
//     1: Sub
//     2: Mul
//     3: Div
//     4: Pow
//     5-10: Functions (sin=5, cos=6, tan=7, ln=8, e=9, pi=10)
//     11: Sqrt
//     12: Neg
//     13: Equals
//     14: Clear
//     15: Delete
//   operator_valid: 1 if key_code was an operator/function, else 0
//   dot_pressed: 1 if KEY_DOT pressed
//
// ============================================================================

module data_parser(
    input wire clk,
    input wire rst,
    input wire [4:0] key_code,      // From OLED keypad
    input wire key_valid,            // Pulse when key pressed

    // Digit outputs
    output reg [3:0] digit_value,    // 0-9
    output reg digit_valid,           // Pulse when digit key pressed

    // Operator outputs
    output reg [3:0] operator_code,  // See mapping above
    output reg operator_valid,        // Pulse when operator key pressed

    // Special outputs
    output reg dot_pressed            // Pulse when decimal point pressed
);

    // Key code constants (must match oled_keypad.v)
    localparam KEY_0      = 5'd0;
    localparam KEY_1      = 5'd1;
    localparam KEY_2      = 5'd2;
    localparam KEY_3      = 5'd3;
    localparam KEY_4      = 5'd4;
    localparam KEY_5      = 5'd5;
    localparam KEY_6      = 5'd6;
    localparam KEY_7      = 5'd7;
    localparam KEY_8      = 5'd8;
    localparam KEY_9      = 5'd9;
    localparam KEY_ADD    = 5'd10;
    localparam KEY_SUB    = 5'd11;
    localparam KEY_MUL    = 5'd12;
    localparam KEY_DIV    = 5'd13;
    localparam KEY_POW    = 5'd14;
    localparam KEY_SIN    = 5'd15;
    localparam KEY_COS    = 5'd16;
    localparam KEY_TAN    = 5'd17;
    localparam KEY_LN     = 5'd18;
    localparam KEY_E      = 5'd19;
    localparam KEY_PI     = 5'd20;
    localparam KEY_LPAREN = 5'd21;
    localparam KEY_RPAREN = 5'd22;
    localparam KEY_NEG    = 5'd23;
    localparam KEY_SQRT   = 5'd24;
    localparam KEY_DOT    = 5'd25;
    localparam KEY_EQUAL  = 5'd26;
    localparam KEY_CLEAR  = 5'd27;
    localparam KEY_DELETE = 5'd28;

    // Operator code constants
    localparam OP_ADD    = 4'd0;
    localparam OP_SUB    = 4'd1;
    localparam OP_MUL    = 4'd2;
    localparam OP_DIV    = 4'd3;
    localparam OP_POW    = 4'd4;
    localparam OP_SIN    = 4'd5;
    localparam OP_COS    = 4'd6;
    localparam OP_TAN    = 4'd7;
    localparam OP_LN     = 4'd8;
    localparam OP_E      = 4'd9;
    localparam OP_PI     = 4'd10;
    localparam OP_SQRT   = 4'd11;
    localparam OP_NEG    = 4'd12;
    localparam OP_EQUAL  = 4'd13;
    localparam OP_CLEAR  = 4'd14;
    localparam OP_DELETE = 4'd15;

    // ============================================================================
    // COMBINATIONAL DECODER
    // ============================================================================
    always @(posedge clk) begin
        if (rst) begin
            digit_value <= 4'd0;
            digit_valid <= 1'b0;
            operator_code <= 4'd0;
            operator_valid <= 1'b0;
            dot_pressed <= 1'b0;
        end else begin
            // Default: clear all pulses
            digit_valid <= 1'b0;
            operator_valid <= 1'b0;
            dot_pressed <= 1'b0;

            if (key_valid) begin
                // Decode key_code
                case (key_code)
                    // Digits
                    KEY_0: begin
                        digit_value <= 4'd0;
                        digit_valid <= 1'b1;
                    end
                    KEY_1: begin
                        digit_value <= 4'd1;
                        digit_valid <= 1'b1;
                    end
                    KEY_2: begin
                        digit_value <= 4'd2;
                        digit_valid <= 1'b1;
                    end
                    KEY_3: begin
                        digit_value <= 4'd3;
                        digit_valid <= 1'b1;
                    end
                    KEY_4: begin
                        digit_value <= 4'd4;
                        digit_valid <= 1'b1;
                    end
                    KEY_5: begin
                        digit_value <= 4'd5;
                        digit_valid <= 1'b1;
                    end
                    KEY_6: begin
                        digit_value <= 4'd6;
                        digit_valid <= 1'b1;
                    end
                    KEY_7: begin
                        digit_value <= 4'd7;
                        digit_valid <= 1'b1;
                    end
                    KEY_8: begin
                        digit_value <= 4'd8;
                        digit_valid <= 1'b1;
                    end
                    KEY_9: begin
                        digit_value <= 4'd9;
                        digit_valid <= 1'b1;
                    end

                    // Operators
                    KEY_ADD: begin
                        operator_code <= OP_ADD;
                        operator_valid <= 1'b1;
                    end
                    KEY_SUB: begin
                        operator_code <= OP_SUB;
                        operator_valid <= 1'b1;
                    end
                    KEY_MUL: begin
                        operator_code <= OP_MUL;
                        operator_valid <= 1'b1;
                    end
                    KEY_DIV: begin
                        operator_code <= OP_DIV;
                        operator_valid <= 1'b1;
                    end
                    KEY_POW: begin
                        operator_code <= OP_POW;
                        operator_valid <= 1'b1;
                    end

                    // Functions
                    KEY_SIN: begin
                        operator_code <= OP_SIN;
                        operator_valid <= 1'b1;
                    end
                    KEY_COS: begin
                        operator_code <= OP_COS;
                        operator_valid <= 1'b1;
                    end
                    KEY_TAN: begin
                        operator_code <= OP_TAN;
                        operator_valid <= 1'b1;
                    end
                    KEY_LN: begin
                        operator_code <= OP_LN;
                        operator_valid <= 1'b1;
                    end
                    KEY_E: begin
                        operator_code <= OP_E;
                        operator_valid <= 1'b1;
                    end
                    KEY_PI: begin
                        operator_code <= OP_PI;
                        operator_valid <= 1'b1;
                    end
                    KEY_SQRT: begin
                        operator_code <= OP_SQRT;
                        operator_valid <= 1'b1;
                    end
                    KEY_NEG: begin
                        operator_code <= OP_NEG;
                        operator_valid <= 1'b1;
                    end

                    // Special keys
                    KEY_DOT: begin
                        dot_pressed <= 1'b1;
                    end
                    KEY_EQUAL: begin
                        operator_code <= OP_EQUAL;
                        operator_valid <= 1'b1;
                    end
                    KEY_CLEAR: begin
                        operator_code <= OP_CLEAR;
                        operator_valid <= 1'b1;
                    end
                    KEY_DELETE: begin
                        operator_code <= OP_DELETE;
                        operator_valid <= 1'b1;
                    end

                    // Parentheses - ignore for now (Phase 3+)
                    KEY_LPAREN, KEY_RPAREN: begin
                        // No action - parentheses not supported yet
                    end

                    default: begin
                        // Invalid key code - do nothing
                    end
                endcase
            end
        end
    end

endmodule
