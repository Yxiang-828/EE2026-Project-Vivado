//////////////////////////////////////////////////////////////////////////////////
// TIMING-OPTIMIZED OLED KEYPAD MODULE - SUBPIXEL LEAK FIX
// FIXED: Strict bounds checking to prevent font data bleeding between characters
// 4-Stage Pipeline: Coord ? Logic ? Font ? Output
// Features: 2-page keypad, expression buffer, blinking cursor, multi-char symbols
//////////////////////////////////////////////////////////////////////////////////

module oled_keypad (
    input clk,
    input reset,
    input [12:0] pixel_index,  // Pixel index (0 to 6143 for 96x64 OLED)
    input [4:0] btn_debounced, // [4:0] = [down, right, left, up, centre]
    output reg [15:0] oled_data,

    // VGA Output Interface - PACKED for synthesis compatibility
    output reg [255:0] vga_expression,       // Packed expression buffer (32 chars × 8 bits)
    output reg [5:0] vga_expr_length,        // Length of expression sent to VGA
    output reg vga_output_valid,             // Pulse: expression data is valid (intermediate operator)
    output reg vga_output_complete           // Pulse: '=' pressed, calculation complete
);

    // ============================================================================
    // CONSTANTS - MATCHING SPECIFICATION
    // ============================================================================
    localparam OLED_WIDTH = 96;
    localparam OLED_HEIGHT = 64;
    localparam FONT_WIDTH = 8;
    localparam FONT_HEIGHT = 8;
    localparam INPUT_Y_START = 0;        // SPEC: y=0-7 (8px height for font)
    localparam INPUT_Y_END = 7;          // CRITICAL FIX: Only 8 rows (0-7), not 12
    localparam KEYPAD_Y_START = 12;      // SPEC: y=12-63 (52px height)

    localparam PAGE_NUMBERS = 1'b0;
    localparam PAGE_FUNCTIONS = 1'b1;

    localparam WHITE = 16'hFFFF;
    localparam BLACK = 16'h0000;

    // Page 1: 4 rows x 5 columns, 19.2x13 cells - SPEC COMPLIANT
    localparam PAGE1_ROWS = 4;
    localparam PAGE1_COLS = 5;
    localparam PAGE1_CELL_WIDTH = 19;    // SPEC: 19.2px (96/5 = 19.2)
    localparam PAGE1_CELL_HEIGHT = 13;   // SPEC: 13px (52/4 = 13)
    localparam PAGE1_TOTAL_WIDTH = PAGE1_COLS * PAGE1_CELL_WIDTH;  // 5 * 19 = 95
    localparam PAGE1_X_START = (OLED_WIDTH - PAGE1_TOTAL_WIDTH) / 2;  // Center: (96-95)/2 = 0

    // Page 2: 3 rows x 3 columns, 32x17 cells - SPEC COMPLIANT
    localparam PAGE2_ROWS = 3;
    localparam PAGE2_COLS = 3;
    localparam PAGE2_CELL_WIDTH = 32;    // SPEC: 32px (96/3 = 32)
    localparam PAGE2_CELL_HEIGHT = 17;   // SPEC: 17px (52/3 = 17.33 ? 17)
    localparam PAGE2_X_START = 0;

    // CORRECT UNICODE CHARACTER CODES (from your mapping)
    localparam CHAR_SQRT = 8'hFB;   // U+221A SQUARE ROOT (Extended ASCII position)
    localparam CHAR_PI = 8'hE3;     // U+03C0 GREEK SMALL LETTER PI

    // Character arrays for keypad (LUT-based symbol drawing)
    reg [7:0] page1_chars [0:3][0:4];  // 4x5 array for numbers/operators
    reg [2:0] page2_char_lengths [0:2][0:2];  // Character lengths for page 2 symbols

    initial begin
        // Initialize Page 1 characters (4x5 grid - numbers/operators)
        page1_chars[0][0] = 8'h37;  // '7' U+0037
        page1_chars[0][1] = 8'h38;  // '8' U+0038
        page1_chars[0][2] = 8'h39;  // '9' U+0039
        page1_chars[0][3] = 8'h2F;  // '/' U+002F
        page1_chars[0][4] = 8'h43;  // 'C' U+0043
        page1_chars[1][0] = 8'h34;  // '4' U+0034
        page1_chars[1][1] = 8'h35;  // '5' U+0035
        page1_chars[1][2] = 8'h36;  // '6' U+0036
        page1_chars[1][3] = 8'h2A;  // '*' U+002A
        page1_chars[1][4] = 8'h44;  // 'D' U+0044
        page1_chars[2][0] = 8'h31;  // '1' U+0031
        page1_chars[2][1] = 8'h32;  // '2' U+0032
        page1_chars[2][2] = 8'h33;  // '3' U+0033
        page1_chars[2][3] = 8'h2D;  // '-' U+002D
        page1_chars[2][4] = 8'h2B;  // '+' U+002B
        page1_chars[3][0] = 8'h30;  // '0' U+0030
        page1_chars[3][1] = 8'h2E;  // '.' U+002E
        page1_chars[3][2] = 8'h5E;  // '^' U+005E
        page1_chars[3][3] = CHAR_SQRT;  // '?' U+221A
        page1_chars[3][4] = 8'h3D;  // '=' U+003D

        // Initialize Page 2 character lengths (3x3 grid)
        page2_char_lengths[0][0] = 3;  // sin
        page2_char_lengths[0][1] = 3;  // cos
        page2_char_lengths[0][2] = 3;  // tan
        page2_char_lengths[1][0] = 1;  // (
        page2_char_lengths[1][1] = 1;  // )
        page2_char_lengths[1][2] = 1;  // !
        page2_char_lengths[2][0] = 2;  // ln
        page2_char_lengths[2][1] = 1;  // ?
        page2_char_lengths[2][2] = 1;  // e
    end

    // ============================================================================
    // EXPRESSION BUFFER & CURSOR STATE
    // ============================================================================
    reg [7:0] expression_buffer [0:31];
    reg [4:0] cursor_pos = 0;
    reg [4:0] expression_length = 0;

    // Cursor blink: 500ms cycle at 100MHz = 50M cycles
    reg [25:0] blink_counter = 0;
    wire cursor_visible = blink_counter < 25000000;

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

    // ============================================================================
    // KEYPAD STATE
    // ============================================================================
    reg current_page = PAGE_NUMBERS;
    reg [2:0] selected_row = 0;
    reg [2:0] selected_col = 0;

    // VGA Output state initialization
    integer i;
    initial begin
        vga_output_valid = 0;
        vga_output_complete = 0;
        vga_expr_length = 0;
        // Initialize all 256 bits (32 chars × 8 bits) to zero
        vga_expression = 256'h0;
    end

    // ============================================================================
    // BUTTON NAVIGATION (SYNCHRONOUS) - ONE ACTION PER PRESS
    // ============================================================================
    reg [4:0] btn_prev = 5'b11111;
    wire [4:0] btn_pressed = ~btn_debounced & btn_prev;

    always @(posedge clk) begin
        if (reset) begin
            btn_prev <= 5'b11111;
            current_page <= PAGE_NUMBERS;
            selected_row <= 0;
            selected_col <= 0;
            cursor_pos <= 0;
            expression_length <= 0;
            vga_output_valid <= 0;
            vga_output_complete <= 0;
            vga_expr_length <= 0;
        end else begin
            btn_prev <= btn_debounced;

            // Default: clear 1-cycle pulses
            vga_output_valid <= 0;
            vga_output_complete <= 0;

            // ONLY ONE BUTTON ACTION PER CLOCK - prevent multiple triggers
            if (btn_pressed[1]) begin  // Up
                if (selected_row > 0) selected_row <= selected_row - 1;
            end else if (btn_pressed[4]) begin  // Down
                if (current_page == PAGE_NUMBERS) begin
                    if (selected_row < 3) selected_row <= selected_row + 1;
                end else begin
                    if (selected_row < 2) selected_row <= selected_row + 1;
                end
            end else if (btn_pressed[2]) begin  // Left
                if (selected_col == 0 && current_page == PAGE_FUNCTIONS) begin
                    current_page <= PAGE_NUMBERS;
                    selected_row <= 0;
                    selected_col <= 4;
                end else if (selected_col > 0) begin
                    selected_col <= selected_col - 1;
                end
            end else if (btn_pressed[3]) begin  // Right
                if (current_page == PAGE_NUMBERS) begin
                    if (selected_col == 4) begin
                        current_page <= PAGE_FUNCTIONS;
                        selected_row <= 0;
                        selected_col <= 0;
                    end else begin
                        selected_col <= selected_col + 1;
                    end
                end else begin
                    if (selected_col < 2) selected_col <= selected_col + 1;
                end
            end else if (btn_pressed[0]) begin  // Centre - select key
                if (current_page == PAGE_NUMBERS) begin
                    case ({selected_row[2:0], selected_col[2:0]})
                        6'b000_100: begin  // 'C' - Clear
                            expression_length <= 0;
                            cursor_pos <= 0;
                        end
                        6'b001_100: begin  // 'D' - Delete
                            if (expression_length > 0) begin
                                expression_length <= expression_length - 1;
                                cursor_pos <= cursor_pos - 1;
                            end
                        end
                        // Intermediate operators: +, -, *, /
                        6'b000_011,  // '/' - Division
                        6'b001_011,  // '*' - Multiplication
                        6'b010_011,  // '-' - Subtraction
                        6'b010_100: begin  // '+' - Addition
                            if (expression_length > 0) begin  // Only if expression not empty
                                // Copy expression to VGA buffer (packed format)
                                for (i = 0; i < 32; i = i + 1) begin
                                    vga_expression[i*8 +: 8] <= expression_buffer[i];
                                end
                                vga_expr_length <= expression_length;
                                vga_output_valid <= 1;  // Pulse for 1 cycle

                                // Insert operator as first character
                                case ({selected_row[2:0], selected_col[2:0]})
                                    6'b000_011: expression_buffer[0] <= 8'h2F;  // '/'
                                    6'b001_011: expression_buffer[0] <= 8'h2A;  // '*'
                                    6'b010_011: expression_buffer[0] <= 8'h2D;  // '-'
                                    6'b010_100: expression_buffer[0] <= 8'h2B;  // '+'
                                endcase
                                expression_length <= 1;
                                cursor_pos <= 1;
                            end
                        end
                        // Final operator: =
                        6'b011_100: begin  // '=' - Equals
                            if (expression_length > 0) begin  // Only if expression not empty
                                // Copy expression to VGA buffer (packed format)
                                for (i = 0; i < 32; i = i + 1) begin
                                    vga_expression[i*8 +: 8] <= expression_buffer[i];
                                end
                                vga_expr_length <= expression_length;
                                vga_output_complete <= 1;  // Pulse for 1 cycle

                                // Clear expression completely
                                expression_length <= 0;
                                cursor_pos <= 0;
                            end
                        end
                        // Regular number/operator input
                        default: begin
                            if (expression_length < 31) begin
                                case ({selected_row[2:0], selected_col[2:0]})
                                    6'b000_000: expression_buffer[expression_length] <= 8'h37;  // '7'
                                    6'b000_001: expression_buffer[expression_length] <= 8'h38;  // '8'
                                    6'b000_010: expression_buffer[expression_length] <= 8'h39;  // '9'
                                    6'b001_000: expression_buffer[expression_length] <= 8'h34;  // '4'
                                    6'b001_001: expression_buffer[expression_length] <= 8'h35;  // '5'
                                    6'b001_010: expression_buffer[expression_length] <= 8'h36;  // '6'
                                    6'b010_000: expression_buffer[expression_length] <= 8'h31;  // '1'
                                    6'b010_001: expression_buffer[expression_length] <= 8'h32;  // '2'
                                    6'b010_010: expression_buffer[expression_length] <= 8'h33;  // '3'
                                    6'b011_000: expression_buffer[expression_length] <= 8'h30;  // '0'
                                    6'b011_001: expression_buffer[expression_length] <= 8'h2E;  // '.'
                                    6'b011_010: expression_buffer[expression_length] <= 8'h5E;  // '^'
                                    6'b011_011: expression_buffer[expression_length] <= CHAR_SQRT;  // '?'
                                endcase
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                    endcase
                end else begin  // PAGE_FUNCTIONS
                    case ({selected_row[1:0], selected_col[1:0]})
                        4'b00_00: begin  // sin
                            if (expression_length + 2 < 31) begin
                                expression_buffer[expression_length] <= 8'h73;      // 's'
                                expression_buffer[expression_length+1] <= 8'h69;   // 'i'
                                expression_buffer[expression_length+2] <= 8'h6E;   // 'n'
                                expression_length <= expression_length + 3;
                                cursor_pos <= cursor_pos + 3;
                            end
                        end
                        4'b00_01: begin  // cos
                            if (expression_length + 2 < 31) begin
                                expression_buffer[expression_length] <= 8'h63;      // 'c'
                                expression_buffer[expression_length+1] <= 8'h6F;   // 'o'
                                expression_buffer[expression_length+2] <= 8'h73;   // 's'
                                expression_length <= expression_length + 3;
                                cursor_pos <= cursor_pos + 3;
                            end
                        end
                        4'b00_10: begin  // tan
                            if (expression_length + 2 < 31) begin
                                expression_buffer[expression_length] <= 8'h74;      // 't'
                                expression_buffer[expression_length+1] <= 8'h61;   // 'a'
                                expression_buffer[expression_length+2] <= 8'h6E;   // 'n'
                                expression_length <= expression_length + 3;
                                cursor_pos <= cursor_pos + 3;
                            end
                        end
                        4'b01_00: begin  // (
                            if (expression_length < 31) begin
                                expression_buffer[expression_length] <= 8'h28;
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                        4'b01_01: begin  // )
                            if (expression_length < 31) begin
                                expression_buffer[expression_length] <= 8'h29;
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                        4'b01_10: begin  // !
                            if (expression_length < 31) begin
                                expression_buffer[expression_length] <= 8'h21;  // '!'
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                        4'b10_00: begin  // ln
                            if (expression_length + 1 < 31) begin
                                expression_buffer[expression_length] <= 8'h6C;      // 'l'
                                expression_buffer[expression_length+1] <= 8'h6E;   // 'n'
                                expression_length <= expression_length + 2;
                                cursor_pos <= cursor_pos + 2;
                            end
                        end
                        4'b10_01: begin  // ?
                            if (expression_length < 31) begin
                                expression_buffer[expression_length] <= CHAR_PI;
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                        4'b10_10: begin  // e
                            if (expression_length < 31) begin
                                expression_buffer[expression_length] <= 8'h65;
                                expression_length <= expression_length + 1;
                                cursor_pos <= cursor_pos + 1;
                            end
                        end
                    endcase
                end
            end
        end
    end

    // ============================================================================
    // STAGE 0: PIXEL INDEX TO COORDINATES
    // ============================================================================
    wire [6:0] oled_x = pixel_index % OLED_WIDTH;
    wire [5:0] oled_y = pixel_index / OLED_WIDTH;

    // ============================================================================
    // STAGE 1: COORDINATE MAPPING - ANTI-GHOSTING VERSION
    // KEY FIX: Bounds check BEFORE any assignments, strict X ranges
    // ============================================================================
    reg [2:0] keypad_cell_row;
    reg [2:0] keypad_cell_col;
    reg in_keypad_cell;
    reg [2:0] cell_font_col;
    reg [2:0] cell_font_row;
    reg [4:0] input_char_idx;
    reg [2:0] input_font_col;
    reg [2:0] input_font_row;
    reg in_input_area;
    reg in_cursor_pos;

    // LUT-based coordinate mapping variables
    reg [2:0] cell_row_lut;
    reg [2:0] cell_col_lut;
    reg [6:0] char_x_base;
    reg [5:0] char_y_base;
    reg signed [7:0] font_x_offset;
    reg signed [6:0] font_y_offset;
    reg [2:0] pixel_cell_row;
    reg [2:0] pixel_cell_col;
    reg [2:0] char_col_calc;

    // Stage 1 pipeline registers
    reg s1_in_input_area;
    reg [4:0] s1_input_char_idx;
    reg [2:0] s1_input_font_col;
    reg [2:0] s1_input_font_row;
    reg s1_in_cursor_pos;
    reg s1_in_keypad_cell;
    reg [2:0] s1_cell_font_col;
    reg [2:0] s1_cell_font_row;
    reg [2:0] s1_keypad_cell_row;
    reg [2:0] s1_keypad_cell_col;
    reg [2:0] s1_char_col_calc;
    reg [2:0] s1_selected_row;
    reg [2:0] s1_selected_col;
    reg s1_current_page;

    // Stage 2 pipeline registers
    reg [7:0] s2_char_code;
    reg [2:0] s2_font_row;
    reg [2:0] s2_font_col;
    reg s2_in_input_area;
    reg s2_in_cursor;
    reg s2_in_keypad_cell;
    reg s2_is_selected_cell;

    always @(*) begin
        // **CRITICAL: Initialize ALL outputs to safe defaults**
        keypad_cell_row = 0;
        keypad_cell_col = 0;
        in_keypad_cell = 0;
        cell_font_col = 0;
        cell_font_row = 0;
        input_char_idx = 31;  // INVALID index (out of bounds)
        input_font_col = 0;
        input_font_row = 0;
        in_input_area = 0;    // DEFAULT: NOT in input area
        in_cursor_pos = 0;    // DEFAULT: NOT on cursor
        cell_row_lut = 0;
        cell_col_lut = 0;
        char_x_base = 0;
        char_y_base = 0;
        font_x_offset = 0;
        font_y_offset = 0;
        pixel_cell_row = 0;
        pixel_cell_col = 0;
        char_col_calc = 0;

        // ========================================================================
        // INPUT BOX AREA - ANTI-GHOSTING FIX
        // KEY CHANGES:
        // 1. Tighter X bounds: < 10 instead of < 11 (excludes gap pixel)
        // 2. Bounds check INSIDE each block BEFORE setting in_input_area
        // 3. Only assign char_idx when FULLY VALID
        // ========================================================================
        if (oled_y >= INPUT_Y_START && oled_y <= INPUT_Y_END) begin
            input_font_row = oled_y - INPUT_Y_START;

            if (input_font_row < 8) begin  // Valid font row only
                // Character 0: X range [2, 9] (8 pixels, gap at x=10)
                if (oled_x >= 2 && oled_x <= 9) begin
                    input_font_col = oled_x - 2;
                    if (input_font_col < 8) begin  // Redundant but explicit
                        input_char_idx = 0;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 1: X range [11, 18]
                else if (oled_x >= 11 && oled_x <= 18) begin
                    input_font_col = oled_x - 11;
                    if (input_font_col < 8) begin
                        input_char_idx = 1;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 2: X range [20, 27]
                else if (oled_x >= 20 && oled_x <= 27) begin
                    input_font_col = oled_x - 20;
                    if (input_font_col < 8) begin
                        input_char_idx = 2;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 3: X range [29, 36]
                else if (oled_x >= 29 && oled_x <= 36) begin
                    input_font_col = oled_x - 29;
                    if (input_font_col < 8) begin
                        input_char_idx = 3;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 4: X range [38, 45]
                else if (oled_x >= 38 && oled_x <= 45) begin
                    input_font_col = oled_x - 38;
                    if (input_font_col < 8) begin
                        input_char_idx = 4;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 5: X range [47, 54]
                else if (oled_x >= 47 && oled_x <= 54) begin
                    input_font_col = oled_x - 47;
                    if (input_font_col < 8) begin
                        input_char_idx = 5;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 6: X range [56, 63]
                else if (oled_x >= 56 && oled_x <= 63) begin
                    input_font_col = oled_x - 56;
                    if (input_font_col < 8) begin
                        input_char_idx = 6;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 7: X range [65, 72]
                else if (oled_x >= 65 && oled_x <= 72) begin
                    input_font_col = oled_x - 65;
                    if (input_font_col < 8) begin
                        input_char_idx = 7;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 8: X range [74, 81]
                else if (oled_x >= 74 && oled_x <= 81) begin
                    input_font_col = oled_x - 74;
                    if (input_font_col < 8) begin
                        input_char_idx = 8;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end
                // Character 9: X range [83, 90]
                else if (oled_x >= 83 && oled_x <= 90) begin
                    input_font_col = oled_x - 83;
                    if (input_font_col < 8) begin
                        input_char_idx = 9;
                        if (input_char_idx < expression_length) in_input_area = 1;
                    end
                end

                // Cursor rendering - ONLY within valid Y bounds
                if (cursor_visible && oled_x == (2 + cursor_pos * 9)) begin
                    in_cursor_pos = 1;
                end
            end
        end
        // ========================================================================
        // KEYPAD AREA - Unchanged, already correct
        // ========================================================================
        else if (oled_y >= KEYPAD_Y_START) begin
            if (current_page == PAGE_NUMBERS) begin
                // Page 1: 4x5 grid, 19x13 cells
                if (oled_x >= PAGE1_X_START && oled_x < (PAGE1_X_START + PAGE1_COLS * PAGE1_CELL_WIDTH)) begin
                    // Row calculation
                    if (oled_y < 25) cell_row_lut = 0;
                    else if (oled_y < 38) cell_row_lut = 1;
                    else if (oled_y < 51) cell_row_lut = 2;
                    else cell_row_lut = 3;

                    // Col calculation
                    if (oled_x < PAGE1_X_START + 19) cell_col_lut = 0;
                    else if (oled_x < PAGE1_X_START + 38) cell_col_lut = 1;
                    else if (oled_x < PAGE1_X_START + 57) cell_col_lut = 2;
                    else if (oled_x < PAGE1_X_START + 76) cell_col_lut = 3;
                    else cell_col_lut = 4;

                    if (cell_row_lut < PAGE1_ROWS && cell_col_lut < PAGE1_COLS) begin
                        pixel_cell_row = cell_row_lut;
                        pixel_cell_col = cell_col_lut;
                        keypad_cell_row = cell_row_lut;
                        keypad_cell_col = cell_col_lut;

                        char_x_base = PAGE1_X_START + cell_col_lut * PAGE1_CELL_WIDTH + 5;
                        char_y_base = KEYPAD_Y_START + cell_row_lut * PAGE1_CELL_HEIGHT + 2;
                        font_x_offset = oled_x - char_x_base;
                        font_y_offset = oled_y - char_y_base;

                        if (font_x_offset >= 0 && font_x_offset < 8 && font_y_offset >= 0 && font_y_offset < 8) begin
                            cell_font_col = font_x_offset;
                            cell_font_row = font_y_offset;
                            in_keypad_cell = 1;
                        end
                    end
                end
            end else begin
                // Page 2: 3x3 grid, 32x17 cells
                if (oled_x < (PAGE2_COLS * PAGE2_CELL_WIDTH)) begin
                    if (oled_y < 29) cell_row_lut = 0;
                    else if (oled_y < 46) cell_row_lut = 1;
                    else cell_row_lut = 2;

                    if (oled_x < 32) cell_col_lut = 0;
                    else if (oled_x < 64) cell_col_lut = 1;
                    else cell_col_lut = 2;

                    if (cell_row_lut < PAGE2_ROWS && cell_col_lut < PAGE2_COLS) begin
                        pixel_cell_row = cell_row_lut;
                        pixel_cell_col = cell_col_lut;
                        keypad_cell_row = cell_row_lut;
                        keypad_cell_col = cell_col_lut;

                        case (page2_char_lengths[cell_row_lut][cell_col_lut])
                            1: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 12;  // (32-8)/2
                            2: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 8;   // (32-16)/2
                            3: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 4;   // (32-24)/2
                            default: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 12;
                        endcase
                        char_y_base = KEYPAD_Y_START + cell_row_lut * PAGE2_CELL_HEIGHT + 4;
                        font_x_offset = oled_x - char_x_base;
                        font_y_offset = oled_y - char_y_base;

                        if (font_y_offset >= 0 && font_y_offset < 8) begin
                            case (page2_char_lengths[cell_row_lut][cell_col_lut])
                                1: begin
                                    if (font_x_offset >= 0 && font_x_offset < 8) begin
                                        char_col_calc = 0;
                                        cell_font_col = font_x_offset;
                                        cell_font_row = font_y_offset;
                                        in_keypad_cell = 1;
                                    end
                                end
                                2: begin
                                    if (font_x_offset >= 0 && font_x_offset < 16) begin
                                        char_col_calc = font_x_offset / 8;
                                        cell_font_col = font_x_offset % 8;
                                        cell_font_row = font_y_offset;
                                        in_keypad_cell = 1;
                                    end
                                end
                                3: begin
                                    if (font_x_offset >= 0 && font_x_offset < 24) begin
                                        char_col_calc = font_x_offset / 8;
                                        cell_font_col = font_x_offset % 8;
                                        cell_font_row = font_y_offset;
                                        in_keypad_cell = 1;
                                    end
                                end
                            endcase
                        end
                    end
                end
            end
        end
    end

    // Stage 1 pipeline capture
    always @(posedge clk) begin
        if (reset) begin
            s1_in_input_area   <= 1'b0;
            s1_input_char_idx  <= 5'd31;  // INVALID default
            s1_input_font_col  <= 3'd0;
            s1_input_font_row  <= 3'd0;
            s1_in_cursor_pos   <= 1'b0;
            s1_in_keypad_cell  <= 1'b0;
            s1_cell_font_col   <= 3'd0;
            s1_cell_font_row   <= 3'd0;
            s1_keypad_cell_row <= 3'd0;
            s1_keypad_cell_col <= 3'd0;
            s1_char_col_calc   <= 3'd0;
            s1_selected_row    <= 3'd0;
            s1_selected_col    <= 3'd0;
            s1_current_page    <= 1'b0;
        end else begin
            s1_in_input_area   <= in_input_area;
            s1_input_char_idx  <= input_char_idx;
            s1_input_font_col  <= input_font_col;
            s1_input_font_row  <= input_font_row;
            s1_in_cursor_pos   <= in_cursor_pos;
            s1_in_keypad_cell  <= in_keypad_cell;
            s1_cell_font_col   <= cell_font_col;
            s1_cell_font_row   <= cell_font_row;
            s1_keypad_cell_row <= keypad_cell_row;
            s1_keypad_cell_col <= keypad_cell_col;
            s1_char_col_calc   <= char_col_calc;
            s1_selected_row    <= selected_row;
            s1_selected_col    <= selected_col;
            s1_current_page    <= current_page;
        end
    end

    // ============================================================================
    // STAGE 2: CHARACTER SELECTION & FONT ROM ACCESS
    // ============================================================================
    reg [7:0] selected_char;
    reg is_selected_cell;
    wire [7:0] s1_expression_char = (s1_input_char_idx < 32) ? expression_buffer[s1_input_char_idx] : 8'h20;

    always @(*) begin
        selected_char = 8'h20; // Space default
        is_selected_cell = 1'b0;

        if (s1_in_keypad_cell) begin
            is_selected_cell = (s1_keypad_cell_row == s1_selected_row) && (s1_keypad_cell_col == s1_selected_col);

            if (s1_current_page == PAGE_NUMBERS) begin
                if (s1_keypad_cell_row < 4 && s1_keypad_cell_col < 5) begin
                    selected_char = page1_chars[s1_keypad_cell_row][s1_keypad_cell_col];
                end
            end else begin
                if (s1_keypad_cell_row < 3 && s1_keypad_cell_col < 3) begin
                    case ({s1_keypad_cell_row[1:0], s1_keypad_cell_col[1:0]})
                        4'b00_00: begin  // sin
                            case (s1_char_col_calc)
                                0: selected_char = 8'h73;  // 's'
                                1: selected_char = 8'h69;  // 'i'
                                2: selected_char = 8'h6E;  // 'n'
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b00_01: begin  // cos
                            case (s1_char_col_calc)
                                0: selected_char = 8'h63;  // 'c'
                                1: selected_char = 8'h6F;  // 'o'
                                2: selected_char = 8'h73;  // 's'
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b00_10: begin  // tan
                            case (s1_char_col_calc)
                                0: selected_char = 8'h74;  // 't'
                                1: selected_char = 8'h61;  // 'a'
                                2: selected_char = 8'h6E;  // 'n'
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b01_00: selected_char = 8'h28;  // '('
                        4'b01_01: selected_char = 8'h29;  // ')'
                        4'b01_10: selected_char = 8'h21;  // '!'
                        4'b10_00: begin  // ln
                            case (s1_char_col_calc)
                                0: selected_char = 8'h6C;  // 'l'
                                1: selected_char = 8'h6E;  // 'n'
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b10_01: selected_char = CHAR_PI;  // '?'
                        4'b10_10: selected_char = 8'h65;    // 'e'
                        default: selected_char = 8'h20;
                    endcase
                end
            end
        end else if (s1_in_input_area) begin
            selected_char = s1_expression_char;
        end
    end

    // Font ROM address
    always @(posedge clk) begin
        if (reset) begin
            s2_char_code       <= 8'h20;
            s2_font_row        <= 3'd0;
            s2_font_col        <= 3'd0;
            s2_in_input_area   <= 1'b0;
            s2_in_cursor       <= 1'b0;
            s2_in_keypad_cell  <= 1'b0;
            s2_is_selected_cell<= 1'b0;
        end else begin
            // **FIX: Only set char_code when in valid region**
            if (s1_in_input_area) begin
                s2_char_code <= s1_expression_char;
                s2_font_row  <= s1_input_font_row;
                s2_font_col  <= s1_input_font_col;
            end else if (s1_in_keypad_cell) begin
                s2_char_code <= selected_char;
                s2_font_row  <= s1_cell_font_row;
                s2_font_col  <= s1_cell_font_col;
            end else begin
                s2_char_code <= 8'h20;  // Force space for invalid regions
                s2_font_row  <= 3'd0;
                s2_font_col  <= 3'd0;
            end

            s2_in_input_area   <= s1_in_input_area;
            s2_in_cursor       <= s1_in_cursor_pos;
            s2_in_keypad_cell  <= s1_in_keypad_cell;
            s2_is_selected_cell<= s1_in_keypad_cell ? is_selected_cell : 1'b0;
        end
    end

    wire [10:0] font_addr = {s2_char_code, s2_font_row[2:0]};

    wire [7:0] font_row_data;
    blk_mem_gen_font font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_row_data)
    );

    // ============================================================================
    // STAGE 3: PIPELINE REGISTERS - ANTI-GHOSTING
    // ============================================================================
    reg [7:0] font_data_reg;
    reg [2:0] font_col_reg;
    reg is_selected_reg;
    reg in_input_reg;
    reg in_cursor_reg;
    reg in_keypad_reg;

    always @(posedge clk) begin
        if (reset) begin
            font_data_reg <= 8'h00;
            font_col_reg <= 0;
            is_selected_reg <= 0;
            in_input_reg <= 0;
            in_cursor_reg <= 0;
            in_keypad_reg <= 0;
        end else begin
            // **CRITICAL: Gate font data - only copy when in valid region**
            font_data_reg <= (s2_in_input_area || s2_in_keypad_cell) ? font_row_data : 8'h00;
            font_col_reg <= s2_font_col;
            is_selected_reg <= s2_in_keypad_cell ? s2_is_selected_cell : 1'b0;
            in_input_reg <= s2_in_input_area;
            in_cursor_reg <= s2_in_cursor;
            in_keypad_reg <= s2_in_keypad_cell;
        end
    end

    // ============================================================================
    // STAGE 4: PIXEL OUTPUT
    // ============================================================================
    wire font_pixel = font_data_reg[7 - font_col_reg];

    always @(posedge clk) begin
        if (reset) begin
            oled_data <= BLACK;
        end else begin
            if (in_cursor_reg) begin
                oled_data <= WHITE;  // Cursor line
            end else if (in_input_reg) begin
                oled_data <= font_pixel ? WHITE : BLACK;  // Input text
            end else if (in_keypad_reg) begin
                // Inversion for selected cells
                oled_data <= is_selected_reg ? (font_pixel ? BLACK : WHITE) : (font_pixel ? WHITE : BLACK);
            end else begin
                oled_data <= BLACK;  // Background
            end
        end
    end

endmodule