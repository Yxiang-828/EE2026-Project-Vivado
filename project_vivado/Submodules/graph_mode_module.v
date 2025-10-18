`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Grapher Mode Module - SHARED BUFFER READER
//
// Reads from shared equation buffer and displays on VGA.
// No internal buffer - just renders the shared state.
//////////////////////////////////////////////////////////////////////////////////

module graph_mode_module(
    input clk,
    input reset,

    // SHARED BUFFER INPUTS (READ-ONLY)
    input [255:0] shared_buffer,  // Shared equation buffer (packed: 32 chars × 8 bits)
    input [4:0] shared_length,         // Current equation length
    input shared_complete,             // Equation completed flag

    // OLED display output (not used in graph mode)
    input [12:0] pixel_index,
    output [15:0] oled_data,

    // VGA display output
    input [9:0] vga_x,
    input [9:0] vga_y,
    output reg [11:0] vga_data
);

    // OLED not used in grapher mode
    assign oled_data = 16'h0000;

    // ========================================================================
    // SHARED BUFFER USAGE - Read-only access to shared equation
    // ========================================================================
    // No internal buffer - just use shared inputs directly

    // ========================================================================
    // VGA TEXT RENDERING - Display equation buffer (top text box only)
    // ========================================================================
    localparam TEXT_BOX_Y_START = 25;  // Moved down so top border is visible
    localparam TEXT_BOX_Y_END = 65;    // Same height, moved down
    localparam TEXT_BOX_X_START = 10;
    localparam TEXT_BOX_X_END = 630;

    localparam GRAPH_Y_START = 75;     // Adjusted for new text box position
    localparam GRAPH_Y_END = 470;

    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 8;
    localparam TEXT_START_X = 15;
    localparam TEXT_START_Y = 41;  // Centered: (25+65)/2 - 4 = 45-4 = 41

    // Calculate character position
    wire [9:0] text_x = vga_x - TEXT_START_X;
    wire [9:0] text_y = vga_y - TEXT_START_Y;
    wire [5:0] char_index = text_x[9:3];  // Divide by 8
    wire [2:0] char_col = 7 - text_x[2:0];    // Mod 8, flipped for correct orientation
    wire [2:0] char_row = text_y[2:0];    // Mod 8

    // Simple text rendering bounds (prevent drawing outside text area and clones)
    wire in_text_render_area = (vga_x >= TEXT_START_X &&
                                vga_y >= TEXT_START_Y &&
                                vga_y < TEXT_START_Y + CHAR_HEIGHT &&  // Only 1 row of text to prevent clones
                                char_index < shared_length);  // Only render actual characters

    // Get current character from shared buffer
    wire [7:0] current_char = (char_index < shared_length) ?
                              shared_buffer[char_index*8 +: 8] : 8'h20;

    // Font ROM access
    wire [10:0] font_addr = {current_char, char_row};
    wire [7:0] font_row_data;

    blk_mem_gen_font font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_row_data)
    );

    // ========================================================================
    // VGA OUTPUT LOGIC
    // ========================================================================
    wire in_text_box = (vga_y >= TEXT_BOX_Y_START && vga_y <= TEXT_BOX_Y_END &&
                        vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END);

    wire in_graph_area = (vga_y >= GRAPH_Y_START && vga_y <= GRAPH_Y_END &&
                          vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END);

    wire is_border = (vga_y == TEXT_BOX_Y_START || vga_y == TEXT_BOX_Y_END ||
                      vga_x == TEXT_BOX_X_START || vga_x == TEXT_BOX_X_END);

    always @(*) begin
        if (in_text_render_area) begin
            // Render text character (white text on black background)
            vga_data = font_row_data[char_col] ? 12'hFFF : 12'h000;  // White text on black
        end else if (in_text_box) begin
            // Text box background
            vga_data = is_border ? 12'hFFF : 12'h000;  // White border, black background
        end else if (in_graph_area) begin
            // Graph area (placeholder - light blue)
            vga_data = 12'hCCF;  // Light blue background for graph
        end else begin
            // Outside all areas
            vga_data = 12'h888;  // Gray background
        end
    end

endmodule
