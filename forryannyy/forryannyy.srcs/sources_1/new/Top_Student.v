`timescale 1ns / 1ps 

module Top_Student (
    
    // Clock
    input clk,

    // Buttons and Switches
    input [4:0] btn,
    input [15:0] sw,

    // PS2 Interface
    inout PS2Clk,
    inout PS2Data,

    // OLED Interfaces
    output [7:0] JB,  // OLED 1 - Keypad Display
    output [7:0] JA,  // OLED 2 - Calculator/Grapher Parameters Display

    // VGA Interface
    output VGA_Hsync,
    output VGA_Vsync,
    output [11:0] VGA_RGB,
    
    // LEDs (for user feedback and debugging)
    output [13:0] led,

    // 7-Segment Display (for status feedback)
    output [7:0] seg,
    output [3:0] an
);

    // ON/OFF CALCULATOR (driven by sw[15])
    wire reset = ~sw[15];

    // MAIN OPERATION MODES
    localparam MODE_OFF           = 2'b00;
    localparam MODE_WELCOME       = 2'b01;
    localparam MODE_CALCULATOR    = 2'b10;
    localparam MODE_GRAPHER       = 2'b11;
    
    // Internal mode tracking
    reg [1:0] current_main_mode;
    
    // Map mode to led[1:0] for visual feedback
    assign led[1:0] = current_main_mode;
    
    // --------------------------------
    // --- OUTPUT DATA MULTIPLEXING ---
    // --------------------------------
    
    // === JB OLED (Keypad/General Display) ===
    wire [15:0] jb_oled_data;
    wire [12:0] jb_pixel_index;

    wire [15:0] off_screen_oled;
    wire [15:0] welcome_screen_oled;
    wire [15:0] calculator_screen_oled;
    wire [15:0] shared_keypad_oled;

    assign jb_oled_data = 
        (current_main_mode == MODE_OFF)        ? off_screen_oled :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? shared_keypad_oled :
        (current_main_mode == MODE_GRAPHER)    ? shared_keypad_oled :
        16'h0000;

    // === JA OLED (Calculator/Grapher Parameters Display) ===
    wire [15:0] ja_oled_data;
    wire [12:0] ja_pixel_index;
    wire [15:0] grapher_screen_oled;
    wire [15:0] calculator_screen_oled_ja;

    assign ja_oled_data = 
        (current_main_mode == MODE_GRAPHER)    ? grapher_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_oled_ja :
        16'h0000;

    // === VGA Display ===
    wire [11:0] vga_pixel_data;
    wire [9:0] vga_x, vga_y;

    wire [11:0] off_screen_vga;
    wire [11:0] welcome_screen_vga;
    wire [11:0] calculator_screen_vga;
    wire [11:0] grapher_vga;

    assign vga_pixel_data = 
        (current_main_mode == MODE_OFF)        ? off_screen_vga :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_vga :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
        (current_main_mode == MODE_GRAPHER)    ? grapher_vga :
        12'h000;

    // ========================================
    // === DISPLAY HANDLERS (TWO OLEDS + VGA) ===
    // ========================================
    
    display_handler jb_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(jb_oled_data),
        .vga_pixel_data(12'h000),
        .pixel_index(jb_pixel_index),
        .JB(JB),
        .VGA_Hsync(),
        .VGA_Vsync(),
        .VGA_RGB(),
        .vga_x(),
        .vga_y(),
        .vga_p_tick()
    );

    display_handler jc_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(ja_oled_data),
        .vga_pixel_data(12'h000),
        .pixel_index(ja_pixel_index),
        .JB(JA),
        .VGA_Hsync(),
        .VGA_Vsync(),
        .VGA_RGB(),
        .vga_x(),
        .vga_y(),
        .vga_p_tick()
    );

    wire vga_p_tick;

    display_handler vga_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(16'h0000),
        .vga_pixel_data(vga_pixel_data),
        .pixel_index(),
        .JB(),
        .VGA_Hsync(VGA_Hsync),
        .VGA_Vsync(VGA_Vsync),
        .VGA_RGB(VGA_RGB),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick)
    );
    
    // Handshake wires
    wire        welcome_mode_req;
    wire [1:0]  welcome_mode_target;
    reg         welcome_mode_ack;

    // ------------------------
    // --- BUTTON DEBOUNCER ---
    // ------------------------
    wire [4:0] btn_debounced;
    button_debouncer_array button_debouncer_array_inst(
        .clk(clk),
        .btn(btn),
        .btn_debounced(btn_debounced)
    );

    // -----------------------------
    // --- SWITCH DEBOUNCER (sw[14]) ---
    // -----------------------------
    wire sw14_rising;
    sw_debouncer_posedge sw14_debouncer_inst(
        .clk(clk),
        .reset(reset),
        .sw_in(sw[14]),
        .sw_posedge(sw14_rising)
    );

    // ========================================
    // === SHARED INPUT PROCESSING CHAIN ===
    // ========================================
    
    wire input_system_enable = 
        (current_main_mode == MODE_GRAPHER) ||
        (current_main_mode == MODE_CALCULATOR);
    
    wire grapher_keypad_request;
    wire calculator_keypad_request;
    
    wire keypad_enable = 
        (current_main_mode == MODE_GRAPHER)    ? grapher_keypad_request :
        (current_main_mode == MODE_CALCULATOR) ? calculator_keypad_request :
        1'b0;

    // 1. OLED KEYPAD (shared) - outputs to JB
    wire [4:0] keypad_key_code;
    wire keypad_key_valid;
    wire [511:0] display_equation_buffer;
    wire [6:0] display_equation_length;
    wire [3:0] display_symbol_count;

    oled_keypad shared_keypad_inst(
        .clk(clk),
        .reset(reset || !input_system_enable),
        .enable(keypad_enable),
        .pixel_index(jb_pixel_index),
        .btn_debounced(btn_debounced),
        .shared_buffer(display_equation_buffer),
        .shared_length(display_equation_length),
        .shared_symbol_count(display_symbol_count),
        .oled_data(shared_keypad_oled),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid)
    );

    // 2. ASCII CONVERTER (shared)
    wire [7:0] shared_ascii_char;
    wire shared_ascii_valid;
    wire shared_is_multichar;
    wire [2:0] shared_char_count;
    wire [23:0] shared_multichar_data;

    key_to_ascii_converter shared_ascii_inst(
        .clk(clk),
        .rst(reset || !input_system_enable),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .ascii_char(shared_ascii_char),
        .char_valid(shared_ascii_valid),
        .is_multichar(shared_is_multichar),
        .char_count(shared_char_count),
        .multichar_data(shared_multichar_data)
    );

    // 3. SHARED EQUATION BUFFER (shared between grapher and calculator)
    wire [511:0] shared_equation_buffer;
    wire [6:0] shared_equation_length;
    wire shared_equation_complete;

    shared_equation_buffer shared_buffer_inst(
        .clk(clk),
        .rst(reset || !input_system_enable),
        .ascii_char(shared_ascii_char),
        .ascii_valid(shared_ascii_valid),
        .is_multichar(shared_is_multichar),
        .char_count(shared_char_count),
        .multichar_data(shared_multichar_data),
        .grapher_submode(sw[3]),
        .shared_equation_buffer(shared_equation_buffer),
        .shared_equation_length(shared_equation_length),
        .shared_equation_complete(shared_equation_complete)
    );

    assign display_equation_buffer = shared_equation_buffer;
    assign display_equation_length = shared_equation_length;
    assign display_symbol_count = shared_equation_length > 15 ? 4'd15 : shared_equation_length[3:0];

    // ------------------
    // --- OFF MODULE ---
    // ------------------
    off_module off_module_inst(
        .off_screen_oled(off_screen_oled),
        .off_screen_vga(off_screen_vga)
    );
    
    // ----------------------
    // --- WELCOME MODULE ---
    // ----------------------
    welcome_mode_module welcome_mode_module_inst(
        .current_main_mode(current_main_mode),
        .btn(btn_debounced),
        .clk(clk),
        .mode_req(welcome_mode_req),
        .mode_target(welcome_mode_target),
        .mode_ack(welcome_mode_ack),
        .pixel_index(jb_pixel_index),
        .oled_data(welcome_screen_oled),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(welcome_screen_vga)
    );
    
    // ========================================
    // === GRAPHER MODULE ===
    // ========================================
    // Gate grapher inputs to only be active in grapher mode
    wire grapher_active = (current_main_mode == MODE_GRAPHER);
    wire grapher_ascii_valid = shared_ascii_valid && grapher_active;
    wire grapher_equation_complete = shared_equation_complete && grapher_active;
    
    grapher_module_slim grapher_module_inst(
        .clk(clk),
        .reset(reset || !grapher_active),  // Reset when leaving grapher mode
        .enable(grapher_active),
        .sw(sw),
        .btn_debounced(btn_debounced),
        .jc_pixel_index(ja_pixel_index),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        
        .input_system_enable(grapher_active),  // Only enable when in grapher mode
        .keypad_request_enable(grapher_keypad_request),
        
        .ascii_char(shared_ascii_char),
        .ascii_valid(grapher_ascii_valid),  // Gated by mode
        
        .shared_equation_buffer(shared_equation_buffer),
        .shared_equation_length(shared_equation_length),
        .shared_equation_complete(grapher_equation_complete),  // Gated by mode
        
        .grapher_oled_data(grapher_screen_oled),
        .vga_data(grapher_vga)
    );
    
    // ------------------------- 
    // --- CALCULATOR MODULE ---
    // ------------------------- 
    
    // Gate calculator inputs to only be active in calculator mode
    wire calculator_active = (current_main_mode == MODE_CALCULATOR);
    wire calculator_ascii_valid = shared_ascii_valid && calculator_active;
    wire calculator_equation_complete = shared_equation_complete && calculator_active;
    
    // Internal wire to capture calculator LED outputs
    wire [13:0] calc_led_internal;
    
    // Convert buffer size from 512-bit (64 bytes) to 256-bit (32 bytes)
    wire [255:0] calc_equation_buffer = shared_equation_buffer[255:0];
    wire [4:0] calc_equation_length = shared_equation_length[4:0];  // Limit to 5 bits (0-31)
    
    calc_mode_top calc_mode_top_inst (
        .clk(clk),
        .reset(reset || !calculator_active),  // Reset when leaving calculator mode
        .current_main_mode(current_main_mode),
        
        // Input control
        .calculator_keypad_request(calculator_keypad_request),
        .input_system_enable(calculator_active),  // Only enable when in calculator mode
        
        // Shared buffer inputs (converted to 32-byte format)
        .shared_equation_buffer(calc_equation_buffer),
        .shared_equation_length(calc_equation_length),
        .shared_equation_complete(calculator_equation_complete),  // Gated by mode
        
        // ASCII input
        .ascii_char(shared_ascii_char),
        .ascii_valid(calculator_ascii_valid),  // Gated by mode
        
        // Display outputs
        .jc_pixel_index(ja_pixel_index),
        .calculator_screen_oled_ja(calculator_screen_oled_ja),
        .calculator_screen_vga(calculator_screen_vga),
        
        // VGA position inputs
        .vga_x(vga_x),
        .vga_y(vga_y),
        
        // Debug outputs
        .led(calc_led_internal),
        .seg(seg),
        .an(an),
        
        // Switches for debug
        .sw(sw)
    );
    
    // Map calculator debug LEDs to led[13:2]
    // led[1:0] is already assigned to current_main_mode above
    assign led[13:2] = calc_led_internal[11:0];
    
    // ========================================
    // === MODE HANDSHAKE LOGIC ===
    // ========================================
    reg resetted;
    always @ (posedge clk or posedge reset) begin
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
                if (sw14_rising && current_main_mode != MODE_WELCOME) begin
                    current_main_mode <= MODE_WELCOME;
                    welcome_mode_ack <= 1'b0;
                end
                else if (current_main_mode == MODE_WELCOME) begin
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

/*`timescale 1ns / 1ps 

module Top_Student (
    
    // Clock
    input clk,

    // Buttons and Switches
    input [4:0] btn,
    input [15:0] sw,

    // PS2 Interface
    inout PS2Clk,
    inout PS2Data,

    // OLED Interfaces
    output [7:0] JB,  // OLED 1 - Keypad Display
    output [7:0] JA,  // OLED 2 - Grapher Parameters Display

    // VGA Interface
    output VGA_Hsync,
    output VGA_Vsync,
    output [11:0] VGA_RGB,
    
    // DEBUGGING
    output reg [1:0] current_main_mode
);

    // ON/OFF CALCULATOR (driven by sw[15])
    wire reset = ~sw[15];

    // MAIN OPERATION MODES
    localparam MODE_OFF           = 2'b00;
    localparam MODE_WELCOME       = 2'b01;
    localparam MODE_CALCULATOR    = 2'b10;
    localparam MODE_GRAPHER       = 2'b11;
    
    // --------------------------------
    // --- OUTPUT DATA MULTIPLEXING ---
    // --------------------------------
    
    // === JB OLED (Keypad/General Display) ===
    wire [15:0] jb_oled_data;
    wire [12:0] jb_pixel_index;

    wire [15:0] off_screen_oled;
    wire [15:0] welcome_screen_oled;
    wire [15:0] calculator_screen_oled;
    wire [15:0] shared_keypad_oled;

    assign jb_oled_data = 
        (current_main_mode == MODE_OFF)        ? off_screen_oled :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? shared_keypad_oled :
        (current_main_mode == MODE_GRAPHER)    ? shared_keypad_oled :
        16'h0000;

    // === JC OLED (Grapher Parameters Display) ===
    wire [15:0] jc_oled_data;
    wire [12:0] jc_pixel_index;
    wire [15:0] grapher_screen_oled;

    assign jc_oled_data = 
        (current_main_mode == MODE_GRAPHER) ? grapher_screen_oled : 16'h0000;

    // === VGA Display ===
    wire [11:0] vga_pixel_data;
    wire [9:0] vga_x, vga_y;

    wire [11:0] off_screen_vga;
    wire [11:0] welcome_screen_vga;
    wire [11:0] calculator_screen_vga;
    wire [11:0] grapher_vga;

    assign vga_pixel_data = 
        (current_main_mode == MODE_OFF)        ? off_screen_vga :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_vga :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
        (current_main_mode == MODE_GRAPHER)    ? grapher_vga :
        12'h000;

    // ========================================
    // === DISPLAY HANDLERS (THREE OLEDS + VGA) ===
    // ========================================
    
    display_handler jb_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(jb_oled_data),
        .vga_pixel_data(12'h000),
        .pixel_index(jb_pixel_index),
        .JB(JB),
        .VGA_Hsync(),
        .VGA_Vsync(),
        .VGA_RGB(),
        .vga_x(),
        .vga_y(),
        .vga_p_tick()
    );

    display_handler jc_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(jc_oled_data),
        .vga_pixel_data(12'h000),
        .pixel_index(jc_pixel_index),
        .JB(JA),
        .VGA_Hsync(),
        .VGA_Vsync(),
        .VGA_RGB(),
        .vga_x(),
        .vga_y(),
        .vga_p_tick()
    );

    wire vga_p_tick;

    display_handler vga_display_handler_inst(
        .clk(clk),
        .reset(reset),
        .oled_data(16'h0000),
        .vga_pixel_data(vga_pixel_data),
        .pixel_index(),
        .JB(),
        .VGA_Hsync(VGA_Hsync),
        .VGA_Vsync(VGA_Vsync),
        .VGA_RGB(VGA_RGB),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick)
    );
    
    // Handshake wires
    wire        welcome_mode_req;
    wire [1:0]  welcome_mode_target;
    reg         welcome_mode_ack;

    // ------------------------
    // --- BUTTON DEBOUNCER ---
    // ------------------------
    wire [4:0] btn_debounced;
    button_debouncer_array button_debouncer_array_inst(
        .clk(clk),
        .btn(btn),
        .btn_debounced(btn_debounced)
    );

    // -----------------------------
    // --- SWITCH DEBOUNCER (sw[14]) ---
    // -----------------------------
    wire sw14_rising;
    sw_debouncer_posedge sw14_debouncer_inst(
        .clk(clk),
        .reset(reset),
        .sw_in(sw[14]),
        .sw_posedge(sw14_rising)
    );

    // ========================================
    // === SHARED INPUT PROCESSING CHAIN ===
    // ========================================
    
    wire input_system_enable = 
        (current_main_mode == MODE_GRAPHER) ||
        (current_main_mode == MODE_CALCULATOR);
    
    wire grapher_keypad_request;
    wire calculator_keypad_request;
    
    wire keypad_enable = 
        (current_main_mode == MODE_GRAPHER)    ? grapher_keypad_request :
        (current_main_mode == MODE_CALCULATOR) ? calculator_keypad_request :
        1'b0;

    // 1. OLED KEYPAD (shared) - outputs to JB
    wire [4:0] keypad_key_code;
    wire keypad_key_valid;
    wire [511:0] display_equation_buffer;
    wire [6:0] display_equation_length;
    wire [3:0] display_symbol_count;

    oled_keypad shared_keypad_inst(
        .clk(clk),
        .reset(reset || !input_system_enable),
        .enable(keypad_enable),
        .pixel_index(jb_pixel_index),
        .btn_debounced(btn_debounced),
        .shared_buffer(display_equation_buffer),
        .shared_length(display_equation_length),
        .shared_symbol_count(display_symbol_count),
        .oled_data(shared_keypad_oled),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid)
    );

    // 2. ASCII CONVERTER (shared)
    wire [7:0] shared_ascii_char;
    wire shared_ascii_valid;
    wire shared_is_multichar;
    wire [2:0] shared_char_count;
    wire [23:0] shared_multichar_data;

    key_to_ascii_converter shared_ascii_inst(
        .clk(clk),
        .rst(reset || !input_system_enable),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .ascii_char(shared_ascii_char),
        .char_valid(shared_ascii_valid),
        .is_multichar(shared_is_multichar),
        .char_count(shared_char_count),
        .multichar_data(shared_multichar_data)
    );

    // 3. SHARED EQUATION BUFFER (shared between grapher and calculator)
    wire [511:0] shared_equation_buffer;
    wire [6:0] shared_equation_length;
    wire shared_equation_complete;

    shared_equation_buffer shared_buffer_inst(
        .clk(clk),
        .rst(reset || !input_system_enable),
        .ascii_char(shared_ascii_char),
        .ascii_valid(shared_ascii_valid),
        .is_multichar(shared_is_multichar),
        .char_count(shared_char_count),
        .multichar_data(shared_multichar_data),
        .grapher_submode(sw[3]),
        .shared_equation_buffer(shared_equation_buffer),
        .shared_equation_length(shared_equation_length),
        .shared_equation_complete(shared_equation_complete)
    );

    assign display_equation_buffer = shared_equation_buffer;
    assign display_equation_length = shared_equation_length;
    assign display_symbol_count = shared_equation_length > 15 ? 4'd15 : shared_equation_length[3:0];

    // ------------------
    // --- OFF MODULE ---
    // ------------------
    off_module off_module_inst(
        .off_screen_oled(off_screen_oled),
        .off_screen_vga(off_screen_vga)
    );
    
    // ----------------------
    // --- WELCOME MODULE ---
    // ----------------------
    welcome_mode_module welcome_mode_module_inst(
        .current_main_mode(current_main_mode),
        .btn(btn_debounced),
        .clk(clk),
        .mode_req(welcome_mode_req),
        .mode_target(welcome_mode_target),
        .mode_ack(welcome_mode_ack),
        .pixel_index(jb_pixel_index),
        .oled_data(welcome_screen_oled),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(welcome_screen_vga)
    );
    
    // ========================================
    // === GRAPHER MODULE ===
    // ========================================
    grapher_module_slim grapher_module_inst(
        .clk(clk),
        .reset(reset),
        .enable(current_main_mode == MODE_GRAPHER),
        .sw(sw),
        .btn_debounced(btn_debounced),
        .jc_pixel_index(jc_pixel_index),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        
        .input_system_enable(input_system_enable),
        .keypad_request_enable(grapher_keypad_request),
        
        .ascii_char(shared_ascii_char),
        .ascii_valid(shared_ascii_valid),
        
        .shared_equation_buffer(shared_equation_buffer),
        .shared_equation_length(shared_equation_length),
        .shared_equation_complete(shared_equation_complete),
        
        .grapher_oled_data(grapher_screen_oled),
        .vga_data(grapher_vga)
    );
    
    // ------------------------- 
    // --- CALCULATOR MODULE ---
    // ------------------------- 
    assign calculator_keypad_request = input_system_enable;
    assign calculator_screen_vga = 12'h000;
    
    // ========================================
    // === MODE HANDSHAKE LOGIC ===
    // ========================================
    reg resetted;
    always @ (posedge clk or posedge reset) begin
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
                if (sw14_rising && current_main_mode != MODE_WELCOME) begin
                    current_main_mode <= MODE_WELCOME;
                    welcome_mode_ack <= 1'b0;
                end
                else if (current_main_mode == MODE_WELCOME) begin
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

endmodule*/