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
    output reg [11:0] vga_data,

    // DEBUG: Expose display length for LED feedback
    output [5:0] debug_display_length
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
    // PACKED vector: 32 chars × 8 bits = 256 bits
    wire [255:0] display_buffer_flat;
    wire [5:0] display_length;

    // DEBUG: Expose display length (no LUT cost - just wire)
    assign debug_display_length = display_length;

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
        .display_text(display_buffer_flat),  // Packed 256-bit vector
        .text_length(display_length),
        .overflow_error(),
        .invalid_input_error()
    );

    // ========================================================================
    // VGA TEXT RENDERING - Using same font ROM as OLED keypad
    // ========================================================================
    localparam TEXT_BOX_Y_START = 10;
    localparam TEXT_BOX_Y_END = 50;
    localparam TEXT_BOX_X_START = 10;
    localparam TEXT_BOX_X_END = 630;

    // Text rendering parameters (8x8 font, same as OLED)
    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 8;
    localparam TEXT_START_X = 15;
    localparam TEXT_START_Y = 15;

    // Calculate which character and pixel within character
    wire [9:0] text_x = vga_x - TEXT_START_X;
    wire [9:0] text_y = vga_y - TEXT_START_Y;
    wire [5:0] char_index_raw = text_x[9:3];  // Divide by 8 (0-79 for 640 pixels)
    wire [2:0] char_col = text_x[2:0];    // Mod 8
    wire [2:0] char_row = text_y[2:0];    // Mod 8

    // Render text within the entire text box area
    // Character row is determined by char_row (text_y[2:0]), not by limiting vga_y!
    wire in_text_render_area = (vga_x >= TEXT_START_X &&
                                vga_y >= TEXT_START_Y &&
                                vga_y < TEXT_BOX_Y_END &&              // Full text box height!
                                char_index_raw < display_length);      // Within text bounds

    // Font ROM (same as oled_keypad) - 1 cycle latency!
    // Extract current character from packed buffer using bit slicing
    // Character N is at bits [N*8+7 : N*8]
    // Use char_index_raw directly (already bounds-checked by in_text_render_area)
    wire [7:0] current_char = (char_index_raw < display_length) ?
                              display_buffer_flat[char_index_raw*8 +: 8] : 8'h20;
    wire [10:0] font_addr = {current_char, char_row};
    wire [7:0] font_row_data;

    blk_mem_gen_font font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_row_data)
    );

    // VGA output logic (declare before pipeline uses them!)
    wire in_text_box = (vga_y >= TEXT_BOX_Y_START && vga_y <= TEXT_BOX_Y_END &&
                        vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END);
    wire is_border = (vga_y == TEXT_BOX_Y_START || vga_y == TEXT_BOX_Y_END ||
                      vga_x == TEXT_BOX_X_START || vga_x == TEXT_BOX_X_END);

    // Pipeline stage to compensate for BRAM latency
    reg [11:0] vga_data_next;
    reg in_text_render_area_d;
    reg is_border_d;
    reg in_text_box_d;
    reg [2:0] char_col_d;

    always @(posedge clk) begin
        in_text_render_area_d <= in_text_render_area;
        is_border_d <= is_border;
        in_text_box_d <= in_text_box;
        char_col_d <= char_col;
    end

    // Font pixel extraction (delayed to match BRAM output)
    wire font_pixel = font_row_data[7 - char_col_d];

    always @(posedge clk) begin
        if (in_text_box_d) begin
            if (is_border_d) begin
                vga_data <= 12'h000;  // Black border
            end else if (in_text_render_area_d && font_pixel) begin
                vga_data <= 12'h000;  // Black text
            end else begin
                vga_data <= 12'hFFF;  // White background
            end
        end else begin
            vga_data <= 12'h888;  // Gray outside text box
        end
    end

endmodule
