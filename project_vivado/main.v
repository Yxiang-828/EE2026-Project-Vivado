    `timescale 1ns / 1ps

    //////////////////////////////////////////////////////////////////////////////////
    //
    //  FILL IN THE FOLLOWING INFORMATION:
    //  STUDENT A NAME:
    //  STUDENT B NAME:
    //  STUDENT C NAME:
    //  STUDENT D NAME:
    //
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
    output [15:0] led,

    // 7-Segment Display (for status feedback)
    output [7:0] seg,
    output [3:0] an,

    // DEBUGGING
    output [1:0] current_main_mode
);        // ON/OFF CALCULATOR (driven by sw[15])
        wire reset = ~sw[15];

        // current_main_mode is a register (2 bits). new_mode is produced by
        // the welcome (and other) modules and must be a wire (module output).
        // reg [1:0] current_main_mode;

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
        wire [15:0] keypad_oled;

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

        // VGA Data from Sub-Modules
        wire [11:0] off_screen_vga;
        wire [11:0] welcome_screen_vga;
        wire [11:0] calculator_screen_vga;
        wire [11:0] grapher_screen_vga;

        // VGA Screen Data
        assign vga_pixel_data =
            (current_main_mode == MODE_OFF)        ? off_screen_vga :
            (current_main_mode == MODE_WELCOME)    ? welcome_screen_vga :
            (current_main_mode == MODE_CALCULATOR) ? calculator_screen_vga :
            (current_main_mode == MODE_GRAPHER)    ? grapher_screen_vga :
            12'h000;

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
            .vga_y(vga_y)
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
    wire keypad_key_valid;

    oled_keypad oled_keypad_inst(
        .clk(clk),
        .reset(reset),
        .pixel_index(pixel_index),
        .btn_debounced(btn_debounced),
        .oled_data(keypad_oled),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid)
    );
    
    // -------------------
    // --- DATA PARSER ---
    // -------------------
    
    // Parser outputs
    wire [3:0] parser_digit_value;
    wire parser_digit_valid;
    wire [3:0] parser_operator_code;
    wire parser_operator_valid;
    wire parser_dot_pressed;
    
    data_parser data_parser_inst(
        .clk(clk),
        .rst(reset),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .digit_value(parser_digit_value),
        .digit_valid(parser_digit_valid),
        .operator_code(parser_operator_code),
        .operator_valid(parser_operator_valid),
        .dot_pressed(parser_dot_pressed)
    );
    
    // Debug: Show parser outputs on LEDs
    // LED[4:0]   = key_code from keypad
    // LED[8:5]   = digit_value
    // LED[9]     = digit_valid
    // LED[13:10] = operator_code
    // LED[14:15] are not physically available on Basys3, tie to 0
    // Note: operator_valid and dot_pressed will be shown on 7-segment display
    assign led = {
        2'b00,  // LED[15:14] - not available on Basys3
        parser_operator_code,  // LED[13:10]
        parser_digit_valid,    // LED[9]
        parser_digit_value,    // LED[8:5]
        keypad_key_code        // LED[4:0]
    };
    
    // 7-Segment Display: Show status feedback
    // For now, display operator_valid and dot_pressed as simple indicators
    // Format: Display "----" when idle, flash patterns for loading/completion
    // TODO: Add proper 7-segment controller in future phases for better UX
    assign seg = {parser_dot_pressed, 7'b1111111};  // Dot on seg[7] (DP), all segments off
    assign an = {2'b11, parser_operator_valid, ~parser_operator_valid};  // Flash digit 0/1 when operator pressed        // -------------------------
        // --- CALCULATOR MODULE ---
        // -------------------------

        // ----------------------
        // --- GRAPHER MODULE ---
        // ----------------------

        // New Mode Logic: accept handshake requests from submodules
        reg [1:0] current_main_mode;
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