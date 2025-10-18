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
    // Basys3 only has 14 LEDs (LED0-LED13)
    output [13:0] led,

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
        wire [15:0] keypad_oled_raw;

        // EFFICIENT FIX: Blank keypad OLED when not in calc/graph mode (16 LUTs)
        wire [15:0] keypad_oled = (current_main_mode == MODE_CALCULATOR ||
                                    current_main_mode == MODE_GRAPHER) ? keypad_oled_raw : 16'h0000;

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
    wire keypad_key_valid_raw;

    // Enable keypad only in calculator or grapher mode
    wire keypad_enable = (current_main_mode == MODE_CALCULATOR | current_main_mode == MODE_GRAPHER);

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

    key_to_ascii_converter ascii_converter_inst(
        .clk(clk),
        .rst(reset),
        .key_code(keypad_key_code),
        .key_valid(keypad_key_valid),
        .ascii_char(ascii_char),
        .char_valid(ascii_valid)
    );

    // -------------------
    // --- SHARED EQUATION BUFFER ---
    // -------------------
    reg [255:0] shared_equation_buffer;  // 32 chars × 8 bits = 256 bits (packed array)
    reg [4:0] shared_equation_length = 0;     // 0-31 characters
    reg shared_equation_complete = 0;         // Set when '=' pressed

    // SHARED BUFFER MANAGEMENT - Central input processing
    always @(posedge clk) begin
        if (reset) begin
            shared_equation_length <= 0;
            shared_equation_complete <= 0;
        end else if (ascii_valid && !shared_equation_complete) begin
            case (ascii_char)
                8'h43: begin  // 'C' - Clear
                    shared_equation_length <= 0;
                    shared_equation_complete <= 0;
                end
                8'h44: begin  // 'D' - Delete
                    if (shared_equation_length > 0) begin
                        shared_equation_length <= shared_equation_length - 1;
                    end
                end
                8'h3D: begin  // '=' - Complete equation
                    shared_equation_complete <= 1;
                end
                default: begin  // Regular character - append if space
                    if (shared_equation_length < 31) begin
                        shared_equation_buffer[shared_equation_length*8 +: 8] <= ascii_char;
                        shared_equation_length <= shared_equation_length + 1;
                    end
                end
            endcase
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
    assign led = {
        current_main_mode,          // LED[13:12] - Mode indicator
        shared_equation_length,     // LED[11:6]  - Shared equation length (0-31)
        keypad_key_valid,           // LED[5]     - Key press indicator
        keypad_key_code             // LED[4:0]   - Current key code
    };

    // 7-Segment Display: Show status feedback
    assign seg = 8'b11111111;  // All segments off for now
    assign an = 4'b1111;       // All digits off

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
        .vga_data(grapher_screen_vga)
    );

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