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
    output reg [2:0] current_main_mode
);

    // ON/OFF CALCULATOR (driven by sw[15])
    wire reset = ~sw[15];

    // MAIN OPERATION MODES
    localparam MODE_OFF           = 3'b000; // Off Screen
    localparam MODE_WELCOME       = 3'b001; // Main Screen
    localparam MODE_CALCULATOR    = 3'b010; // Calculator Mode
    localparam MODE_GRAPHER       = 3'b011; // Grapher Mode
    localparam MODE_POLY          = 3'b100; // Polynomial Mode

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

    // EFFICIENT FIX: Blank keypad OLED when not in calc/graph/poly mode (16 LUTs)
    wire [15:0] keypad_oled = ((current_main_mode == MODE_CALCULATOR) ||
                               (current_main_mode == MODE_GRAPHER) ||
                               (current_main_mode == MODE_POLY)) ? keypad_oled_raw : 16'h0000;

    // OLED Screen Data
    assign oled_data =
        (current_main_mode == MODE_OFF)        ? off_screen_oled :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_oled :
        (current_main_mode == MODE_CALCULATOR) ? keypad_oled :
        (current_main_mode == MODE_GRAPHER)    ? keypad_oled :
        (current_main_mode == MODE_POLY)       ? keypad_oled :
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
    wire [11:0] poly_screen_vga;

    // VGA Screen Data - Combinatorial selection
    wire [11:0] selected_vga_data =
        (current_main_mode == MODE_OFF)        ? off_screen_vga :
        (current_main_mode == MODE_WELCOME)    ? welcome_screen_vga :
        (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
        (current_main_mode == MODE_GRAPHER)    ? grapher_screen_vga :
        (current_main_mode == MODE_POLY)       ? poly_screen_vga :
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
    wire [2:0]  welcome_mode_target;  // Expanded to 3 bits for MODE_POLY
    reg         welcome_mode_ack;

    // =========================================
    // === POLYNOMIAL SOLVER WIRES (EARLY DECLARATION) ===
    // =========================================
    // Upgraded to Q16.8 format (24-bit signed) for extended range
    wire signed [23:0] poly_coeff_a3, poly_coeff_a2, poly_coeff_a1, poly_coeff_a0;
    wire [79:0] poly_coeff_a3_str, poly_coeff_a2_str, poly_coeff_a1_str, poly_coeff_a0_str;
    wire poly_solve_trigger, poly_solve_done;
    wire signed [23:0] poly_root_real_1, poly_root_imag_1;
    wire signed [23:0] poly_root_real_2, poly_root_imag_2;
    wire signed [23:0] poly_root_real_3, poly_root_imag_3;
    wire signed [23:0] poly_root_real_4, poly_root_imag_4;
    wire signed [23:0] poly_root_real_5, poly_root_imag_5;
    wire poly_delete_signal, poly_clear_signal, poly_equal_signal;
    wire poly_key_strobe = ascii_valid && (current_main_mode == MODE_POLY);
    reg prev_poly_key_strobe;

    // ------------------------
    // --- BUTTON DEBOUNCER ---
    // ------------------------
    wire [4:0] btn_debounced;
    button_debouncer_array button_debouncer_array_inst(
        .clk(clk),
        .btn(btn),
        .btn_debounced(btn_debounced)
    );

    // ====================================
    // === POLYNOMIAL KEY STROBE LOGIC ===
    // ====================================
    always @(posedge clk) begin
        if (reset) begin
            prev_poly_key_strobe <= 1'b0;
        end else begin
            prev_poly_key_strobe <= poly_key_strobe;
        end
    end

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

    // Enable keypad in calculator, grapher, or polynomial mode
    wire keypad_enable = ((current_main_mode == MODE_CALCULATOR) || (current_main_mode == MODE_GRAPHER) || (current_main_mode == MODE_POLY));

    // NO DOUBLE-GATING! Keypad already handles enable internally
    wire keypad_key_valid = keypad_key_valid_raw;  // Direct connection

    oled_keypad oled_keypad_inst(
        .clk(clk),
        .reset(reset),
        .enable(keypad_enable),       // Keypad gates internally
        .vga_buffer_full(shared_equation_length >= 64),
        .pixel_index(pixel_index),
        .btn_debounced(btn_debounced),
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_symbol_count(shared_equation_length > 15 ? 4'd15 : shared_equation_length[3:0]),
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
    reg [511:0] shared_equation_buffer;  // 64 chars Ã— 8 bits = 512 bits (packed array)
    reg [6:0] shared_equation_length;     // 0-127 characters
    reg shared_equation_complete;         // Set when '=' pressed

    // POLYNOMIAL MODE STATE
    reg [2:0] poly_active_coeff;          // 0=a3, 1=a2, 2=a1, 3=a0 (CUBIC)
    reg [3:0] poly_coeff_lengths [0:3];   // Length of each coefficient (0-10 chars)

    // ===================================================================
    // MODULAR BUFFER MANAGEMENT - Mode-Independent Input Processing
    // ===================================================================

    // Common character type detection
    wire is_digit = (ascii_char >= 8'h30 && ascii_char <= 8'h39);
    wire is_dot = (ascii_char == 8'h2E);
    wire is_minus = (ascii_char == 8'h2D);
    wire is_operator = (ascii_char == 8'h2B || ascii_char == 8'h2D ||
                        ascii_char == 8'h2A || ascii_char == 8'h2F);
    wire is_clear = (ascii_char == 8'h43);
    wire is_delete = (ascii_char == 8'h44);
    wire is_equals = (ascii_char == 8'h3D);

    // Mode-specific behaviors
    wire poly_mode = (current_main_mode == MODE_POLY);
    wire calc_mode = (current_main_mode == MODE_CALCULATOR);
    wire graph_mode = (current_main_mode == MODE_GRAPHER);
    wire linear_mode = calc_mode || graph_mode;  // Linear buffer modes

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Reset all state
            shared_equation_length <= 0;
            shared_equation_complete <= 0;
            shared_equation_buffer <= 512'b0;
            poly_active_coeff <= 0;
            poly_coeff_lengths[0] <= 0; poly_coeff_lengths[1] <= 0;
            poly_coeff_lengths[2] <= 0; poly_coeff_lengths[3] <= 0;
        end else begin
            if (ascii_valid) begin
                // ===== UNIVERSAL CLEAR HANDLER =====
                if (is_clear) begin
                    if (poly_mode) begin
                        // Poly: Clear current coefficient only
                        for (i=0; i<10; i=i+1) begin
                            shared_equation_buffer[(poly_active_coeff*10 + i)*8 +: 8] <= 8'h20;
                        end
                        poly_coeff_lengths[poly_active_coeff] <= 0;
                    end else if (linear_mode) begin
                        // Calc/Graph: Clear entire buffer
                        shared_equation_length <= 0;
                        shared_equation_complete <= 0;
                        shared_equation_buffer <= 512'b0;
                    end
                end

                // ===== UNIVERSAL DELETE HANDLER =====
                else if (is_delete) begin
                    if (poly_mode) begin
                        // Poly: Delete in current coeff OR navigate back
                        if (poly_coeff_lengths[poly_active_coeff] > 0) begin
                            poly_coeff_lengths[poly_active_coeff] <= poly_coeff_lengths[poly_active_coeff] - 1;
                            shared_equation_buffer[(poly_active_coeff*10 + poly_coeff_lengths[poly_active_coeff]-1)*8 +: 8] <= 8'h20;
                        end else if (poly_active_coeff > 0) begin
                            poly_active_coeff <= poly_active_coeff - 1;
                        end
                    end else if (linear_mode) begin
                        // Calc/Graph: Delete last character
                        if (shared_equation_length > 0) begin
                            shared_equation_length <= shared_equation_length - 1;
                        end
                        shared_equation_complete <= 0;
                    end
                end

                // ===== UNIVERSAL EQUALS HANDLER =====
                else if (is_equals) begin
                    if (poly_mode) begin
                        // Poly: Advance to next coeff OR trigger solve
                        if (poly_active_coeff < 3) begin
                            poly_active_coeff <= poly_active_coeff + 1;
                        end else begin
                            shared_equation_complete <= 1;
                        end
                    end else if (linear_mode) begin
                        // Calc/Graph: Mark equation complete
                        if (!shared_equation_complete) begin
                            shared_equation_complete <= 1;
                        end
                    end
                end

                // ===== MODE-SPECIFIC CHARACTER INPUT =====
                else begin
                    if (poly_mode) begin
                        // Poly: Only accept digits, dot, minus
                        if (is_digit || is_dot || is_minus) begin
                            if (poly_coeff_lengths[poly_active_coeff] < 10) begin
                                shared_equation_buffer[(poly_active_coeff*10 + poly_coeff_lengths[poly_active_coeff])*8 +: 8] <= ascii_char;
                                poly_coeff_lengths[poly_active_coeff] <= poly_coeff_lengths[poly_active_coeff] + 1;
                            end
                        end
                    end else if (linear_mode) begin
                        // Calc/Graph: Handle operators and function keys based on key code
                        case (current_key_code)
                            5'd15: begin  // KEY_SIN - insert "sin"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h73;      // 's'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h69; // 'i'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h6E; // 'n'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd16: begin  // KEY_COS - insert "cos"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h63;      // 'c'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h6F; // 'o'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h73; // 's'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd17: begin  // KEY_TAN - insert "tan"
                                if (shared_equation_length + 3 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h74;      // 't'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h61; // 'a'
                                    shared_equation_buffer[(shared_equation_length+2)*8 +: 8] <= 8'h6E; // 'n'
                                    shared_equation_length <= shared_equation_length + 3;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd18: begin  // KEY_LN - insert "ln"
                                if (shared_equation_length + 2 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h6C;      // 'l'
                                    shared_equation_buffer[(shared_equation_length+1)*8 +: 8] <= 8'h6E; // 'n'
                                    shared_equation_length <= shared_equation_length + 2;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd19: begin  // KEY_SQRT - insert special char (placeholder 0xFB)
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'hFB;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd20: begin  // KEY_PI - insert special char (placeholder 0xE3)
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'hE3;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd21: begin  // KEY_E - insert "e"
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h65;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            5'd28: begin  // KEY_FACTORIAL - insert "!"
                                if (shared_equation_length + 1 <= 64) begin
                                    shared_equation_buffer[shared_equation_length*8 +: 8] <= 8'h21;
                                    shared_equation_length <= shared_equation_length + 1;
                                    shared_equation_complete <= 0;  // Allow further editing
                                end
                            end
                            default: begin  // Regular character or operator
                                // Check if it's an operator (+, -, *, /)
                                if (ascii_char == 8'h2B || ascii_char == 8'h2D ||
                                    ascii_char == 8'h2A || ascii_char == 8'h2F) begin
                                    // OPERATOR: Clear buffer and show operator only
                                    shared_equation_buffer <= 512'b0;
                                    shared_equation_buffer[0*8 +: 8] <= ascii_char;
                                    shared_equation_length <= 1;
                                    shared_equation_complete <= 0;
                                end else begin
                                    // Regular character - append
                                    if (shared_equation_length < 64) begin
                                        shared_equation_buffer[shared_equation_length*8 +: 8] <= ascii_char;
                                        shared_equation_length <= shared_equation_length + 1;
                                        shared_equation_complete <= 0;  // Allow further editing
                                    end
                                end
                            end
                        endcase
                    end  // End else if (linear mode character handling)
                end  // End else (MODE-SPECIFIC CHARACTER INPUT)
            end  // End if(ascii_valid)
        end  // End else (not reset)
    end  // End always @(posedge clk)

    // VGA Output Register Update - Synchronize to prevent mode switching glitches
    always @(posedge clk) begin
        if (reset) begin
            vga_pixel_data_reg <= 12'h000;  // Initialize to black on reset
        end else begin
            vga_pixel_data_reg <= selected_vga_data;
        end
    end

    // Debug: Show shared equation state on LEDs
    // LED mapping: [13:11] mode, [10:6] length[5:1], [5] key valid, [4:0] key code
    assign led = {
        current_main_mode,               // LED[13:11] - Mode indicator (3-bit)
        shared_equation_length[5:1],     // LED[10:6]  - Shared equation length (0-127, shifted)
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

    // =========================================
    // === POLYNOMIAL SOLVER MODULES ===
    // =========================================
    // (Wires declared at top of module after handshake wires)

    // -------------------------
    // --- POLYNOMIAL MODULE ---
    // -------------------------
    poly_mode_module poly_mode_inst (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .poly_key_strobe(poly_key_strobe),
        .prev_poly_key_strobe(prev_poly_key_strobe),
        .poly_ascii_char(ascii_char),
        .delete_signal(poly_delete_signal),
        .clear_signal(poly_clear_signal),
        .equal_signal(poly_equal_signal),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(poly_screen_vga),
        .coeff_a3(poly_coeff_a3),
        .coeff_a2(poly_coeff_a2), .coeff_a1(poly_coeff_a1), .coeff_a0(poly_coeff_a0),
        .coeff_a3_str(poly_coeff_a3_str),
        .coeff_a2_str(poly_coeff_a2_str), .coeff_a1_str(poly_coeff_a1_str), .coeff_a0_str(poly_coeff_a0_str),
        .solve_trigger(poly_solve_trigger),
        .solve_done(poly_solve_done),
        .root_real_1(poly_root_real_1), .root_imag_1(poly_root_imag_1),
        .root_real_2(poly_root_real_2), .root_imag_2(poly_root_imag_2),
        .root_real_3(poly_root_real_3), .root_imag_3(poly_root_imag_3)
    );

    // -------------------------
    // --- POLYNOMIAL SOLVER ---
    // -------------------------
    poly_solver poly_solver_inst (
        .clk(clk),
        .rst_n(~reset),  // Active-low reset (solver expects rst_n)
        .start(poly_solve_trigger),
        .busy(),  // Not connected
        .done(poly_solve_done),
        .coeff_a(poly_coeff_a3),  // a3 = coefficient of x^3
        .coeff_b(poly_coeff_a2),  // a2 = coefficient of x^2
        .coeff_c(poly_coeff_a1),  // a1 = coefficient of x^1
        .coeff_d(poly_coeff_a0),  // a0 = coefficient of x^0
        .root1_real(poly_root_real_1), .root1_imag(poly_root_imag_1),
        .root2_real(poly_root_real_2), .root2_imag(poly_root_imag_2),
        .root3_real(poly_root_real_3), .root3_imag(poly_root_imag_3)
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
