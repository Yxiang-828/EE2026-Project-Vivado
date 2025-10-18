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
    output reg [11:0] vga_data,

    // DEBUG: Expose equation length for LED feedback
    output [5:0] debug_equation_length
);

    // OLED not used in grapher mode
    assign oled_data = 16'h0000;

    // DEBUG: Expose equation length (no LUT cost - just wire)
    assign debug_equation_length = equation_length;

    // ========================================================================
    // DATA PARSER ACCUMULATOR - Converts keypad to equation text
    // ========================================================================
    wire [24:0] parsed_number;
    wire number_ready;
    wire [3:0] operator_code;
    wire operator_ready;
    wire [1:0] precedence;
    wire equals_pressed, clear_pressed, delete_pressed;
    // PACKED vector: 32 chars × 8 bits = 256 bits
    wire [255:0] equation_buffer_flat;
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
        .display_text(equation_buffer_flat),  // Packed 256-bit vector
        .text_length(equation_length),
        .overflow_error(),
        .invalid_input_error()
    );

    // ========================================================================
    // VGA TEXT RENDERING & GRAPHING
    // ========================================================================
    localparam TEXT_BOX_Y_START = 10;
    localparam TEXT_BOX_Y_END = 50;
    localparam TEXT_BOX_X_START = 10;
    localparam TEXT_BOX_X_END = 630;

    localparam GRAPH_Y_START = 60;
    localparam GRAPH_Y_END = 470;

    // Text rendering parameters (8x8 font, same as OLED)
    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 8;
    localparam TEXT_START_X = 15;
    localparam TEXT_START_Y = 15;

    // Calculate which character and pixel within character
    wire [9:0] text_x = vga_x - TEXT_START_X;
    wire [9:0] text_y = vga_y - TEXT_START_Y;
    wire [5:0] char_index = text_x[9:3];  // Divide by 8
    wire [2:0] char_col = text_x[2:0];    // Mod 8
    wire [2:0] char_row = text_y[2:0];    // Mod 8

    // Check if we're in valid text rendering area
    // BUG FIX: Allow text to render across text box height, not just first 8 pixels
    wire in_text_render_area = (vga_y >= TEXT_START_Y && vga_y < TEXT_BOX_Y_END &&
                                vga_x >= TEXT_START_X &&
                                char_index < equation_length);

    // Font ROM (same as oled_keypad) - 1 cycle latency!
    // Extract current character from packed buffer using bit slicing
    // Character N is at bits [N*8+7 : N*8]
    wire [7:0] current_char = (char_index < equation_length) ?
                              equation_buffer_flat[char_index*8 +: 8] : 8'h20;
    wire [10:0] font_addr = {current_char, char_row};
    wire [7:0] font_row_data;

    blk_mem_gen_font font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_row_data)
    );

    // Pipeline stage to compensate for BRAM latency
    reg in_text_render_area_d;
    reg is_border_d;
    reg in_text_box_d;
    reg in_graph_area_d;
    reg [2:0] char_col_d;

    always @(posedge clk) begin
        in_text_render_area_d <= in_text_render_area;
        is_border_d <= is_border;
        in_text_box_d <= in_text_box;
        in_graph_area_d <= in_graph_area;
        char_col_d <= char_col;
    end

    // Font pixel extraction (delayed to match BRAM output)
    wire font_pixel = font_row_data[7 - char_col_d];

    // VGA output logic
    wire in_text_box = (vga_y >= TEXT_BOX_Y_START && vga_y <= TEXT_BOX_Y_END &&
                        vga_x >= TEXT_BOX_X_START && vga_x <= TEXT_BOX_X_END);
    wire is_border = (vga_y == TEXT_BOX_Y_START || vga_y == TEXT_BOX_Y_END ||
                      vga_x == TEXT_BOX_X_START || vga_x == TEXT_BOX_X_END);
    wire in_graph_area = (vga_y >= GRAPH_Y_START && vga_y <= GRAPH_Y_END);

    always @(posedge clk) begin
        if (in_text_box_d) begin
            if (is_border_d) begin
                vga_data <= 12'h000;  // Black border
            end else if (in_text_render_area_d && font_pixel) begin
                vga_data <= 12'h000;  // Black text
            end else begin
                vga_data <= 12'hFFF;  // White background
            end
        end else if (in_graph_area_d) begin
            vga_data <= 12'h000;  // Black graph area (TODO: draw graph)
        end else begin
            vga_data <= 12'h888;  // Gray background
        end
    end

endmodule
