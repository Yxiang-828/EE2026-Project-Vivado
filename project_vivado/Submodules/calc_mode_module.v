`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Calculator Mode Module
// Displays calculator interface on VGA monitor with:
// - Text input box showing what user is typing
// - Calculator results display
// - All computation happens here and displays on VGA
//////////////////////////////////////////////////////////////////////////////////

module calc_mode_module(
    input clk,
    input reset,
    
    // Keypad inputs
    input [4:0] key_code,
    input key_valid,
    
    // OLED display output (not used in calc mode - display on VGA instead)
    input [12:0] pixel_index,
    output [15:0] oled_data,
    
    // VGA display output - MAIN DISPLAY FOR CALCULATOR
    input [9:0] vga_x,
    input [9:0] vga_y,
    output reg [11:0] vga_data
);

    // OLED not used in calculator mode
    assign oled_data = 16'h0000;
    
    // ========================================================================
    // DATA PARSER ACCUMULATOR - Converts keypad to Q16.8 numbers
    // ========================================================================
    wire [24:0] parsed_number;
    wire number_ready;
    wire [3:0] operator_code;
    wire operator_ready;
    wire [1:0] precedence;
    wire equals_pressed, clear_pressed, delete_pressed;
    wire [7:0] display_buffer [0:31];
    wire [5:0] display_length;
    
    data_parser_accumulator parser_inst(
        .clk(clk),
        .rst(reset),
        .key_code(key_code),
        .key_valid(key_valid),
        .parsed_number(parsed_number),
        .number_ready(number_ready),
        .operator_code(operator_code),
        .operator_ready(operator_ready),
        .precedence(precedence),
        .equals_pressed(equals_pressed),
        .clear_pressed(clear_pressed),
        .delete_pressed(delete_pressed),
        .display_text(display_buffer),
        .text_length(display_length),
        .overflow_error(),
        .invalid_input_error()
    );
    
    // VGA Display: Draw white background with black text box
    // Text box position: top of screen, 40 pixels tall
    localparam TEXT_BOX_Y_START = 10;
    localparam TEXT_BOX_Y_END = 50;
    localparam TEXT_BOX_X_START = 10;
    localparam TEXT_BOX_X_END = 630;
    
    always @(*) begin
        // Draw text box border (white background, black border)
        if (vga_y >= TEXT_BOX_Y_START && vga_y <= TEXT_BOX_Y_END &&
            vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END) begin
            
            // Border pixels (black)
            if (vga_y == TEXT_BOX_Y_START || vga_y == TEXT_BOX_Y_END ||
                vga_x == TEXT_BOX_X_START || vga_x == TEXT_BOX_X_END) begin
                vga_data = 12'h000; // Black border
            end else begin
                vga_data = 12'hFFF; // White text box interior
                // TODO: Render text from input_buffer here
            end
        end else begin
            // Gray background outside text box
            vga_data = 12'h888;
        end
    end

endmodule
