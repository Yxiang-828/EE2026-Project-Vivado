`timescale 1ns / 1ps

module welcome_drawer_vga(
    input  clk,
    input  [2:0] current_main_mode,  // Expanded to 3 bits for MODE_POLY
    input  [4:0] btn,
    input  [9:0] vga_x,
    input  [9:0] vga_y,
    output reg [11:0] vga_data,
    // Handshake outputs: request & target; ack input from top-level
    output reg        mode_req,
    output reg [2:0]  mode_target,  // Expanded to 3 bits for MODE_POLY
    input             mode_ack
);

    // Mode Constants
    localparam MODE_OFF        = 3'b000;
    localparam MODE_WELCOME    = 3'b001;
    localparam MODE_CALCULATOR = 3'b010;
    localparam MODE_GRAPHER    = 3'b011;
    localparam MODE_POLY       = 3'b100;

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

    // Row 4: Grapher
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

    // Row 5: Polynomial
    localparam CHAR_COUNT_ROW_5 = 10;
    localparam X_START_ROW_5 = 280;
    localparam Y_START_ROW_5 = 344;
    reg [7:0] row_5_rom [0:9];
    initial begin
        row_5_rom[0] = 8'h50; // P
        row_5_rom[1] = 8'h4F; // O
        row_5_rom[2] = 8'h4C; // L
        row_5_rom[3] = 8'h59; // Y
        row_5_rom[4] = 8'h4E; // N
        row_5_rom[5] = 8'h4F; // O
        row_5_rom[6] = 8'h4D; // M
        row_5_rom[7] = 8'h49; // I
        row_5_rom[8] = 8'h41; // A
        row_5_rom[9] = 8'h4C; // L
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
    
    // Selection logic (0 = Calculator, 1 = Grapher, 2 = Polynomial)
    reg [1:0] selection = 2'b00;
    
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
    assign font_address = {char_code_reg, row_index_reg};

    // Effective font byte after optional bit-reversal (use delayed ROM output)
    wire [7:0] font_data_eff;
    assign font_data_eff = font_data_out_d;

    // Pixel column shift
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
    wire in_row_5 = (
        ( (vga_x >= X_START_ROW_5) && (vga_x < (X_START_ROW_5 + CHAR_COUNT_ROW_5 * FONT_WIDTH)) &&
          (vga_y >= Y_START_ROW_5) && (vga_y < (Y_START_ROW_5 + FONT_HEIGHT)) )
    );

    // BRAM ACCESS AND PIPELINING LOGIC
    // Runs on clock edge N
    always @(posedge clk) begin
        if (current_main_mode == MODE_WELCOME) begin
            // update selection: btn[1]=up, btn[4]=down (wrap around 0-2)
            if (btn[4]) begin
                if (selection == 2'd2) selection <= 2'd0; // wrap to top
                else selection <= selection + 1'd1;
            end else if (btn[1]) begin
                if (selection == 2'd0) selection <= 2'd2; // wrap to bottom
                else selection <= selection - 1'd1;
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
            // Arrow column immediately left of Row 3 (when Calculator selected)
            else if ((selection == 1'b0) &&
                     (vga_x >= (X_START_ROW_3 - FONT_WIDTH)) && (vga_x < X_START_ROW_3) &&
                     (vga_y >= Y_START_ROW_3) && (vga_y < (Y_START_ROW_3 + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg  <= 8'h10; // arrow glyph
                row_index_reg  <= vga_y - Y_START_ROW_3;
                pixel_column_d <= (vga_x - (X_START_ROW_3 - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Row 3 text
            else if (in_row_3) begin
                char_index_reg <= (vga_x - X_START_ROW_3) / FONT_WIDTH;
                char_code_reg  <= row_3_rom[(vga_x - X_START_ROW_3) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_3;
                pixel_column_d <= (vga_x - X_START_ROW_3) % FONT_WIDTH;
            end
            // Arrow column immediately left of Row 4 (when Grapher selected)
            else if ((selection == 1'b1) &&
                     (vga_x >= (X_START_ROW_4 - FONT_WIDTH)) && (vga_x < X_START_ROW_4) &&
                     (vga_y >= Y_START_ROW_4) && (vga_y < (Y_START_ROW_4 + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg  <= 8'h10; // arrow glyph
                row_index_reg  <= vga_y - Y_START_ROW_4;
                pixel_column_d <= (vga_x - (X_START_ROW_4 - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Row 4 text
            else if (in_row_4) begin
                char_index_reg <= (vga_x - X_START_ROW_4) / FONT_WIDTH;
                char_code_reg  <= row_4_rom[(vga_x - X_START_ROW_4) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_4;
                pixel_column_d <= (vga_x - X_START_ROW_4) % FONT_WIDTH;
            end
            // Arrow column immediately left of Row 5 (when Polynomial selected)
            else if ((selection == 2'd2) &&
                     (vga_x >= (X_START_ROW_5 - FONT_WIDTH)) && (vga_x < X_START_ROW_5) &&
                     (vga_y >= Y_START_ROW_5) && (vga_y < (Y_START_ROW_5 + FONT_HEIGHT))) begin
                char_index_reg <= 4'b0;
                char_code_reg  <= 8'h10; // arrow glyph
                row_index_reg  <= vga_y - Y_START_ROW_5;
                pixel_column_d <= (vga_x - (X_START_ROW_5 - FONT_WIDTH)) % FONT_WIDTH;
            end
            // Row 5 text
            else if (in_row_5) begin
                char_index_reg <= (vga_x - X_START_ROW_5) / FONT_WIDTH;
                char_code_reg  <= row_5_rom[(vga_x - X_START_ROW_5) / FONT_WIDTH];
                row_index_reg  <= vga_y - Y_START_ROW_5;
                pixel_column_d <= (vga_x - X_START_ROW_5) % FONT_WIDTH;
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
            // Arrow column immediately left of Row 3 (when Calculator selected) -- draw arrow with TEXT_COLOR
            else if ((selection == 1'b0) &&
                     (vga_x_d >= (X_START_ROW_3 - FONT_WIDTH)) && (vga_x_d < X_START_ROW_3) &&
                     (vga_y_d >= Y_START_ROW_3) && (vga_y_d < (Y_START_ROW_3 + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
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
                    vga_data <= TEXT_COLOR;
                end else if (~(font_data_eff[font_bit_index]) && (~selection)) begin
                    vga_data <= BG_COLOR;
                end else if ((font_data_eff[font_bit_index] == 1'b1) && (selection)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow column immediately left of Row 4 (when Grapher selected) -- draw arrow with TEXT_COLOR
            else if ((selection == 1'b1) &&
                     (vga_x_d >= (X_START_ROW_4 - FONT_WIDTH)) && (vga_x_d < X_START_ROW_4) &&
                     (vga_y_d >= Y_START_ROW_4) && (vga_y_d < (Y_START_ROW_4 + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Row 4
            else if ( (vga_x_d >= X_START_ROW_4) && (vga_x_d < (X_START_ROW_4 + CHAR_COUNT_ROW_4 * FONT_WIDTH)) &&
                    (vga_y_d >= Y_START_ROW_4) && (vga_y_d < (Y_START_ROW_4 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1) && (selection == 2'd1)) begin
                    vga_data <= TEXT_COLOR;
                end else if (~(font_data_eff[font_bit_index]) && (selection == 2'd1)) begin
                    vga_data <= BG_COLOR;
                end else if ((font_data_eff[font_bit_index] == 1'b1) && (selection != 2'd1)) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Arrow column immediately left of Row 5 (when Polynomial selected)
            else if ((selection == 2'd2) &&
                     (vga_x_d >= (X_START_ROW_5 - FONT_WIDTH)) && (vga_x_d < X_START_ROW_5) &&
                     (vga_y_d >= Y_START_ROW_5) && (vga_y_d < (Y_START_ROW_5 + FONT_HEIGHT))) begin
                if (font_data_eff[font_bit_index] == 1'b1) begin
                    vga_data <= TEXT_COLOR;
                end else begin
                    vga_data <= BG_COLOR;
                end
            end
            // Row 5
            else if ( (vga_x_d >= X_START_ROW_5) && (vga_x_d < (X_START_ROW_5 + CHAR_COUNT_ROW_5 * FONT_WIDTH)) &&
                    (vga_y_d >= Y_START_ROW_5) && (vga_y_d < (Y_START_ROW_5 + FONT_HEIGHT)) ) 
            begin
                if ((font_data_eff[font_bit_index] == 1'b1) && (selection == 2'd2)) begin
                    vga_data <= TEXT_COLOR;
                end else if (~(font_data_eff[font_bit_index]) && (selection == 2'd2)) begin
                    vga_data <= BG_COLOR;
                end else if ((font_data_eff[font_bit_index] == 1'b1) && (selection != 2'd2)) begin
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

    // Handshake behaviour:
    // - When in welcome mode and centre button pressed, assert mode_req=1 and
    //   set mode_target. Hold mode_req until top-level pulses mode_ack.
    // - When not in welcome mode, keep mode_req low.
    always @(posedge clk) begin
        if (current_main_mode != MODE_WELCOME) begin
            mode_req    <= 1'b0;
            mode_target <= MODE_WELCOME; // no-request (stay in welcome)
        end else begin
            if (mode_ack) begin
                // top-level accepted request, clear
                mode_req <= 1'b0;
            end else if (btn[0]) begin
                // centre pressed: request change depending on selection
                mode_req <= 1'b1;
                case (selection)
                    2'd0: mode_target <= MODE_CALCULATOR; // 3'b010
                    2'd1: mode_target <= MODE_GRAPHER;    // 3'b011
                    2'd2: mode_target <= MODE_POLY;       // 3'b100
                    default: mode_target <= MODE_WELCOME; // Should not happen
                endcase
            end
        end
    end

endmodule