`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Grapher Mode Module
// Displays graphing interface on VGA monitor with:
// - Text input box at top showing equation being typed
// - Graph display area showing plotted function
// - All graphing happens here and displays on VGA
//////////////////////////////////////////////////////////////////////////////////

module graph_mode_module(
    input clk,
    input reset,
    
    // Keypad inputs
    input [4:0] key_code,
    input key_valid,
    
    // OLED display output (not used in graph mode - display on VGA instead)
    input [12:0] pixel_index,
    output [15:0] oled_data,
    
    // VGA display output - MAIN DISPLAY FOR GRAPHER
    input [9:0] vga_x,
    input [9:0] vga_y,
    output reg [11:0] vga_data
);

    // OLED not used in grapher mode
    assign oled_data = 16'h0000;
    
    // ========================================================================
    // DATA PARSER ACCUMULATOR - Converts keypad to equation text
    // ========================================================================
    wire [24:0] parsed_number;
    wire number_ready;
    wire [3:0] operator_code;
    wire operator_ready;
    wire [1:0] precedence;
    wire equals_pressed, clear_pressed, delete_pressed;
    wire [7:0] equation_buffer [0:31];
    wire [5:0] equation_length;
    
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
        .display_text(equation_buffer),
        .text_length(equation_length),
        .overflow_error(),
        .invalid_input_error()
    );
    
    // VGA Display Layout:
    // - Top section: Text box for equation input (40 pixels tall)
    // - Bottom section: Graph display area
    
    localparam TEXT_BOX_Y_START = 10;
    localparam TEXT_BOX_Y_END = 50;
    localparam TEXT_BOX_X_START = 10;
    localparam TEXT_BOX_X_END = 630;
    
    localparam GRAPH_Y_START = 60;
    localparam GRAPH_Y_END = 470;
    
    always @(*) begin
        // Draw text box at top for equation input
        if (vga_y >= TEXT_BOX_Y_START && vga_y <= TEXT_BOX_Y_END &&
            vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END) begin
            
            // Border pixels (black)
            if (vga_y == TEXT_BOX_Y_START || vga_y == TEXT_BOX_Y_END ||
                vga_x == TEXT_BOX_X_START || vga_x == TEXT_BOX_X_END) begin
                vga_data = 12'h000; // Black border
            end else begin
                vga_data = 12'hFFF; // White text box interior
                // TODO: Render equation text from equation_buffer here
            end
            
        // Draw graph area
        end else if (vga_y >= GRAPH_Y_START && vga_y <= GRAPH_Y_END) begin
            // Black background for graph
            vga_data = 12'h000;
            // TODO: Draw axes and plot function here
            
        end else begin
            // Gray background for rest of screen
            vga_data = 12'h888;
        end
    end

endmodule
