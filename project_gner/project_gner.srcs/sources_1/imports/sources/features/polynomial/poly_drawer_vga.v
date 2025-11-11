module poly_drawer_vga(
    input clk,
    input [9:0] vga_x,
    input [9:0] vga_y,
    output reg [11:0] vga_data,
    input [2:0] active_coeff_index,
    input [79:0] coeff_a3_str, coeff_a2_str, coeff_a1_str, coeff_a0_str,
    input signed [23:0] coeff_a3, coeff_a2, coeff_a1, coeff_a0,
    input solve_done,
    input signed [23:0] root_real_1, root_imag_1,
    input signed [23:0] root_real_2, root_imag_2,
    input signed [23:0] root_real_3, root_imag_3,
    input [3:0] input_digit_index
);

    // Screen Resolution
    localparam H_RES = 640;
    localparam V_RES = 480;

    // Font Parameters
    localparam FONT_WIDTH  = 8;
    localparam FONT_HEIGHT = 8;

    // Colors
    localparam BG_COLOR = 12'h000;        // Black background
    localparam TEXT_COLOR = 12'hFFF;      // White text
    localparam ACTIVE_BG = 12'h440;       // Darker background for active coefficient
    localparam BOX_COLOR = 12'hFFF;       // White for box drawing

    // Font BRAM interface
    wire [7:0] font_data_out;
    reg [10:0] font_addr;

    blk_mem_gen_font font_inst (
        .clka(clk),
        .ena(1'b1),
        .addra(font_addr),
        .douta(font_data_out)
    );

    // Cursor blinking
    reg [25:0] blink_counter = 0;
    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;
        if (blink_counter >= 50000000) blink_counter <= 0;
    end
    wire cursor_visible = blink_counter < 25000000;

    // Combinational temporaries
    reg [2:0] coeff_index;

    // Pipelining registers
    reg [7:0] char_code_reg;
    reg [2:0] row_index_reg;
    reg [2:0] pixel_column_reg;
    reg [11:0] fg_color_reg;
    reg [11:0] bg_color_reg;
    reg font_bit;

    // Combinational logic for character and background
    reg [7:0] char_code;
    reg [11:0] bg_color;
    reg [9:0] rel_x, rel_y;
    reg [6:0] char_x, char_y;
    reg [79:0] current_coeff_str;

    // Root display formatting variables
    reg signed [23:0] real_val, imag_val;
    reg signed [23:0] abs_real_val, abs_imag_val; // Use absolute values for parsing
    reg signed [17:0] real_int, imag_int;     // 18-bit integer part
    reg [5:0] real_frac, imag_frac;         // 6-bit fractional part
    reg [7:0] real_frac_digits, imag_frac_digits;
    reg [7:0] r_digit0, r_digit1, r_digit2, r_digit3, r_digit4, r_digit5;
    reg [7:0] i_digit0, i_digit1, i_digit2, i_digit3, i_digit4, i_digit5;
    integer abs_real_int_val, abs_imag_int_val; // Integer type for division
    integer real_leading_zeros, imag_leading_zeros;

    always @* begin
        rel_x = vga_x;
        rel_y = vga_y;
        char_x = rel_x / FONT_WIDTH;
        char_y = rel_y / FONT_HEIGHT;

        // Boundary check
        if (char_x >= 80 || char_y >= 60) begin
            char_code = 8'h20; // Space
        end else begin
            // Content area
            case (char_y)
            15: begin // Title: "POLYNOMIAL SOLVER - DEGREE 3" (centered)
                case (char_x)
                    26: char_code = 8'h50; // P
                    27: char_code = 8'h4F; // O
                    28: char_code = 8'h4C; // L
                    29: char_code = 8'h59; // Y
                    30: char_code = 8'h4E; // N
                    31: char_code = 8'h4F; // O
                    32: char_code = 8'h4D; // M
                    33: char_code = 8'h49; // I
                    34: char_code = 8'h41; // A
                    35: char_code = 8'h4C; // L
                    37: char_code = 8'h53; // S
                    38: char_code = 8'h4F; // O
                    39: char_code = 8'h4C; // L
                    40: char_code = 8'h56; // V
                    41: char_code = 8'h45; // E
                    42: char_code = 8'h52; // R
                    44: char_code = 8'h2D; // -
                    46: char_code = 8'h44; // D
                    47: char_code = 8'h45; // E
                    48: char_code = 8'h47; // G
                    49: char_code = 8'h52; // R
                    50: char_code = 8'h45; // E
                    51: char_code = 8'h45; // E
                    53: char_code = 8'h33; // 3
                    default: char_code = 8'h20; // Space
                endcase
            end
            18: begin // Warning: "ONLY NUMBER INPUTS ARE ALLOWED" (centered)
                case (char_x)
                    27: char_code = 8'h4F; // O
                    28: char_code = 8'h4E; // N
                    29: char_code = 8'h4C; // L
                    30: char_code = 8'h59; // Y
                    32: char_code = 8'h4E; // N
                    33: char_code = 8'h55; // U
                    34: char_code = 8'h4D; // M
                    35: char_code = 8'h42; // B
                    36: char_code = 8'h45; // E
                    37: char_code = 8'h52; // R
                    39: char_code = 8'h49; // I
                    40: char_code = 8'h4E; // N
                    41: char_code = 8'h50; // P
                    42: char_code = 8'h55; // U
                    43: char_code = 8'h54; // T
                    44: char_code = 8'h53; // S
                    46: char_code = 8'h41; // A
                    47: char_code = 8'h52; // R
                    48: char_code = 8'h45; // E
                    50: char_code = 8'h41; // A
                    51: char_code = 8'h4C; // L
                    52: char_code = 8'h4C; // L
                    53: char_code = 8'h4F; // O
                    54: char_code = 8'h57; // W
                    55: char_code = 8'h45; // E
                    56: char_code = 8'h44; // D
                    default: char_code = 8'h20; // Space
                endcase
            end
            21: begin // Polynomial equation: Ax^3 + Bx^2 + Cx + D = 0
                case (char_x)
                    28: char_code = 8'h41; // A
                    29: char_code = 8'h78; // x
                    30: char_code = 8'h5E; // ^
                    31: char_code = 8'h33; // 3
                    32: char_code = 8'h20; // space
                    33: char_code = 8'h2B; // +
                    34: char_code = 8'h20; // space
                    35: char_code = 8'h42; // B
                    36: char_code = 8'h78; // x
                    37: char_code = 8'h5E; // ^
                    38: char_code = 8'h32; // 2
                    39: char_code = 8'h20; // space
                    40: char_code = 8'h2B; // +
                    41: char_code = 8'h20; // space
                    42: char_code = 8'h43; // C
                    43: char_code = 8'h78; // x
                    44: char_code = 8'h20; // space
                    45: char_code = 8'h2B; // +
                    46: char_code = 8'h20; // space
                    47: char_code = 8'h44; // D
                    48: char_code = 8'h20; // space
                    49: char_code = 8'h3D; // =
                    50: char_code = 8'h20; // space
                    51: char_code = 8'h30; // 0
                    default: char_code = 8'h20; // Space
                endcase
            end
            26,28,30,32: begin // Coefficients A, B, C, D (cubic: a3..a0)
                coeff_index = (char_y - 26) >> 1; // 0..3
                case (coeff_index)
                    0: current_coeff_str = coeff_a3_str; // A (a3)
                    1: current_coeff_str = coeff_a2_str; // B (a2)
                    2: current_coeff_str = coeff_a1_str; // C (a1)
                    3: current_coeff_str = coeff_a0_str; // D (a0)
                    default: current_coeff_str = 80'h20202020202020202020;
                endcase
                case (char_x)
                    30: char_code = 8'h41 + coeff_index; // A, B, C, D
                    32: char_code = 8'h3A; // :
                    34: char_code = 8'h5B; // [
                    35: char_code = current_coeff_str[7:0];   // 1st char
                    36: char_code = current_coeff_str[15:8];  // 2nd
                    37: char_code = current_coeff_str[23:16]; // 3rd
                    38: char_code = current_coeff_str[31:24]; // 4th
                    39: char_code = current_coeff_str[39:32]; // 5th
                    40: char_code = current_coeff_str[47:40]; // 6th
                    41: char_code = current_coeff_str[55:48]; // 7th
                    42: char_code = current_coeff_str[63:56]; // 8th
                    43: char_code = current_coeff_str[71:64]; // 9th
                    44: char_code = current_coeff_str[79:72]; // 10th
                    45: char_code = 8'h5D; // ]
                    default: char_code = 8'h20; // Space
                endcase
                // Cursor override
                if (((char_y - 26) >> 1) == active_coeff_index && cursor_visible && char_x == 35 + input_digit_index) begin
                    char_code = 8'h7C; // Cursor (|) at current input position
                end
            end
            41: begin // Navigation: "NAVIGATION: [D TO GO BACK] [= TO GO NEXT] [C TO RESET]" (centered)
                case (char_x)
                    14: char_code = 8'h4E; // N
                    15: char_code = 8'h41; // A
                    16: char_code = 8'h56; // V
                    17: char_code = 8'h49; // I
                    18: char_code = 8'h47; // G
                    19: char_code = 8'h41; // A
                    20: char_code = 8'h54; // T
                    21: char_code = 8'h49; // I
                    22: char_code = 8'h4F; // O
                    23: char_code = 8'h4E; // N
                    24: char_code = 8'h3A; // :
                    25: char_code = 8'h20; // space
                    26: char_code = 8'h5B; // [
                    27: char_code = 8'h44; // D
                    28: char_code = 8'h20; // space
                    29: char_code = 8'h54; // T
                    30: char_code = 8'h4F; // O
                    31: char_code = 8'h20; // space
                    32: char_code = 8'h47; // G
                    33: char_code = 8'h4F; // O
                    34: char_code = 8'h20; // space
                    35: char_code = 8'h42; // B
                    36: char_code = 8'h41; // A
                    37: char_code = 8'h43; // C
                    38: char_code = 8'h4B; // K
                    39: char_code = 8'h5D; // ]
                    40: char_code = 8'h20; // space
                    41: char_code = 8'h5B; // [
                    42: char_code = 8'h3D; // =
                    43: char_code = 8'h20; // space
                    44: char_code = 8'h54; // T
                    45: char_code = 8'h4F; // O
                    46: char_code = 8'h20; // space
                    47: char_code = 8'h47; // G
                    48: char_code = 8'h4F; // O
                    49: char_code = 8'h20; // space
                    50: char_code = 8'h4E; // N
                    51: char_code = 8'h45; // E
                    52: char_code = 8'h58; // X
                    53: char_code = 8'h54; // T
                    54: char_code = 8'h5D; // ]
                    55: char_code = 8'h20; // space
                    56: char_code = 8'h5B; // [
                    57: char_code = 8'h43; // C
                    58: char_code = 8'h20; // space
                    59: char_code = 8'h54; // T
                    60: char_code = 8'h4F; // O
                    61: char_code = 8'h20; // space
                    62: char_code = 8'h52; // R
                    63: char_code = 8'h45; // E
                    64: char_code = 8'h53; // S
                    65: char_code = 8'h45; // E
                    66: char_code = 8'h54; // T
                    67: char_code = 8'h5D; // ]
                    default: char_code = 8'h20; // Space
                endcase
            end

            // ==========================================================
            // === WARNING LINE (char_y == 44) ===
            // ==========================================================
            44: begin // Warning: " NOTE: 0 IS NOT AN AVAILABLE LEADING INPUT"
                case (char_x)
                    19: char_code = 8'h20; // space
                    20: char_code = 8'h4E; // N
                    21: char_code = 8'h4F; // O
                    22: char_code = 8'h54; // T
                    23: char_code = 8'h45; // E
                    24: char_code = 8'h3A; // :
                    // 25: space
                    26: char_code = 8'h20; // space
                    27: char_code = 8'h30; // 0
                    // 28: space
                    29: char_code = 8'h49; // I
                    30: char_code = 8'h53; // S
                    // 31: space
                    32: char_code = 8'h4E; // N
                    33: char_code = 8'h4F; // O
                    34: char_code = 8'h54; // T
                    // 35: space
                    36: char_code = 8'h41; // A
                    37: char_code = 8'h4E; // N
                    // 38: space
                    39: char_code = 8'h41; // A
                    40: char_code = 8'h56; // V
                    41: char_code = 8'h41; // A
                    42: char_code = 8'h49; // I
                    43: char_code = 8'h4C; // L
                    44: char_code = 8'h41; // A
                    45: char_code = 8'h42; // B
                    46: char_code = 8'h4C; // L
                    47: char_code = 8'h45; // E
                    // 48: space
                    49: char_code = 8'h4C; // L
                    50: char_code = 8'h45; // E
                    51: char_code = 8'h41; // A
                    52: char_code = 8'h44; // D
                    53: char_code = 8'h49; // I
                    54: char_code = 8'h4E; // N
                    55: char_code = 8'h47; // G
                    // 56: space
                    57: char_code = 8'h49; // I
                    58: char_code = 8'h4E; // N
                    59: char_code = 8'h50; // P
                    60: char_code = 8'h55; // U
                    61: char_code = 8'h54; // T
                    default: char_code = 8'h20; // Space
                endcase
            end
            // ==========================================================
            // === END OF WARNING LINE ===
            // ==========================================================

            47,49,51: begin // Solutions X1=, X2=, X3=
                if (!solve_done) begin
                    // Show "Not solved" message
                    case (char_x)
                        26: char_code = 8'h4E; // N
                        27: char_code = 8'h4F; // O
                        28: char_code = 8'h54; // T
                        30: char_code = 8'h53; // S
                        31: char_code = 8'h4F; // O
                        32: char_code = 8'h4C; // L
                        33: char_code = 8'h56; // V
                        34: char_code = 8'h45; // E
                        35: char_code = 8'h44; // D
                        default: char_code = 8'h20; // Space
                    endcase
                end else begin
                    // Select root based on row
                    case ((char_y - 47) >> 1)
                         0: begin real_val = root_real_1; imag_val = root_imag_1; end
                        1: begin real_val = root_real_2; imag_val = root_imag_2; end
                        2: begin real_val = root_real_3; imag_val = root_imag_3; end
                        default: begin real_val = 24'sd0; imag_val = 24'sd0; end
                    endcase

                    // ==========================================================
                    // === "SMART" ROOT PARSING LOGIC (FIXED) ===
                    // ==========================================================

                    // --- PARSE REAL PART (FULLY CORRECTED) ---
                    // Get absolute value of entire Q18.6 number FIRST
                    abs_real_val = (real_val[23]) ? -real_val : real_val;

                    // Now extract integer and fractional parts from absolute value
                    real_int = abs_real_val >>> 6;  // Integer part (unsigned, since we took abs)
                    real_frac = abs_real_val[5:0];  // Fractional bits (unsigned)
                    real_frac_digits = (real_frac * 100) >> 6;
                    abs_real_int_val = real_int;

                    // Extract digits from absolute integer value
                    r_digit0 = (abs_real_int_val / 100000) % 10; // 100k
                    r_digit1 = (abs_real_int_val / 10000) % 10;  // 10k
                    r_digit2 = (abs_real_int_val / 1000) % 10;   // 1k
                    r_digit3 = (abs_real_int_val / 100) % 10;    // 100
                    r_digit4 = (abs_real_int_val / 10) % 10;     // 10
                    r_digit5 = abs_real_int_val % 10;            // 1

                    // Calculate leading zeros
                    real_leading_zeros = 0;
                    if (r_digit0 == 0) begin
                        real_leading_zeros = real_leading_zeros + 1;
                        if (r_digit1 == 0) begin
                            real_leading_zeros = real_leading_zeros + 1;
                            if (r_digit2 == 0) begin
                                real_leading_zeros = real_leading_zeros + 1;
                                if (r_digit3 == 0) begin
                                    real_leading_zeros = real_leading_zeros + 1;
                                    if (r_digit4 == 0) begin
                                        real_leading_zeros = real_leading_zeros + 1;
                                    end
                                end
                            end
                        end
                    end

                    // --- PARSE IMAGINARY PART (FULLY CORRECTED) ---
                    // Get absolute value of entire Q18.6 number FIRST
                    abs_imag_val = (imag_val[23]) ? -imag_val : imag_val;

                    // Now extract integer and fractional parts from absolute value
                    imag_int = abs_imag_val >>> 6;  // Integer part (unsigned, since we took abs)
                    imag_frac = abs_imag_val[5:0];  // Fractional bits (unsigned)
                    imag_frac_digits = (imag_frac * 100) >> 6;
                    abs_imag_int_val = imag_int;

                    // Extract digits from absolute integer value
                    i_digit0 = (abs_imag_int_val / 100000) % 10; // 100k
                    i_digit1 = (abs_imag_int_val / 10000) % 10;  // 10k
                    i_digit2 = (abs_imag_int_val / 1000) % 10;   // 1k
                    i_digit3 = (abs_imag_int_val / 100) % 10;    // 100
                    i_digit4 = (abs_imag_int_val / 10) % 10;     // 10
                    i_digit5 = abs_imag_int_val % 10;            // 1

                    imag_leading_zeros = 0;
                    if (i_digit0 == 0) begin
                        imag_leading_zeros = imag_leading_zeros + 1;
                        if (i_digit1 == 0) begin
                            imag_leading_zeros = imag_leading_zeros + 1;
                            if (i_digit2 == 0) begin
                                imag_leading_zeros = imag_leading_zeros + 1;
                                if (i_digit3 == 0) begin
                                    imag_leading_zeros = imag_leading_zeros + 1;
                                    if (i_digit4 == 0) begin
                                        imag_leading_zeros = imag_leading_zeros + 1;
                                    end
                                end
                            end
                        end
                    end
                    // ==========================================================
                    // === END OF PARSING LOGIC FIX ===
                    // ==========================================================

                    // Display format: "X1 = RRRRRR.RR + IIIIII.IIi"
                    case (char_x)
                        26: char_code = 8'h58; // X
                        27: char_code = 8'h31 + ((char_y - 47) >> 1); // 1,2,3
                        28: char_code = 8'h20; // space
                        29: char_code = 8'h3D; // =
                        30: char_code = 8'h20; // space

                        // ==========================================================
                        // === "SMART" REAL ROOT DISPLAY (FIXED) ===
                        // ==========================================================
                        31: begin // Sign
                            if (real_val < 0) char_code = 8'h2D; // '-'
                            else char_code = 8'h20; // space
                        end
                        // Hide leading zeros and display in correct order
                        32: char_code = (real_leading_zeros >= 1) ? 8'h20 : (8'h30 + r_digit0); // 100k
                        33: char_code = (real_leading_zeros >= 2) ? 8'h20 : (8'h30 + r_digit1); // 10k
                        34: char_code = (real_leading_zeros >= 3) ? 8'h20 : (8'h30 + r_digit2); // 1k
                        35: char_code = (real_leading_zeros >= 4) ? 8'h20 : (8'h30 + r_digit3); // 100s
                        36: char_code = (real_leading_zeros >= 5) ? 8'h20 : (8'h30 + r_digit4); // 10s
                        37: char_code = 8'h30 + r_digit5; // 1s (always show)

                        38: char_code = 8'h2E; // '.'
                        39: char_code = 8'h30 + (real_frac_digits / 10); // .x
                        40: char_code = 8'h30 + (real_frac_digits % 10); // ._x
                        41: char_code = 8'h20; // space

                        // Sign between real and imaginary (+ or -)
                        42: begin
                            if (imag_val < 0) char_code = 8'h2D; // '-'
                            else char_code = 8'h2B; // '+'
                        end
                        43: char_code = 8'h20; // space

                        // ==========================================================
                        // === "SMART" IMAGINARY ROOT DISPLAY (FIXED) ===
                        // ==========================================================
                        44: char_code = (imag_leading_zeros >= 1) ? 8'h20 : (8'h30 + i_digit0); // 100k
                        45: char_code = (imag_leading_zeros >= 2) ? 8'h20 : (8'h30 + i_digit1); // 10k
                        46: char_code = (imag_leading_zeros >= 3) ? 8'h20 : (8'h30 + i_digit2); // 1k
                        47: char_code = (imag_leading_zeros >= 4) ? 8'h20 : (8'h30 + i_digit3); // 100s
                        48: char_code = (imag_leading_zeros >= 5) ? 8'h20 : (8'h30 + i_digit4); // 10s
                        49: char_code = 8'h30 + i_digit5; // 1s (always show)

                        50: char_code = 8'h2E; // '.'
                        51: char_code = 8'h30 + (imag_frac_digits / 10); // .x
                        52: char_code = 8'h30 + (imag_frac_digits % 10); // ._x
                        53: char_code = 8'h69; // 'i'
                        default: char_code = 8'h20; // space
                    endcase
                    // ==========================================================
                    // === END OF "SMART" DISPLAY FIX ===
                    // ==========================================================
                end
            end
            default: char_code = 8'h20; // Space
            endcase
        end
    end

    always @* begin
        rel_x = vga_x;
        rel_y = vga_y;
        char_x = rel_x / FONT_WIDTH;
        char_y = rel_y / FONT_HEIGHT;

        // Active coefficient highlighting
        if (char_y >= 26 && char_y <= 36 && (char_y % 2 == 0) && (((char_y - 26) >> 1) == active_coeff_index) &&
            char_x >= 34 && char_x <= 45) begin
            bg_color = ACTIVE_BG;
        end else begin
            bg_color = BG_COLOR;
        end
    end

    // Main rendering logic
    always @(posedge clk) begin
        bg_color_reg <= bg_color;
        fg_color_reg <= TEXT_COLOR;

        char_code_reg <= char_code;
        row_index_reg <= vga_y % FONT_HEIGHT;
        pixel_column_reg <= vga_x % FONT_WIDTH;

        font_addr <= {char_code_reg, row_index_reg};
        font_bit <= font_data_out[7 - pixel_column_reg];

        if (font_bit) begin
            vga_data <= fg_color_reg;
        end else begin
            vga_data <= bg_color_reg;
        end
    end

endmodule