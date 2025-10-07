`timescale 1ns / 1ps

module welcome_drawer_vga(
    input  clk,
    input  [1:0] current_main_mode,
    input  [4:0] btn,
    input  [9:0] vga_x,
    input  [9:0] vga_y,
    output reg [11:0] vga_data,
    output reg [1:0] new_mode
);

    // Welcome Mode Constant
    localparam MODE_WELCOME = 2'b01;

    // Screen Resolution (Example: 640x480)
    localparam H_RES = 640;
    localparam V_RES = 480;
    
    // Font Parameters
    localparam FONT_WIDTH  = 8;  // 8 pixels wide
    localparam FONT_HEIGHT = 8;  // 8 pixels high
    
    // Row 1: EE2026
    localparam CHAR_COUNT_ROW_1 = 6;
    localparam X_START_ROW_1 = 296;
    localparam Y_START_ROW_1 = 208;
    reg [7:0] row_1_rom [0:5];
    initial begin
        row_1_rom[0] = 8'h45; // E
        row_1_rom[1] = 8'h45; // E
        row_1_rom[2] = 8'h32; // 2
        row_1_rom[3] = 8'h30; // 0
        row_1_rom[4] = 8'h32; // 2
        row_1_rom[5] = 8'h36; // 6
    end

    // Row 2: CALCULATOR
    localparam CHAR_COUNT_ROW_2 = 10;
    localparam X_START_ROW_2 = 280;
    localparam Y_START_ROW_2 = 224;
    reg [7:0] row_2_rom [0:9];
    initial begin
        row_2_rom[0] = 8'h43; // C
        row_2_rom[1] = 8'h41; // A
        row_2_rom[2] = 8'h4C; // L
        row_2_rom[3] = 8'h43; // C
        row_2_rom[4] = 8'h55; // U
        row_2_rom[5] = 8'h4C; // L
        row_2_rom[6] = 8'h41; // A
        row_2_rom[7] = 8'h54; // T
        row_2_rom[8] = 8'h4F; // O
        row_2_rom[9] = 8'h52; // R
    end

    // Row 3: Calculator (Selected with btn[1])
    localparam CHAR_COUNT_ROW_3 = 10;
    localparam X_START_ROW_3 = 280;
    localparam Y_START_ROW_3 = 272;
    reg [7:0] row_3_rom [0:9];
    initial begin
        row_3_rom[0] = 8'h43; // C
        row_3_rom[1] = 8'h41; // A
        row_3_rom[2] = 8'h4C; // L
        row_3_rom[3] = 8'h43; // C
        row_3_rom[4] = 8'h55; // U
        row_3_rom[5] = 8'h4C; // L
        row_3_rom[6] = 8'h41; // A
        row_3_rom[7] = 8'h54; // T
        row_3_rom[8] = 8'h4F; // O
        row_3_rom[9] = 8'h52; // R
    end

    // Row 4: Grapher (Selected with btn[4])
    localparam CHAR_COUNT_ROW_4 = 7;
    localparam X_START_ROW_4 = 292;
    localparam Y_START_ROW_4 = 308;
    reg [7:0] row_4_rom [0:6];
    initial begin
        row_4_rom[0] = 8'h47; // G
        row_4_rom[1] = 8'h52; // R
        row_4_rom[2] = 8'h41; // A
        row_4_rom[3] = 8'h50; // P
        row_4_rom[4] = 8'h48; // H
        row_4_rom[5] = 8'h45; // E
        row_4_rom[6] = 8'h52; // R
    end

    // Signals for BRAM Addressing and Pipelining
    reg  [3:0] char_index_reg;
    reg  [7:0] char_code_reg;
    reg  [2:0] row_index_reg; // Corrected width for 8 rows (0-7)
    
    reg  [9:0] vga_x_d;
    reg  [9:0] vga_y_d;
    reg  [2:0] pixel_column_d; // Corrected width for 8 columns (0-7)
    
    wire [10:0] font_address;  // BRAM address (11-bit)
    wire [7:0] font_data_out;
    
    reg  [7:0] font_data_out_d;
    
    // Selection logic flip-flop (0 = Calculator, 1 = Grapher)
    reg selection = 1'b0;
    
    // Instantiation
    blk_mem_gen_font font_rom_inst (
        .clka  (clk),
        .ena   (1'b1),
        .addra (font_address),
        .douta (font_data_out)
    ); 
    
    localparam SELECTION_COLOR = 12'h000;
    localparam SELECTION_BG_COLOR = 12'hFFF;
    localparam TEXT_COLOR = 12'hFFF;
    localparam BG_COLOR   = 12'h000;
    
    // Combinatorial Address Calculation
    wire [10:0] font_address_char_row = {char_code_reg, row_index_reg};
    assign font_address = font_address_char_row;

    // Effective font byte after optional bit-reversal (use delayed ROM output)
    wire [7:0] font_data_eff;
    assign font_data_eff = font_data_out_d;

    // Pixel column shift to test horizontal alignment issues
    wire [2:0] pixel_column_eff;
    assign pixel_column_eff = ((pixel_column_d + 7) & 3'b111);

    // Compute bit index to sample from font_data_eff
    wire [2:0] font_bit_index;
    assign font_bit_index = (FONT_WIDTH - 1 - pixel_column_eff);

    // New Mode Logic
    wire in_row_1 = (
        ( (vga_x >= X_START_ROW_1) && (vga_x < (X_START_ROW_1 + CHAR_COUNT_ROW_1 * FONT_WIDTH)) &&
          (vga_y >= Y_START_ROW_1) && (vga_y < (Y_START_ROW_1 + FONT_HEIGHT)) )
    );
    wire in_row_2 = (
        ( (vga_x >= X_START_ROW_2) && (vga_x < (X_START_ROW_2 + CHAR_COUNT_ROW_2 * FONT_WIDTH)) &&
          (vga_y >= Y_START_ROW_2) && (vga_y < (Y_START_ROW_2 + FONT_HEIGHT)) )
    );
    wire in_row_3 = (
        ( (vga_x >= X_START_ROW_3) && (vga_x < (X_START_ROW_3 + CHAR_COUNT_ROW_3 * FONT_WIDTH)) &&
          (vga_y >= Y_START_ROW_3) && (vga_y < (Y_START_ROW_3 + FONT_HEIGHT)) )
    );
    wire in_row_4 = (
        ( (vga_x >= X_START_ROW_4) && (vga_x < (X_START_ROW_4 + CHAR_COUNT_ROW_4 * FONT_WIDTH)) &&
          (vga_y >= Y_START_ROW_4) && (vga_y < (Y_START_ROW_4 + FONT_HEIGHT)) )
    );

    // BRAM ACCESS AND PIPELINING LOGIC
    // Runs on clock edge N
    always @(posedge clk) begin
        if (current_main_mode == MODE_WELCOME) begin
            // update selection by level (buttons are debounced)
            if (btn[4]) begin
                selection <= 1'b1;
            end else if (btn[1]) begin
                selection <= 1'b0;
            end

            // Pipelining: Delay the coordinates for the next cycle's logic
            vga_x_d <= vga_x;
            vga_y_d <= vga_y;
             
             // Delay the BRAM output (Read Latency compensation)
             font_data_out_d <= font_data_out; 
    
            // Default values (address for ASCII space, row 0)
            char_index_reg <= 4'b0;
            char_code_reg  <= 8'h20; // Default to SPACE
            row_index_reg  <= 3'b0;
            pixel_column_d <= 3'b0;
            
            // Row 1
            if (in_row_1) begin
                char_index_reg <= (vga_x - X_START_ROW_1) / FONT_WIDTH;
                char_code_reg  <= row_1_rom[(vga_x - X_START_ROW_1) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_1;
                pixel_column_d <= (vga_x - X_START_ROW_1) % FONT_WIDTH;
            end
            // Row 2
            else if (in_row_2) begin
                char_index_reg <= (vga_x - X_START_ROW_2) / FONT_WIDTH;
                char_code_reg  <= row_2_rom[(vga_x - X_START_ROW_2) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_2;
                pixel_column_d <= (vga_x - X_START_ROW_2) % FONT_WIDTH;
            end
            // Row 3
            else if (in_row_3) begin
                char_index_reg <= (vga_x - X_START_ROW_3) / FONT_WIDTH;
                char_code_reg  <= row_3_rom[(vga_x - X_START_ROW_3) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_3;
                pixel_column_d <= (vga_x - X_START_ROW_3) % FONT_WIDTH;
            end
            // Row 4
            else if (in_row_4) begin
                char_index_reg <= (vga_x - X_START_ROW_4) / FONT_WIDTH;
                char_code_reg  <= row_4_rom[(vga_x - X_START_ROW_4) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_4;
                pixel_column_d <= (vga_x - X_START_ROW_4) % FONT_WIDTH;
            end
        end
    end

    // PIXEL ASSIGNMENT LOGIC
    always @(posedge clk) begin
        if (current_main_mode == MODE_WELCOME) begin
            // Row 1 (use delayed coordinates)
            if ( (vga_x_d >= X_START_ROW_1) && (vga_x_d < (X_START_ROW_1 + CHAR_COUNT_ROW_1 * FONT_WIDTH)) &&
                (vga_y_d >= Y_START_ROW_1) && (vga_y_d < (Y_START_ROW_1 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Row 2
            else if ( (vga_x_d >= X_START_ROW_2) && (vga_x_d < (X_START_ROW_2 + CHAR_COUNT_ROW_2 * FONT_WIDTH)) &&
                    (vga_y_d >= Y_START_ROW_2) && (vga_y_d < (Y_START_ROW_2 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Row 3
            else if ( (vga_x_d >= X_START_ROW_3) && (vga_x_d < (X_START_ROW_3 + CHAR_COUNT_ROW_3 * FONT_WIDTH)) &&
                    (vga_y_d >= Y_START_ROW_3) && (vga_y_d < (Y_START_ROW_3 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1) && (~selection)) begin
                    vga_data <= SELECTION_COLOR;
                end else if (~(font_data_eff[font_bit_index]) && (~selection)) begin
                    vga_data <= SELECTION_BG_COLOR;
                end else if ((font_data_eff[font_bit_index] == 1'b1) && (selection)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Row 4
            else if ( (vga_x_d >= X_START_ROW_4) && (vga_x_d < (X_START_ROW_4 + CHAR_COUNT_ROW_4 * FONT_WIDTH)) &&
                    (vga_y_d >= Y_START_ROW_4) && (vga_y_d < (Y_START_ROW_4 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1) && (selection)) begin
                    vga_data <= SELECTION_COLOR;
                end else if (~(font_data_eff[font_bit_index]) && (selection)) begin
                    vga_data <= SELECTION_BG_COLOR;
                end else if ((font_data_eff[font_bit_index] == 1'b1) && (~selection)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Outside any row
            else begin
                vga_data <= BG_COLOR;
            end
        end
    end

    // Small, dedicated button handler => produce a one-cycle new_mode pulse when centre pressed
    // new_mode encoding: 2'b01 = none, 2'b10 = go to Calculator, 2'b11 = go to Grapher
    always @(posedge clk) begin
        if (current_main_mode == MODE_WELCOME) begin
            if (btn[0]) begin
                // centre pressed: output one-clock pulse depending on selection
                if (selection)
                    new_mode <= 2'b11; // Grapher
                else
                    new_mode <= 2'b10; // Calculator
            end else begin
                new_mode <= 2'b01; // no request
            end
        end else begin
            new_mode <= 2'b01; // stay in welcome mode
        end
    end

endmodule