`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Combined Calculator Display Module
//
// Displays both the input equation (top) and output result (bottom)
//////////////////////////////////////////////////////////////////////////////////

module calculator_mode_output_drawer(
    input  clk,
    input  reset,
    input  clr_p,
    input  [1:0] current_main_mode,
    
    // SHARED BUFFER INPUTS (READ-ONLY) - for input equation
    input  [255:0] shared_buffer,      // Shared equation buffer (packed: 32 chars × 8 bits)
    input  [4:0] shared_length,        // Current equation length
    input  shared_complete,            // Equation completed flag
    
    // Calculator result input - for output display
    input  signed [24:0] number_input,  // sign.16.8 format (1 sign + 16 integer + 8 fractional)
    
    // Error and execution status
    input  exec_done,                  // Execution completed flag
    input  has_error,                  // Error present flag
    input  exec_overflow,              // Overflow flag
    
    input  [9:0] vga_x,
    input  [9:0] vga_y,
    output reg [11:0] vga_data
);

    // Calculator Mode Constant
    localparam MODE_CALCULATOR = 2'b10;

    // Font Parameters
    localparam FONT_WIDTH  = 8;  // 8 pixels wide
    localparam FONT_HEIGHT = 8;  // 8 pixels high
    
    // Colors
    localparam TEXT_COLOR = 12'hFFF;  // White text
    localparam BG_COLOR   = 12'h000;  // Black background
    
    // ========================================================================
    // INPUT EQUATION DISPLAY (TOP SECTION - 1/3 down)
    // ========================================================================
    localparam INPUT_BOX_Y_START = 140;
    localparam INPUT_BOX_Y_END = 180;
    localparam INPUT_BOX_X_START = 10;
    localparam INPUT_BOX_X_END = 630;
    localparam INPUT_TEXT_START_X = 15;
    localparam INPUT_TEXT_START_Y = 156;  // Centered in box
    
    // Reset message constants (17 characters: "PRESS C TO RESET")
    localparam RESET_MSG_LEN = 17;
    localparam RESET_MSG_WIDTH = RESET_MSG_LEN * FONT_WIDTH;  // 17 * 8 = 136 pixels
    localparam RESET_MSG_X = (INPUT_BOX_X_START + INPUT_BOX_X_END - RESET_MSG_WIDTH) / 2;  // Centered
    localparam RESET_MSG_Y = INPUT_TEXT_START_Y;  // Same Y as input text
    
    // ========================================================================
    // OUTPUT RESULT DISPLAY (BOTTOM SECTION - 2/3 down)
    // ========================================================================
    localparam ANSWER_LABEL_Y = 305;       // "ANSWER:" label position
    localparam OUTPUT_BOX_Y_START = 320;
    localparam OUTPUT_BOX_Y_END = 360;
    localparam OUTPUT_BOX_X_START = 10;
    localparam OUTPUT_BOX_X_END = 630;
    localparam OUTPUT_TEXT_START_X = 240;  // Centered
    localparam OUTPUT_TEXT_START_Y = 336;  // Centered in box
    localparam MAX_DIGITS = 12;  // Max characters: "-65535.99"
    
    // ========================================================================
    // INPUT EQUATION RENDERING
    // ========================================================================
    
    // Calculate character position for input
    wire [9:0] input_text_x = vga_x - INPUT_TEXT_START_X;
    wire [9:0] input_text_y = vga_y - INPUT_TEXT_START_Y;
    wire [5:0] input_char_index = input_text_x[9:3];
    wire [2:0] input_char_col = 7 - input_text_x[2:0];
    wire [2:0] input_char_row = input_text_y[2:0];
    
    wire in_input_text_render_area = (vga_x >= INPUT_TEXT_START_X &&
                                      vga_y >= INPUT_TEXT_START_Y &&
                                      vga_y < INPUT_TEXT_START_Y + FONT_HEIGHT &&
                                      vga_x < INPUT_TEXT_START_X + (shared_length * FONT_WIDTH) &&
                                      input_char_index < shared_length);
    
    // Get current character from shared buffer
    wire [7:0] input_current_char = (input_char_index < shared_length) ?
                                    shared_buffer[input_char_index*8 +: 8] : 8'h20;
    
    // Reset message character array: "PRESS C TO RESET"
    wire [7:0] reset_msg [0:16];
    assign reset_msg[0]  = 8'h50; // 'P'
    assign reset_msg[1]  = 8'h52; // 'R'
    assign reset_msg[2]  = 8'h45; // 'E'
    assign reset_msg[3]  = 8'h53; // 'S'
    assign reset_msg[4]  = 8'h53; // 'S'
    assign reset_msg[5]  = 8'h20; // ' '
    assign reset_msg[6]  = 8'h43; // 'C'
    assign reset_msg[7]  = 8'h20; // ' '
    assign reset_msg[8]  = 8'h54; // 'T'
    assign reset_msg[9]  = 8'h4F; // 'O'
    assign reset_msg[10] = 8'h20; // ' '
    assign reset_msg[11] = 8'h52; // 'R'
    assign reset_msg[12] = 8'h45; // 'E'
    assign reset_msg[13] = 8'h53; // 'S'
    assign reset_msg[14] = 8'h45; // 'E'
    assign reset_msg[15] = 8'h54; // 'T'
    assign reset_msg[16] = 8'h00; // Null terminator
    
    // Latch exec_done and error flags until cleared
    reg show_reset_message;
    always @(posedge clk) begin
        if (reset) begin
            show_reset_message <= 1'b0;
        end else if (current_main_mode == MODE_CALCULATOR) begin
            if (exec_done || has_error || exec_overflow) begin
                show_reset_message <= 1'b1;
            end else if (clr_p) begin
                show_reset_message <= 1'b0;
            end
        end
    end
    
    // Reset message rendering
    wire [9:0] reset_text_x = vga_x - RESET_MSG_X;
    wire [9:0] reset_text_y = vga_y - RESET_MSG_Y;
    wire [4:0] reset_char_index = reset_text_x[9:3];
    wire [2:0] reset_char_col = 7 - reset_text_x[2:0];
    wire [2:0] reset_char_row = reset_text_y[2:0];
    
    wire in_reset_msg_area = show_reset_message &&
                            (vga_x >= RESET_MSG_X && 
                             vga_x < RESET_MSG_X + RESET_MSG_WIDTH &&
                             vga_y >= RESET_MSG_Y && 
                             vga_y < RESET_MSG_Y + FONT_HEIGHT &&
                             reset_char_index < RESET_MSG_LEN);
    
    wire [7:0] reset_current_char = reset_msg[reset_char_index];
    wire [10:0] reset_font_addr = {reset_current_char, reset_char_row};
    wire [7:0] reset_font_row_data;
    
    blk_mem_gen_font reset_font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(reset_font_addr),
        .douta(reset_font_row_data)
    );
    
    // Font ROM for input equation
    wire [10:0] input_font_addr = {input_current_char, input_char_row};
    wire [7:0] input_font_row_data;
    
    blk_mem_gen_font input_font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(input_font_addr),
        .douta(input_font_row_data)
    );
    
    // Cursor blinking for input
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
    
    wire cursor_x_match = (vga_x == (INPUT_TEXT_START_X + shared_length * FONT_WIDTH));
    wire cursor_visible_here = cursor_visible && shared_complete && cursor_x_match &&
                              (vga_y >= INPUT_TEXT_START_Y && vga_y < INPUT_TEXT_START_Y + FONT_HEIGHT);
    
    wire in_input_box = (vga_y >= INPUT_BOX_Y_START && vga_y <= INPUT_BOX_Y_END &&
                         vga_x >= INPUT_BOX_X_START && vga_x <= INPUT_BOX_X_END);
    
    wire is_input_border = (vga_y == INPUT_BOX_Y_START || vga_y == INPUT_BOX_Y_END ||
                           vga_x == INPUT_BOX_X_START || vga_x == INPUT_BOX_X_END);
    
    // ========================================================================
    // OUTPUT RESULT RENDERING
    // ========================================================================
    
    // Character ROM for output display
    reg [7:0] display_chars [0:MAX_DIGITS-1];
    reg [3:0] char_count;

    // Signals for BRAM Addressing and Pipelining (Output)
    reg  [3:0] output_char_index_reg;
    reg  [7:0] output_char_code_reg;
    reg  [2:0] output_row_index_reg;
    
    reg  [9:0] output_vga_x_d;
    reg  [9:0] output_vga_y_d;
    reg  [2:0] output_pixel_column_d;
    
    wire [10:0] output_font_address;
    wire [7:0] output_font_data_out;
    reg  [7:0] output_font_data_out_d;
    
    // Instantiate Font ROM for output
    blk_mem_gen_font output_font_rom (
        .clka  (clk),
        .ena   (1'b1),
        .addra (output_font_address),
        .douta (output_font_data_out)
    );
    
    assign output_font_address = {output_char_code_reg, output_row_index_reg};
    
    wire [7:0] output_font_data_eff = output_font_data_out_d;
    wire [2:0] output_pixel_column_eff = ((output_pixel_column_d + 7) & 3'b111);
    wire [2:0] output_font_bit_index = (FONT_WIDTH - 1 - output_pixel_column_eff);

    wire in_output_display_region = (
        (vga_x >= OUTPUT_TEXT_START_X) && (vga_x < (OUTPUT_TEXT_START_X + char_count * FONT_WIDTH)) &&
        (vga_y >= OUTPUT_TEXT_START_Y) && (vga_y < (OUTPUT_TEXT_START_Y + FONT_HEIGHT))
    );
    
    wire in_output_display_region_delayed = (
        (output_vga_x_d >= OUTPUT_TEXT_START_X) && 
        (output_vga_x_d < (OUTPUT_TEXT_START_X + char_count * FONT_WIDTH)) &&
        (output_vga_y_d >= OUTPUT_TEXT_START_Y) && 
        (output_vga_y_d < (OUTPUT_TEXT_START_Y + FONT_HEIGHT))
    );
    
    wire in_output_box = (vga_y >= OUTPUT_BOX_Y_START && vga_y <= OUTPUT_BOX_Y_END &&
                         vga_x >= OUTPUT_BOX_X_START && vga_x <= OUTPUT_BOX_X_END);
    
    wire is_output_border = (vga_y == OUTPUT_BOX_Y_START || vga_y == OUTPUT_BOX_Y_END ||
                            vga_x == OUTPUT_BOX_X_START || vga_x == OUTPUT_BOX_X_END);

    // "Answer:" label rendering (7 characters)
    localparam ANSWER_LABEL_X = 15;
    wire [7:0] answer_label [0:6];
    assign answer_label[0] = 8'h41; // 'A'
    assign answer_label[1] = 8'h4E; // 'N'
    assign answer_label[2] = 8'h53; // 'S'
    assign answer_label[3] = 8'h57; // 'W'
    assign answer_label[4] = 8'h45; // 'E'
    assign answer_label[5] = 8'h52; // 'R'
    assign answer_label[6] = 8'h3A; // ':'
    
    wire [9:0] label_text_x = vga_x - ANSWER_LABEL_X;
    wire [9:0] label_text_y = vga_y - ANSWER_LABEL_Y;
    wire [2:0] label_char_index = label_text_x[9:3];
    wire [2:0] label_char_col = 7 - label_text_x[2:0];
    wire [2:0] label_char_row = label_text_y[2:0];
    
    wire in_label_area = (vga_x >= ANSWER_LABEL_X && 
                          vga_x < ANSWER_LABEL_X + (7 * FONT_WIDTH) &&
                          vga_y >= ANSWER_LABEL_Y && 
                          vga_y < ANSWER_LABEL_Y + FONT_HEIGHT &&
                          label_char_index < 7);
    
    wire [7:0] label_current_char = answer_label[label_char_index];
    wire [10:0] label_font_addr = {label_current_char, label_char_row};
    wire [7:0] label_font_row_data;
    
    blk_mem_gen_font label_font_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(label_font_addr),
        .douta(label_font_row_data)
    );

    // Number to ASCII conversion logic
    integer i;
    
    // Always show output (always valid)
    wire has_valid_output = 1'b1;
    
    // Combinational conversion
    wire [24:0] abs_value;
    wire [15:0] int_abs;
    wire [7:0] frac_abs;
    wire sign_bit;
    
    assign sign_bit = number_input[24];
    assign abs_value = sign_bit ? (~number_input + 1'b1) : number_input;
    assign int_abs = abs_value[23:8];
    assign frac_abs = abs_value[7:0];
    
    // Decimal conversion for integer part
    wire [3:0] d4 = (int_abs / 10000) % 10;
    wire [3:0] d3 = (int_abs / 1000) % 10;
    wire [3:0] d2 = (int_abs / 100) % 10;
    wire [3:0] d1 = (int_abs / 10) % 10;
    wire [3:0] d0 = int_abs % 10;
    
    // Fractional conversion (2 decimal places)
    wire [7:0] frac_decimal = (frac_abs * 100) / 256;
    wire [3:0] f1 = frac_decimal / 10;
    wire [3:0] f0 = frac_decimal % 10;
    
    // Check if need decimal places
    wire has_frac = (frac_decimal != 0);
    wire has_f0 = (f0 != 0); 
    
    // Determine significant digits
    wire has_d4 = (int_abs >= 10000);
    wire has_d3 = (int_abs >= 1000);
    wire has_d2 = (int_abs >= 100);
    wire has_d1 = (int_abs >= 10);
    
    always @(posedge clk) begin
        if (current_main_mode == MODE_CALCULATOR) begin
            // Clear display buffer
            for (i = 0; i < MAX_DIGITS; i = i + 1) begin
                display_chars[i] <= 8'h20; // Space
            end
            
            // Only build display string if we have valid output
            if (has_valid_output) begin
                // Build display string with explicit indices
                // Sign (position 0 if negative)
                if (sign_bit) begin
                    display_chars[0] <= 8'h2D; // '-'
                
                // Integer digits after sign
                if (has_d4) begin
                    display_chars[1] <= 8'h30 + d4;
                    display_chars[2] <= 8'h30 + d3;
                    display_chars[3] <= 8'h30 + d2;
                    display_chars[4] <= 8'h30 + d1;
                    display_chars[5] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[6] <= 8'h2E;
                        display_chars[7] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[8] <= 8'h30 + f0;
                            char_count <= 9;
                        end else begin
                            char_count <= 8;
                        end
                    end else begin
                        char_count <= 6;
                    end
                end else if (has_d3) begin
                    display_chars[1] <= 8'h30 + d3;
                    display_chars[2] <= 8'h30 + d2;
                    display_chars[3] <= 8'h30 + d1;
                    display_chars[4] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[5] <= 8'h2E;
                        display_chars[6] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[7] <= 8'h30 + f0;
                            char_count <= 8;
                        end else begin
                            char_count <= 7;
                        end
                    end else begin
                        char_count <= 5;
                    end
                end else if (has_d2) begin
                    display_chars[1] <= 8'h30 + d2;
                    display_chars[2] <= 8'h30 + d1;
                    display_chars[3] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[4] <= 8'h2E;
                        display_chars[5] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[6] <= 8'h30 + f0;
                            char_count <= 7;
                        end else begin
                            char_count <= 6;
                        end
                    end else begin
                        char_count <= 4;
                    end
                end else if (has_d1) begin
                    display_chars[1] <= 8'h30 + d1;
                    display_chars[2] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[3] <= 8'h2E;
                        display_chars[4] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[5] <= 8'h30 + f0;
                            char_count <= 6;
                        end else begin
                            char_count <= 5;
                        end
                    end else begin
                        char_count <= 3;
                    end
                end else begin
                    display_chars[1] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[2] <= 8'h2E;
                        display_chars[3] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[4] <= 8'h30 + f0;
                            char_count <= 5;
                        end else begin
                            char_count <= 4;
                        end
                    end else begin
                        char_count <= 2;
                    end
                end
                end else begin
                    // Positive number (no sign)
                if (has_d4) begin
                    display_chars[0] <= 8'h30 + d4;
                    display_chars[1] <= 8'h30 + d3;
                    display_chars[2] <= 8'h30 + d2;
                    display_chars[3] <= 8'h30 + d1;
                    display_chars[4] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[5] <= 8'h2E;
                        display_chars[6] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[7] <= 8'h30 + f0;
                            char_count <= 8;
                        end else begin
                            char_count <= 7;
                        end
                    end else begin
                        char_count <= 5;
                    end
                end else if (has_d3) begin
                    display_chars[0] <= 8'h30 + d3;
                    display_chars[1] <= 8'h30 + d2;
                    display_chars[2] <= 8'h30 + d1;
                    display_chars[3] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[4] <= 8'h2E; 
                        display_chars[5] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[6] <= 8'h30 + f0;
                            char_count <= 7;
                        end else begin
                            char_count <= 6;
                        end
                    end else begin
                        char_count <= 4;
                    end
                end else if (has_d2) begin
                    display_chars[0] <= 8'h30 + d2;
                    display_chars[1] <= 8'h30 + d1;
                    display_chars[2] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[3] <= 8'h2E;
                        display_chars[4] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[5] <= 8'h30 + f0;
                            char_count <= 6;
                        end else begin
                            char_count <= 5;
                        end
                    end else begin
                        char_count <= 3;
                    end
                end else if (has_d1) begin
                    display_chars[0] <= 8'h30 + d1;
                    display_chars[1] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[2] <= 8'h2E;
                        display_chars[3] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[4] <= 8'h30 + f0;
                            char_count <= 5;
                        end else begin
                            char_count <= 4;
                        end
                    end else begin
                        char_count <= 2;
                    end
                end else begin
                    display_chars[0] <= 8'h30 + d0;
                    if (has_frac) begin
                        display_chars[1] <= 8'h2E; // '.'
                        display_chars[2] <= 8'h30 + f1;
                        if (has_f0) begin
                            display_chars[3] <= 8'h30 + f0;
                            char_count <= 4;
                        end else begin
                            char_count <= 3;
                        end
                    end else begin
                        char_count <= 1;
                    end
                end
                end
            end else begin
                // No valid output - set char_count to 0 so nothing displays
                char_count <= 0;
            end
        end
    end

    // BRAM ACCESS AND PIPELINING LOGIC FOR OUTPUT
    always @(posedge clk) begin
        if (current_main_mode == MODE_CALCULATOR) begin
            // Pipeline delay for coordinates
            output_vga_x_d <= vga_x;
            output_vga_y_d <= vga_y;
            
            // Delay BRAM output
            output_font_data_out_d <= output_font_data_out;
            
            // Default values
            output_char_index_reg <= 4'b0;
            output_char_code_reg  <= 8'h20; // Space
            output_row_index_reg  <= 3'b0;
            output_pixel_column_d <= 3'b0;
            
            // If in display region, calculate character to fetch
            if (in_output_display_region) begin
                output_char_index_reg <= (vga_x - OUTPUT_TEXT_START_X) / FONT_WIDTH;
                output_char_code_reg  <= display_chars[(vga_x - OUTPUT_TEXT_START_X) / FONT_WIDTH];
                output_row_index_reg  <= vga_y - OUTPUT_TEXT_START_Y;
                output_pixel_column_d <= (vga_x - OUTPUT_TEXT_START_X) % FONT_WIDTH;
            end
        end
    end

    // COMBINED VGA OUTPUT LOGIC
    always @(posedge clk) begin
        if (current_main_mode == MODE_CALCULATOR) begin
            // Priority: Reset message > Input text > Input cursor > Input box > Answer label > Output text > Output box > Background
            if (in_reset_msg_area) begin
                // Reset message (red text)
                vga_data <= reset_font_row_data[reset_char_col] ? 12'hFFF : 12'h000;
            end else if (in_input_text_render_area && !show_reset_message) begin
                // Input equation text (only show when not showing reset message)
                vga_data <= input_font_row_data[input_char_col] ? 12'hFFF : 12'h000;
            end else if (cursor_visible_here && !show_reset_message) begin
                // Input cursor (only show when not showing reset message)
                vga_data <= 12'h000; 
            end else if (in_input_box) begin
                // Input box border/background
                vga_data <= is_input_border ? 12'hFFF : 12'h000;
            end else if (in_label_area && has_valid_output) begin
                // "Answer:" label (only show if we have output)
                vga_data <= label_font_row_data[label_char_col] ? 12'hFFF : 12'h000;
            end else if (in_output_display_region_delayed && has_valid_output) begin
                // Output result text (only show if we have output)
                if (output_font_data_eff[output_font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end else if (in_output_box && has_valid_output) begin
                // Output box border/background (only show if we have output)
                vga_data <= is_output_border ? 12'hFFF : 12'h000;
            end else begin
                // Background
                vga_data <= 12'h888;  // Gray background
            end
        end
    end

endmodule