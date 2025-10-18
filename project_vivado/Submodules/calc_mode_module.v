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
    
    // Input buffer to store what user types (up to 32 characters)
    reg [7:0] input_buffer [0:31];
    reg [5:0] input_length;
    
    // Capture keypad input and store in buffer
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            input_length <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                input_buffer[i] <= 8'h00;
            end
        end else if (key_valid && input_length < 32) begin
            // TODO: Convert key_code to ASCII and store in buffer
            // For now, just increment length
            input_length <= input_length + 1;
        end
    end
    
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
