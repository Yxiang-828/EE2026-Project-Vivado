// CURRENTLY UNUSED

`timescale 1ns / 1ps

module diagonal_drawer_oled (
    input [6:0] x, y,           // Current pixel coordinates
    input [6:0] x1, y1,         // Start Point
    input [6:0] x2, y2,         // End Point
    input [6:0] thickness,      // Segment Thickness (SEG_W)
    output wire is_on_line
);

    // Use 8-bit for coordinates (7 bits + 1 sign bit) for signed operations
    // --- Bounding Box Check (Unsigned) ---
    wire [6:0] x_min = (x1 < x2) ? x1 : x2;
    wire [6:0] x_max = (x1 > x2) ? x1 : x2;
    wire [6:0] y_min = (y1 < y2) ? y1 : y2;
    wire [6:0] y_max = (y1 > y2) ? y1 : y2;

    wire in_box = (x >= x_min) && (x <= x_max) && (y >= y_min) && (y <= y_max);

    // --- Line Equation (Signed Arithmetic) ---
    // Signed differences (8-bit)
    wire signed [7:0] dx_line = x2 - x1;
    wire signed [7:0] dy_line = y2 - y1;
    wire signed [7:0] dx_point = x - x1;
    wire signed [7:0] dy_point = y - y1;

    // Line term 1: (Y - Y1) * (X2 - X1). Result is 16 bits
    wire signed [15:0] term1 = dy_point * dx_line;

    // Line term 2: (X - X1) * (Y2 - Y1). Result is 16 bits
    wire signed [15:0] term2 = dx_point * dy_line;

    // Cross-product error 
    wire signed [15:0] error = term1 - term2;

    // Absolute distance from the line
    wire [15:0] distance_abs = (error >= 0) ? error : -error; // Absolute value

    // Tolerance Check
    // 1. Calculate the absolute line components
    wire [7:0] dx_abs = (dx_line >= 0) ? dx_line : -dx_line;
    wire [7:0] dy_abs = (dy_line >= 0) ? dy_line : -dy_line;
    
    // 2. Determine the maximum component (Approximation of the hypotenuse)
    wire [7:0] max_delta = (dx_abs > dy_abs) ? dx_abs : dy_abs;
    
    // 3. Define base tolerance
    wire [6:0] base_thickness_limit;
    assign base_thickness_limit = (thickness >> 1);

    // 4. New Tolerance Limit
    wire [15:0] tolerance_limit = max_delta * base_thickness_limit;

    assign is_on_line = in_box && (distance_abs <= tolerance_limit);
    
endmodule


module fourteen_segment_drawer_oled (
    input [6:0] x,
    input [6:0] y,
    input [5:0] character,      
    input [6:0] x_start,
    input [6:0] y_start,
    input [6:0] height,
    input [6:0] width,
    output reg draw_pixel
);

    // --- Estimated Segment Width ---
    wire [6:0] SEG_W_CALC = height / 10;
    wire [6:0] SEG_W = (SEG_W_CALC == 7'd0) ? 7'd1 : SEG_W_CALC;

    // --- X/Y Boundary Coordinates ---
    wire [6:0] X_MID = x_start + (width / 2);
    wire [6:0] Y_MID = y_start + (height / 2);
    wire [6:0] X_MID_SEG = X_MID - (SEG_W / 2);
    wire [6:0] Y_TOP_SEG = y_start;
    wire [6:0] Y_MID_SEG = Y_MID - (SEG_W / 2); 
    wire [6:0] Y_BOT_SEG = y_start + height - SEG_W;
    wire [6:0] X_LEFT_SEG  = x_start;
    wire [6:0] X_RIGHT_SEG = x_start + width - SEG_W;
    
    wire in_seg_A = (x >= X_LEFT_SEG) && (x <= X_RIGHT_SEG + SEG_W - 1'b1) && (y >= Y_TOP_SEG) && (y <= Y_TOP_SEG + SEG_W - 1'b1);
    wire in_seg_B = (x >= X_RIGHT_SEG) && (x <= X_RIGHT_SEG + SEG_W - 1'b1) && (y >= Y_TOP_SEG) && (y <= Y_MID_SEG + SEG_W - 1'b1);
    wire in_seg_C = (x >= X_RIGHT_SEG) && (x <= X_RIGHT_SEG + SEG_W - 1'b1) && (y >= Y_MID_SEG) && (y <= Y_BOT_SEG + SEG_W - 1'b1);
    wire in_seg_D = (x >= X_LEFT_SEG) && (x <= X_RIGHT_SEG + SEG_W - 1'b1) && (y >= Y_BOT_SEG) && (y <= Y_BOT_SEG + SEG_W - 1'b1);
    wire in_seg_E = (x >= X_LEFT_SEG) && (x <= X_LEFT_SEG + SEG_W - 1'b1) && (y >= Y_MID_SEG) && (y <= Y_BOT_SEG + SEG_W - 1'b1);
    wire in_seg_F = (x >= X_LEFT_SEG) && (x <= X_LEFT_SEG + SEG_W - 1'b1) && (y >= Y_TOP_SEG) && (y <= Y_MID_SEG + SEG_W - 1'b1);
    wire in_seg_G1 = (x >= X_LEFT_SEG) && (x <= X_MID_SEG + SEG_W - 1'b1) && (y >= Y_MID_SEG) && (y <= Y_MID_SEG + SEG_W - 1'b1);
    wire in_seg_G2 = (x >= X_MID_SEG) && (x <= X_RIGHT_SEG + SEG_W - 1'b1) && (y >= Y_MID_SEG) && (y <= Y_MID_SEG + SEG_W - 1'b1);
    wire in_seg_I = (x >= X_MID_SEG) && (x <= X_MID_SEG + SEG_W - 1'b1) && (y >= Y_TOP_SEG) && (y <= Y_MID_SEG + SEG_W - 1'b1);
    wire in_seg_L = (x >= X_MID_SEG) && (x <= X_MID_SEG + SEG_W - 1'b1) && (y >= Y_MID_SEG) && (y <= Y_BOT_SEG + SEG_W - 1'b1);
    
    wire in_seg_G = in_seg_G1 | in_seg_G2;
    
    // --- Diagonal Segment Instantiations ---
    wire in_seg_H, in_seg_J, in_seg_K, in_seg_M;

    diagonal_drawer_oled diag_H (
        .x(x), .y(y), .x1(X_LEFT_SEG), .y1(Y_TOP_SEG), .x2(X_MID), .y2(Y_MID), .thickness(SEG_W), .is_on_line(in_seg_H)
    );

    diagonal_drawer_oled diag_J (
        .x(x), .y(y), .x1(X_RIGHT_SEG + SEG_W - 1'b1), .y1(Y_TOP_SEG), .x2(X_MID), .y2(Y_MID), .thickness(SEG_W), .is_on_line(in_seg_J)
    );
    
    diagonal_drawer_oled diag_K (
        .x(x), .y(y), .x1(X_RIGHT_SEG + SEG_W - 1'b1), .y1(Y_BOT_SEG + SEG_W - 1'b1), .x2(X_MID), .y2(Y_MID), .thickness(SEG_W), .is_on_line(in_seg_K)
    );

    diagonal_drawer_oled diag_M (
        .x(x), .y(y), .x1(X_LEFT_SEG), .y1(Y_BOT_SEG + SEG_W - 1'b1), .x2(X_MID), .y2(Y_MID), .thickness(SEG_W), .is_on_line(in_seg_M)
    );
    
    // --- Character Logic (Updated for G1/G2 and matching your specific guide) ---
    always @ (*) begin
        draw_pixel = 1'b0; 

        case (character)
            // -----------------------------------------------------------------
            // NUMBERS (0-9) - Using the specified patterns
            // -----------------------------------------------------------------
            6'd0: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_E | in_seg_F;
            6'd1: draw_pixel = in_seg_B | in_seg_C; 
            6'd2: draw_pixel = in_seg_A | in_seg_B | in_seg_D | in_seg_E | in_seg_G;
            6'd3: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_G;
            6'd4: draw_pixel = in_seg_B | in_seg_C | in_seg_F | in_seg_G;
            6'd5: draw_pixel = in_seg_A | in_seg_C | in_seg_D | in_seg_F | in_seg_G;
            6'd6: draw_pixel = in_seg_A | in_seg_C | in_seg_D | in_seg_E | in_seg_F | in_seg_G;
            6'd7: draw_pixel = in_seg_A | in_seg_B | in_seg_C;
            6'd8: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_E | in_seg_F | in_seg_G;
            6'd9: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_F | in_seg_G;
            
            // -----------------------------------------------------------------
            // LETTERS (A-Z, using indices 10-35) - Using the standard (first) pattern listed
            // -----------------------------------------------------------------
            6'd10: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_E | in_seg_F | in_seg_G; 
            6'd11: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_G2 | in_seg_I | in_seg_L;
            6'd12: draw_pixel = in_seg_A | in_seg_D | in_seg_E | in_seg_F;
            6'd13: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_I | in_seg_L;
            6'd14: draw_pixel = in_seg_A | in_seg_D | in_seg_E | in_seg_F | in_seg_G;
            6'd15: draw_pixel = in_seg_A | in_seg_E | in_seg_F | in_seg_G;
            6'd16: draw_pixel = in_seg_A | in_seg_C | in_seg_D | in_seg_E | in_seg_F | in_seg_G2;
            6'd17: draw_pixel = in_seg_B | in_seg_C | in_seg_E | in_seg_F | in_seg_G;
            6'd18: draw_pixel = in_seg_A | in_seg_D | in_seg_I | in_seg_L;
            6'd19: draw_pixel = in_seg_B | in_seg_C | in_seg_D | in_seg_E;
            6'd20: draw_pixel = in_seg_E | in_seg_F | in_seg_G1 | in_seg_J | in_seg_K;
            6'd21: draw_pixel = in_seg_D | in_seg_E | in_seg_F;
            6'd22: draw_pixel = in_seg_B | in_seg_C | in_seg_E | in_seg_F | in_seg_H | in_seg_J;
            6'd23: draw_pixel = in_seg_B | in_seg_C | in_seg_E | in_seg_F | in_seg_H | in_seg_K;
            6'd24: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_E | in_seg_F;
            6'd25: draw_pixel = in_seg_A | in_seg_B | in_seg_E | in_seg_F | in_seg_G;
            6'd26: draw_pixel = in_seg_A | in_seg_B | in_seg_C | in_seg_D | in_seg_E | in_seg_F | in_seg_K;
            6'd27: draw_pixel = in_seg_A | in_seg_B | in_seg_E | in_seg_F | in_seg_G | in_seg_K;
            6'd28: draw_pixel = in_seg_A | in_seg_C | in_seg_D | in_seg_F | in_seg_G;
            6'd29: draw_pixel = in_seg_A | in_seg_I | in_seg_L;
            6'd30: draw_pixel = in_seg_B | in_seg_C | in_seg_D | in_seg_E | in_seg_F;
            6'd31: draw_pixel = in_seg_E | in_seg_F | in_seg_J | in_seg_M;
            6'd32: draw_pixel = in_seg_B | in_seg_C | in_seg_E | in_seg_F | in_seg_K | in_seg_M;
            6'd33: draw_pixel = in_seg_H | in_seg_J | in_seg_K | in_seg_M;
            6'd34: draw_pixel = in_seg_B | in_seg_C | in_seg_D | in_seg_F | in_seg_G1 | in_seg_G2;
            6'd35: draw_pixel = in_seg_A | in_seg_D | in_seg_J | in_seg_M;
            6'd36: draw_pixel = 1'b0; // Space
            default: draw_pixel = 1'b0; // Unhandled characters
        endcase
    end
endmodule