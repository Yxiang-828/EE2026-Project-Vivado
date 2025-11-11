`timescale 1ns / 1ps

module graph_renderer(
    input clk,
    input reset,
    input vga_p_tick,
    input auto_color_en,
    input find_intersect_btn,
    input highlight_intersect_en,
    input [2:0] selected_graph_type0, selected_graph_type1,
    input [2:0] manual_color_slot0, 
    input [2:0] manual_color_slot1, 
    input signed [8:0] linear_slope0, linear_intercept0,
    input signed [8:0] linear_slope1, linear_intercept1,
    input signed [8:0] quadratic_a0, quadratic_b0, quadratic_c0,
    input signed [8:0] quadratic_a1, quadratic_b1, quadratic_c1,
    input signed [8:0] cubic_a0, cubic_b0, cubic_c0, cubic_d0,
    input signed [8:0] cubic_a1, cubic_b1, cubic_c1, cubic_d1,
    input signed [8:0] sin_amplitude0, cos_amplitude0, tan_amplitude0,
    input signed [8:0] sin_amplitude1, cos_amplitude1, tan_amplitude1,
    input signed [8:0] exp_scale0, ln_scale0,
    input signed [8:0] exp_scale1, ln_scale1,
    input [9:0] vga_x, vga_y,
    
    output wire [11:0] vga_data,
    
    // --- OUTPUTS FOR OLED ---
    output reg [9:0] intersect_x = 0,
    output reg [9:0] intersect_y = 0,
    output reg intersect_found = 0
);

    wire grid_on = (((vga_x - 320) % 16) == 0) || (((vga_y - 240) % 16) == 0);

    wire [11:0] cubic_vga0, cubic_vga1;
    wire [11:0] sin_vga0, sin_vga1;
    wire [11:0] cos_vga0, cos_vga1;
    wire [11:0] tan_vga0, tan_vga1;
    wire [11:0] exp_vga0, exp_vga1;
    wire [11:0] ln_vga0, ln_vga1;
    
    reg signed [8:0] c0_a, c0_b, c0_c, c0_d;
    reg signed [8:0] c1_a, c1_b, c1_c, c1_d;
    
    reg [2:0] effective_color_slot0, effective_color_slot1;

    always @* begin
        // MUX for Slot 0
        case (selected_graph_type0)
            3'b000: {c0_a, c0_b, c0_c, c0_d} = {9'd0, 9'd0, linear_slope0, linear_intercept0};
            3'b001: {c0_a, c0_b, c0_c, c0_d} = {9'd0, quadratic_a0, quadratic_b0, quadratic_c0};
            3'b010: {c0_a, c0_b, c0_c, c0_d} = {cubic_a0, cubic_b0, cubic_c0, cubic_d0};
            default: {c0_a, c0_b, c0_c, c0_d} = {9'd0, 9'd0, 9'd0, 9'd0}; // Off
        endcase

        // MUX for Slot 1
        case (selected_graph_type1)
            3'b000: {c1_a, c1_b, c1_c, c1_d} = {9'd0, 9'd0, linear_slope1, linear_intercept1};
            3'b001: {c1_a, c1_b, c1_c, c1_d} = {9'd0, quadratic_a1, quadratic_b1, quadratic_c1};
            3'b010: {c1_a, c1_b, c1_c, c1_d} = {cubic_a1, cubic_b1, cubic_c1, cubic_d1};
            default: {c1_a, c1_b, c1_c, c1_d} = {9'd0, 9'd0, 9'd0, 9'd0}; // Off
        endcase
        
        // --- Auto-Color MUX Logic ---
        // Slot 0
        if (auto_color_en) begin
            case (selected_graph_type0)
                3'b000: effective_color_slot0 = 3'd1; // Linear    = Green
                3'b001: effective_color_slot0 = 3'd3; // Quadratic = Cyan
                3'b010: effective_color_slot0 = 3'd4; // Cubic     = Magenta
                3'b011: effective_color_slot0 = 3'd0; // Sin       = Red
                3'b100: effective_color_slot0 = 3'd2; // Cos       = Blue
                3'b101: effective_color_slot0 = 3'd5; // Tan       = Yellow
                3'b110: effective_color_slot0 = 3'd6; // Exp       = White
                3'b111: effective_color_slot0 = 3'd4; // Ln        = Magenta (re-used)
                default: effective_color_slot0 = 3'd7; // 7 = Off
            endcase
        end else begin
            effective_color_slot0 = manual_color_slot0; // Use manual input
        end
        
        // Slot 1
        if (auto_color_en) begin
            case (selected_graph_type1)
                3'b000: effective_color_slot1 = 3'd1; // Linear    = Green
                3'b001: effective_color_slot1 = 3'd3; // Quadratic = Cyan
                3'b010: effective_color_slot1 = 3'd4; // Cubic     = Magenta
                3'b011: effective_color_slot1 = 3'd0; // Sin       = Red
                3'b100: effective_color_slot1 = 3'd2; // Cos       = Blue
                3'b101: effective_color_slot1 = 3'd5; // Tan       = Yellow
                3'b110: effective_color_slot1 = 3'd6; // Exp       = White
                3'b111: effective_color_slot1 = 3'd4; // Ln        = Magenta (re-used)
                default: effective_color_slot1 = 3'd7; // 7 = Off
            endcase
        end else begin
            effective_color_slot1 = manual_color_slot1;
        end
    end

    // --- Instantiate the 12 Graph Engines ---
    
    // Slot 0 Engines
    cubic_graph cg0(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .a(c0_a), .b(c0_b), .c(c0_c), .d(c0_d), .color_slot(effective_color_slot0), .vga_data(cubic_vga0));
    sincos_graph scg0(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(sin_amplitude0), .color_slot(effective_color_slot0), .is_cos(0), .vga_data(sin_vga0));
    sincos_graph scg0_cos(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(cos_amplitude0), .color_slot(effective_color_slot0), .is_cos(1), .vga_data(cos_vga0));
    tan_graph tg0(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(tan_amplitude0), .color_slot(effective_color_slot0), .vga_data(tan_vga0));
    exp_graph eg0(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(exp_scale0), .color_slot(effective_color_slot0), .vga_data(exp_vga0));
    ln_graph lng0(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(ln_scale0), .color_slot(effective_color_slot0), .vga_data(ln_vga0));
    
    // Slot 1 Engines
    cubic_graph cg1(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .a(c1_a), .b(c1_b), .c(c1_c), .d(c1_d), .color_slot(effective_color_slot1), .vga_data(cubic_vga1));
    sincos_graph scg1(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(sin_amplitude1), .color_slot(effective_color_slot1), .is_cos(0), .vga_data(sin_vga1));
    sincos_graph scg1_cos(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(cos_amplitude1), .color_slot(effective_color_slot1), .is_cos(1), .vga_data(cos_vga1));
    tan_graph tg1(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(tan_amplitude1), .color_slot(effective_color_slot1), .vga_data(tan_vga1));
    exp_graph eg1(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(exp_scale1), .color_slot(effective_color_slot1), .vga_data(exp_vga1));
    ln_graph lng1(.clk(clk), .vga_p_tick(vga_p_tick), .vga_x(vga_x), .vga_y(vga_y), .grid_on(grid_on), .scale(ln_scale1), .color_slot(effective_color_slot1), .vga_data(ln_vga1));

    // --- Final Output MUXes ---
    reg [11:0] vga_data_next0, vga_data_next1;
    always @* begin
        case (selected_graph_type0)
            3'b000: vga_data_next0 = cubic_vga0; // Linear uses cubic engine
            3'b001: vga_data_next0 = cubic_vga0; // Quadratic uses cubic engine
            3'b010: vga_data_next0 = cubic_vga0; // Cubic uses cubic engine
            3'b011: vga_data_next0 = sin_vga0;
            3'b100: vga_data_next0 = cos_vga0;
            3'b101: vga_data_next0 = tan_vga0;
            3'b110: vga_data_next0 = exp_vga0;
            3'b111: vga_data_next0 = ln_vga0;
            default: vga_data_next0 = 12'h000;
        endcase
        
        case (selected_graph_type1)
            3'b000: vga_data_next1 = cubic_vga1; // Linear uses cubic engine
            3'b001: vga_data_next1 = cubic_vga1; // Quadratic uses cubic engine
            3'b010: vga_data_next1 = cubic_vga1; // Cubic uses cubic engine
            3'b011: vga_data_next1 = sin_vga1;
            3'b100: vga_data_next1 = cos_vga1;
            3'b101: vga_data_next1 = tan_vga1;
            3'b110: vga_data_next1 = exp_vga1;
            3'b111: vga_data_next1 = ln_vga1;
            default: vga_data_next1 = 12'h000;
        endcase
    end
    
    // --- X/Y Intercept Logic ---
    // "is_on" now INCLUDES the axis pixel (12'hFFF) by removing that check
    wire is_on_0_comb = (vga_data_next0 != 12'h000) && (vga_data_next0 != 12'h222) && (vga_data_next0 != 12'hFFF);
    wire is_on_1_comb = (vga_data_next1 != 12'h000) && (vga_data_next1 != 12'h222) && (vga_data_next1 != 12'hFFF);
    
    // --- 7-Stage Pipeline for Intersection Logic ---
    reg [9:0] vga_x_p1, vga_y_p1; reg auto_color_en_p1;
    reg [9:0] vga_x_p2, vga_y_p2; reg auto_color_en_p2;
    reg [9:0] vga_x_p3, vga_y_p3; reg auto_color_en_p3;
    reg [9:0] vga_x_p4, vga_y_p4; reg auto_color_en_p4;
    reg [9:0] vga_x_p5, vga_y_p5; reg auto_color_en_p5;
    reg [9:0] vga_x_p6, vga_y_p6; reg auto_color_en_p6;
    reg [9:0] vga_x_p7, vga_y_p7; reg auto_color_en_p7;

    // pipeline registers for highlight_intersect_en
    reg highlight_intersect_en_p1, highlight_intersect_en_p2, highlight_intersect_en_p3;
    reg highlight_intersect_en_p4, highlight_intersect_en_p5, highlight_intersect_en_p6;
    reg highlight_intersect_en_p7;

    // --- Final Stage Registers (Stage 7) ---
    reg [11:0] graph_pixel;
    reg is_on_p0, is_on_p1;
    
    // --- Search FSM States ---
    localparam S_IDLE     = 2'd0; // Not searching
    localparam S_SEARCH   = 2'd1; // Actively looking for the next point
    localparam S_SUPPRESS = 2'd2; // Found a point, ignoring the rest of its "blob"

    reg [1:0] search_state = S_IDLE;
    localparam DEAD_ZONE = 10; // Ignore intersection pixels within a 10-pixel radius

    // --- Button Latch ---
    reg btn_latch = 0;

    // --- GATED 7-Stage Pipeline for Coordinates and Switch ---
    always @(posedge clk) begin
        if (reset) begin 
            vga_x_p1 <= 0; vga_y_p1 <= 0; auto_color_en_p1 <= 0; highlight_intersect_en_p1 <= 0;
            vga_x_p2 <= 0; vga_y_p2 <= 0; auto_color_en_p2 <= 0; highlight_intersect_en_p2 <= 0;
            vga_x_p3 <= 0; vga_y_p3 <= 0; auto_color_en_p3 <= 0; highlight_intersect_en_p3 <= 0;
            vga_x_p4 <= 0; vga_y_p4 <= 0; auto_color_en_p4 <= 0; highlight_intersect_en_p4 <= 0;
            vga_x_p5 <= 0; vga_y_p5 <= 0; auto_color_en_p5 <= 0; highlight_intersect_en_p5 <= 0;
            vga_x_p6 <= 0; vga_y_p6 <= 0; auto_color_en_p6 <= 0; highlight_intersect_en_p6 <= 0;
            vga_x_p7 <= 0; vga_y_p7 <= 0; auto_color_en_p7 <= 0; highlight_intersect_en_p7 <= 0;
        end else if (vga_p_tick) begin
            vga_x_p1 <= vga_x; vga_y_p1 <= vga_y; auto_color_en_p1 <= auto_color_en; highlight_intersect_en_p1 <= highlight_intersect_en;
            vga_x_p2 <= vga_x_p1; vga_y_p2 <= vga_y_p1; auto_color_en_p2 <= auto_color_en_p1; highlight_intersect_en_p2 <= highlight_intersect_en_p1;
            vga_x_p3 <= vga_x_p2; vga_y_p3 <= vga_y_p2; auto_color_en_p3 <= auto_color_en_p2; highlight_intersect_en_p3 <= highlight_intersect_en_p2;
            vga_x_p4 <= vga_x_p3; vga_y_p4 <= vga_y_p3; auto_color_en_p4 <= auto_color_en_p3; highlight_intersect_en_p4 <= highlight_intersect_en_p3;
            vga_x_p5 <= vga_x_p4; vga_y_p5 <= vga_y_p4; auto_color_en_p5 <= auto_color_en_p4; highlight_intersect_en_p5 <= highlight_intersect_en_p4;
            vga_x_p6 <= vga_x_p5; vga_y_p6 <= vga_y_p5; auto_color_en_p6 <= auto_color_en_p5; highlight_intersect_en_p6 <= highlight_intersect_en_p5;
            vga_x_p7 <= vga_x_p6; vga_y_p7 <= vga_y_p6; auto_color_en_p7 <= auto_color_en_p6; highlight_intersect_en_p7 <= highlight_intersect_en_p6;
        end
    end
    
    // --- Combinational "intersection" check (uses 7-cycle-delayed data) ---
    wire is_x_axis_p7 = (vga_y_p7 == 240);
    wire is_y_axis_p7 = (vga_x_p7 == 320);
    wire y_intercept = (is_on_p0 || is_on_p1) && is_y_axis_p7;
    wire x_intercept = (is_on_p0 || is_on_p1) && is_x_axis_p7;
    wire graph_intersect = (is_on_p0 && is_on_p1);
    wire is_intersection_dot = (y_intercept || x_intercept || graph_intersect);

    // --- Wires for FSM logic ---
    wire is_after_last_point = (vga_y_p7 > intersect_y) || 
                              (vga_y_p7 == intersect_y && vga_x_p7 > intersect_x);
    
    wire signed [10:0] s_vga_x_p7 = vga_x_p7;
    wire signed [10:0] s_vga_y_p7 = vga_y_p7;
    wire signed [10:0] s_intersect_x = intersect_x;
    wire signed [10:0] s_intersect_y = intersect_y;

    wire x_outside_dz = (s_vga_x_p7 < s_intersect_x - DEAD_ZONE) || 
                      (s_vga_x_p7 > s_intersect_x + DEAD_ZONE);
    wire y_outside_dz = (s_vga_y_p7 < s_intersect_y - DEAD_ZONE) || 
                      (s_vga_y_p7 > s_intersect_y + DEAD_ZONE);
    wire is_far_from_last = x_outside_dz || y_outside_dz;

    // --- GATED register stage + Cycling FSM Latch ---
    always @(posedge clk) begin
        if (reset) begin  
            graph_pixel <= 0;
            is_on_p0 <= 0; 
            is_on_p1 <= 0; 
            search_state <= S_IDLE;
            intersect_x <= 0;
            intersect_y <= 0;
            intersect_found <= 0;
            btn_latch <= 0; // Reset new latch
        end else begin    
        
            // --- Button Latch Logic (runs on main clk) ---
            // This logic is *outside* the vga_p_tick gate.
            // It catches the button press and holds it.
            if (find_intersect_btn) begin
                btn_latch <= 1'b1;
            end
        
            // --- Pipelined logic (runs on p_tick) ---
            if (vga_p_tick) begin
                // --- Register graph signals (Stage 7) ---
                graph_pixel <= vga_data_next0 | vga_data_next1;
                is_on_p0 <= is_on_0_comb;
                is_on_p1 <= is_on_1_comb;
                
                // --- Frame-Synchronous FSM Logic ---
                
                // --- Start-of-Frame (SOF) Logic ---
                if (vga_y_p7 == 0 && vga_x_p7 == 0) begin
                    if (search_state == S_IDLE && btn_latch) begin
                        // A search was armed. Start it now.
                        search_state <= S_SEARCH;
                        btn_latch <= 0; // Clear the button latch
                        intersect_found <= 0; // Clear the "found" flag
                        // We KEEP intersect_x/y to search *after* them
                    end
                    else if (search_state == S_SUPPRESS) begin
                        // We finished finding a point last frame.
                        search_state <= S_IDLE;
                    end
                end
                
                // --- End-of-Frame (EOF) Logic ---
                // (Note: vga_y_p7 == 480 is one line *after* the visible area)
                if (vga_y_p7 == 480) begin
                    if (search_state == S_SEARCH) begin
                        // We searched a whole frame and didn't find a new point
                        // after the last one. Wrap around.
                        intersect_x <= 0;
                        intersect_y <= 0;
                        // Stay in S_SEARCH. On the next frame (at SOF),
                        // the search will continue, finding the *first* point.
                    end
                    else if (search_state == S_SUPPRESS) begin
                        // We found a point. Go to IDLE at the end of the frame.
                        search_state <= S_IDLE;
                    end
                end

                // --- Mid-Frame FSM Actions ---
                case (search_state)
                    S_SEARCH: begin
                        // We are actively looking for the next point
                        if (is_intersection_dot && is_after_last_point && is_far_from_last
                            && (vga_x_p7 < 640) && (vga_y_p7 < 480)) begin
                            
                            // Found the *next* valid point!
                            intersect_x <= vga_x_p7;  // Latch it
                            intersect_y <= vga_y_p7;
                            intersect_found <= 1'b1;  // Tell OLED we got one
                            search_state <= S_SUPPRESS; // Stop searching
                        end
                    end
                    
                    S_SUPPRESS: begin
                        // We found a point. Do nothing until the frame ends
                        // (see EOF logic). This prevents finding the same
                        // point "blob" multiple times.
                    end
                    
                    S_IDLE: begin
                        // Do nothing, wait for SOF and btn_latch
                    end
                endcase // case (search_state)
            
            end // if (vga_p_tick)
        
        end // else (not reset)
    end // always
    
    // --- Highlight Box Logic (Combinational) ---
    // This logic checks if the current (pipelined) pixel is near the latched coordinate
    localparam BOX_RADIUS = 2; // Creates a 5x5 box (2 pixels in each direction)

    wire x_in_range = (s_vga_x_p7 >= s_intersect_x - BOX_RADIUS) && (s_vga_x_p7 <= s_intersect_x + BOX_RADIUS);
    wire y_in_range = (s_vga_y_p7 >= s_intersect_y - BOX_RADIUS) && (s_vga_y_p7 <= s_intersect_y + BOX_RADIUS);

    // Show the box only if a point has been found AND the highlight switch is on
    wire is_highlight_box = intersect_found && highlight_intersect_en_p7 && x_in_range && y_in_range;

    // --- Final Combinational Output MUX ---
    // The new highlight box (bright white) takes precedence over everything.
    assign vga_data = (is_highlight_box) ? 12'hFFF : 
                      (!auto_color_en_p7 && is_intersection_dot) ? 12'hF0F : 
                      graph_pixel;

endmodule

// ============================================
// CUBIC GRAPH (No TDM, 6-Stage, Dynamic Scaling, Grid Units)
// ============================================
module cubic_graph(
    input clk,
    input vga_p_tick,
    input [9:0] vga_x, vga_y,
    input grid_on,
    input signed [8:0] a, b, c, d,
    input [2:0] color_slot,
    output reg [11:0] vga_data
);
    wire signed [10:0] x = vga_x - 320;
    wire signed [10:0] y = 240 - vga_y;
    wire is_axis = (vga_x == 320 || vga_y == 240);
    
    // --- STAGE 1 ---
    reg signed [10:0] x_p1, y_p1;
    reg is_axis_p1, is_grid_p1;
    reg [2:0] color_slot_p1;
    reg signed [8:0] a_p1, b_p1, c_p1, d_p1; 
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p1 <= x;
            y_p1 <= y;
            is_axis_p1 <= is_axis;
            is_grid_p1 <= grid_on;
            color_slot_p1 <= color_slot;
            a_p1 <= a;
            b_p1 <= b;
            c_p1 <= c;
            d_p1 <= d;
        end
    end
    
    // --- STAGE 2 ---
    reg signed [21:0] x_squared_p2; // 11b*11b=22b
    reg signed [10:0] x_p2, y_p2;
    reg is_axis_p2, is_grid_p2;
    reg [2:0] color_slot_p2;
    reg signed [8:0] a_p2, b_p2, c_p2, d_p2;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_squared_p2 <= x_p1 * x_p1;
            x_p2 <= x_p1; 
            y_p2 <= y_p1;
            is_axis_p2 <= is_axis_p1;
            is_grid_p2 <= is_grid_p1;
            color_slot_p2 <= color_slot_p1;
            a_p2 <= a_p1;
            b_p2 <= b_p1;
            c_p2 <= c_p1;
            d_p2 <= d_p1;
        end
    end
    
    // --- STAGE 3 ---
    reg signed [32:0] x_cubed_p3; // 22b*11b=33b
    reg signed [21:0] x_squared_p3;
    reg signed [10:0] x_p3, y_p3;
    reg is_axis_p3, is_grid_p3;
    reg [2:0] color_slot_p3;
    reg signed [8:0] a_p3, b_p3, c_p3, d_p3;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_cubed_p3 <= x_squared_p2 * x_p2;
            x_squared_p3 <= x_squared_p2; 
            x_p3 <= x_p2; 
            y_p3 <= y_p2;
            is_axis_p3 <= is_axis_p2;
            is_grid_p3 <= is_grid_p2;
            color_slot_p3 <= color_slot_p2;
            a_p3 <= a_p2;
            b_p3 <= b_p2;
            c_p3 <= c_p2;
            d_p3 <= d_p2;
        end
    end
    
    // --- STAGE 4 (Calculate FULL terms in parallel) ---
    reg signed [41:0] a_x_cubed_p4;     // 9b+33b=42b
    reg signed [30:0] b_x_squared_p4; // 9b+22b=31b
    reg signed [19:0] c_x_p4;         // 9b+11b=20b
    reg signed [14:0] d_scaled_p4;    // << 4 for 16-pixel grid
    reg signed [10:0] y_p4;
    reg is_axis_p4, is_grid_p4;
    reg [2:0] color_slot_p4;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            a_x_cubed_p4 <= a_p3 * x_cubed_p3;
            b_x_squared_p4 <= b_p3 * x_squared_p3;
            c_x_p4 <= c_p3 * x_p3;
            d_scaled_p4 <= d_p3 << 4; // << 4 for 16-pixel grid (d * 16)
            y_p4 <= y_p3;
            is_axis_p4 <= is_axis_p3;
            is_grid_p4 <= is_grid_p3;
            color_slot_p4 <= color_slot_p3;
        end
    end
    
    // --- STAGE 5 (Dynamic Scaling & Sum) ---
    reg signed [31:0] expected_y_p5; // Widen from 27 to 32 bits
    reg signed [10:0] y_p5;
    reg is_axis_p5, is_grid_p5;
    reg [2:0] color_slot_p5;
    
    // Apply new grid-based scaling (adjusted for 16-pixel grid)
    wire signed [31:0] term_a_scaled = a_x_cubed_p4 >>> 8; // >>> 8 for 16-pixel grid (div by 256)
    wire signed [25:0] term_b_scaled = b_x_squared_p4 >>> 4;  // >>> 4 for 16-pixel grid (div by 16)
    wire signed [19:0] term_c_scaled = c_x_p4;                 // No shift (for x)

    always @(posedge clk) begin
        if (vga_p_tick) begin
            // Sum the scaled terms (corrected sign)
            expected_y_p5 <= term_a_scaled + term_b_scaled + term_c_scaled + d_scaled_p4; // Plus for correct math
            
            y_p5 <= y_p4;
            is_axis_p5 <= is_axis_p4;
            is_grid_p5 <= is_grid_p4;
            color_slot_p5 <= color_slot_p4;
        end
    end
    
    // --- STAGE 6 (Output with Continuity) ---
    // Add these pipeline registers at the top of the module
    reg signed [19:0] expected_y_prev;  // Store previous expected_y
    reg [9:0] vga_x_prev;               // Store previous x coordinate

    // Continuity logic wires
    wire signed [19:0] y_diff = (expected_y_p5 > expected_y_prev) ? 
                                 (expected_y_p5 - expected_y_prev) : 
                                 (expected_y_prev - expected_y_p5);
    
    wire is_continuous = (vga_x == vga_x_prev + 1) && (y_diff < 20) && (y_diff > 0);
    
    wire is_on_curve = (y_p5 >= expected_y_p5 - 1) && (y_p5 <= expected_y_p5 + 1);
    
    wire is_steep_bridge = is_continuous && (y_diff > 2) && 
                           (y_p5 >= expected_y_prev - 1) && 
                           (y_p5 <= expected_y_p5 + 1);
    
    wire should_draw = is_on_curve || is_steep_bridge;

    always @(posedge clk) begin
        if (vga_p_tick) begin
            // Update state for next pixel
            expected_y_prev <= expected_y_p5;
            vga_x_prev <= vga_x;
            
            // Output logic
            if (vga_x >= 640 || vga_y >= 480) 
                vga_data <= 12'h000;
            else if (should_draw) begin  // Check graph FIRST
                case (color_slot_p5)
                    3'd0: vga_data <= 12'hF00; // Red
                    3'd1: vga_data <= 12'h0F0; // Green
                    3'd2: vga_data <= 12'h00F; // Blue
                    3'd3: vga_data <= 12'h0FF; // Cyan
                    3'd4: vga_data <= 12'hF0F; // Magenta
                    3'd5: vga_data <= 12'hFF0; // Yellow
                    3'd6: vga_data <= 12'hFFF; // White
                    3'd7: vga_data <= 12'h000; // Off / Black
                    default: vga_data <= 12'h000;
                endcase
            end else if (is_axis_p5)    // Then axis
                vga_data <= 12'hFFF;
            else if (is_grid_p5)         // Then grid
                vga_data <= 12'h222;
            else 
                vga_data <= 12'h000;
        end
    end
endmodule

module sincos_graph(
    input clk,
    input vga_p_tick,
    input [9:0] vga_x, vga_y,
    input grid_on,
    input signed [8:0] scale,
    input [2:0] color_slot,
    input is_cos,
    output reg [11:0] vga_data
);
    wire signed [10:0] x_pixel = vga_x - 320;
    wire signed [10:0] y_pixel = 240 - vga_y;
    wire is_axis = (vga_x == 320 || vga_y == 240);
    
    (* rom_style = "block" *) reg signed [15:0] sin_rom [0:255];
    initial begin
        $readmemh("sin_table_ver_two.mem", sin_rom);
    end

    wire [7:0] base_address = x_pixel[7:0];
    wire [7:0] address_offset = (is_cos) ? 8'd25 : 8'd0; // Correct!
    wire [7:0] rom_address = base_address + address_offset;
    
    // --- FIX: Add x_valid logic ---
    // Check if the *effective* x_pixel (with cos offset) is in the ROM's range
    wire signed [10:0] effective_x_pixel = x_pixel + address_offset;
    wire x_valid = (effective_x_pixel >= -128) && (effective_x_pixel <= 127);
    
    // Pipeline registers
    reg [9:0] x_p1, x_p2, x_p3, x_p4, x_p5;
    reg x_valid_p1, x_valid_p2, x_valid_p3, x_valid_p4, x_valid_p5; // <-- Add this

    // --- STAGE 1 ---
    reg signed [10:0] y_p1;
    reg is_axis_p1, is_grid_p1;
    reg [7:0] rom_addr_p1;
    reg [2:0] color_slot_p1;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p1 <= vga_x; 
            y_p1 <= y_pixel;
            is_axis_p1 <= is_axis;
            is_grid_p1 <= grid_on;
            rom_addr_p1 <= rom_address;
            color_slot_p1 <= color_slot;
            x_valid_p1 <= x_valid; // <-- Add this
        end
    end

    // --- STAGE 2 ---
    reg signed [15:0] y_math_p2;
    reg signed [10:0] y_p2;
    reg is_axis_p2, is_grid_p2;
    reg [2:0] color_slot_p2;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p2 <= x_p1; 
            y_math_p2 <= sin_rom[rom_addr_p1];
            y_p2 <= y_p1;
            is_axis_p2 <= is_axis_p1;
            is_grid_p2 <= is_grid_p1;
            color_slot_p2 <= color_slot_p1;
            x_valid_p2 <= x_valid_p1; // <-- Add this
        end
    end
    
    // --- STAGE 3 ---
    reg signed [19:0] expected_y_p3;
    reg signed [10:0] y_p3;
    reg is_axis_p3, is_grid_p3;
    reg [2:0] color_slot_p3;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p3 <= x_p2;
            expected_y_p3 <= (y_math_p2 * scale) >>> 4; 
            y_p3 <= y_p2;
            is_axis_p3 <= is_axis_p2;
            is_grid_p3 <= is_grid_p2;
            color_slot_p3 <= color_slot_p2;
            x_valid_p3 <= x_valid_p2; // <-- Add this
        end
    end

    // --- STAGE 4 ---
    reg signed [19:0] expected_y_p4;
    reg signed [10:0] y_p4;
    reg is_axis_p4, is_grid_p4;
    reg [2:0] color_slot_p4;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p4 <= x_p3;
            expected_y_p4 <= expected_y_p3;
            y_p4 <= y_p3;
            is_axis_p4 <= is_axis_p3;
            is_grid_p4 <= is_grid_p3;
            color_slot_p4 <= color_slot_p3;
            x_valid_p4 <= x_valid_p3; // <-- Add this
        end
    end

    // --- STAGE 5 ---
    reg signed [19:0] expected_y_p5;
    reg signed [10:0] y_p5;
    reg is_axis_p5, is_grid_p5;
    reg [2:0] color_slot_p5;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p5 <= x_p4;
            expected_y_p5 <= expected_y_p4;
            y_p5 <= y_p4;
            is_axis_p5 <= is_axis_p4;
            is_grid_p5 <= is_grid_p4;
            color_slot_p5 <= color_slot_p4;
            x_valid_p5 <= x_valid_p4; // <-- Add this
        end
    end

    // --- STAGE 6 (Output with Continuity) ---
    reg signed [19:0] expected_y_prev;
    reg [9:0] vga_x_prev;
    
    wire signed [19:0] y_diff = (expected_y_p5 > expected_y_prev) ? 
                               (expected_y_p5 - expected_y_prev) : 
                               (expected_y_prev - expected_y_p5);
    
    wire is_continuous = (x_p5 == vga_x_prev + 1) && (y_diff < 20) && (y_diff > 0);
    wire is_on_curve = (y_p5 >= expected_y_p5 - 1) && (y_p5 <= expected_y_p5 + 1);
    wire is_steep_bridge = is_continuous && (y_diff > 2) && 
                           (y_p5 >= expected_y_prev - 1) && 
                           (y_p5 <= expected_y_p5 + 1);
                           
    wire should_draw = is_on_curve || is_steep_bridge;

    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_prev <= expected_y_p5;
            vga_x_prev <= x_p5; 
            
            if (x_p5 >= 640 || y_p5 >= 240 || y_p5 < -240) 
                vga_data <= 12'h000;
            // --- APPLY THE FIX HERE ---
            else if (x_valid_p5 && should_draw) begin // <-- Check x_valid_p5
                case (color_slot_p5) 
                    3'd0: vga_data <= 12'hF00; // Red
                    3'd1: vga_data <= 12'h0F0; // Green
                    3'd2: vga_data <= 12'h00F; // Blue
                    3'd3: vga_data <= 12'h0FF; // Cyan
                    3'd4: vga_data <= 12'hF0F; // Magenta
                    3'd5: vga_data <= 12'hFF0; // Yellow
                    3'd6: vga_data <= 12'hFFF; // White
                    3'd7: vga_data <= 12'h000; // Off / Black
                    default: vga_data <= 12'h000;
                endcase
            end else if (is_axis_p5)
                vga_data <= 12'hFFF;
            else if (is_grid_p5)
                vga_data <= 12'h222;
            else 
                vga_data <= 12'h000;
        end
    end
endmodule

module tan_graph(
    input clk,
    input vga_p_tick,
    input [9:0] vga_x, vga_y,
    input grid_on,
    input signed [8:0] scale,
    input [2:0] color_slot,
    output reg [11:0] vga_data
);
    wire signed [10:0] x_pixel = vga_x - 320;
    wire signed [10:0] y_pixel = 240 - vga_y;
    wire is_axis = (vga_x == 320 || vga_y == 240);
    
    (* rom_style = "block" *) reg signed [15:0] tan_rom [0:255];
    initial begin
        $readmemh("tan_table_ver_two.mem", tan_rom);
    end

    wire [7:0] rom_address = x_pixel[7:0];
    
    // --- FIX: Add x_valid logic ---
    wire x_valid = (x_pixel >= -128) && (x_pixel <= 127);
    
    // Pipeline registers
    reg [9:0] x_p1, x_p2, x_p3, x_p4, x_p5;
    reg x_valid_p1, x_valid_p2, x_valid_p3, x_valid_p4, x_valid_p5; // <-- Add this

    // --- STAGE 1 ---
    reg signed [10:0] y_p1;
    reg is_axis_p1, is_grid_p1;
    reg [7:0] rom_addr_p1;
    reg [2:0] color_slot_p1;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p1 <= vga_x; 
            y_p1 <= y_pixel;
            is_axis_p1 <= is_axis;
            is_grid_p1 <= grid_on;
            rom_addr_p1 <= rom_address;
            color_slot_p1 <= color_slot;
            x_valid_p1 <= x_valid; // <-- Add this
        end
    end

    // --- STAGE 2 ---
    reg signed [15:0] y_math_p2;
    reg signed [10:0] y_p2;
    reg is_axis_p2, is_grid_p2;
    reg [2:0] color_slot_p2;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p2 <= x_p1; 
            y_math_p2 <= tan_rom[rom_addr_p1];
            y_p2 <= y_p1;
            is_axis_p2 <= is_axis_p1;
            is_grid_p2 <= is_grid_p1;
            color_slot_p2 <= color_slot_p1;
            x_valid_p2 <= x_valid_p1; // <-- Add this
        end
    end
    
    // --- STAGE 3 ---
    reg signed [19:0] expected_y_p3;
    reg signed [10:0] y_p3;
    reg is_axis_p3, is_grid_p3;
    reg [2:0] color_slot_p3;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p3 <= x_p2;
            expected_y_p3 <= (y_math_p2 * scale) >>> 4; 
            y_p3 <= y_p2;
            is_axis_p3 <= is_axis_p2;
            is_grid_p3 <= is_grid_p2;
            color_slot_p3 <= color_slot_p2;
            x_valid_p3 <= x_valid_p2; // <-- Add this
        end
    end

    // --- STAGE 4 ---
    reg signed [19:0] expected_y_p4;
    reg signed [10:0] y_p4;
    reg is_axis_p4, is_grid_p4;
    reg [2:0] color_slot_p4;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p4 <= x_p3;
            expected_y_p4 <= expected_y_p3;
            y_p4 <= y_p3;
            is_axis_p4 <= is_axis_p3;
            is_grid_p4 <= is_grid_p3;
            color_slot_p4 <= color_slot_p3;
            x_valid_p4 <= x_valid_p3; // <-- Add this
        end
    end

    // --- STAGE 5 ---
    reg signed [19:0] expected_y_p5;
    reg signed [10:0] y_p5;
    reg is_axis_p5, is_grid_p5;
    reg [2:0] color_slot_p5;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            x_p5 <= x_p4;
            expected_y_p5 <= expected_y_p4;
            y_p5 <= y_p4;
            is_axis_p5 <= is_axis_p4;
            is_grid_p5 <= is_grid_p4;
            color_slot_p5 <= color_slot_p4;
            x_valid_p5 <= x_valid_p4; // <-- Add this
        end
    end

    // --- STAGE 6 (Output) ---
    reg signed [19:0] expected_y_prev;
    reg [9:0] vga_x_prev;
    reg was_valid_prev;

    wire signed [19:0] y_diff = (expected_y_p5 > expected_y_prev) ? 
                               (expected_y_p5 - expected_y_prev) : 
                               (expected_y_prev - expected_y_p5);
    
    wire is_asymptote_jump = (y_diff > 100);
    
    wire is_continuous = (x_p5 == vga_x_prev + 1) && 
                         !is_asymptote_jump && 
                         was_valid_prev;
    
    wire is_on_curve = (y_p5 >= expected_y_p5 - 1) && 
                       (y_p5 <= expected_y_p5 + 1);
    
    wire is_steep_bridge = is_continuous && 
                           (y_diff > 2) && (y_diff < 50) &&
                           (y_p5 >= expected_y_prev - 1) && 
                           (y_p5 <= expected_y_p5 + 1);
    
    wire should_draw = (is_on_curve || is_steep_bridge) && !is_asymptote_jump;
    
    // --- APPLY THE FIX HERE ---
    // Add x_valid_p5 to the is_valid_point check
    wire is_valid_point = (expected_y_p5 > -240) && (expected_y_p5 < 240) && x_valid_p5;

    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_prev <= expected_y_p5;
            vga_x_prev <= x_p5; 
            was_valid_prev <= is_valid_point;
            
            if (x_p5 >= 640 || y_p5 >= 240 || y_p5 < -240) 
                vga_data <= 12'h000;
            // This check now automatically includes the x_valid check
            else if (should_draw && is_valid_point) begin 
                case (color_slot_p5)
                    3'd0: vga_data <= 12'hF00;
                    3'd1: vga_data <= 12'h0F0;
                    3'd2: vga_data <= 12'h00F;
                    3'd3: vga_data <= 12'h0FF;
                    3'd4: vga_data <= 12'hF0F;
                    3'd5: vga_data <= 12'hFF0;
                    3'd6: vga_data <= 12'hFFF;
                    3'd7: vga_data <= 12'h000;
                    default: vga_data <= 12'h000;
                endcase
            end else if (is_axis_p5)
                vga_data <= 12'hFFF;
            else if (is_grid_p5)
                vga_data <= 12'h222;
            else 
                vga_data <= 12'h000;
        end
    end
endmodule

module exp_graph(
    input clk,
    input vga_p_tick,
    input [9:0] vga_x, vga_y,
    input grid_on,
    input signed [8:0] scale,
    input [2:0] color_slot,
    output reg [11:0] vga_data
);
    wire signed [10:0] x_pixel = vga_x - 320;
    wire signed [10:0] y_pixel = 240 - vga_y;
    wire is_axis = (vga_x == 320 || vga_y == 240);
    
    (* rom_style = "block" *) reg signed [15:0] exp_rom [0:255];
    initial begin
        $readmemh("exp_table.mem", exp_rom);
    end

    wire signed [10:0] x_offset = x_pixel + 128;
    wire x_valid = (x_offset >= 0) && (x_offset < 256);
    wire [7:0] rom_address = x_offset[7:0];
    
    // --- STAGE 1 ---
    reg signed [10:0] y_p1;
    reg is_axis_p1, is_grid_p1, x_valid_p1;
    reg [7:0] rom_addr_p1;
    reg [2:0] color_slot_p1;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            y_p1 <= y_pixel;
            is_axis_p1 <= is_axis;
            is_grid_p1 <= grid_on;
            rom_addr_p1 <= rom_address;
            x_valid_p1 <= x_valid;
            color_slot_p1 <= color_slot;
        end
    end

    // --- STAGE 2 ---
    reg signed [15:0] y_math_p2;
    reg signed [10:0] y_p2;
    reg is_axis_p2, is_grid_p2, x_valid_p2;
    reg [2:0] color_slot_p2;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            y_math_p2 <= exp_rom[rom_addr_p1];
            y_p2 <= y_p1;
            is_axis_p2 <= is_axis_p1;
            is_grid_p2 <= is_grid_p1;
            x_valid_p2 <= x_valid_p1;
            color_slot_p2 <= color_slot_p1;
        end
    end
    
    // --- STAGE 3 ---
    reg signed [19:0] expected_y_p3;
    reg signed [10:0] y_p3;
    reg is_axis_p3, is_grid_p3, x_valid_p3;
    reg [2:0] color_slot_p3;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p3 <= (y_math_p2 * scale) >>> 4; // >>> 4 for 16-pixel grid
            y_p3 <= y_p2;
            is_axis_p3 <= is_axis_p2;
            is_grid_p3 <= is_grid_p2;
            x_valid_p3 <= x_valid_p2;
            color_slot_p3 <= color_slot_p2;
        end
    end

    // --- STAGE 4 ---
    reg signed [19:0] expected_y_p4;
    reg signed [10:0] y_p4;
    reg is_axis_p4, is_grid_p4, x_valid_p4;
    reg [2:0] color_slot_p4;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p4 <= expected_y_p3;
            y_p4 <= y_p3;
            is_axis_p4 <= is_axis_p3;
            is_grid_p4 <= is_grid_p3;
            x_valid_p4 <= x_valid_p3;
            color_slot_p4 <= color_slot_p3;
        end
    end

    // --- STAGE 5 ---
    reg signed [19:0] expected_y_p5;
    reg signed [10:0] y_p5;
    reg is_axis_p5, is_grid_p5, x_valid_p5;
    reg [2:0] color_slot_p5;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p5 <= expected_y_p4;
            y_p5 <= y_p4;
            is_axis_p5 <= is_axis_p4;
            is_grid_p5 <= is_grid_p4;
            x_valid_p5 <= x_valid_p4;
            color_slot_p5 <= color_slot_p4;
        end
    end

    // --- STAGE 6 (Output with Continuity) ---
    // Add these pipeline registers at the top of the module
    reg signed [19:0] expected_y_prev;  // Store previous expected_y
    reg [9:0] vga_x_prev;               // Store previous x coordinate

    // Continuity logic wires
    wire signed [19:0] y_diff = (expected_y_p5 > expected_y_prev) ? 
                                 (expected_y_p5 - expected_y_prev) : 
                                 (expected_y_prev - expected_y_p5);
    
    wire is_continuous = (vga_x == vga_x_prev + 1) && (y_diff < 20) && (y_diff > 0);
    
    wire is_on_curve = (y_p5 >= expected_y_p5 - 1) && (y_p5 <= expected_y_p5 + 1);
    
    wire is_steep_bridge = is_continuous && (y_diff > 2) && 
                           (y_p5 >= expected_y_prev - 1) && 
                           (y_p5 <= expected_y_p5 + 1);
    
    wire should_draw = is_on_curve || is_steep_bridge;

    always @(posedge clk) begin
        if (vga_p_tick) begin
            // Update state for next pixel
            expected_y_prev <= expected_y_p5;
            vga_x_prev <= vga_x;
            
            // Output logic
            if (vga_x >= 640 || vga_y >= 480) 
                vga_data <= 12'h000;
            else if (x_valid_p5 && should_draw) begin  // Check graph FIRST
                case (color_slot_p5)
                    3'd0: vga_data <= 12'hF00; // Red
                    3'd1: vga_data <= 12'h0F0; // Green
                    3'd2: vga_data <= 12'h00F; // Blue
                    3'd3: vga_data <= 12'h0FF; // Cyan
                    3'd4: vga_data <= 12'hF0F; // Magenta
                    3'd5: vga_data <= 12'hFF0; // Yellow
                    3'd6: vga_data <= 12'hFFF; // White
                    3'd7: vga_data <= 12'h000; // Off / Black
                    default: vga_data <= 12'h000;
                endcase
            end else if (is_axis_p5)    // Then axis
                vga_data <= 12'hFFF;
            else if (is_grid_p5)         // Then grid
                vga_data <= 12'h222;
            else 
                vga_data <= 12'h000;
        end
    end
endmodule

module ln_graph(
    input clk,
    input vga_p_tick,
    input [9:0] vga_x, vga_y,
    input grid_on,
    input signed [8:0] scale,
    input [2:0] color_slot,
    output reg [11:0] vga_data
);
    wire signed [10:0] x_pixel = vga_x - 320;
    wire signed [10:0] y_pixel = 240 - vga_y;
    wire is_axis = (vga_x == 320 || vga_y == 240);
    
    (* rom_style = "block" *) reg signed [15:0] ln_rom [0:255];
    initial begin
        $readmemh("ln_table.mem", ln_rom);
    end

    wire x_valid = (x_pixel >= 1) && (x_pixel <= 256);
    wire [7:0] rom_address = (x_pixel - 1);
    
    // --- STAGE 1 ---
    reg signed [10:0] y_p1;
    reg is_axis_p1, is_grid_p1, x_valid_p1;
    reg [7:0] rom_addr_p1;
    reg [2:0] color_slot_p1;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            y_p1 <= y_pixel;
            is_axis_p1 <= is_axis;
            is_grid_p1 <= grid_on;
            x_valid_p1 <= x_valid;
            rom_addr_p1 <= rom_address;
            color_slot_p1 <= color_slot;
        end
    end

    // --- STAGE 2 ---
    reg signed [15:0] y_math_p2;
    reg signed [10:0] y_p2;
    reg is_axis_p2, is_grid_p2, x_valid_p2;
    reg [2:0] color_slot_p2;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            y_math_p2 <= ln_rom[rom_addr_p1];
            y_p2 <= y_p1;
            is_axis_p2 <= is_axis_p1;
            is_grid_p2 <= is_grid_p1;
            x_valid_p2 <= x_valid_p1;
            color_slot_p2 <= color_slot_p1;
        end
    end
    
    // --- STAGE 3 ---
    reg signed [19:0] expected_y_p3;
    reg signed [10:0] y_p3;
    reg is_axis_p3, is_grid_p3, x_valid_p3;
    reg [2:0] color_slot_p3;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p3 <= (y_math_p2 * scale) >>> 4; // >>> 4 for 16-pixel grid
            y_p3 <= y_p2;
            is_axis_p3 <= is_axis_p2;
            is_grid_p3 <= is_grid_p2;
            x_valid_p3 <= x_valid_p2;
            color_slot_p3 <= color_slot_p2;
        end
    end

    // --- STAGE 4 ---
    reg signed [19:0] expected_y_p4;
    reg signed [10:0] y_p4;
    reg is_axis_p4, is_grid_p4, x_valid_p4;
    reg [2:0] color_slot_p4;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p4 <= expected_y_p3;
            y_p4 <= y_p3;
            is_axis_p4 <= is_axis_p3;
            is_grid_p4 <= is_grid_p3;
            x_valid_p4 <= x_valid_p3;
            color_slot_p4 <= color_slot_p3;
        end
    end

    // --- STAGE 5 ---
    reg signed [19:0] expected_y_p5;
    reg signed [10:0] y_p5;
    reg is_axis_p5, is_grid_p5, x_valid_p5;
    reg [2:0] color_slot_p5;
    always @(posedge clk) begin
        if (vga_p_tick) begin
            expected_y_p5 <= expected_y_p4;
            y_p5 <= y_p4;
            is_axis_p5 <= is_axis_p4;
            is_grid_p5 <= is_grid_p4;
            x_valid_p5 <= x_valid_p4;
            color_slot_p5 <= color_slot_p4;
        end
    end

    // --- STAGE 6 (Output with Continuity) ---
    // Add these pipeline registers at the top of the module
    reg signed [19:0] expected_y_prev;  // Store previous expected_y
    reg [9:0] vga_x_prev;               // Store previous x coordinate

    // Continuity logic wires
    wire signed [19:0] y_diff = (expected_y_p5 > expected_y_prev) ? 
                                 (expected_y_p5 - expected_y_prev) : 
                                 (expected_y_prev - expected_y_p5);
    
    wire is_continuous = (vga_x == vga_x_prev + 1) && (y_diff < 20) && (y_diff > 0);
    
    wire is_on_curve = (y_p5 >= expected_y_p5 - 1) && (y_p5 <= expected_y_p5 + 1);
    
    wire is_steep_bridge = is_continuous && (y_diff > 2) && 
                           (y_p5 >= expected_y_prev - 1) && 
                           (y_p5 <= expected_y_p5 + 1);
    
    wire should_draw = is_on_curve || is_steep_bridge;

    always @(posedge clk) begin
        if (vga_p_tick) begin
            // Update state for next pixel
            expected_y_prev <= expected_y_p5;
            vga_x_prev <= vga_x;
            
            // Output logic
            if (vga_x >= 640 || vga_y >= 480) 
                vga_data <= 12'h000;
            else if (x_valid_p5 && should_draw) begin  // Check graph FIRST
                case (color_slot_p5)
                    3'd0: vga_data <= 12'hF00; // Red
                    3'd1: vga_data <= 12'h0F0; // Green
                    3'd2: vga_data <= 12'h00F; // Blue
                    3'd3: vga_data <= 12'h0FF; // Cyan
                    3'd4: vga_data <= 12'hF0F; // Magenta
                    3'd5: vga_data <= 12'hFF0; // Yellow
                    3'd6: vga_data <= 12'hFFF; // White
                    3'd7: vga_data <= 12'h000; // Off / Black
                    default: vga_data <= 12'h000;
                endcase
            end else if (is_axis_p5)    // Then axis
                vga_data <= 12'hFFF;
            else if (is_grid_p5)         // Then grid
                vga_data <= 12'h222;
            else 
                vga_data <= 12'h000;
        end
    end
endmodule