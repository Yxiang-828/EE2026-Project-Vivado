`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// FILE 1: key_to_ascii_converter.v
// Enhanced Key to ASCII Converter with Symbol Count Tracking
//////////////////////////////////////////////////////////////////////////////////

module key_to_ascii_converter(
    input clk,
    input rst,
    
    // Keypad input
    input [4:0] key_code,
    input key_valid,
    
    // ASCII output (for single-char functions)
    output reg [7:0] ascii_char,
    output reg char_valid,
    
    // Multi-character function output
    output reg is_multichar,          // 1 if this is a multi-char function
    output reg [2:0] char_count,      // Number of chars in this input (1-3)
    output reg [23:0] multichar_data  // Up to 3 chars packed: [char2, char1, char0]
);

    // Key code constants
    localparam KEY_0 = 5'd0, KEY_1 = 5'd1, KEY_2 = 5'd2, KEY_3 = 5'd3;
    localparam KEY_4 = 5'd4, KEY_5 = 5'd5, KEY_6 = 5'd6, KEY_7 = 5'd7;
    localparam KEY_8 = 5'd8, KEY_9 = 5'd9;
    localparam KEY_ADD = 5'd10, KEY_SUB = 5'd11, KEY_MUL = 5'd12, KEY_DIV = 5'd13;
    localparam KEY_POW = 5'd14;
    localparam KEY_SIN = 5'd15, KEY_COS = 5'd16, KEY_TAN = 5'd17, KEY_LN = 5'd18;
    localparam KEY_SQRT = 5'd19;
    localparam KEY_PI = 5'd20, KEY_E = 5'd21;
    localparam KEY_DOT = 5'd22, KEY_EQUAL = 5'd23, KEY_CLEAR = 5'd24;
    localparam KEY_LPAREN = 5'd25, KEY_RPAREN = 5'd26;
    localparam KEY_DELETE = 5'd27, KEY_FACTORIAL = 5'd28;

    always @(posedge clk) begin
        if (rst) begin
            ascii_char <= 8'h00;
            char_valid <= 0;
            is_multichar <= 0;
            char_count <= 0;
            multichar_data <= 24'h000000;
        end else begin
            char_valid <= 0;
            is_multichar <= 0;
            char_count <= 0;
            
            if (key_valid) begin
                char_valid <= 1;
                
                case (key_code)
                    // Digits
                    KEY_0: begin ascii_char <= 8'h30; char_count <= 1; end
                    KEY_1: begin ascii_char <= 8'h31; char_count <= 1; end
                    KEY_2: begin ascii_char <= 8'h32; char_count <= 1; end
                    KEY_3: begin ascii_char <= 8'h33; char_count <= 1; end
                    KEY_4: begin ascii_char <= 8'h34; char_count <= 1; end
                    KEY_5: begin ascii_char <= 8'h35; char_count <= 1; end
                    KEY_6: begin ascii_char <= 8'h36; char_count <= 1; end
                    KEY_7: begin ascii_char <= 8'h37; char_count <= 1; end
                    KEY_8: begin ascii_char <= 8'h38; char_count <= 1; end
                    KEY_9: begin ascii_char <= 8'h39; char_count <= 1; end
                    
                    // Operators
                    KEY_ADD: begin ascii_char <= 8'h2B; char_count <= 1; end
                    KEY_SUB: begin ascii_char <= 8'h2D; char_count <= 1; end
                    KEY_MUL: begin ascii_char <= 8'h2A; char_count <= 1; end
                    KEY_DIV: begin ascii_char <= 8'h2F; char_count <= 1; end
                    KEY_POW: begin ascii_char <= 8'h5E; char_count <= 1; end
                    KEY_DOT: begin ascii_char <= 8'h2E; char_count <= 1; end
                    KEY_LPAREN: begin ascii_char <= 8'h28; char_count <= 1; end
                    KEY_RPAREN: begin ascii_char <= 8'h29; char_count <= 1; end
                    KEY_FACTORIAL: begin ascii_char <= 8'h21; char_count <= 1; end
                    
                    // Special chars
                    KEY_SQRT: begin ascii_char <= 8'hFB; char_count <= 1; end
                    KEY_PI: begin ascii_char <= 8'hE3; char_count <= 1; end
                    KEY_E: begin ascii_char <= 8'h65; char_count <= 1; end
                    
                    // Control (no symbols)
                    KEY_EQUAL: begin ascii_char <= 8'h3D; char_count <= 0; end
                    KEY_CLEAR: begin ascii_char <= 8'h43; char_count <= 0; end
                    KEY_DELETE: begin ascii_char <= 8'h44; char_count <= 0; end
                    
                    // Multi-char functions
                    KEY_SIN: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h6E, 8'h69, 8'h73};  // 'n','i','s'
                        ascii_char <= 8'h73;
                    end
                    
                    KEY_COS: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h73, 8'h6F, 8'h63};  // 's','o','c'
                        ascii_char <= 8'h63;
                    end
                    
                    KEY_TAN: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h6E, 8'h61, 8'h74};  // 'n','a','t'
                        ascii_char <= 8'h74;
                    end
                    
                    KEY_LN: begin
                        is_multichar <= 1;
                        char_count <= 2;
                        multichar_data <= {8'h00, 8'h6E, 8'h6C};  // 0,'n','l'
                        ascii_char <= 8'h6C;
                    end
                    
                    default: begin
                        ascii_char <= 8'h3F;
                        char_count <= 0;
                    end
                endcase
            end
        end
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
// FILE 2: symbol_counter.v
// Symbol Counter for 10-Symbol Limit Enforcement
//////////////////////////////////////////////////////////////////////////////////

module symbol_counter(
    input clk,
    input rst,
    
    input char_valid,
    input [2:0] char_count,
    input [7:0] ascii_char,
    input [6:0] buffer_length,  // NEW: for smart delete
    input [511:0] buffer_data,   // NEW: for smart delete detection
    
    output reg [3:0] symbol_count,
    output wire can_add,
    output wire at_limit
);

    assign can_add = (symbol_count + char_count <= 10);
    assign at_limit = (symbol_count >= 10);

    always @(posedge clk) begin
        if (rst) begin
            symbol_count <= 0;
        end else if (char_valid) begin
            case (ascii_char)
                8'h43: begin  // 'C' - Clear
                    symbol_count <= 0;
                end
                
                8'h44: begin  // 'D' - Delete (smart)
                    if (buffer_length > 0) begin
                        // Check what we're deleting
                        if (buffer_length >= 3 &&
                            buffer_data[(buffer_length-3)*8 +: 8] == 8'h73 &&  // 's'
                            buffer_data[(buffer_length-2)*8 +: 8] == 8'h69 &&  // 'i'
                            buffer_data[(buffer_length-1)*8 +: 8] == 8'h6E) begin // 'n'
                            // Deleting "sin" = 3 symbols
                            if (symbol_count >= 3) symbol_count <= symbol_count - 3;
                        end else if (buffer_length >= 3 &&
                            buffer_data[(buffer_length-3)*8 +: 8] == 8'h63 &&  // 'c'
                            buffer_data[(buffer_length-2)*8 +: 8] == 8'h6F &&  // 'o'
                            buffer_data[(buffer_length-1)*8 +: 8] == 8'h73) begin // 's'
                            // Deleting "cos" = 3 symbols
                            if (symbol_count >= 3) symbol_count <= symbol_count - 3;
                        end else if (buffer_length >= 3 &&
                            buffer_data[(buffer_length-3)*8 +: 8] == 8'h74 &&  // 't'
                            buffer_data[(buffer_length-2)*8 +: 8] == 8'h61 &&  // 'a'
                            buffer_data[(buffer_length-1)*8 +: 8] == 8'h6E) begin // 'n'
                            // Deleting "tan" = 3 symbols
                            if (symbol_count >= 3) symbol_count <= symbol_count - 3;
                        end else if (buffer_length >= 2 &&
                            buffer_data[(buffer_length-2)*8 +: 8] == 8'h6C &&  // 'l'
                            buffer_data[(buffer_length-1)*8 +: 8] == 8'h6E) begin // 'n'
                            // Deleting "ln" = 2 symbols
                            if (symbol_count >= 2) symbol_count <= symbol_count - 2;
                        end else begin
                            // Single char delete = 1 symbol
                            if (symbol_count > 0) symbol_count <= symbol_count - 1;
                        end
                    end
                end
                
                8'h3D: begin  // '=' - No change
                    // Keep current count
                end
                
                default: begin  // Regular input
                    if (can_add) begin
                        symbol_count <= symbol_count + char_count;
                    end
                end
            endcase
        end
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
// FILE 3: Top_Student.v (COMPLETE UPDATED VERSION)
//////////////////////////////////////////////////////////////////////////////////

module Top_Student (
    input clk,
    input [4:0] btn,
    input [15:0] sw,
    inout PS2Clk,
    inout PS2Data,
    output [7:0] JB,
    output VGA_Hsync,
    output VGA_Vsync,
    output [11:0] VGA_RGB,
    output [13:0] led,
    output [7:0] seg,
    output [3:0] an,
    output reg [1:0] current_main_mode
);

    wire reset = ~sw[15];

    localparam MODE_OFF = 2'b00;
    localparam MODE_WELCOME = 2'b01;
    localparam MODE_CALCULATOR = 2'b10;
    localparam MODE_GRAPHER = 2'b11;

    // Display wires
    wire [15:0] oled_data;
    wire [12:0] pixel_index;
    wire [15:0] off_screen_oled, welcome_screen_oled, calculator_screen_oled, grapher_screen_oled;
    wire [15:0] keypad_oled_raw;
    wire [15:0] keypad_oled = ((current_main_mode == MODE_CALCULATOR) ||
                               (current_main_mode == MODE_GRAPHER)) ? keypad_oled_raw : 16'h0000;

    assign oled_data =
        (current_main_mode == MODE_OFF) ? off_screen_oled :
        (current_main_mode == MODE_WELCOME) ? welcome_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? keypad_oled :
        (current_main_mode == MODE_GRAPHER) ? keypad_oled : 16'h0000;

    wire [11:0] vga_pixel_data;
    wire [9:0] vga_x, vga_y;
    wire vga_p_tick;
    wire [11:0] off_screen_vga, welcome_screen_vga, calculator_screen_vga, grapher_screen_vga;

    wire [11:0] selected_vga_data =
        (current_main_mode == MODE_OFF) ? off_screen_vga :
        (current_main_mode == MODE_WELCOME) ? welcome_screen_vga :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
        (current_main_mode == MODE_GRAPHER) ? grapher_screen_vga : 12'h000;

    reg [11:0] vga_pixel_data_reg;
    assign vga_pixel_data = vga_pixel_data_reg;

    display_handler display_handler_inst(
        .clk(clk), .reset(reset),
        .oled_data(oled_data),
        .vga_pixel_data(vga_pixel_data),
        .pixel_index(pixel_index),
        .JB(JB),
        .VGA_Hsync(VGA_Hsync),
        .VGA_Vsync(VGA_Vsync),
        .VGA_RGB(VGA_RGB),
        .vga_x(vga_x), .vga_y(vga_y),
        .vga_p_tick(vga_p_tick)
    );

    wire welcome_mode_req;
    wire [1:0] welcome_mode_target;
    reg welcome_mode_ack;

    wire [4:0] btn_debounced;
    button_debouncer_array button_debouncer_array_inst(
        .clk(clk), .btn(btn), .btn_debounced(btn_debounced)
    );

    off_module off_module_inst(
        .off_screen_oled(off_screen_oled),
        .off_screen_vga(off_screen_vga)
    );

    welcome_mode_module welcome_mode_module_inst(
        .current_main_mode(current_main_mode),
        .btn(btn_debounced), .clk(clk),
        .mode_req(welcome_mode_req),
        .mode_target(welcome_mode_target),
        .mode_ack(welcome_mode_ack),
        .pixel_index(pixel_index),
        .oled_data(welcome_screen_oled),
        .vga_x(vga_x), .vga_y(vga_y),
        .vga_data(welcome_screen_vga)
    );

    // ==========================================
    // KEYPAD + ASCII CONVERTER + SYMBOL COUNTER
    // ==========================================
    wire [4:0] keypad_key_code;
    wire keypad_key_valid_raw;
    wire keypad_enable = ((current_main_mode == MODE_CALCULATOR) || (current_main_mode == MODE_GRAPHER));
    wire keypad_key_valid = keypad_key_valid_raw;

    // Pass symbol_count to keypad for display
    wire [3:0] current_symbol_count;

    // OLED KEYPAD - NOW READS FROM SHARED BUFFER
    oled_keypad oled_keypad_inst(
        .clk(clk), 
        .reset(reset),
        .enable(keypad_enable),
        .vga_buffer_full(1'b0),
        .pixel_index(pixel_index),
        .btn_debounced(btn_debounced),
        // NEW: Connect shared buffer for display
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_symbol_count(current_symbol_count),
        // Outputs
        .oled_data(keypad_oled_raw),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid_raw),
        .vga_expression(),
        .vga_expr_length(),
        .vga_output_valid(),
        .vga_output_complete()
    );

    wire [7:0] ascii_char;
    wire ascii_valid;
    wire is_multichar;
    wire [2:0] char_count;
    wire [23:0] multichar_data;

    key_to_ascii_converter ascii_converter_inst(
        .clk(clk), .rst(reset),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .ascii_char(ascii_char),
        .char_valid(ascii_valid),
        .is_multichar(is_multichar),
        .char_count(char_count),
        .multichar_data(multichar_data)
    );

    wire can_add_symbol, at_limit;
    
    symbol_counter symbol_counter_inst(
        .clk(clk), .rst(reset),
        .char_valid(ascii_valid),
        .char_count(char_count),
        .ascii_char(ascii_char),
        .buffer_length(shared_equation_length),
        .buffer_data(shared_equation_buffer),
        .symbol_count(current_symbol_count),
        .can_add(can_add_symbol),
        .at_limit(at_limit)
    );

    // ==========================================
    // SHARED EQUATION BUFFER (SYMBOL-AWARE)
    // ==========================================
    reg [511:0] shared_equation_buffer;
    reg [6:0] shared_equation_length;
    reg shared_equation_complete;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            shared_equation_length <= 0;
            shared_equation_complete <= 0;
            shared_equation_buffer <= 512'b0;
        end else begin
            if (ascii_valid) begin
                case (ascii_char)
                    8'h43: begin  // 'C' - Clear
                        shared_equation_length <= 0;
                        shared_equation_complete <= 0;
                        shared_equation_buffer <= 512'b0;
                    end
                    
                    8'h44: begin  // 'D' - Delete (smart)
                        if (shared_equation_length > 0) begin
                            if (shared_equation_length >= 3 &&
                                shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h73 &&
                                shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h69 &&
                                shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E) begin
                                shared_equation_length <= shared_equation_length - 3;  // sin
                                for (i = 0; i < 3; i = i + 1) begin
                                    shared_equation_buffer[(shared_equation_length - 1 - i)*8 +: 8] <= 8'h20;
                                end
                            end else if (shared_equation_length >= 3 &&
                                shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h63 &&
                                shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h6F &&
                                shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h73) begin
                                shared_equation_length <= shared_equation_length - 3;  // cos
                                for (i = 0; i < 3; i = i + 1) begin
                                    shared_equation_buffer[(shared_equation_length - 1 - i)*8 +: 8] <= 8'h20;
                                end
                            end else if (shared_equation_length >= 3 &&
                                shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h74 &&
                                shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h61 &&
                                shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E) begin
                                shared_equation_length <= shared_equation_length - 3;  // tan
                                for (i = 0; i < 3; i = i + 1) begin
                                    shared_equation_buffer[(shared_equation_length - 1 - i)*8 +: 8] <= 8'h20;
                                end
                            end else if (shared_equation_length >= 2 &&
                                shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h6C &&
                                shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E) begin
                                shared_equation_length <= shared_equation_length - 2;  // ln
                                for (i = 0; i < 2; i = i + 1) begin
                                    shared_equation_buffer[(shared_equation_length - 1 - i)*8 +: 8] <= 8'h20;
                                end
                            end else begin
                                shared_equation_length <= shared_equation_length - 1;  // single char
                                shared_equation_buffer[(shared_equation_length - 1)*8 +: 8] <= 8'h20;
                            end
                        end
                        shared_equation_complete <= 0;
                    end
                    
                    8'h3D: begin  // '=' - Complete
                        if (!shared_equation_complete) begin
                            shared_equation_complete <= 1;
                        end
                    end
                    
                    default: begin  // Regular input
                        if (can_add_symbol) begin
                            if (is_multichar) begin
                                case (char_count)
                                    3: begin  // sin/cos/tan
                                        if (shared_equation_length + 3 <= 64) begin
                                            shared_equation_buffer[shared_equation_length*8 +: 8] <= multichar_data[7:0];
                                            shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= multichar_data[15:8];
                                            shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= multichar_data[23:16];
                                            shared_equation_length <= shared_equation_length + 3;
                                        end
                                    end
                                    2: begin  // ln
                                        if (shared_equation_length + 2 <= 64) begin
                                            shared_equation_buffer[shared_equation_length*8 +: 8] <= multichar_data[7:0];
                                            shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= multichar_data[15:8];
                                            shared_equation_length <= shared_equation_length + 2;
                                        end
                                    end
                                endcase
                            end else begin
                                if (shared_equation_length < 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= ascii_char;
                                    shared_equation_length <= shared_equation_length + 1;
                                end
                            end
                            shared_equation_complete <= 0;
                        end
                    end
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (reset) vga_pixel_data_reg <= 12'h000;
        else vga_pixel_data_reg <= selected_vga_data;
    end

    // Debug LEDs
    assign led = {
        current_main_mode,         // [13:12]
        current_symbol_count,      // [11:8]
        can_add_symbol,           // [7]
        at_limit,                 // [6]
        is_multichar,             // [5]
        keypad_key_code           // [4:0]
    };

    assign seg = 8'b11111111;
    assign an = 4'b1111;

    // Calculator and Grapher modules
    calc_mode_module calc_mode_module_inst(
        .clk(clk), .reset(reset),
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_complete(shared_equation_complete),
        .pixel_index(pixel_index),
        .oled_data(calculator_screen_oled),
        .vga_x(vga_x), .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        .vga_data(calculator_screen_vga)
    );

    graph_mode_module graph_mode_module_inst(
        .clk(clk), .reset(reset),
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_complete(shared_equation_complete),
        .pixel_index(pixel_index),
        .oled_data(grapher_screen_oled),
        .vga_x(vga_x), .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        .vga_data(grapher_screen_vga)
    );

    // Mode switching logic
    reg resetted;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_main_mode <= MODE_OFF;
            resetted <= 1'b0;
            welcome_mode_ack <= 1'b0;
        end else begin
            if (~resetted) begin
                current_main_mode <= MODE_WELCOME;
                resetted <= 1'b1;
                welcome_mode_ack <= 1'b0;
            end else begin
                if (current_main_mode == MODE_WELCOME) begin
                    if (welcome_mode_req) begin
                        current_main_mode <= welcome_mode_target;
                        welcome_mode_ack <= 1'b1;
                    end else begin
                        welcome_mode_ack <= 1'b0;
                    end
                end else begin
                    welcome_mode_ack <= 1'b0;
                end
            end
        end
    end

endmodule