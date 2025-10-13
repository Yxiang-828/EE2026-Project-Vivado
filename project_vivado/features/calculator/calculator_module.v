`timescale 1ns / 1ps

module calculator_module (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [15:0] sw,
    input  wire [4:0]  key_code,
    input  wire        key_valid,
    input  wire [12:0] pixel_index,
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,
    output wire [15:0] oled_overlay,
    output wire [11:0] vga_pixel
);

    // ------------------------------------------------------------
    // Key mapping constants (must match keypad module)
    // ------------------------------------------------------------
    localparam [4:0] KEY_ADD    = 5'd10;
    localparam [4:0] KEY_SUB    = 5'd11;
    localparam [4:0] KEY_MUL    = 5'd12;
    localparam [4:0] KEY_DIV    = 5'd13;
    localparam [4:0] KEY_EQUAL  = 5'd14;
    localparam [4:0] KEY_CLEAR  = 5'd15;
    localparam [4:0] KEY_TOGGLE = 5'd16;

    // ------------------------------------------------------------
    // State machine for calculator workflow
    // ------------------------------------------------------------
    localparam [2:0] STATE_IDLE          = 3'd0;
    localparam [2:0] STATE_FIRST_ENTRY   = 3'd1;
    localparam [2:0] STATE_WAIT_OPERATOR = 3'd2;
    localparam [2:0] STATE_SECOND_ENTRY  = 3'd3;
    localparam [2:0] STATE_SHOW_RESULT   = 3'd4;

    reg [2:0] state = STATE_IDLE;

    // Operator encoding
    localparam [1:0] OP_ADD = 2'd0;
    localparam [1:0] OP_SUB = 2'd1;
    localparam [1:0] OP_MUL = 2'd2;
    localparam [1:0] OP_DIV = 2'd3;

    reg [1:0] operator_sel = OP_ADD;

    // Operands and result in Q16.8 format (signed)
    reg signed [23:0] first_value  = 24'sd0;
    reg signed [23:0] second_value = 24'sd0;
    reg signed [23:0] result_value = 24'sd0;

    reg error_flag = 1'b0;
    reg signed [47:0] temp_result;

    (* use_dsp = "no" *) wire signed [47:0] mult_first_second = first_value * second_value;

    // Forward declaration of helper functions
    function signed [23:0] append_digit;
        input signed [23:0] current_value;
        input [3:0] digit;
        reg signed [39:0] scaled_value;
        reg signed [39:0] candidate;
        reg signed [39:0] digit_q168;
        begin
            digit_q168   = {12'd0, digit, 8'd0};
            scaled_value = {{16{current_value[23]}}, current_value};
            scaled_value = (scaled_value <<< 3) + (scaled_value <<< 1);
            candidate    = scaled_value + digit_q168;

            if (candidate > 40'sd8_388_607)
                append_digit = 24'sh7FFFFF;
            else if (candidate < -40'sd8_388_608)
                append_digit = -24'sh800000;
            else
                append_digit = candidate[23:0];
        end
    endfunction

    function signed [23:0] saturate_q168;
        input signed [47:0] value_in;
        begin
            if (value_in > 48'sd8_388_607)
                saturate_q168 = 24'sh7FFFFF;
            else if (value_in < -48'sd8_388_608)
                saturate_q168 = -24'sh800000;
            else
                saturate_q168 = value_in[23:0];
        end
    endfunction

    function [5:0] digit_char;
        input integer digit;
        begin
            if (digit < 0)
                digit_char = 6'd36;
            else if (digit > 9)
                digit_char = 6'd9;
            else
                digit_char = digit[5:0];
        end
    endfunction

    function [17:0] encode_value_digits;
        input signed [15:0] value_in;
        integer magnitude;
        integer hundreds;
        integer tens;
        integer units;
        begin
            magnitude = (value_in < 0) ? -value_in : value_in;
            if (magnitude > 999)
                magnitude = 999;

            hundreds = magnitude / 100;
            tens     = (magnitude % 100) / 10;
            units    = magnitude % 10;

            encode_value_digits = {digit_char(hundreds), digit_char(tens), digit_char(units)};
        end
    endfunction

    function [5:0] sign_char;
        input signed [15:0] value_in;
        begin
            if (value_in < 0)
                sign_char = 6'd23; // N
            else
                sign_char = 6'd36; // space
        end
    endfunction

    function [5:0] operator_char;
        input [1:0] op_sel;
        begin
            case (op_sel)
                OP_ADD: operator_char = 6'd10; // A
                OP_SUB: operator_char = 6'd28; // S
                OP_MUL: operator_char = 6'd22; // M
                default: operator_char = 6'd13; // D
            endcase
        end
    endfunction

    // Handle main calculator logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= STATE_IDLE;
            operator_sel <= OP_ADD;
            first_value  <= 24'sd0;
            second_value <= 24'sd0;
            result_value <= 24'sd0;
            error_flag   <= 1'b0;
        end else begin
            if (!enable) begin
                // Pause updates when mode inactive
                state <= state;
            end else if (key_valid && (key_code != KEY_TOGGLE)) begin
                case (state)
                    STATE_IDLE: begin
                        if (key_code <= 5'd9) begin
                            first_value  <= append_digit(24'sd0, key_code[3:0]);
                            state        <= STATE_FIRST_ENTRY;
                            error_flag   <= 1'b0;
                        end else if (key_code == KEY_CLEAR) begin
                            first_value  <= 24'sd0;
                            second_value <= 24'sd0;
                            result_value <= 24'sd0;
                            operator_sel <= OP_ADD;
                            error_flag   <= 1'b0;
                        end
                    end

                    STATE_FIRST_ENTRY: begin
                        if (key_code <= 5'd9) begin
                            first_value <= append_digit(first_value, key_code[3:0]);
                        end else if (key_code == KEY_CLEAR) begin
                            first_value  <= 24'sd0;
                            second_value <= 24'sd0;
                            result_value <= 24'sd0;
                            operator_sel <= OP_ADD;
                            state        <= STATE_IDLE;
                            error_flag   <= 1'b0;
                        end else if ((key_code >= KEY_ADD) && (key_code <= KEY_DIV)) begin
                            operator_sel <= (key_code == KEY_ADD) ? OP_ADD :
                                             (key_code == KEY_SUB) ? OP_SUB :
                                             (key_code == KEY_MUL) ? OP_MUL : OP_DIV;
                            second_value <= 24'sd0;
                            state        <= STATE_WAIT_OPERATOR;
                            error_flag   <= 1'b0;
                        end
                    end

                    STATE_WAIT_OPERATOR: begin
                        if (key_code <= 5'd9) begin
                            second_value <= append_digit(24'sd0, key_code[3:0]);
                            state        <= STATE_SECOND_ENTRY;
                        end else if ((key_code >= KEY_ADD) && (key_code <= KEY_DIV)) begin
                            operator_sel <= (key_code == KEY_ADD) ? OP_ADD :
                                             (key_code == KEY_SUB) ? OP_SUB :
                                             (key_code == KEY_MUL) ? OP_MUL : OP_DIV;
                        end else if (key_code == KEY_CLEAR) begin
                            second_value <= 24'sd0;
                            state        <= STATE_IDLE;
                        end
                    end

                    STATE_SECOND_ENTRY: begin
                        if (key_code <= 5'd9) begin
                            second_value <= append_digit(second_value, key_code[3:0]);
                        end else if (key_code == KEY_CLEAR) begin
                            second_value <= 24'sd0;
                            state        <= STATE_WAIT_OPERATOR;
                        end else if (key_code == KEY_EQUAL) begin
                            // Perform computation
                            error_flag <= 1'b0;
                            case (operator_sel)
                                OP_ADD: begin
                                    temp_result = {{24{first_value[23]}}, first_value} + {{24{second_value[23]}}, second_value};
                                    result_value <= saturate_q168(temp_result);
                                end
                                OP_SUB: begin
                                    temp_result = {{24{first_value[23]}}, first_value} - {{24{second_value[23]}}, second_value};
                                    result_value <= saturate_q168(temp_result);
                                end
                                OP_MUL: begin
                                    temp_result = mult_first_second >>> 8;
                                    result_value <= saturate_q168(temp_result);
                                end
                                default: begin
                                    if (second_value == 24'sd0) begin
                                        error_flag   <= 1'b1;
                                        result_value <= 24'sd0;
                                    end else begin
                                        temp_result = ({{24{first_value[23]}}, first_value} <<< 8) / {{24{second_value[23]}}, second_value};
                                        result_value <= saturate_q168(temp_result);
                                    end
                                end
                            endcase
                            state <= STATE_SHOW_RESULT;
                        end
                    end

                    STATE_SHOW_RESULT: begin
                        if (key_code == KEY_CLEAR) begin
                            first_value  <= 24'sd0;
                            second_value <= 24'sd0;
                            result_value <= 24'sd0;
                            operator_sel <= OP_ADD;
                            state        <= STATE_IDLE;
                            error_flag   <= 1'b0;
                        end else if (key_code <= 5'd9) begin
                            first_value  <= append_digit(24'sd0, key_code[3:0]);
                            second_value <= 24'sd0;
                            operator_sel <= OP_ADD;
                            state        <= STATE_FIRST_ENTRY;
                            error_flag   <= 1'b0;
                        end else if ((key_code >= KEY_ADD) && (key_code <= KEY_DIV)) begin
                            first_value  <= result_value;
                            second_value <= 24'sd0;
                            operator_sel <= (key_code == KEY_ADD) ? OP_ADD :
                                             (key_code == KEY_SUB) ? OP_SUB :
                                             (key_code == KEY_MUL) ? OP_MUL : OP_DIV;
                            state        <= STATE_WAIT_OPERATOR;
                            error_flag   <= 1'b0;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                    end
                endcase
            end

            // Optional switch input override (sw[15] acts as capture latch)
            if (enable && sw[15]) begin
                first_value  <= {8'd0, sw[7:0], 8'd0};
                second_value <= {8'd0, sw[15:8], 8'd0};
                operator_sel <= OP_ADD;
                state        <= STATE_FIRST_ENTRY;
                error_flag   <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Character mapping for VGA overlay
    // ------------------------------------------------------------
    wire signed [15:0] first_int   = first_value[23:8];
    wire signed [15:0] second_int  = second_value[23:8];
    wire signed [15:0] result_int  = result_value[23:8];

    wire [17:0] first_digits  = encode_value_digits(first_int);
    wire [17:0] second_digits = encode_value_digits(second_int);
    wire [17:0] result_digits = encode_value_digits(result_int);

    wire [5:0] first_sign_char  = sign_char(first_int);
    wire [5:0] second_sign_char = sign_char(second_int);
    wire [5:0] result_sign_char = error_flag ? 6'd36 : sign_char(result_int);

    wire [5:0] first_digit_hundreds  = first_digits[17:12];
    wire [5:0] first_digit_tens      = first_digits[11:6];
    wire [5:0] first_digit_units     = first_digits[5:0];

    wire [5:0] second_digit_hundreds = second_digits[17:12];
    wire [5:0] second_digit_tens     = second_digits[11:6];
    wire [5:0] second_digit_units    = second_digits[5:0];

    wire [5:0] result_digit_hundreds = error_flag ? 6'd14 : result_digits[17:12]; // 'E' if error
    wire [5:0] result_digit_tens     = error_flag ? 6'd27 : result_digits[11:6];  // 'R'
    wire [5:0] result_digit_units    = error_flag ? 6'd27 : result_digits[5:0];   // 'R'

    wire [5:0] op_char = operator_char(operator_sel);

    // VGA text placement (character width/height)
    localparam [9:0] CHAR_W = 10'd48;
    localparam [9:0] CHAR_H = 10'd80;
    localparam [9:0] CHAR_SPACING = 10'd4;
    localparam [9:0] START_X = 10'd60;
    localparam [9:0] START_Y = 10'd140;

    wire calc_panel = enable && (vga_x >= (START_X - 10'd20)) && (vga_x < (START_X + 15*(CHAR_W + CHAR_SPACING))) &&
                      (vga_y >= (START_Y - 10'd20)) && (vga_y < (START_Y + CHAR_H + 10'd20));

    wire panel_border = calc_panel &&
                        ((vga_x == (START_X - 10'd20)) ||
                         (vga_x == (START_X + 15*(CHAR_W + CHAR_SPACING) - 1)) ||
                         (vga_y == (START_Y - 10'd20)) ||
                         (vga_y == (START_Y + CHAR_H + 10'd20 - 1)));

    wire result_strip = enable && (vga_x >= START_X) && (vga_x < (START_X + 5*(CHAR_W + CHAR_SPACING))) &&
                        (vga_y >= START_Y) && (vga_y < (START_Y + (CHAR_H >> 1)));

    assign vga_pixel = enable ? (panel_border ? 12'h0F0 :
                                 result_strip ? 12'hF00 :
                                 calc_panel ? 12'h112 : 12'h000)
                              : 12'h000;

    // ------------------------------------------------------------
    // OLED overlay (title badge)
    // ------------------------------------------------------------
    wire [6:0] oled_x = pixel_index % 13'd96;
    wire [5:0] oled_y = pixel_index / 13'd96;

    wire title_draw0, title_draw1, title_draw2, title_draw3;

    fourteen_segment_drawer_oled title_c0 (
        .x(oled_x), .y(oled_y), .character(6'd12),
        .x_start(7'd4), .y_start(6'd0), .height(7'd12), .width(7'd20), .draw_pixel(title_draw0)
    );

    fourteen_segment_drawer_oled title_c1 (
        .x(oled_x), .y(oled_y), .character(6'd10),
        .x_start(7'd24), .y_start(6'd0), .height(7'd12), .width(7'd20), .draw_pixel(title_draw1)
    );

    fourteen_segment_drawer_oled title_c2 (
        .x(oled_x), .y(oled_y), .character(6'd21),
        .x_start(7'd44), .y_start(6'd0), .height(7'd12), .width(7'd20), .draw_pixel(title_draw2)
    );

    fourteen_segment_drawer_oled title_c3 (
        .x(oled_x), .y(oled_y), .character(6'd12),
        .x_start(7'd64), .y_start(6'd0), .height(7'd12), .width(7'd20), .draw_pixel(title_draw3)
    );

    wire title_draw = title_draw0 | title_draw1 | title_draw2 | title_draw3;

    assign oled_overlay = (enable && title_draw) ? 16'h07E0 : 16'h0000;

endmodule
