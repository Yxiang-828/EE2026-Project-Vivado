//////////////////////////////////////////////////////////////////////////////////
// FIXED OLED KEYPAD - Reads from Shared Buffer for Display
// NO LOCAL BUFFER - Display is always in sync with shared buffer
//////////////////////////////////////////////////////////////////////////////////

module oled_keypad (
    input clk,
    input reset,
    input enable,
    input vga_buffer_full,
    input [12:0] pixel_index,
    input [4:0] btn_debounced,
    
    // NEW: Read shared buffer for display
    input [511:0] shared_buffer,      // 64 chars ? 8 bits from Top_Student
    input [6:0] shared_length,        // Actual length in shared buffer
    input [3:0] shared_symbol_count,  // Current symbol count (for display)
    
    output reg [15:0] oled_data,
    output reg [4:0] key_code,
    output reg key_valid,
    
    // Legacy VGA interface (unused)
    output reg [79:0] vga_expression,
    output reg [3:0] vga_expr_length,
    output reg vga_output_valid,
    output reg vga_output_complete
);

    localparam OLED_WIDTH = 96;
    localparam OLED_HEIGHT = 64;
    localparam INPUT_Y_START = 0;
    localparam INPUT_Y_END = 7;
    localparam KEYPAD_Y_START = 12;
    localparam PAGE_NUMBERS = 1'b0;
    localparam PAGE_FUNCTIONS = 1'b1;
    localparam WHITE = 16'hFFFF;
    localparam BLACK = 16'h0000;

    localparam PAGE1_ROWS = 4;
    localparam PAGE1_COLS = 5;
    localparam PAGE1_CELL_WIDTH = 19;
    localparam PAGE1_CELL_HEIGHT = 13;
    localparam PAGE1_X_START = 0;
    localparam PAGE2_ROWS = 3;
    localparam PAGE2_COLS = 3;
    localparam PAGE2_CELL_WIDTH = 32;
    localparam PAGE2_CELL_HEIGHT = 17;
    localparam PAGE2_X_START = 0;

    localparam CHAR_SQRT = 8'hFB;
    localparam CHAR_PI = 8'hE3;

    // Key codes
    localparam KEY_0=5'd0, KEY_1=5'd1, KEY_2=5'd2, KEY_3=5'd3, KEY_4=5'd4;
    localparam KEY_5=5'd5, KEY_6=5'd6, KEY_7=5'd7, KEY_8=5'd8, KEY_9=5'd9;
    localparam KEY_ADD=5'd10, KEY_SUB=5'd11, KEY_MUL=5'd12, KEY_DIV=5'd13, KEY_POW=5'd14;
    localparam KEY_SIN=5'd15, KEY_COS=5'd16, KEY_TAN=5'd17, KEY_LN=5'd18, KEY_SQRT=5'd19;
    localparam KEY_PI=5'd20, KEY_E=5'd21, KEY_DOT=5'd22, KEY_EQUAL=5'd23, KEY_CLEAR=5'd24;
    localparam KEY_LPAREN=5'd25, KEY_RPAREN=5'd26, KEY_DELETE=5'd27, KEY_FACTORIAL=5'd28;

    reg [7:0] page1_chars [0:3][0:4];
    reg [2:0] page2_char_lengths [0:2][0:2];

    initial begin
        page1_chars[0][0]=8'h37; page1_chars[0][1]=8'h38; page1_chars[0][2]=8'h39;
        page1_chars[0][3]=8'h2F; page1_chars[0][4]=8'h43;
        page1_chars[1][0]=8'h34; page1_chars[1][1]=8'h35; page1_chars[1][2]=8'h36;
        page1_chars[1][3]=8'h2A; page1_chars[1][4]=8'h44;
        page1_chars[2][0]=8'h31; page1_chars[2][1]=8'h32; page1_chars[2][2]=8'h33;
        page1_chars[2][3]=8'h2D; page1_chars[2][4]=8'h2B;
        page1_chars[3][0]=8'h30; page1_chars[3][1]=8'h2E; page1_chars[3][2]=8'h5E;
        page1_chars[3][3]=CHAR_SQRT; page1_chars[3][4]=8'h3D;

        page2_char_lengths[0][0]=3; page2_char_lengths[0][1]=3; page2_char_lengths[0][2]=3;
        page2_char_lengths[1][0]=1; page2_char_lengths[1][1]=1; page2_char_lengths[1][2]=1;
        page2_char_lengths[2][0]=2; page2_char_lengths[2][1]=1; page2_char_lengths[2][2]=1;
    end

    // NO LOCAL BUFFER - Display reads directly from shared_buffer
    // Cursor position for display
    reg [3:0] cursor_pos = 0;
    reg current_page = PAGE_NUMBERS;
    reg [2:0] selected_row = 0;
    reg [2:0] selected_col = 0;

    integer i;
    reg [25:0] blink_counter = 0;
    wire cursor_visible = blink_counter < 25000000;

    always @(posedge clk) begin
        if (reset) blink_counter <= 0;
        else begin
            blink_counter <= blink_counter + 1;
            if (blink_counter >= 50000000) blink_counter <= 0;
        end
    end

    initial begin
        vga_output_valid = 0;
        vga_output_complete = 0;
        vga_expr_length = 0;
        vga_expression = 80'h0;
    end

    reg [4:0] btn_prev = 5'b11111;
    wire [4:0] btn_pressed_raw = ~btn_debounced & btn_prev;
    wire [4:0] btn_pressed = enable ? btn_pressed_raw : 5'b00000;

    // Button handling - ONLY sends key codes, NO buffer management
    always @(posedge clk) begin
        if (reset) begin
            btn_prev <= 5'b11111;
            current_page <= PAGE_NUMBERS;
            selected_row <= 0;
            selected_col <= 0;
            cursor_pos <= 0;
            vga_output_valid <= 0;
            vga_output_complete <= 0;
            vga_expr_length <= 0;
            key_code <= 5'b00000;
            key_valid <= 0;
        end else begin
            btn_prev <= btn_debounced;
            key_valid <= 0;
            vga_output_valid <= 0;
            vga_output_complete <= 0;

            // Update cursor position based on shared buffer length
            if (shared_length < 10) begin
                cursor_pos <= shared_length[3:0];
            end else begin
                cursor_pos <= 4'd9;  // Max cursor at position 9
            end

            // Navigation
            if (enable && btn_pressed[1]) begin  // Up
                if (selected_row > 0) selected_row <= selected_row - 1;
            end else if (enable && btn_pressed[4]) begin  // Down
                if (current_page == PAGE_NUMBERS) begin
                    if (selected_row < 3) selected_row <= selected_row + 1;
                end else begin
                    if (selected_row < 2) selected_row <= selected_row + 1;
                end
            end else if (enable && btn_pressed[2]) begin  // Left
                if (selected_col == 0 && current_page == PAGE_FUNCTIONS) begin
                    current_page <= PAGE_NUMBERS;
                    selected_row <= 0;
                    selected_col <= 4;
                end else if (selected_col > 0) begin
                    selected_col <= selected_col - 1;
                end
            end else if (enable && btn_pressed[3]) begin  // Right
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
            end else if (enable && !vga_buffer_full && btn_pressed[0]) begin  // Centre
                key_valid <= 1;

                if (current_page == PAGE_NUMBERS) begin
                    case ({selected_row[2:0], selected_col[2:0]})
                        6'b000_100: key_code <= KEY_CLEAR;
                        6'b001_100: key_code <= KEY_DELETE;
                        6'b000_011: key_code <= KEY_DIV;
                        6'b001_011: key_code <= KEY_MUL;
                        6'b010_011: key_code <= KEY_SUB;
                        6'b010_100: key_code <= KEY_ADD;
                        6'b011_100: key_code <= KEY_EQUAL;
                        6'b000_000: key_code <= KEY_7;
                        6'b000_001: key_code <= KEY_8;
                        6'b000_010: key_code <= KEY_9;
                        6'b001_000: key_code <= KEY_4;
                        6'b001_001: key_code <= KEY_5;
                        6'b001_010: key_code <= KEY_6;
                        6'b010_000: key_code <= KEY_1;
                        6'b010_001: key_code <= KEY_2;
                        6'b010_010: key_code <= KEY_3;
                        6'b011_000: key_code <= KEY_0;
                        6'b011_001: key_code <= KEY_DOT;
                        6'b011_010: key_code <= KEY_POW;
                        6'b011_011: key_code <= KEY_SQRT;
                        default: key_code <= 5'b11111;
                    endcase
                end else begin  // PAGE_FUNCTIONS
                    case ({selected_row[1:0], selected_col[1:0]})
                        4'b00_00: key_code <= KEY_SIN;
                        4'b00_01: key_code <= KEY_COS;
                        4'b00_10: key_code <= KEY_TAN;
                        4'b01_00: key_code <= KEY_LPAREN;
                        4'b01_01: key_code <= KEY_RPAREN;
                        4'b01_10: key_code <= KEY_FACTORIAL;
                        4'b10_00: key_code <= KEY_LN;
                        4'b10_01: key_code <= KEY_PI;
                        4'b10_10: key_code <= KEY_E;
                        default: key_code <= 5'b11111;
                    endcase
                end
            end
        end
    end

    // RENDERING: Read from shared_buffer for display (mirrored from VGA logic, with OLED tesselation/scrolling)
    wire [6:0] oled_x = pixel_index % OLED_WIDTH;
    wire [5:0] oled_y = pixel_index / OLED_WIDTH;

    reg [2:0] keypad_cell_row, keypad_cell_col;
    reg in_keypad_cell;
    reg [2:0] cell_font_col, cell_font_row;
    reg [6:0] display_offset;
    reg [2:0] input_font_col, input_font_row;
    reg in_input_area, in_cursor_pos;
    reg [2:0] cell_row_lut, cell_col_lut;
    reg [6:0] char_x_base;
    reg [5:0] char_y_base;
    reg signed [7:0] font_x_offset;
    reg signed [6:0] font_y_offset;
    reg [2:0] pixel_cell_row, pixel_cell_col, char_col_calc;
    reg [6:0] input_char_idx;  // 7-bit for 64-char buffer

    reg s1_in_input_area;
    reg [6:0] s1_input_char_idx;  // 7-bit for 64-char buffer
    reg [2:0] s1_input_font_col, s1_input_font_row;
    reg s1_in_cursor_pos;
    reg s1_in_keypad_cell;
    reg [2:0] s1_cell_font_col, s1_cell_font_row;
    reg [2:0] s1_keypad_cell_row, s1_keypad_cell_col;
    reg [2:0] s1_char_col_calc;
    reg [2:0] s1_selected_row, s1_selected_col;
    reg s1_current_page;

    reg [7:0] s2_char_code;
    reg [2:0] s2_font_row, s2_font_col;
    reg s2_in_input_area, s2_in_cursor, s2_in_keypad_cell, s2_is_selected_cell;

    // Stage 1: Coordinate mapping - READ FROM SHARED BUFFER (OLED auto-scrolls last 10 symbols)
    always @(*) begin
        keypad_cell_row = 0; keypad_cell_col = 0;
        in_keypad_cell = 0;
        cell_font_col = 0; cell_font_row = 0;
        input_char_idx = 127;  // Invalid default
        input_font_col = 0; input_font_row = 0;
        in_input_area = 0; in_cursor_pos = 0;
        
        // OLED auto-scroll: show last 10 symbols
        display_offset = (shared_length > 10) ? (shared_length - 10) : 0;
        
        cell_row_lut = 0; cell_col_lut = 0;
        char_x_base = 0; char_y_base = 0;
        font_x_offset = 0; font_y_offset = 0;
        pixel_cell_row = 0; pixel_cell_col = 0;
        char_col_calc = 0;

        if (oled_y >= INPUT_Y_START && oled_y <= INPUT_Y_END) begin
            input_font_row = oled_y - INPUT_Y_START;
            if (input_font_row < 8) begin
                // Character 0
                if (oled_x >= 2 && oled_x <= 9) begin
                    input_font_col = oled_x - 2;
                    if (input_font_col < 8) begin
                        input_char_idx = 0 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 1
                else if (oled_x >= 11 && oled_x <= 18) begin
                    input_font_col = oled_x - 11;
                    if (input_font_col < 8) begin
                        input_char_idx = 1 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 2
                else if (oled_x >= 20 && oled_x <= 27) begin
                    input_font_col = oled_x - 20;
                    if (input_font_col < 8) begin
                        input_char_idx = 2 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 3
                else if (oled_x >= 29 && oled_x <= 36) begin
                    input_font_col = oled_x - 29;
                    if (input_font_col < 8) begin
                        input_char_idx = 3 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 4
                else if (oled_x >= 38 && oled_x <= 45) begin
                    input_font_col = oled_x - 38;
                    if (input_font_col < 8) begin
                        input_char_idx = 4 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 5
                else if (oled_x >= 47 && oled_x <= 54) begin
                    input_font_col = oled_x - 47;
                    if (input_font_col < 8) begin
                        input_char_idx = 5 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 6
                else if (oled_x >= 56 && oled_x <= 63) begin
                    input_font_col = oled_x - 56;
                    if (input_font_col < 8) begin
                        input_char_idx = 6 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 7
                else if (oled_x >= 65 && oled_x <= 72) begin
                    input_font_col = oled_x - 65;
                    if (input_font_col < 8) begin
                        input_char_idx = 7 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 8
                else if (oled_x >= 74 && oled_x <= 81) begin
                    input_font_col = oled_x - 74;
                    if (input_font_col < 8) begin
                        input_char_idx = 8 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end
                // Character 9
                else if (oled_x >= 83 && oled_x <= 90) begin
                    input_font_col = oled_x - 83;
                    if (input_font_col < 8) begin
                        input_char_idx = 9 + display_offset;
                        if (input_char_idx < shared_length) in_input_area = 1;
                    end
                end

                // Cursor rendering
                if (cursor_visible && cursor_pos >= display_offset && oled_x == (2 + (cursor_pos - display_offset) * 9)) begin
                    in_cursor_pos = 1;
                end
            end
        end else if (oled_y >= KEYPAD_Y_START) begin
            // Keypad rendering (unchanged, tesselation logic preserved)
            if (current_page == PAGE_NUMBERS) begin
                if (oled_x >= PAGE1_X_START && oled_x < (PAGE1_X_START + PAGE1_COLS * PAGE1_CELL_WIDTH)) begin
                    if (oled_y < 25) cell_row_lut = 0;
                    else if (oled_y < 38) cell_row_lut = 1;
                    else if (oled_y < 51) cell_row_lut = 2;
                    else cell_row_lut = 3;

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
                            1: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 12;
                            2: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 8;
                            3: char_x_base = cell_col_lut * PAGE2_CELL_WIDTH + 4;
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

    // Pipeline stages
    always @(posedge clk) begin
        if (reset) begin
            s1_in_input_area <= 0; s1_input_char_idx <= 127;
            s1_input_font_col <= 0; s1_input_font_row <= 0;
            s1_in_cursor_pos <= 0; s1_in_keypad_cell <= 0;
            s1_cell_font_col <= 0; s1_cell_font_row <= 0;
            s1_keypad_cell_row <= 0; s1_keypad_cell_col <= 0;
            s1_char_col_calc <= 0;
            s1_selected_row <= 0; s1_selected_col <= 0;
            s1_current_page <= 0;
        end else begin
            s1_in_input_area <= in_input_area;
            s1_input_char_idx <= input_char_idx;
            s1_input_font_col <= input_font_col;
            s1_input_font_row <= input_font_row;
            s1_in_cursor_pos <= in_cursor_pos;
            s1_in_keypad_cell <= in_keypad_cell;
            s1_cell_font_col <= cell_font_col;
            s1_cell_font_row <= cell_font_row;
            s1_keypad_cell_row <= keypad_cell_row;
            s1_keypad_cell_col <= keypad_cell_col;
            s1_char_col_calc <= char_col_calc;
            s1_selected_row <= selected_row;
            s1_selected_col <= selected_col;
            s1_current_page <= current_page;
        end
    end

    // Stage 2: Character selection - READ FROM SHARED BUFFER
    reg [7:0] selected_char;
    reg is_selected_cell;
    
    // CRITICAL FIX: Extract character from shared_buffer
    wire [7:0] shared_buffer_char = (s1_input_char_idx < 64) ? 
        shared_buffer[s1_input_char_idx*8 +: 8] : 8'h20;

    always @(*) begin
        selected_char = 8'h20;
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
                        4'b00_00: begin
                            case (s1_char_col_calc)
                                0: selected_char = 8'h73;
                                1: selected_char = 8'h69;
                                2: selected_char = 8'h6E;
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b00_01: begin
                            case (s1_char_col_calc)
                                0: selected_char = 8'h63;
                                1: selected_char = 8'h6F;
                                2: selected_char = 8'h73;
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b00_10: begin
                            case (s1_char_col_calc)
                                0: selected_char = 8'h74;
                                1: selected_char = 8'h61;
                                2: selected_char = 8'h6E;
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b01_00: selected_char = 8'h28;
                        4'b01_01: selected_char = 8'h29;
                        4'b01_10: selected_char = 8'h21;
                        4'b10_00: begin
                            case (s1_char_col_calc)
                                0: selected_char = 8'h6C;
                                1: selected_char = 8'h6E;
                                default: selected_char = 8'h20;
                            endcase
                        end
                        4'b10_01: selected_char = CHAR_PI;
                        4'b10_10: selected_char = 8'h65;
                        default: selected_char = 8'h20;
                    endcase
                end
            end
        end else if (s1_in_input_area) begin
            // READ FROM SHARED BUFFER!
            selected_char = shared_buffer_char;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            s2_char_code <= 8'h20;
            s2_font_row <= 3'd0;
            s2_font_col <= 3'd0;
            s2_in_input_area <= 1'b0;
            s2_in_cursor <= 1'b0;
            s2_in_keypad_cell <= 1'b0;
            s2_is_selected_cell <= 1'b0;
        end else begin
            if (s1_in_input_area) begin
                s2_char_code <= shared_buffer_char;  // READ FROM SHARED BUFFER
                s2_font_row <= s1_input_font_row;
                s2_font_col <= s1_input_font_col;
            end else if (s1_in_keypad_cell) begin
                s2_char_code <= selected_char;
                s2_font_row <= s1_cell_font_row;
                s2_font_col <= s1_cell_font_col;
            end else begin
                s2_char_code <= 8'h20;
                s2_font_row <= 3'd0;
                s2_font_col <= 3'd0;
            end

            s2_in_input_area <= s1_in_input_area;
            s2_in_cursor <= s1_in_cursor_pos;
            s2_in_keypad_cell <= s1_in_keypad_cell;
            s2_is_selected_cell <= s1_in_keypad_cell ? is_selected_cell : 1'b0;
        end
    end

    // Font ROM access
    wire [10:0] font_addr = {s2_char_code, s2_font_row[2:0]};
    wire [7:0] font_row_data;
    
    blk_mem_gen_font font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_row_data)
    );

    // Stage 3: Pipeline registers
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
            font_data_reg <= (s2_in_input_area || s2_in_keypad_cell) ? font_row_data : 8'h00;
            font_col_reg <= s2_font_col;
            is_selected_reg <= s2_in_keypad_cell ? s2_is_selected_cell : 1'b0;
            in_input_reg <= s2_in_input_area;
            in_cursor_reg <= s2_in_cursor;
            in_keypad_reg <= s2_in_keypad_cell;
        end
    end

    // Stage 4: Pixel output
    wire font_pixel = font_data_reg[7 - font_col_reg];

    always @(posedge clk) begin
        if (reset) begin
            oled_data <= BLACK;
        end else begin
            if (in_cursor_reg) begin
                oled_data <= WHITE;
            end else if (in_input_reg) begin
                oled_data <= font_pixel ? WHITE : BLACK;
            end else if (in_keypad_reg) begin
                oled_data <= is_selected_reg ? (font_pixel ? BLACK : WHITE) : (font_pixel ? WHITE : BLACK);
            end else begin
                oled_data <= BLACK;
            end
        end
    end

endmodule