`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Calculator Mode Module - SHARED BUFFER READER
//
// Reads from shared equation buffer and displays on VGA.
// No internal buffer - just renders the shared state.
//////////////////////////////////////////////////////////////////////////////////

module calc_mode_module(
    input clk,
    input reset,

    // SHARED BUFFER INPUTS (READ-ONLY)
    input [511:0] shared_buffer,  // Shared equation buffer (packed: 64 chars × 8 bits)
    input [6:0] shared_length,         // Current equation length
    input shared_complete,             // Equation completed flag

    // OLED display output (not used in calc mode)
    input [12:0] pixel_index,
    output [15:0] oled_data,

    // VGA display output
    input [9:0] vga_x,
    input [9:0] vga_y,
    input vga_p_tick,
    output reg [11:0] vga_data
);

    // OLED not used in calculator mode
    assign oled_data = 16'h0000;

    // ========================================================================
    // COORDINATE REGISTRATION - Prevents glitches from rapid coordinate changes
    // ========================================================================
    reg [9:0] vga_x_reg, vga_y_reg;
    always @(posedge clk) begin
        if (reset) begin
            vga_x_reg <= 0;
            vga_y_reg <= 0;
        end else if (vga_p_tick) begin
            vga_x_reg <= vga_x;
            vga_y_reg <= vga_y;
        end
    end

    // ========================================================================
    // SHARED BUFFER USAGE - Read-only access to shared equation
    // ========================================================================
    // No internal buffer - just use shared inputs directly

    // ========================================================================
    // VGA TEXT RENDERING - Display equation buffer
    // ========================================================================
    localparam TEXT_BOX_Y_START = 25;  // Moved down so top border is visible
    localparam TEXT_BOX_Y_END = 65;    // Same height, moved down

    // Center the text box for exactly 63 characters (63 * 8 = 504 pixels)
    // VGA width = 640, so centered start = (640 - 504) / 2 = 68
    localparam TEXT_BOX_X_START = 60;   // Border around centered text
    localparam TEXT_BOX_X_END = 580;    // 60 + 504 + 16 (padding) = 580

    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 8;
    localparam TEXT_START_X = 68;       // Centered: (640 - 504) / 2 = 68
    localparam TEXT_START_Y = 41;       // Centered: (25+65)/2 - 4 = 45-4 = 41

    // Calculate character position
    wire [9:0] text_x = vga_x_reg - TEXT_START_X;
    wire [9:0] text_y = vga_y_reg - TEXT_START_Y;
    wire [5:0] char_index = text_x[9:3];  // Divide by 8
    wire [2:0] char_col = 7 - text_x[2:0];    // Mod 8, flipped for correct orientation
    wire [2:0] char_row = text_y[2:0];    // Mod 8

    // Simple text rendering bounds (prevent drawing outside text area and clones)
    wire in_text_render_area = (vga_x_reg >= TEXT_START_X &&
                                vga_y_reg >= TEXT_START_Y &&
                                vga_y_reg < TEXT_START_Y + CHAR_HEIGHT &&  // Only 1 row of text to prevent clones
                                vga_x_reg < TEXT_START_X + (shared_length * CHAR_WIDTH) &&  // Prevent horizontal clones
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
    // CURSOR BLINKING - When equation complete
    // ========================================================================
    reg [25:0] blink_counter = 0;
    wire cursor_visible = blink_counter < 25000000;  // 500ms on/off at 100MHz

    always @(posedge clk) begin
        if (reset) begin
            blink_counter <= 0;
        end else begin
            blink_counter <= blink_counter + 1;
            if (blink_counter >= 50000000) begin
                blink_counter <= 0;
            end
        end
    end

    // Cursor position (after last character)
    wire cursor_x_match = (vga_x_reg == (TEXT_START_X + shared_length * CHAR_WIDTH));
    wire buffer_full = (shared_length >= 64);
    wire cursor_visible_here = cursor_visible && shared_complete && cursor_x_match &&
                              (vga_y_reg >= TEXT_START_Y && vga_y_reg < TEXT_START_Y + CHAR_HEIGHT);

    // ========================================================================
    // VGA OUTPUT LOGIC
    // ========================================================================
    wire in_text_box = (vga_y_reg >= TEXT_BOX_Y_START && vga_y_reg <= TEXT_BOX_Y_END &&
                        vga_x_reg >= TEXT_BOX_X_START && vga_x_reg <= TEXT_BOX_X_END);

    wire is_border = (vga_y_reg == TEXT_BOX_Y_START || vga_y_reg == TEXT_BOX_Y_END ||
                      vga_x_reg == TEXT_BOX_X_START || vga_x_reg == TEXT_BOX_X_END);

    always @(*) begin
        if (in_text_render_area) begin
            // Render text character (white text on black background)
            vga_data = font_row_data[char_col] ? 12'hFFF : 12'h000;  // White text on black
        end else if (cursor_visible_here) begin
            // Render blinking cursor (red when buffer full, green when space available)
            vga_data = buffer_full ? 12'hF00 : 12'h0F0;  // Red when full, green when available
        end else if (in_text_box) begin
            // Text box background
            vga_data = is_border ? 12'hFFF : 12'h000;  // White border, black background
        end else begin
            // Outside text box
            vga_data = 12'h888;  // Gray background
        end
    end

endmodule
