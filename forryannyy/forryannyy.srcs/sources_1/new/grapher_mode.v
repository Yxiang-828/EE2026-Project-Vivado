`timescale 1ns / 1ps

module grapher_module_slim(
    input clk,
    input reset,
    input enable,
    input [15:0] sw,
    input [4:0] btn_debounced,
    input [12:0] jc_pixel_index,
    input [9:0] vga_x,
    input [9:0] vga_y,
    input vga_p_tick,
    
    input input_system_enable,
    output keypad_request_enable,
    
    input [7:0] ascii_char,
    input ascii_valid,
    
    input [511:0] shared_equation_buffer,
    input [6:0] shared_equation_length,
    input shared_equation_complete,
    
    output [15:0] grapher_oled_data,
    output [11:0] vga_data
);

    wire grapher_submode = sw[3];
    
    // ========================================
    // === NUMBER PARSER INSTANTIATION ===
    // ========================================
    wire signed [8:0] parsed_number;
    wire parsed_valid;
    wire [1:0] error_code;
    
    number_parser parser_inst (
        .clk(clk),
        .rst(reset),
        .ascii_char(ascii_char),
        .ascii_valid(ascii_valid),
        .grapher_submode(grapher_submode),
        .sw3_signed_mode(sw[3]),
        .parsed_number(parsed_number),
        .parsed_valid(parsed_valid),
        .error_code(error_code)
    );
    
    // ========================================
    // === SUBMODE EDGE DETECTION ===
    // ========================================
    reg grapher_submode_prev;
    wire submode_changed = (grapher_submode != grapher_submode_prev);
    
    always @(posedge clk) begin
        if (reset) begin
            grapher_submode_prev <= 0;
        end else begin
            grapher_submode_prev <= grapher_submode;
        end
    end

    // ========================================
    // === GRAPH TYPE SELECTION ===
    // ========================================
    wire [2:0] selected_graph_type;
    wire type_selected;
    wire [11:0] menu_vga;

    graph_type_selector graph_type_selector_inst(
        .clk(clk),
        .btn(btn_debounced),
        .current_main_mode(2'b11),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .sw14(sw[14]),
        .enable(grapher_submode),
        .reset_selection(submode_changed),
        .selected_graph_type(selected_graph_type),
        .type_selected(type_selected),
        .vga_data(menu_vga),
        .oled_data()
    );

    // ========================================
    // === EQUATION PARSER ===
    // ========================================
    wire [2:0] parsed_graph_type;
    wire signed [8:0] parsed_coeff_a;
    wire signed [8:0] parsed_coeff_b;
    wire signed [8:0] parsed_coeff_c;
    wire signed [8:0] parsed_coeff_d;
    wire parse_valid_pulse;
    wire [1:0] parse_error;

    equation_parser equation_parser_inst(
        .clk(clk),
        .rst(reset || submode_changed),
        .shared_equation_buffer(shared_equation_buffer),
        .shared_equation_length(shared_equation_length),
        .shared_equation_complete(shared_equation_complete && !grapher_submode),
        .parsed_graph_type(parsed_graph_type),
        .parsed_coeff_a(parsed_coeff_a),
        .parsed_coeff_b(parsed_coeff_b),
        .parsed_coeff_c(parsed_coeff_c),
        .parsed_coeff_d(parsed_coeff_d),
        .parse_valid(parse_valid_pulse),
        .parse_error(parse_error)
    );

    // ========================================
    // === MULTI-GRAPH STORAGE (Up to 2 Graphs) ===
    // ========================================
    reg [2:0] stored_graph_type0, stored_graph_type1;
    reg signed [8:0] stored_coeff_a0, stored_coeff_a1;
    reg signed [8:0] stored_coeff_b0, stored_coeff_b1;
    reg signed [8:0] stored_coeff_c0, stored_coeff_c1;
    reg signed [8:0] stored_coeff_d0, stored_coeff_d1;
    reg [2:0] stored_color_slot0, stored_color_slot1;  // Now 3-bit
    reg [1:0] graph_count;  // Number of stored graphs (0-2)
    reg [1:0] next_slot;    // Next slot to overwrite (0-1)

    // Color cycling: 0,1 for manual colors
    reg [2:0] color_counter;

    always @(posedge clk) begin
        if (reset || submode_changed) begin  // Clear on any sw[3] toggle or reset
            graph_count <= 0;
            next_slot <= 0;
            color_counter <= 0;
            stored_graph_type0 <= 3'b111;  // Set to OFF
            stored_graph_type1 <= 3'b111;  // Set to OFF
            stored_coeff_a0 <= 9'd0;       // Clear coefficients
            stored_coeff_a1 <= 9'd0;
            stored_coeff_b0 <= 9'd0;
            stored_coeff_b1 <= 9'd0;
            stored_coeff_c0 <= 9'd0;
            stored_coeff_c1 <= 9'd0;
            stored_coeff_d0 <= 9'd0;
            stored_coeff_d1 <= 9'd0;
            stored_color_slot0 <= 3'd7;    // Set colors to OFF
            stored_color_slot1 <= 3'd7;
        end else if (parse_valid_pulse && parse_error == 2'b00 && !grapher_submode) begin
            // Store the new graph
            case (next_slot)
                0: begin
                    stored_graph_type0 <= parsed_graph_type;
                    stored_coeff_a0 <= parsed_coeff_a;
                    stored_coeff_b0 <= parsed_coeff_b;
                    stored_coeff_c0 <= parsed_coeff_c;
                    stored_coeff_d0 <= parsed_coeff_d;
                    stored_color_slot0 <= color_counter;
                end
                1: begin
                    stored_graph_type1 <= parsed_graph_type;
                    stored_coeff_a1 <= parsed_coeff_a;
                    stored_coeff_b1 <= parsed_coeff_b;
                    stored_coeff_c1 <= parsed_coeff_c;
                    stored_coeff_d1 <= parsed_coeff_d;
                    stored_color_slot1 <= color_counter;
                end
            endcase

            // Update counters
            color_counter <= (color_counter + 1) % 2;
            next_slot <= (next_slot + 1) % 2;
            if (graph_count < 2) graph_count <= graph_count + 1;
        end
    end

    // ========================================
    // === KEYPAD ENABLE LOGIC ===
    // ========================================
    assign keypad_request_enable = input_system_enable && 
        (grapher_submode ? !(grapher_submode && !type_selected) : 1'b1);

    // ========================================
    // === RANDOM NUMBER GENERATOR ===
    // ========================================
    wire sw2_rising;
    sw_debouncer_posedge sw2_debouncer_inst(
        .clk(clk),
        .reset(reset),
        .sw_in(sw[2]),
        .sw_posedge(sw2_rising)
    );

    wire signed [8:0] captured_random;
    wire captured_valid;

    random_9bit_signed random_inst(
        .clk(clk),
        .rst(reset),
        .enable(sw2_rising),
        .captured_output(captured_random),
        .captured_valid(captured_valid)
    );

    // ========================================
    // === EFFECTIVE PARSED NUMBER ===
    // ========================================
    wire signed [8:0] effective_parsed_number = captured_valid ? captured_random : parsed_number;
    wire effective_parsed_valid = captured_valid | parsed_valid;
    wire [1:0] effective_error_code = captured_valid ? 2'b00 : error_code;

    // ========================================
    // === PARAMETER INPUT (Manual Mode) ===
    // ========================================
    wire signed [8:0] manual_linear_slope, manual_linear_intercept;
    wire signed [8:0] manual_quadratic_a, manual_quadratic_b, manual_quadratic_c;
    wire signed [8:0] manual_cubic_a, manual_cubic_b, manual_cubic_c, manual_cubic_d;
    wire signed [8:0] manual_exp_scale;
    wire signed [8:0] manual_ln_scale;
    wire signed [8:0] manual_sin_amplitude, manual_cos_amplitude, manual_tan_amplitude;
    wire [1:0] current_param_index;

    parameter_input u_parameter_input (
        .clk(clk),
        .enable(grapher_submode && type_selected),
        .parsed_number(effective_parsed_number),
        .parsed_valid(effective_parsed_valid),
        .selected_graph_type(selected_graph_type),
        .current_param_index(current_param_index),
        .linear_slope(manual_linear_slope),
        .linear_intercept(manual_linear_intercept),
        .quadratic_a(manual_quadratic_a),
        .quadratic_b(manual_quadratic_b),
        .quadratic_c(manual_quadratic_c),
        .cubic_a(manual_cubic_a),
        .cubic_b(manual_cubic_b),
        .cubic_c(manual_cubic_c),
        .cubic_d(manual_cubic_d),
        .exp_scale(manual_exp_scale),
        .ln_scale(manual_ln_scale),
        .sin_amplitude(manual_sin_amplitude),
        .cos_amplitude(manual_cos_amplitude),
        .tan_amplitude(manual_tan_amplitude)
    );

    // ========================================
    // === COEFFICIENT MUX (Parsed vs Manual) ===
    // ========================================
    wire signed [8:0] linear_slope0, linear_slope1;
    wire signed [8:0] linear_intercept0, linear_intercept1;
    wire signed [8:0] quadratic_a0, quadratic_a1;
    wire signed [8:0] quadratic_b0, quadratic_b1;
    wire signed [8:0] quadratic_c0, quadratic_c1;
    wire signed [8:0] cubic_a0, cubic_a1;
    wire signed [8:0] cubic_b0, cubic_b1;
    wire signed [8:0] cubic_c0, cubic_c1;
    wire signed [8:0] cubic_d0, cubic_d1;
    wire signed [8:0] exp_scale0, exp_scale1;
    wire signed [8:0] ln_scale0, ln_scale1;
    wire signed [8:0] sin_amplitude0, sin_amplitude1;
    wire signed [8:0] cos_amplitude0, cos_amplitude1;
    wire signed [8:0] tan_amplitude0, tan_amplitude1;

    assign linear_slope0 = grapher_submode ? manual_linear_slope : stored_coeff_a0;
    assign linear_slope1 = grapher_submode ? manual_linear_slope : stored_coeff_a1;
    assign linear_intercept0 = grapher_submode ? manual_linear_intercept : stored_coeff_b0;
    assign linear_intercept1 = grapher_submode ? manual_linear_intercept : stored_coeff_b1;
    assign quadratic_a0 = grapher_submode ? manual_quadratic_a : stored_coeff_a0;
    assign quadratic_a1 = grapher_submode ? manual_quadratic_a : stored_coeff_a1;
    assign quadratic_b0 = grapher_submode ? manual_quadratic_b : stored_coeff_b0;
    assign quadratic_b1 = grapher_submode ? manual_quadratic_b : stored_coeff_b1;
    assign quadratic_c0 = grapher_submode ? manual_quadratic_c : stored_coeff_c0;
    assign quadratic_c1 = grapher_submode ? manual_quadratic_c : stored_coeff_c1;
    assign cubic_a0 = grapher_submode ? manual_cubic_a : stored_coeff_a0;
    assign cubic_a1 = grapher_submode ? manual_cubic_a : stored_coeff_a1;
    assign cubic_b0 = grapher_submode ? manual_cubic_b : stored_coeff_b0;
    assign cubic_b1 = grapher_submode ? manual_cubic_b : stored_coeff_b1;
    assign cubic_c0 = grapher_submode ? manual_cubic_c : stored_coeff_c0;
    assign cubic_c1 = grapher_submode ? manual_cubic_c : stored_coeff_c1;
    assign cubic_d0 = grapher_submode ? manual_cubic_d : stored_coeff_d0;
    assign cubic_d1 = grapher_submode ? manual_cubic_d : stored_coeff_d1;
    assign exp_scale0 = grapher_submode ? manual_exp_scale : stored_coeff_a0;
    assign exp_scale1 = grapher_submode ? manual_exp_scale : stored_coeff_a1;
    assign ln_scale0 = grapher_submode ? manual_ln_scale : stored_coeff_a0;
    assign ln_scale1 = grapher_submode ? manual_ln_scale : stored_coeff_a1;
    assign sin_amplitude0 = grapher_submode ? manual_sin_amplitude : stored_coeff_a0;
    assign sin_amplitude1 = grapher_submode ? manual_sin_amplitude : stored_coeff_a1;
    assign cos_amplitude0 = grapher_submode ? manual_cos_amplitude : stored_coeff_a0;
    assign cos_amplitude1 = grapher_submode ? manual_cos_amplitude : stored_coeff_a1;
    assign tan_amplitude0 = grapher_submode ? manual_tan_amplitude : stored_coeff_a0;
    assign tan_amplitude1 = grapher_submode ? manual_tan_amplitude : stored_coeff_a1;

    wire [2:0] effective_graph_type0, effective_graph_type1;
    assign effective_graph_type0 = grapher_submode ? selected_graph_type : stored_graph_type0;
    assign effective_graph_type1 = grapher_submode ? selected_graph_type : stored_graph_type1;

    // Effective types and colors
    wire [2:0] final_selected_graph_type0 = grapher_submode ? effective_graph_type0 : stored_graph_type0;
    wire [2:0] final_selected_graph_type1 = grapher_submode ? effective_graph_type1 : stored_graph_type1;
    wire [2:0] final_manual_color_slot0 = grapher_submode ? 3'd0 : stored_color_slot0;  // Use default color 0 in manual mode
    wire [2:0] final_manual_color_slot1 = grapher_submode ? 3'd1 : stored_color_slot1;  // Use default color 1 in manual mode

    // ========================================
    // === GRAPH RENDERING ===
    // ========================================
    wire [11:0] graph_vga;
    
    reg sw2_prev;
    wire sw2_pulse = (!sw[3] && sw[2] && !sw2_prev);  // Rising edge when sw[3] is off
    
    always @(posedge clk) begin
        sw2_prev <= sw[2];
    end
    
    // Add Wires for graph_renderer outputs
    wire [9:0] intersect_x_raw;
    wire [9:0] intersect_y_raw;
    wire intersect_found_raw;
    
    graph_renderer graph_renderer_inst(
        .clk(clk),
        .highlight_intersect_en(sw[2]),
        .find_intersect_btn(sw2_pulse),
        .auto_color_en(sw[3]),  // Connect to sw[3]
        .selected_graph_type0(final_selected_graph_type0),
        .selected_graph_type1(final_selected_graph_type1),
        .manual_color_slot0(final_manual_color_slot0),  // 3-bit manual colors
        .manual_color_slot1(final_manual_color_slot1),
        .linear_slope0(linear_slope0),
        .linear_slope1(linear_slope1),
        .linear_intercept0(linear_intercept0),
        .linear_intercept1(linear_intercept1),
        .quadratic_a0(quadratic_a0),
        .quadratic_a1(quadratic_a1),
        .quadratic_b0(quadratic_b0),
        .quadratic_b1(quadratic_b1),
        .quadratic_c0(quadratic_c0),
        .quadratic_c1(quadratic_c1),
        .cubic_a0(cubic_a0),
        .cubic_a1(cubic_a1),
        .cubic_b0(cubic_b0),
        .cubic_b1(cubic_b1),
        .cubic_c0(cubic_c0),
        .cubic_c1(cubic_c1),
        .cubic_d0(cubic_d0),
        .cubic_d1(cubic_d1),
        .exp_scale0(exp_scale0),
        .exp_scale1(exp_scale1),
        .ln_scale0(ln_scale0),
        .ln_scale1(ln_scale1),
        .sin_amplitude0(sin_amplitude0),
        .sin_amplitude1(sin_amplitude1),
        .cos_amplitude0(cos_amplitude0),
        .cos_amplitude1(cos_amplitude1),
        .tan_amplitude0(tan_amplitude0),
        .tan_amplitude1(tan_amplitude1),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(graph_vga),
        .vga_p_tick(vga_p_tick),
        // --- Add these three lines ---
        .intersect_x(intersect_x_raw),
        .intersect_y(intersect_y_raw),
        .intersect_found(intersect_found_raw)
    );

    // ========================================
    // === LATCH THE INTERSECTION DATA ===
    // ========================================
    reg [9:0] intersect_x_latched;
    reg [9:0] intersect_y_latched;
    reg intersect_found_latched;
    
    always @(posedge clk) begin
        if (reset) begin
            intersect_found_latched <= 1'b0;
        end else if (sw2_pulse) begin 
            // A new search starts, clear the old result
            intersect_found_latched <= 1'b0;
        end else if (intersect_found_raw) begin
            // The renderer found one, latch it.
            intersect_found_latched <= 1'b1;
            intersect_x_latched <= intersect_x_raw;
            intersect_y_latched <= intersect_y_raw;
        end
    end

    // ========================================
    // === VGA OUTPUT ===
    // ========================================
    assign vga_data = grapher_submode ? 
        (type_selected ? graph_vga : menu_vga) : 
        graph_vga;

    // ========================================
    // === JC OLED OUTPUT ===
    // ========================================
    wire show_intersect_screen = sw[2] && !grapher_submode; // (grapher_submode is sw[3])
    
    grapher_screen_oled graph_oled(
        .clk(clk),
        .pixel_index(jc_pixel_index),
        .enable(enable),
        // --- Add these new inputs ---
        .show_intersect_screen(show_intersect_screen),
        .intersect_found_latched(intersect_found_latched),
        .intersect_x_latched(intersect_x_latched),
        .intersect_y_latched(intersect_y_latched),
        // ---
        .selected_graph_type(effective_graph_type0),  // Show first graph's type for OLED
        .parsed_valid(effective_parsed_valid),
        .error_code(effective_error_code),
        .current_param_index(current_param_index),
        .linear_slope(linear_slope0),
        .linear_intercept(linear_intercept0),
        .quadratic_a(quadratic_a0),
        .quadratic_b(quadratic_b0),
        .quadratic_c(quadratic_c0),
        .cubic_a(cubic_a0),
        .cubic_b(cubic_b0),
        .cubic_c(cubic_c0),
        .cubic_d(cubic_d0),
        .exp_scale(exp_scale0),
        .ln_scale(ln_scale0),
        .sin_amplitude(sin_amplitude0),
        .cos_amplitude(sin_amplitude0),
        .tan_amplitude(tan_amplitude0),
        .oled_data(grapher_oled_data)
    );

endmodule