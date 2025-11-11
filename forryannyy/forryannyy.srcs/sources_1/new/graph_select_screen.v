`timescale 1ns / 1ps

module graph_type_selector(
    input clk,
    input [4:0] btn,
    input [1:0] current_main_mode,
    input [9:0] vga_x,
    input [9:0] vga_y,
    input sw14,
    input enable,
    input reset_selection,  // Reset type_selected when sw[3] changes
    output reg [2:0] selected_graph_type,
    output reg type_selected,
    output reg [11:0] vga_data,
    output reg [15:0] oled_data
);

    localparam MODE_GRAPHER = 2'b11;
    
    // Font Parameters
    localparam FONT_WIDTH  = 8;
    localparam FONT_HEIGHT = 8;
    
    // Title: SELECT GRAPH TYPE
    localparam CHAR_COUNT_TITLE = 17;
    localparam X_START_TITLE = 264;
    localparam Y_START_TITLE = 180;
    reg [7:0] title_rom [0:16];
    initial begin
        title_rom[0]  = 8'h53; // S
        title_rom[1]  = 8'h45; // E
        title_rom[2]  = 8'h4C; // L
        title_rom[3]  = 8'h45; // E
        title_rom[4]  = 8'h43; // C
        title_rom[5]  = 8'h54; // T
        title_rom[6]  = 8'h20; // (space)
        title_rom[7]  = 8'h47; // G
        title_rom[8]  = 8'h52; // R
        title_rom[9]  = 8'h41; // A
        title_rom[10] = 8'h50; // P
        title_rom[11] = 8'h48; // H
        title_rom[12] = 8'h20; // (space)
        title_rom[13] = 8'h54; // T
        title_rom[14] = 8'h59; // Y
        title_rom[15] = 8'h50; // P
        title_rom[16] = 8'h45; // E
    end

    // Option 1: Linear
    localparam CHAR_COUNT_LINEAR = 6;
    localparam X_START_LINEAR = 296;
    localparam Y_START_LINEAR = 220;
    reg [7:0] linear_rom [0:5];
    initial begin
        linear_rom[0] = 8'h4C; // L
        linear_rom[1] = 8'h49; // I
        linear_rom[2] = 8'h4E; // N
        linear_rom[3] = 8'h45; // E
        linear_rom[4] = 8'h41; // A
        linear_rom[5] = 8'h52; // R
    end

    // Option 2: Quadratic
    localparam CHAR_COUNT_QUADRATIC = 9;
    localparam X_START_QUADRATIC = 279;
    localparam Y_START_QUADRATIC = 250;
    reg [7:0] quadratic_rom [0:8];
    initial begin
        quadratic_rom[0] = 8'h51; // Q
        quadratic_rom[1] = 8'h55; // U
        quadratic_rom[2] = 8'h41; // A
        quadratic_rom[3] = 8'h44; // D
        quadratic_rom[4] = 8'h52; // R
        quadratic_rom[5] = 8'h41; // A
        quadratic_rom[6] = 8'h54; // T
        quadratic_rom[7] = 8'h49; // I
        quadratic_rom[8] = 8'h43; // C
    end

    // Option 3: Cubic
    localparam CHAR_COUNT_CUBIC = 5;
    localparam X_START_CUBIC = 300;
    localparam Y_START_CUBIC = 280;
    reg [7:0] cubic_rom [0:4];
    initial begin
        cubic_rom[0] = 8'h43; // C
        cubic_rom[1] = 8'h55; // U
        cubic_rom[2] = 8'h42; // B
        cubic_rom[3] = 8'h49; // I
        cubic_rom[4] = 8'h43; // C
    end

    // Option 4: Sin
    localparam CHAR_COUNT_SIN = 3;
    localparam X_START_SIN = 308;
    localparam Y_START_SIN = 310;
    reg [7:0] sin_rom [0:2];
    initial begin
        sin_rom[0] = 8'h53; // S
        sin_rom[1] = 8'h49; // I
        sin_rom[2] = 8'h4E; // N
    end

    // Option 5: Cos
    localparam CHAR_COUNT_COS = 3;
    localparam X_START_COS = 308;
    localparam Y_START_COS = 340;
    reg [7:0] cos_rom [0:2];
    initial begin
        cos_rom[0] = 8'h43; // C
        cos_rom[1] = 8'h4F; // O
        cos_rom[2] = 8'h53; // S
    end

    // Option 6: Tan
    localparam CHAR_COUNT_TAN = 3;
    localparam X_START_TAN = 308;
    localparam Y_START_TAN = 370;
    reg [7:0] tan_rom [0:2];
    initial begin
        tan_rom[0] = 8'h54; // T
        tan_rom[1] = 8'h41; // A
        tan_rom[2] = 8'h4E; // N
    end

    // Option 7: Exponential
    localparam CHAR_COUNT_EXP = 11;
    localparam X_START_EXP = 275;
    localparam Y_START_EXP = 400;
    reg [7:0] exp_rom [0:10];
    initial begin
        exp_rom[0] = 8'h45; // E
        exp_rom[1] = 8'h58; // X
        exp_rom[2] = 8'h50; // P
        exp_rom[3] = 8'h4F; // O
        exp_rom[4] = 8'h4E; // N
        exp_rom[5] = 8'h45; // E
        exp_rom[6] = 8'h4E; // N
        exp_rom[7] = 8'h54; // T
        exp_rom[8] = 8'h49; // I
        exp_rom[9] = 8'h41; // A
        exp_rom[10] = 8'h4C; // L
    end

    // Option 8: Natural Log
    localparam CHAR_COUNT_LN = 11;
    localparam X_START_LN = 275;
    localparam Y_START_LN = 430;
    reg [7:0] ln_rom [0:10];
    initial begin
        ln_rom[0] = 8'h4E; // N
        ln_rom[1] = 8'h41; // A
        ln_rom[2] = 8'h54; // T
        ln_rom[3] = 8'h55; // U
        ln_rom[4] = 8'h52; // R
        ln_rom[5] = 8'h41; // A
        ln_rom[6] = 8'h4C; // L
        ln_rom[7] = 8'h20; // (space)
        ln_rom[8] = 8'h4C; // L
        ln_rom[9] = 8'h4F; // O
        ln_rom[10] = 8'h47; // G
    end

    // Signals for BRAM Addressing and Pipelining
    reg [3:0] char_index_reg;
    reg [7:0] char_code_reg;
    reg [2:0] row_index_reg;
    
    reg [9:0] vga_x_d;
    reg [9:0] vga_y_d;
    reg [2:0] pixel_column_d;
    
    wire [10:0] font_address;
    wire [7:0] font_data_out;
    reg [7:0] font_data_out_d;

    // Menu state
    wire menu_enable;
    wire [3:0] menu_option;
    wire menu_confirmed;
    assign menu_enable = (current_main_mode == MODE_GRAPHER) && enable;

    menu_selector menu_inst(
        .clk(clk),
        .btn(btn),
        .enable(menu_enable),
        .max_options(4'd7),  // 8 options (0-7)
        .selected_option(menu_option),
        .selection_confirmed(menu_confirmed)
    );

    // Font ROM instantiation
    blk_mem_gen_font font_rom_inst (
        .clka(clk),
        .ena(1'b1),
        .addra(font_address),
        .douta(font_data_out)
    );

    localparam TEXT_COLOR = 12'hFFF;
    localparam BG_COLOR = 12'h000;

    // Combinatorial Address Calculation
    assign font_address = {char_code_reg, row_index_reg};

    // Effective font byte (use delayed ROM output)
    wire [7:0] font_data_eff;
    assign font_data_eff = font_data_out_d;

    // Pixel column shift
    wire [2:0] pixel_column_eff;
    assign pixel_column_eff = ((pixel_column_d + 7) & 3'b111);

    // Compute bit index to sample from font_data_eff
    wire [2:0] font_bit_index;
    assign font_bit_index = (FONT_WIDTH - 1 - pixel_column_eff);

    // Area detection wires
    wire in_title = (
        (vga_x >= X_START_TITLE) && (vga_x < (X_START_TITLE + CHAR_COUNT_TITLE * FONT_WIDTH)) &&
        (vga_y >= Y_START_TITLE) && (vga_y < (Y_START_TITLE + FONT_HEIGHT))
    );
    wire in_linear = (
        (vga_x >= X_START_LINEAR) && (vga_x < (X_START_LINEAR + CHAR_COUNT_LINEAR * FONT_WIDTH)) &&
        (vga_y >= Y_START_LINEAR) && (vga_y < (Y_START_LINEAR + FONT_HEIGHT))
    );
    wire in_quadratic = (
        (vga_x >= X_START_QUADRATIC) && (vga_x < (X_START_QUADRATIC + CHAR_COUNT_QUADRATIC * FONT_WIDTH)) &&
        (vga_y >= Y_START_QUADRATIC) && (vga_y < (Y_START_QUADRATIC + FONT_HEIGHT))
    );
    wire in_cubic = (
        (vga_x >= X_START_CUBIC) && (vga_x < (X_START_CUBIC + CHAR_COUNT_CUBIC * FONT_WIDTH)) &&
        (vga_y >= Y_START_CUBIC) && (vga_y < (Y_START_CUBIC + FONT_HEIGHT))
    );
    wire in_sin = (
        (vga_x >= X_START_SIN) && (vga_x < (X_START_SIN + CHAR_COUNT_SIN * FONT_WIDTH)) &&
        (vga_y >= Y_START_SIN) && (vga_y < (Y_START_SIN + FONT_HEIGHT))
    );
    wire in_cos = (
        (vga_x >= X_START_COS) && (vga_x < (X_START_COS + CHAR_COUNT_COS * FONT_WIDTH)) &&
        (vga_y >= Y_START_COS) && (vga_y < (Y_START_COS + FONT_HEIGHT))
    );
    wire in_tan = (
        (vga_x >= X_START_TAN) && (vga_x < (X_START_TAN + CHAR_COUNT_TAN * FONT_WIDTH)) &&
        (vga_y >= Y_START_TAN) && (vga_y < (Y_START_TAN + FONT_HEIGHT))
    );
    wire in_exp = (
        (vga_x >= X_START_EXP) && (vga_x < (X_START_EXP + CHAR_COUNT_EXP * FONT_WIDTH)) &&
        (vga_y >= Y_START_EXP) && (vga_y < (Y_START_EXP + FONT_HEIGHT))
    );
    wire in_ln = (
        (vga_x >= X_START_LN) && (vga_x < (X_START_LN + CHAR_COUNT_LN * FONT_WIDTH)) &&
        (vga_y >= Y_START_LN) && (vga_y < (Y_START_LN + FONT_HEIGHT))
    );

    // ========================================
    // === SELECTION LOGIC ===
    // ========================================
    always @(posedge clk) begin
        if (!enable || current_main_mode != MODE_GRAPHER) begin
            selected_graph_type <= 3'b000;
            type_selected <= 0;
        end else begin
            // Reset selection when sw[3] changes
            if (reset_selection) begin
                type_selected <= 0;
                // Keep selected_graph_type to remember last choice
            end
            // Select on menu confirmation (BTN_C)
            else if (menu_confirmed && !type_selected) begin
                selected_graph_type <= menu_option[2:0];
                type_selected <= 1;
            end
            // Deselect with sw[14] (optional - for manual reset)
            else if (sw14) begin
                type_selected <= 0;
            end
        end
    end

    // BRAM ACCESS AND PIPELINING LOGIC
    always @(posedge clk) begin
        if (current_main_mode == MODE_GRAPHER && enable) begin
            // Pipelining: Delay the coordinates for the next cycle's logic
            vga_x_d <= vga_x;
            vga_y_d <= vga_y;
            
            // Delay the BRAM output (Read Latency compensation)
            font_data_out_d <= font_data_out;

            // Default values
            char_index_reg <= 4'b0;
            char_code_reg <= 8'h20; // Default to SPACE
            row_index_reg <= 3'b0;
            pixel_column_d <= 3'b0;

            // Title
            if (in_title) begin
                char_index_reg <= (vga_x - X_START_TITLE) / FONT_WIDTH;
                char_code_reg <= title_rom[(vga_x - X_START_TITLE) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_TITLE;
                pixel_column_d <= (vga_x - X_START_TITLE) % FONT_WIDTH;
            end
            // Arrow for Linear (when selected)
            else if ((menu_option == 0) &&
                     (vga_x >= (X_START_LINEAR - FONT_WIDTH)) && (vga_x < X_START_LINEAR) &&
                     (vga_y >= Y_START_LINEAR) && (vga_y < (Y_START_LINEAR + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_LINEAR;
                pixel_column_d <= (vga_x - (X_START_LINEAR - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Linear text
            else if (in_linear) begin
                char_index_reg <= (vga_x - X_START_LINEAR) / FONT_WIDTH;
                char_code_reg <= linear_rom[(vga_x - X_START_LINEAR) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_LINEAR;
                pixel_column_d <= (vga_x - X_START_LINEAR) % FONT_WIDTH;
            end
            // Arrow for Quadratic (when selected)
            else if ((menu_option == 1) &&
                     (vga_x >= (X_START_QUADRATIC - FONT_WIDTH)) && (vga_x < X_START_QUADRATIC) &&
                     (vga_y >= Y_START_QUADRATIC) && (vga_y < (Y_START_QUADRATIC + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_QUADRATIC;
                pixel_column_d <= (vga_x - (X_START_QUADRATIC - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Quadratic text
            else if (in_quadratic) begin
                char_index_reg <= (vga_x - X_START_QUADRATIC) / FONT_WIDTH;
                char_code_reg <= quadratic_rom[(vga_x - X_START_QUADRATIC) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_QUADRATIC;
                pixel_column_d <= (vga_x - X_START_QUADRATIC) % FONT_WIDTH;
            end
            // Arrow for Cubic (when selected)
            else if ((menu_option == 2) &&
                     (vga_x >= (X_START_CUBIC - FONT_WIDTH)) && (vga_x < X_START_CUBIC) &&
                     (vga_y >= Y_START_CUBIC) && (vga_y < (Y_START_CUBIC + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_CUBIC;
                pixel_column_d <= (vga_x - (X_START_CUBIC - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Cubic text
            else if (in_cubic) begin
                char_index_reg <= (vga_x - X_START_CUBIC) / FONT_WIDTH;
                char_code_reg <= cubic_rom[(vga_x - X_START_CUBIC) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_CUBIC;
                pixel_column_d <= (vga_x - X_START_CUBIC) % FONT_WIDTH;
            end
            // Arrow for Sin (when selected)
            else if ((menu_option == 3) &&
                     (vga_x >= (X_START_SIN - FONT_WIDTH)) && (vga_x < X_START_SIN) &&
                     (vga_y >= Y_START_SIN) && (vga_y < (Y_START_SIN + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_SIN;
                pixel_column_d <= (vga_x - (X_START_SIN - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Sin text
            else if (in_sin) begin
                char_index_reg <= (vga_x - X_START_SIN) / FONT_WIDTH;
                char_code_reg <= sin_rom[(vga_x - X_START_SIN) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_SIN;
                pixel_column_d <= (vga_x - X_START_SIN) % FONT_WIDTH;
            end
            // Arrow for Cos (when selected)
            else if ((menu_option == 4) &&
                     (vga_x >= (X_START_COS - FONT_WIDTH)) && (vga_x < X_START_COS) &&
                     (vga_y >= Y_START_COS) && (vga_y < (Y_START_COS + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_COS;
                pixel_column_d <= (vga_x - (X_START_COS - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Cos text
            else if (in_cos) begin
                char_index_reg <= (vga_x - X_START_COS) / FONT_WIDTH;
                char_code_reg <= cos_rom[(vga_x - X_START_COS) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_COS;
                pixel_column_d <= (vga_x - X_START_COS) % FONT_WIDTH;
            end
            // Arrow for Tan (when selected)
            else if ((menu_option == 5) &&
                     (vga_x >= (X_START_TAN - FONT_WIDTH)) && (vga_x < X_START_TAN) &&
                     (vga_y >= Y_START_TAN) && (vga_y < (Y_START_TAN + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_TAN;
                pixel_column_d <= (vga_x - (X_START_TAN - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Tan text
            else if (in_tan) begin
                char_index_reg <= (vga_x - X_START_TAN) / FONT_WIDTH;
                char_code_reg <= tan_rom[(vga_x - X_START_TAN) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_TAN;
                pixel_column_d <= (vga_x - X_START_TAN) % FONT_WIDTH;
            end
            // Arrow for Exponential (when selected)
            else if ((menu_option == 6) &&
                     (vga_x >= (X_START_EXP - FONT_WIDTH)) && (vga_x < X_START_EXP) &&
                     (vga_y >= Y_START_EXP) && (vga_y < (Y_START_EXP + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_EXP;
                pixel_column_d <= (vga_x - (X_START_EXP - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Exponential text
            else if (in_exp) begin
                char_index_reg <= (vga_x - X_START_EXP) / FONT_WIDTH;
                char_code_reg <= exp_rom[(vga_x - X_START_EXP) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_EXP;
                pixel_column_d <= (vga_x - X_START_EXP) % FONT_WIDTH;
            end
            // Arrow for Natural Log (when selected)
            else if ((menu_option == 7) &&
                     (vga_x >= (X_START_LN - FONT_WIDTH)) && (vga_x < X_START_LN) &&
                     (vga_y >= Y_START_LN) && (vga_y < (Y_START_LN + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg <= 8'h10; // arrow glyph
                row_index_reg <= vga_y - Y_START_LN;
                pixel_column_d <= (vga_x - (X_START_LN - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Natural Log text
            else if (in_ln) begin
                char_index_reg <= (vga_x - X_START_LN) / FONT_WIDTH;
                char_code_reg <= ln_rom[(vga_x - X_START_LN) / FONT_WIDTH];
                row_index_reg <= vga_y - Y_START_LN;
                pixel_column_d <= (vga_x - X_START_LN) % FONT_WIDTH;
            end
        end
    end

    // PIXEL ASSIGNMENT LOGIC
    always @(posedge clk) begin
        if (current_main_mode == MODE_GRAPHER && enable) begin
            // Title
            if ((vga_x_d >= X_START_TITLE) && (vga_x_d < (X_START_TITLE + CHAR_COUNT_TITLE * FONT_WIDTH)) &&
                (vga_y_d >= Y_START_TITLE) && (vga_y_d < (Y_START_TITLE + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Linear (when selected)
            else if ((menu_option == 0) &&
                     (vga_x_d >= (X_START_LINEAR - FONT_WIDTH)) && (vga_x_d < X_START_LINEAR) &&
                     (vga_y_d >= Y_START_LINEAR) && (vga_y_d < (Y_START_LINEAR + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Linear text
            else if ((vga_x_d >= X_START_LINEAR) && (vga_x_d < (X_START_LINEAR + CHAR_COUNT_LINEAR * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_LINEAR) && (vga_y_d < (Y_START_LINEAR + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Quadratic (when selected)
            else if ((menu_option == 1) &&
                     (vga_x_d >= (X_START_QUADRATIC - FONT_WIDTH)) && (vga_x_d < X_START_QUADRATIC) &&
                     (vga_y_d >= Y_START_QUADRATIC) && (vga_y_d < (Y_START_QUADRATIC + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Quadratic text
            else if ((vga_x_d >= X_START_QUADRATIC) && (vga_x_d < (X_START_QUADRATIC + CHAR_COUNT_QUADRATIC * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_QUADRATIC) && (vga_y_d < (Y_START_QUADRATIC + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Cubic (when selected)
            else if ((menu_option == 2) &&
                     (vga_x_d >= (X_START_CUBIC - FONT_WIDTH)) && (vga_x_d < X_START_CUBIC) &&
                     (vga_y_d >= Y_START_CUBIC) && (vga_y_d < (Y_START_CUBIC + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Cubic text
            else if ((vga_x_d >= X_START_CUBIC) && (vga_x_d < (X_START_CUBIC + CHAR_COUNT_CUBIC * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_CUBIC) && (vga_y_d < (Y_START_CUBIC + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Sin (when selected)
            else if ((menu_option == 3) &&
                     (vga_x_d >= (X_START_SIN - FONT_WIDTH)) && (vga_x_d < X_START_SIN) &&
                     (vga_y_d >= Y_START_SIN) && (vga_y_d < (Y_START_SIN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Sin text
            else if ((vga_x_d >= X_START_SIN) && (vga_x_d < (X_START_SIN + CHAR_COUNT_SIN * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_SIN) && (vga_y_d < (Y_START_SIN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Cos (when selected)
            else if ((menu_option == 4) &&
                     (vga_x_d >= (X_START_COS - FONT_WIDTH)) && (vga_x_d < X_START_COS) &&
                     (vga_y_d >= Y_START_COS) && (vga_y_d < (Y_START_COS + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Cos text
            else if ((vga_x_d >= X_START_COS) && (vga_x_d < (X_START_COS + CHAR_COUNT_COS * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_COS) && (vga_y_d < (Y_START_COS + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Tan (when selected)
            else if ((menu_option == 5) &&
                     (vga_x_d >= (X_START_TAN - FONT_WIDTH)) && (vga_x_d < X_START_TAN) &&
                     (vga_y_d >= Y_START_TAN) && (vga_y_d < (Y_START_TAN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Tan text
            else if ((vga_x_d >= X_START_TAN) && (vga_x_d < (X_START_TAN + CHAR_COUNT_TAN * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_TAN) && (vga_y_d < (Y_START_TAN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Exponential (when selected)
            else if ((menu_option == 6) &&
                     (vga_x_d >= (X_START_EXP - FONT_WIDTH)) && (vga_x_d < X_START_EXP) &&
                     (vga_y_d >= Y_START_EXP) && (vga_y_d < (Y_START_EXP + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Exponential text
            else if ((vga_x_d >= X_START_EXP) && (vga_x_d < (X_START_EXP + CHAR_COUNT_EXP * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_EXP) && (vga_y_d < (Y_START_EXP + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow for Natural Log (when selected)
            else if ((menu_option == 7) &&
                     (vga_x_d >= (X_START_LN - FONT_WIDTH)) && (vga_x_d < X_START_LN) &&
                     (vga_y_d >= Y_START_LN) && (vga_y_d < (Y_START_LN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Natural Log text
            else if ((vga_x_d >= X_START_LN) && (vga_x_d < (X_START_LN + CHAR_COUNT_LN * FONT_WIDTH)) &&
                     (vga_y_d >= Y_START_LN) && (vga_y_d < (Y_START_LN + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Outside any text area
            else begin
                vga_data <= BG_COLOR;
            end
        end else begin
            vga_data <= BG_COLOR;
        end
    end

    // OLED Display - show current selection
    always @(*) begin
        if (current_main_mode == MODE_GRAPHER && enable) begin
            case (menu_option)
                4'b0000: oled_data = 16'hF800; // Linear = Red
                4'b0001: oled_data = 16'h07E0; // Quadratic = Green
                4'b0010: oled_data = 16'h001F; // Cubic = Blue
                4'b0011: oled_data = 16'hFFE0; // Sin = Yellow
                4'b0100: oled_data = 16'hF81F; // Cos = Magenta
                4'b0101: oled_data = 16'h07FF; // Tan = Cyan
                4'b0110: oled_data = 16'hFFFF; // Exponential = White
                4'b0111: oled_data = 16'h8410; // Natural Log = Gray
                default: oled_data = 16'h0000;
            endcase
        end else begin
            oled_data = 16'h0000;
        end
    end

endmodule