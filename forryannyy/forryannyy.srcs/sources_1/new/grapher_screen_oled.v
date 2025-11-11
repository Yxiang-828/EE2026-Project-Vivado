`timescale 1ns / 1ps

module grapher_screen_oled(
    input clk,
    input [12:0] pixel_index,
    input [2:0] selected_graph_type,
    input enable,
    input parsed_valid,
    input [1:0] error_code,
    input [1:0] current_param_index,
    input signed [8:0] linear_slope, linear_intercept,
    input signed [8:0] quadratic_a, quadratic_b, quadratic_c,
    input signed [8:0] cubic_a, cubic_b, cubic_c, cubic_d,
    input signed [8:0] exp_scale,
    input signed [8:0] ln_scale,
    input signed [8:0] sin_amplitude, cos_amplitude, tan_amplitude,
    // --- int inputs ---
    input show_intersect_screen,
    input intersect_found_latched,
    input [9:0] intersect_x_latched,
    input [9:0] intersect_y_latched,
    
    output reg [15:0] oled_data
);

    parameter WIDTH  = 96;
    parameter HEIGHT = 64;
    
    localparam [15:0] WHITE = 16'hFFFF;
    localparam [15:0] BLACK = 16'h0000;
    localparam [15:0] RED = 16'hF800;
    localparam [15:0] YELLOW = 16'hFFE0;
    localparam [15:0] GREEN = 16'h07E0;

    // Invert both x and y
    wire [6:0] x = WIDTH - 1 - (pixel_index % WIDTH);
    wire [5:0] y = HEIGHT - 1 - (pixel_index / WIDTH);

    // Error state management
    reg [1:0] latched_error_code;
    reg error_displayed;
    
    always @(posedge clk) begin
        if (!enable) begin
            latched_error_code <= 2'b00;
            error_displayed <= 0;
        end else if (error_code != 2'b00) begin
            latched_error_code <= error_code;
            error_displayed <= 1;
        end else if (parsed_valid && error_displayed && error_code == 2'b00) begin
            latched_error_code <= 2'b00;
            error_displayed <= 0;
        end
    end
    
    wire [1:0] display_error = error_displayed ? latched_error_code : 2'b00;

    // Error message drawing
    wire draw_error_s = (display_error == 2'b01) && draw_small_char("S", x - 42, y - 26);
    wire draw_error_y = (display_error == 2'b01) && draw_small_char("Y", x - 48, y - 26);
    wire draw_error_n = (display_error == 2'b01) && draw_small_char("N", x - 54, y - 26);
    wire draw_error_e = (display_error == 2'b01) && draw_small_char("E", x - 42, y - 38);
    wire draw_error_r1 = (display_error == 2'b01) && draw_small_char("R", x - 48, y - 38);
    wire draw_error_r2 = (display_error == 2'b01) && draw_small_char("R", x - 54, y - 38);

    wire draw_trunc_t = (display_error == 2'b10) && draw_small_char("T", x - 30, y - 2);
    wire draw_trunc_r = (display_error == 2'b10) && draw_small_char("R", x - 36, y - 2);
    wire draw_trunc_u = (display_error == 2'b10) && draw_small_char("U", x - 42, y - 2);
    wire draw_trunc_n = (display_error == 2'b10) && draw_small_char("N", x - 48, y - 2);
    wire draw_trunc_c = (display_error == 2'b10) && draw_small_char("C", x - 54, y - 2);

    localparam [5:0] LINE1_Y = 15;
    localparam [5:0] LINE2_Y = 27;
    localparam [5:0] LINE3_Y = 39;
    localparam [5:0] LINE4_Y = 51;

    reg signed [8:0] param1_val, param2_val, param3_val, param4_val;
    reg [23:0] param1_name, param2_name, param3_name, param4_name;
    reg [1:0] num_params;
    
    always @(*) begin
        param1_val = 0; param2_val = 0; param3_val = 0; param4_val = 0;
        param1_name = {8'h20, 8'h20, 8'h20};
        param2_name = {8'h20, 8'h20, 8'h20};
        param3_name = {8'h20, 8'h20, 8'h20};
        param4_name = {8'h20, 8'h20, 8'h20};
        num_params = 0;
        
        case (selected_graph_type)
            3'b000: begin
                num_params = 2;
                param1_name = {"S", "L", "P"};
                param1_val = linear_slope;
                param2_name = {"I", "N", "T"};
                param2_val = linear_intercept;
            end
            3'b001: begin
                num_params = 3;
                param1_name = {"A", " ", " "};
                param1_val = quadratic_a;
                param2_name = {"B", " ", " "};
                param2_val = quadratic_b;
                param3_name = {"C", " ", " "};
                param3_val = quadratic_c;
            end
            3'b010: begin
                num_params = 4;
                param1_name = {"A", " ", " "};
                param1_val = cubic_a;
                param2_name = {"B", " ", " "};
                param2_val = cubic_b;
                param3_name = {"C", " ", " "};
                param3_val = cubic_c;
                param4_name = {"D", " ", " "};
                param4_val = cubic_d;
            end
            3'b011: begin
                num_params = 1;
                param1_name = {"S", "I", "N"};
                param1_val = sin_amplitude;
            end
            3'b100: begin
                num_params = 1;
                param1_name = {"C", "O", "S"};
                param1_val = cos_amplitude;
            end
            3'b101: begin
                num_params = 1;
                param1_name = {"T", "A", "N"};
                param1_val = tan_amplitude;
            end
            3'b110: begin
                num_params = 1;
                param1_name = {"E", "X", "P"};
                param1_val = exp_scale;
            end
            3'b111: begin
                num_params = 1;
                param1_name = {"L", "N", " "};
                param1_val = ln_scale;
            end
        endcase
    end

    wire draw_param1, draw_param2, draw_param3, draw_param4;
    wire is_active1, is_active2, is_active3, is_active4;
    
    assign is_active1 = (current_param_index == 2'd0);
    assign is_active2 = (current_param_index == 2'd1);
    assign is_active3 = (current_param_index == 2'd2);
    assign is_active4 = (current_param_index == 2'd3);
    
    draw_parameter_line #(.LINE_Y(LINE1_Y)) line1 (
        .x(x), .y(y), .enable(display_error == 2'b00 && num_params >= 1),
        .param_name(param1_name), .param_value(param1_val),
        .is_active(is_active1),
        .draw_active(draw_param1)
    );
    
    draw_parameter_line #(.LINE_Y(LINE2_Y)) line2 (
        .x(x), .y(y), .enable(display_error == 2'b00 && num_params >= 2),
        .param_name(param2_name), .param_value(param2_val),
        .is_active(is_active2),
        .draw_active(draw_param2)
    );
    
    draw_parameter_line #(.LINE_Y(LINE3_Y)) line3 (
        .x(x), .y(y), .enable(display_error == 2'b00 && num_params >= 3),
        .param_name(param3_name), .param_value(param3_val),
        .is_active(is_active3),
        .draw_active(draw_param3)
    );
    
    draw_parameter_line #(.LINE_Y(LINE4_Y)) line4 (
        .x(x), .y(y), .enable(display_error == 2'b00 && num_params >= 4),
        .param_name(param4_name), .param_value(param4_val),
        .is_active(is_active4),
        .draw_active(draw_param4)
    );

    function draw_small_char;
        input [7:0] char_code;
        input signed [7:0] char_x;
        input signed [6:0] char_y;
        begin
            if (char_x < 0 || char_x >= 96 || char_y < 0 || char_y >= 64) begin
                draw_small_char = 1'b0;
            end else begin
                case (char_code)
                    "A": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 6 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 6 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "B": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 6 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "C": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 0 && char_x < 2)
                    );
                    "D": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "E": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 5 && char_y < 7 && char_x >= 2 && char_x < 4) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5)
                    );
                    "I": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    "L": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5)
                    );
                    "M": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 12 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 2 && char_x < 4)
                    );
                    "N": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 12 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 8 && char_x >= 2 && char_x < 4)
                    );
                    "O": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "P": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6)
                    );
                    "R": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 6 && char_y < 8 && char_x >= 3 && char_x < 5) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "S": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 6 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "T": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 0 && char_x < 6) ||
                        (char_y >= 2 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    "U": draw_small_char = (
                        (char_y >= 0 && char_y < 10 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 10 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    "X": draw_small_char = (
                        (char_y >= 0 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 8 && char_x >= 2 && char_x < 4) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "Y": draw_small_char = (
                        (char_y >= 0 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    ":": draw_small_char = (
                        (char_y >= 3 && char_y < 5 && char_x >= 1 && char_x < 3) ||
                        (char_y >= 7 && char_y < 9 && char_x >= 1 && char_x < 3)
                    );
                    " ": draw_small_char = 1'b0;
                    default: draw_small_char = 1'b0;
                endcase
            end
        end
    endfunction

    // --- Add draw_digit function to main module ---
    function draw_digit;
        input [3:0] digit;
        input [6:0] base_x;
        input [6:0] px;
        input signed [6:0] py;
        reg [6:0] dx;
        begin
            dx = px - base_x;
            if (dx >= 0 && dx < 8 && py >= 0 && py < 10) begin
                case (digit)
                    4'd0: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && (dx < 2 || dx >= 6))
                    );
                    4'd1: draw_digit = (py >= 0 && py < 10 && dx >= 6);
                    4'd2: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx >= 6) ||
                        (py >= 6 && py < 8 && dx < 2)
                    );
                    4'd3: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && dx >= 6)
                    );
                    4'd4: draw_digit = (
                        (py >= 0 && py < 6 && dx < 2) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 0 && py < 10 && dx >= 6)
                    );
                    4'd5: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx < 2) ||
                        (py >= 6 && py < 8 && dx >= 6)
                    );
                    4'd6: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && dx < 2) ||
                        (py >= 6 && py < 8 && dx >= 6)
                    );
                    4'd7: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 10 && dx >= 6)
                    );
                    4'd8: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && (dx < 2 || dx >= 6))
                    );
                    4'd9: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx < 2) ||
                        (py >= 0 && py < 10 && dx >= 6)
                    );
                    4'd10: draw_digit = (py >= 4 && py < 6 && dx >= 0 && dx < 8);
                    default: draw_digit = 1'b0;
                endcase
            end else begin
                draw_digit = 1'b0;
            end
        end
    endfunction

    // --- draw_decimal_point function ---
    function draw_decimal_point;
        input [6:0] base_x;
        input [6:0] px;
        input signed [6:0] py;
        reg [6:0] dx;
        begin
            dx = px - base_x;
            // Draw a 2x2 square
            if (dx >= 0 && dx < 2 && py >= 8 && py < 10)
                draw_decimal_point = 1'b1;
            else
                draw_decimal_point = 1'b0;
        end
    endfunction

    // --- new number-to-digit logic ---
    // _tenths registers
    reg [3:0] x_huns, x_tens, x_ones, x_tenths;
    reg [3:0] y_huns, y_tens, y_ones, y_tenths;
    reg x_sign, y_sign;
    reg [10:0] x_abs, y_abs;
    reg [10:0] x_integer_part, y_integer_part; // For the part before the decimal

    // --- PIPELINE REGISTERS ---
    reg signed [10:0] graph_x_pixel_p1, graph_y_pixel_p1;
    reg signed [14:0] graph_x_scaled_p2, graph_y_scaled_p2;
    reg signed [10:0] graph_x_fixed_p3, graph_y_fixed_p3;
    reg [10:0] x_abs_p4, y_abs_p4;
    reg x_sign_p4, y_sign_p4;
    reg [10:0] x_integer_part_p5, y_integer_part_p5;
    reg [6:0] x_rem_p5, y_rem_p5;

    // This block pipelines all math over 7 clock cycles to ensure timing is met.
    always @(posedge clk) begin

        // --- STAGE 1: Calculate Pixel Coordinate ---
        graph_x_pixel_p1 <= intersect_x_latched - 320;
        graph_y_pixel_p1 <= 240 - intersect_y_latched;

        // --- STAGE 2: Scale by 10 (for decimal) ---
        graph_x_scaled_p2 <= graph_x_pixel_p1 * 10;
        graph_y_scaled_p2 <= graph_y_pixel_p1 * 10;

        // --- STAGE 3: Divide by 16 (for grid) ---
        graph_x_fixed_p3 <= graph_x_scaled_p2 >>> 4;
        graph_y_fixed_p3 <= graph_y_scaled_p2 >>> 4;
        
        // --- STAGE 4: Get Sign and Absolute Value ---
        x_sign_p4 <= graph_x_fixed_p3[10];
        y_sign_p4 <= graph_y_fixed_p3[10];
        x_abs_p4 <= x_sign_p4 ? -graph_x_fixed_p3 : graph_x_fixed_p3;
        y_abs_p4 <= y_sign_p4 ? -graph_y_fixed_p3 : graph_y_fixed_p3;
        
        // --- STAGE 5: Split Integer and Decimal Parts ---
        x_tenths <= x_abs_p4 % 10;
        x_integer_part_p5 <= x_abs_p4 / 10;
        
        y_tenths <= y_abs_p4 % 10;
        y_integer_part_p5 <= y_abs_p4 / 10;
        
        // Pass the sign through the pipeline to keep it in sync
        x_sign <= x_sign_p4;
        y_sign <= y_sign_p4;

        // --- STAGE 6: Calculate Hundreds and Remainder ---
        x_huns <= x_integer_part_p5 / 100;
        x_rem_p5 <= x_integer_part_p5 % 100;
        
        y_huns <= y_integer_part_p5 / 100;
        y_rem_p5 <= y_integer_part_p5 % 100;

        // --- STAGE 7: Calculate Final Tens and Ones ---
        x_tens <= x_rem_p5 / 10;
        x_ones <= x_rem_p5 % 10;
        
        y_tens <= y_rem_p5 / 10;
        y_ones <= y_rem_p5 % 10;
    end

    // --- drawing wires ---
    wire draw_x_label = draw_small_char("X", x - 2, y - 15) || draw_small_char(":", x - 8, y - 15);
    wire draw_y_label = draw_small_char("Y", x - 2, y - 39) || draw_small_char(":", x - 8, y - 39);

    // Shift all X positions to make room for ".X"
    wire draw_x_num = (x_sign && draw_digit(4'd10, 24, x, y-15)) ||
                      draw_digit(x_huns, 36, x, y-15) ||
                      draw_digit(x_tens, 48, x, y-15) ||
                      draw_digit(x_ones, 60, x, y-15) ||
                      draw_decimal_point(69, x, y-15) || // Add decimal point
                      draw_digit(x_tenths, 73, x, y-15); // Add tenths digit
                      
    wire draw_y_num = (y_sign && draw_digit(4'd10, 24, x, y-39)) ||
                      draw_digit(y_huns, 36, x, y-39) ||
                      draw_digit(y_tens, 48, x, y-39) ||
                      draw_digit(y_ones, 60, x, y-39) ||
                      draw_decimal_point(69, x, y-39) || // Add decimal point
                      draw_digit(y_tenths, 73, x, y-39); // Add tenths digit

    wire draw_no = draw_small_char("N", x - 30, y - 26) || draw_small_char("O", x - 36, y - 26);

    always @(*) begin
        // --- Main Mode MUX ---
        if (show_intersect_screen) begin
            // --- Intersect Mode Rendering ---
            if (!enable) begin
                oled_data = BLACK;
            end else if (!intersect_found_latched) begin
                // Draw "NO"
                oled_data = (draw_no) ? RED : BLACK;
            end else begin
                // Draw "X:", "Y:", and the numbers
                if (draw_x_label || draw_y_label)
                    oled_data = WHITE;
                else if (draw_x_num || draw_y_num)
                    oled_data = GREEN;
                else
                    oled_data = BLACK;
            end
        
        end else begin
            // --- Parameter Mode Rendering ---
            if (!enable) begin
                oled_data = BLACK;
            end else if (display_error == 2'b01) begin
                if (draw_error_s || draw_error_y || draw_error_n || 
                    draw_error_e || draw_error_r1 || draw_error_r2)
                    oled_data = RED;
                else
                    oled_data = BLACK;
            end else if (display_error == 2'b10) begin
                if (draw_trunc_t || draw_trunc_r || draw_trunc_u || draw_trunc_n || draw_trunc_c)
                    oled_data = YELLOW;
                else if (draw_param1)
                    oled_data = is_active1 ? GREEN : WHITE;
                else if (draw_param2)
                    oled_data = is_active2 ? GREEN : WHITE;
                else if (draw_param3)
                    oled_data = is_active3 ? GREEN : WHITE;
                else if (draw_param4)
                    oled_data = is_active4 ? GREEN : WHITE;
                else
                    oled_data = BLACK;
            end else begin
                if (draw_param1)
                    oled_data = is_active1 ? GREEN : WHITE;
                else if (draw_param2)
                    oled_data = is_active2 ? GREEN : WHITE;
                else if (draw_param3)
                    oled_data = is_active3 ? GREEN : WHITE;
                else if (draw_param4)
                    oled_data = is_active4 ? GREEN : WHITE;
                else
                    oled_data = BLACK;
            end
        end
    end

endmodule

// Helper module to draw a single parameter line
module draw_parameter_line #(
    parameter [5:0] LINE_Y = 15
)(
    input [6:0] x,
    input [5:0] y,
    input enable,
    input [23:0] param_name,
    input signed [8:0] param_value,
    input is_active,
    output draw_active
);

    localparam [6:0] NAME_X = 2;
    localparam [6:0] COLON_X = 24;
    localparam [6:0] SIGN_X = 36;
    localparam [6:0] HUND_X = 48;
    localparam [6:0] TENS_X = 60;
    localparam [6:0] ONES_X = 72;

    wire signed [6:0] ly = y - LINE_Y;
    
    wire sign = param_value[8];
    wire [7:0] magnitude = sign ? ((~param_value[7:0]) + 1) : param_value[7:0];
    wire [3:0] hundreds = magnitude / 100;
    wire [7:0] rem = magnitude - (hundreds * 100);
    wire [3:0] tens = rem / 10;
    wire [3:0] ones = rem - (tens * 10);

    function draw_small_char;
        input [7:0] char_code;
        input signed [7:0] char_x;
        input signed [6:0] char_y;
        begin
            if (char_x < 0 || char_y < 0 || char_y >= 12) begin
                draw_small_char = 1'b0;
            end else begin
                case (char_code)
                    "A": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 6 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 6 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "B": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 6 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "C": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 0 && char_x < 2)
                    );
                    "D": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "E": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 5 && char_y < 7 && char_x >= 2 && char_x < 4) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5)
                    );
                    "I": draw_small_char = (char_y >= 0 && char_y < 12 && char_x >= 2 && char_x < 4);
                    "L": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 5)
                    );
                    "M": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 12 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 2 && char_x < 4)
                    );
                    "N": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 12 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 8 && char_x >= 2 && char_x < 4)
                    );
                    "O": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 2 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "P": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6)
                    );
                    "R": draw_small_char = (
                        (char_y >= 0 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 2 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 2 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 6 && char_y < 8 && char_x >= 3 && char_x < 5) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "S": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 4 && char_y < 6 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 1 && char_x < 5) ||
                        (char_y >= 2 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 6 && char_y < 10 && char_x >= 4 && char_x < 6)
                    );
                    "T": draw_small_char = (
                        (char_y >= 0 && char_y < 2 && char_x >= 0 && char_x < 6) ||
                        (char_y >= 2 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    "U": draw_small_char = (
                        (char_y >= 0 && char_y < 10 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 10 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 10 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    "X": draw_small_char = (
                        (char_y >= 0 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 8 && char_x >= 2 && char_x < 4) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 8 && char_y < 12 && char_x >= 4 && char_x < 6)
                    );
                    "Y": draw_small_char = (
                        (char_y >= 0 && char_y < 4 && char_x >= 0 && char_x < 2) ||
                        (char_y >= 0 && char_y < 4 && char_x >= 4 && char_x < 6) ||
                        (char_y >= 4 && char_y < 12 && char_x >= 2 && char_x < 4)
                    );
                    ":": draw_small_char = (
                        (char_y >= 3 && char_y < 5 && char_x >= 1 && char_x < 3) ||
                        (char_y >= 7 && char_y < 9 && char_x >= 1 && char_x < 3)
                    );
                    " ": draw_small_char = 1'b0;
                    default: draw_small_char = 1'b0;
                endcase
            end
        end
    endfunction

    function draw_digit;
        input [3:0] digit;
        input [6:0] base_x;
        input [6:0] px;
        input signed [6:0] py;
        reg [6:0] dx;
        begin
            dx = px - base_x;
            if (dx >= 0 && dx < 8 && py >= 0 && py < 10) begin
                case (digit)
                    4'd0: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && (dx < 2 || dx >= 6))
                    );
                    4'd1: draw_digit = (py >= 0 && py < 10 && dx >= 6);
                    4'd2: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx >= 6) ||
                        (py >= 6 && py < 8 && dx < 2)
                    );
                    4'd3: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && dx >= 6)
                    );
                    4'd4: draw_digit = (
                        (py >= 0 && py < 6 && dx < 2) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 0 && py < 10 && dx >= 6)
                    );
                    4'd5: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx < 2) ||
                        (py >= 6 && py < 8 && dx >= 6)
                    );
                    4'd6: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && dx < 2) ||
                        (py >= 6 && py < 8 && dx >= 6)
                    );
                    4'd7: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 10 && dx >= 6)
                    );
                    4'd8: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 8 && (dx < 2 || dx >= 6))
                    );
                    4'd9: draw_digit = (
                        (py >= 0 && py < 2 && dx >= 0 && dx < 8) ||
                        (py >= 4 && py < 6 && dx >= 0 && dx < 8) ||
                        (py >= 8 && py < 10 && dx >= 0 && dx < 8) ||
                        (py >= 2 && py < 4 && dx < 2) ||
                        (py >= 0 && py < 10 && dx >= 6)
                    );
                    4'd10: draw_digit = (py >= 4 && py < 6 && dx >= 0 && dx < 8);
                    default: draw_digit = 1'b0;
                endcase
            end else begin
                draw_digit = 1'b0;
            end
        end
    endfunction

    wire [7:0] char1 = param_name[23:16];
    wire [7:0] char2 = param_name[15:8];
    wire [7:0] char3 = param_name[7:0];
    
    wire draw_name = enable && (
        draw_small_char(char1, x - NAME_X, ly) ||
        draw_small_char(char2, x - (NAME_X + 6), ly) ||
        draw_small_char(char3, x - (NAME_X + 12), ly) ||
        draw_small_char(":", x - COLON_X, ly)
    );
    
    wire draw_number = enable && (
        (sign && draw_digit(4'd10, SIGN_X, x, ly)) ||
        draw_digit(hundreds, HUND_X, x, ly) ||
        draw_digit(tens, TENS_X, x, ly) ||
        draw_digit(ones, ONES_X, x, ly)
    );
    
    assign draw_active = draw_name || draw_number;

endmodule