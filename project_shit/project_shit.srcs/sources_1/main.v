`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME:
//  STUDENT B NAME:
//  STUDENT C NAME:
//  STUDENT D NAME:
//////////////////////////////////////////////////////////////////////////////////

module Top_Student (

    // Clock
    input clk,

    // Buttons and Switches
    input [4:0] btn,
    input [15:0] sw,

    // PS2 Interface
    inout PS2Clk,
    inout PS2Data,

    // OLED Interface
    output [7:0] JB,

    // VGA Interface
    output VGA_Hsync,
    output VGA_Vsync,
    output [11:0] VGA_RGB,

    // LEDs (for user feedback and debugging)
    // Basys3 only has 14 LEDs (LED0-LED13)
    output [13:0] led,

    // 7-Segment Display (for status feedback)
    output [7:0] seg,
    output [3:0] an,

    // DEBUGGING
    output reg [1:0] current_main_mode
);

    // ON/OFF CALCULATOR (driven by sw[15])
    wire reset = ~sw[15];

    // MAIN OPERATION MODES
    localparam MODE_OFF           = 2'b00; // Off Screen
    localparam MODE_WELCOME       = 2'b01; // Main Screen
    localparam MODE_CALCULATOR    = 2'b10; // Calculator Mode
    localparam MODE_GRAPHER       = 2'b11; // Grapher Mode

    // --------------------------------
    // --- OUTPUT DATA MULTIPLEXING ---
    // --------------------------------
    // OLED Data Wires
    wire [15:0] oled_data;
    wire [12:0] pixel_index;

    // OLED Data from Sub-Modules
    wire [15:0] off_screen_oled;
    wire [15:0] welcome_screen_oled;
    wire [15:0] calculator_screen_oled;
    wire [15:0] grapher_screen_oled;
    wire [15:0] keypad_oled_raw;

    // EFFICIENT FIX: Blank keypad OLED when not in calc/graph mode (16 LUTs)
    wire [15:0] keypad_oled = ((current_main_mode == MODE_CALCULATOR) ||
                               (current_main_mode == MODE_GRAPHER)) ? keypad_oled_raw : 16'h0000;

    // OLED Screen Data
    assign oled_data =
        (current_main_mode == MODE_OFF)        ? off_screen_oled :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? keypad_oled :
        (current_main_mode == MODE_GRAPHER)    ? keypad_oled :
        16'h0000;

    // VGA Display Wires
    wire [11:0] vga_pixel_data;
    wire [9:0] vga_x, vga_y;
    wire vga_p_tick;

    // VGA Data from Sub-Modules
    wire [11:0] off_screen_vga;
    wire [11:0] welcome_screen_vga;
    wire [11:0] calculator_screen_vga;
    wire [11:0] grapher_screen_vga;

    // VGA Screen Data - Combinatorial selection
    wire [11:0] selected_vga_data =
        (current_main_mode == MODE_OFF)        ? off_screen_vga :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_vga :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
        (current_main_mode == MODE_GRAPHER)    ? grapher_screen_vga :
        12'h000;

    // VGA Output Register - Prevents glitches during mode switching
    reg [11:0] vga_pixel_data_reg;
    assign vga_pixel_data = vga_pixel_data_reg;

    // Instantiate display handler to manage OLED and VGA
    display_handler display_handler_inst(
        // Clock and Reset
        .clk(clk),
        .reset(reset),

        // OLED Data
        .oled_data(oled_data),

        // VGA Colour Data
        .vga_pixel_data(vga_pixel_data),

        // OLED Outputs
        .pixel_index(pixel_index),
        .JB(JB),

        // VGA Outputs
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
        // Mode Input
        .current_main_mode(current_main_mode),

        // Physical Inputs
        .btn(btn_debounced),
        .clk(clk),

        // New Mode Handshake
        .mode_req(welcome_mode_req),
        .mode_target(welcome_mode_target),
        .mode_ack(welcome_mode_ack),

        // OLED Interface
        .pixel_index(pixel_index),
        .oled_data(welcome_screen_oled),

        // VGA Interface
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(welcome_screen_vga)
    );

    // -------------------
    // --- OLED KEYPAD ---
    // -------------------

    // Keypad-to-Parser wires
    wire [4:0] keypad_key_code;
    wire keypad_key_valid_raw;

    // Enable keypad only in calculator or grapher mode
    wire keypad_enable = ((current_main_mode == MODE_CALCULATOR) || (current_main_mode == MODE_GRAPHER));

    // NO DOUBLE-GATING! Keypad already handles enable internally
    wire keypad_key_valid = keypad_key_valid_raw;  // Direct connection

    oled_keypad oled_keypad_inst(
        .clk(clk),
        .reset(reset),
        .enable(keypad_enable),       // Keypad gates internally
        .pixel_index(pixel_index),
        .btn_debounced(btn_debounced),
        .oled_data(keypad_oled_raw),  // Raw output, gated in main
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid_raw)
    );

    // -------------------
    // --- ASCII CONVERTER ---
    // -------------------
    wire [7:0] ascii_char;
    wire ascii_valid;
    wire [4:0] current_key_code;  // For function key detection

    key_to_ascii_converter ascii_converter_inst(
        .clk(clk),
        .rst(reset),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .ascii_char(ascii_char),
        .char_valid(ascii_valid)
    );

    // Capture key code for function detection
    reg [4:0] key_code_reg;
    always @(posedge clk) begin
        if (reset) begin
            key_code_reg <= 0;
        end else if (keypad_key_valid) begin
            key_code_reg <= keypad_key_code;
        end
    end
    assign current_key_code = key_code_reg;

    // -------------------
    // --- SHARED EQUATION BUFFER ---
    // -------------------
    reg [511:0] shared_equation_buffer;  // 64 chars × 8 bits = 512 bits (packed array)
    reg [6:0] shared_equation_length;     // 0-127 characters
    reg shared_equation_complete;         // Set when '=' pressed

    // SHARED BUFFER MANAGEMENT - Central input processing
    always @(posedge clk) begin
        if (reset) begin
            shared_equation_length <= 0;
            shared_equation_complete <= 0;
            shared_equation_buffer <= 512'b0;
        end else begin
            if (ascii_valid) begin
                case (ascii_char)
                    8'h43: begin  // 'C' - Clear (allowed even when complete)
                        shared_equation_length <= 0;
                        shared_equation_complete <= 0;
                        shared_equation_buffer <= 512'b0;
                    end
                    8'h44: begin  // 'D' - Delete (allowed even when complete)
                        if (shared_equation_length > 0) begin
                            shared_equation_length <= shared_equation_length - 1;
                        end
                        shared_equation_complete <= 0;  // Allow editing after complete
                        // Optionally clear the last byte
                        // (not necessary, but helpful for debug)
                        // shared_equation_buffer[(shared_equation_length-1)*8 +: 8] <= 8'h00;
                    end
                    8'h3D: begin  // '=' - Complete equation
                        if (!shared_equation_complete) begin
                            shared_equation_complete <= 1;
                        end
                    end
                    default: begin  // Regular character or function - allow editing even after complete
                        case (current_key_code)
                            5'd20: begin  // KEY_SIN - insert "sin"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h73;      // 's'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h69; // 'i'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h6E; // 'n'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd21: begin  // KEY_COS - insert "cos"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h63;      // 'c'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h6F; // 'o'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h73; // 's'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd22: begin  // KEY_TAN - insert "tan"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h74;      // 't'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h61; // 'a'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h6E; // 'n'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd25: begin  // KEY_X_SQUARED - insert "^2"
                                if (shared_equation_length + 2 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h5E;      // '^'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h32; // '2'
                                    shared_equation_length <= shared_equation_length + 2;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd26: begin  // KEY_SQRT_X - insert "√("
                                if (shared_equation_length + 2 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'hFB;      // '√'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h28; // '('
                                    shared_equation_length <= shared_equation_length + 2;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd27: begin  // KEY_PI - insert special char (π)
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'hE3;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd28: begin  // KEY_E - insert "e"
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h65;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            default: begin  // Regular character - append ascii_char
                                if (shared_equation_length < 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= ascii_char;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                        endcase
                    end
                endcase
            end
        end
    end

    // VGA Output Register Update - Synchronize to prevent mode switching glitches
    always @(posedge clk) begin
        if (reset) begin
            vga_pixel_data_reg <= 12'h000;  // Initialize to black on reset
        end else begin
            vga_pixel_data_reg <= selected_vga_data;
        end
    end

    // Debug: Show shared equation state on LEDs
    // LED mapping: [13:12] mode, [11:6] length[6:1], [5] key valid, [4:0] key code
    assign led = {
        current_main_mode,               // LED[13:12] - Mode indicator
        shared_equation_length[6:1],     // LED[11:6]  - Shared equation length (0-127, shifted)
        keypad_key_valid,                // LED[5]     - Key press indicator
        keypad_key_code                  // LED[4:0]   - Current key code
    };

    // 7-Segment Display: Show status feedback
    assign seg = 8'b11111111;  // All segments off for now
    assign an  = 4'b1111;      // All digits off

    // -------------------------
    // --- CALCULATOR MODULE ---
    // -------------------------
    calc_mode_module calc_mode_module_inst(
        .clk(clk),
        .reset(reset),
        // SHARED BUFFER INPUTS (READ-ONLY)
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_complete(shared_equation_complete),
        .pixel_index(pixel_index),
        .oled_data(calculator_screen_oled),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        .vga_data(calculator_screen_vga)
    );

    // ----------------------
    // --- GRAPHER MODULE ---
    // ----------------------
    graph_mode_module graph_mode_module_inst(
        .clk(clk),
        .reset(reset),
        // SHARED BUFFER INPUTS (READ-ONLY)
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_complete(shared_equation_complete),
        .pixel_index(pixel_index),
        .oled_data(grapher_screen_oled),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_p_tick(vga_p_tick),
        .vga_data(grapher_screen_vga)
    );

    // New Mode Logic: accept handshake requests from submodules
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
                // Only accept requests relevant to the current mode.
                // For now we accept welcome requests when in MODE_WELCOME.
                if (current_main_mode == MODE_WELCOME) begin
                    if (welcome_mode_req) begin
                        current_main_mode <= welcome_mode_target;
                        welcome_mode_ack <= 1'b1; // one-cycle acknowledgement
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
