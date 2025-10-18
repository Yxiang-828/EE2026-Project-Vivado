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
    
    // Equation input buffer to store what user types (up to 32 characters)
    reg [7:0] equation_buffer [0:31];
    reg [5:0] equation_length;
    
    // Capture keypad input and store in buffer
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            equation_length <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                equation_buffer[i] <= 8'h00;
            end
        end else if (key_valid && equation_length < 32) begin
            // TODO: Convert key_code to ASCII and store in buffer
            // For now, just increment length
            equation_length <= equation_length + 1;
        end
    end
    
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
