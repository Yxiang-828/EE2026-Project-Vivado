`timescale 1ns / 1ps

module equation_parser(
    input clk,
    input rst,
    
    // Input from shared buffer
    input [511:0] shared_equation_buffer,
    input [6:0] shared_equation_length,
    input shared_equation_complete,
    
    // Output parsed coefficients for graph rendering
    output reg [2:0] parsed_graph_type,
    output reg signed [8:0] parsed_coeff_a,
    output reg signed [8:0] parsed_coeff_b,
    output reg signed [8:0] parsed_coeff_c,
    output reg signed [8:0] parsed_coeff_d,
    output reg parse_valid,
    output reg [1:0] parse_error
);

    // Graph type encodings
    localparam GRAPH_LINEAR = 3'b000;
    localparam GRAPH_QUADRATIC = 3'b001;
    localparam GRAPH_CUBIC = 3'b010;
    localparam GRAPH_SIN = 3'b011;
    localparam GRAPH_COS = 3'b100;
    localparam GRAPH_TAN = 3'b101;
    localparam GRAPH_EXP = 3'b110;
    localparam GRAPH_LN = 3'b111;

    // Error codes
    localparam ERR_NONE = 2'b00;
    localparam ERR_SYNTAX = 2'b01;
    localparam ERR_UNSUPPORTED = 2'b10;

    // Parser states
    localparam STATE_IDLE = 4'd0;
    localparam STATE_CHECK_FUNCTION = 4'd1;
    localparam STATE_PARSE_SIGN = 4'd2;
    localparam STATE_PARSE_COEFF = 4'd3;
    localparam STATE_PARSE_X = 4'd4;
    localparam STATE_CHECK_POWER = 4'd5;
    localparam STATE_PARSE_POW_CHAR = 4'd6;
    localparam STATE_PARSE_POW_DIGIT = 4'd7;
    localparam STATE_STORE_TERM = 4'd8;
    localparam STATE_COMPLETE = 4'd9;
    
    reg [3:0] state;
    reg [6:0] parse_idx;
    
    // LOCAL COPY of buffer (captured at parse start)
    reg [511:0] local_equation_buffer;
    reg [6:0] local_equation_length;
    
    // Polynomial coefficients (accumulate by power)
    reg signed [15:0] coeff [0:3];
    
    // Current term being parsed
    reg signed [15:0] current_coeff;
    reg signed [1:0] current_sign;
    reg [2:0] current_power;
    reg has_coefficient;
    reg has_x;
    
    // Current character (now a wire for instant updates)
    wire [7:0] current_char;
    assign current_char = local_equation_buffer[parse_idx*8 +: 8];
    
    // Detected function type
    reg [2:0] detected_function;
    reg is_function;
    
    // Helper function
    function is_digit;
        input [7:0] char;
        begin
            is_digit = (char >= 8'h30 && char <= 8'h39);
        end
    endfunction
    
    // Detect rising edge of shared_equation_complete
    reg prev_complete;
    wire complete_rising = shared_equation_complete && !prev_complete;
    
    // Main parser FSM
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            parse_idx <= 0;
            parsed_graph_type <= GRAPH_LINEAR;
            parsed_coeff_a <= 0;
            parsed_coeff_b <= 0;
            parsed_coeff_c <= 0;
            parsed_coeff_d <= 0;
            parse_valid <= 0;
            parse_error <= ERR_NONE;
            coeff[0] <= 0; 
            coeff[1] <= 0; 
            coeff[2] <= 0; 
            coeff[3] <= 0;
            current_coeff <= 0;
            current_sign <= 1;
            current_power <= 0;
            has_coefficient <= 0;
            has_x <= 0;
            detected_function <= GRAPH_LINEAR;
            is_function <= 0;
            local_equation_buffer <= 0;
            local_equation_length <= 0;
            prev_complete <= 0;
        end else begin
            prev_complete <= shared_equation_complete;
            
            // Reset and start parsing on rising edge of complete
            if (complete_rising) begin
                coeff[0] <= 0; 
                coeff[1] <= 0; 
                coeff[2] <= 0; 
                coeff[3] <= 0;
                current_coeff <= 0;
                current_sign <= 1;
                current_power <= 0;
                has_coefficient <= 0;
                has_x <= 0;
                parse_error <= ERR_NONE;
                is_function <= 0;
                local_equation_buffer <= shared_equation_buffer;
                local_equation_length <= shared_equation_length;
                state <= STATE_CHECK_FUNCTION;
                parse_idx <= 0;
            end
            
            parse_valid <= 0;
            
            case (state)
                STATE_IDLE: begin
                    // wait for complete_rising
                end
                
                STATE_CHECK_FUNCTION: begin
                    // Use LOCAL buffer instead of shared
                    if (parse_idx < local_equation_length) begin
                        
                        // Check for "sin"
                        if (current_char == 8'h73 && parse_idx + 2 < local_equation_length) begin
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h69 && 
                                local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h6E) begin
                                detected_function <= GRAPH_SIN;
                                is_function <= 1;
                                parse_idx <= parse_idx + 3;
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end else begin
                                state <= STATE_PARSE_SIGN;
                            end
                        end 
                        // Check for "cos"
                        else if (current_char == 8'h63 && parse_idx + 2 < local_equation_length) begin
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h6F && 
                                local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h73) begin
                                detected_function <= GRAPH_COS;
                                is_function <= 1;
                                parse_idx <= parse_idx + 3;
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end else begin
                                state <= STATE_PARSE_SIGN;
                            end
                        end 
                        // Check for "tan"
                        else if (current_char == 8'h74 && parse_idx + 2 < local_equation_length) begin
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h61 && 
                                local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h6E) begin
                                detected_function <= GRAPH_TAN;
                                is_function <= 1;
                                parse_idx <= parse_idx + 3;
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end else begin
                                state <= STATE_PARSE_SIGN;
                            end
                        end 
                        // Check for "ln"
                        else if (current_char == 8'h6C && parse_idx + 1 < local_equation_length) begin
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h6E) begin
                                detected_function <= GRAPH_LN;
                                is_function <= 1;
                                parse_idx <= parse_idx + 2;
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end else begin
                                state <= STATE_PARSE_SIGN;
                            end
                        end 
                        // Check for "exp" (3 letters) or 'e' shortcut
                        else if (current_char == 8'h65 && parse_idx + 2 < local_equation_length) begin // 'e'
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h78 &&  // 'x'
                                local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h70) begin // 'p'
                                // This is the full word "exp"
                                detected_function <= GRAPH_EXP;
                                is_function <= 1;
                                parse_idx <= parse_idx + 3;
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end else begin
                                // This is 'e' followed by something else (e.g., "e+1" or "ex")
                                // Treat the single 'e' as the EXP function
                                detected_function <= GRAPH_EXP;
                                is_function <= 1;
                                parse_idx <= parse_idx + 1; // Consume only the 'e'
                                state <= STATE_PARSE_SIGN;
                                current_coeff <= 1;
                                has_coefficient <= 1;
                            end
                        end
                        // Check for 'e' as the *last* character
                        else if (current_char == 8'h65) begin
                            detected_function <= GRAPH_EXP;
                            is_function <= 1;
                            parse_idx <= parse_idx + 1;
                            state <= STATE_PARSE_SIGN;
                            current_coeff <= 1;
                            has_coefficient <= 1;
                        end
                        else if (is_digit(current_char)) begin
                            state <= STATE_PARSE_COEFF;
                        end
                        else begin
                            state <= STATE_PARSE_SIGN;
                        end
                    end else begin
                        state <= STATE_COMPLETE;
                    end
                end
                
                STATE_PARSE_SIGN: begin
                    if (parse_idx < local_equation_length) begin
                        
                        if (current_char == 8'h2D) begin
                            current_sign <= -1;
                            parse_idx <= parse_idx + 1;
                            state <= STATE_PARSE_COEFF;
                        end else if (current_char == 8'h2B) begin
                            current_sign <= 1;
                            parse_idx <= parse_idx + 1;
                            state <= STATE_PARSE_COEFF;
                        end else if (is_digit(current_char)) begin
                            current_sign <= 1;
                            state <= STATE_PARSE_COEFF;
                        end else if (current_char == 8'h78) begin
                            current_sign <= 1;
                            current_coeff <= 1;
                            has_coefficient <= 1;
                            state <= STATE_PARSE_X;
                        end else if (current_char == 8'h28 || current_char == 8'h29 || current_char == 8'h20) begin
                            parse_idx <= parse_idx + 1;
                            state <= STATE_PARSE_SIGN;
                        end else begin
                            parse_error <= ERR_SYNTAX;
                            state <= STATE_COMPLETE;
                        end
                    end else begin
                        state <= STATE_COMPLETE;
                    end
                end
                
                STATE_PARSE_COEFF: begin
                    if (parse_idx < local_equation_length) begin
                        
                        if (is_digit(current_char)) begin
                            current_coeff <= current_coeff * 10 + (current_char - 8'h30);
                            has_coefficient <= 1;
                            parse_idx <= parse_idx + 1;
                        end else if (current_char == 8'h78) begin
                            if (!has_coefficient) current_coeff <= 1;
                            state <= STATE_PARSE_X;
                        end else if (current_char == 8'h2B || current_char == 8'h2D) begin
                            current_power <= 0;
                            has_x <= 0;
                            state <= STATE_STORE_TERM;
                        end else if (current_char == 8'h28 || current_char == 8'h29 || current_char == 8'h20) begin
                            parse_idx <= parse_idx + 1;
                        end else if (current_char == 8'h73 || current_char == 8'h63 || 
                                   current_char == 8'h74 || current_char == 8'h6C) begin
                            if (current_char == 8'h73 && parse_idx + 2 < local_equation_length) begin
                                if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h69 && 
                                    local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h6E) begin
                                    detected_function <= GRAPH_SIN;
                                    is_function <= 1;
                                    parse_idx <= parse_idx + 3;
                                    state <= STATE_COMPLETE;
                                end
                            end else if (current_char == 8'h63 && parse_idx + 2 < local_equation_length) begin
                                if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h6F && 
                                    local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h73) begin
                                    detected_function <= GRAPH_COS;
                                    is_function <= 1;
                                    parse_idx <= parse_idx + 3;
                                    state <= STATE_COMPLETE;
                                end
                            end else if (current_char == 8'h74 && parse_idx + 2 < local_equation_length) begin
                                if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h61 && 
                                    local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h6E) begin
                                    detected_function <= GRAPH_TAN;
                                    is_function <= 1;
                                    parse_idx <= parse_idx + 3;
                                    state <= STATE_COMPLETE;
                                end
                            end else if (current_char == 8'h6C && parse_idx + 1 < local_equation_length) begin
                                if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h6E) begin
                                    detected_function <= GRAPH_LN;
                                    is_function <= 1;
                                    parse_idx <= parse_idx + 2;
                                    state <= STATE_COMPLETE;
                                end
                            end
                        end 
                        // Check for "exp" (3 letters) or 'e' shortcut
                        else if (current_char == 8'h65 && parse_idx + 2 < local_equation_length) begin // 'e'
                            if (local_equation_buffer[(parse_idx+1)*8 +: 8] == 8'h78 &&  // 'x'
                                local_equation_buffer[(parse_idx+2)*8 +: 8] == 8'h70) begin // 'p'
                                // This is the full word "exp" (e.g., "6exp")
                                detected_function <= GRAPH_EXP;
                                is_function <= 1;
                                parse_idx <= parse_idx + 3;
                                state <= STATE_COMPLETE;
                            end else begin
                                // This is 'e' followed by something else (e.g., "6e+1" or "6ex")
                                // Treat the single 'e' as the EXP function
                                detected_function <= GRAPH_EXP;
                                is_function <= 1;
                                parse_idx <= parse_idx + 1; // Consume only the 'e'
                                state <= STATE_COMPLETE;
                            end
                        end
                        // Check for 'e' as the *last* character (e.g., "6e")
                        else if (current_char == 8'h65) begin
                            detected_function <= GRAPH_EXP;
                            is_function <= 1;
                            parse_idx <= parse_idx + 1;
                            state <= STATE_COMPLETE;
                        end
                        else begin
                            parse_error <= ERR_SYNTAX;
                            state <= STATE_COMPLETE;
                        end
                    end else begin
                        if (has_coefficient) begin
                            current_power <= 0;
                            has_x <= 0;
                            state <= STATE_STORE_TERM;
                        end else begin
                            state <= STATE_COMPLETE;
                        end
                    end
                end
                
                STATE_PARSE_X: begin
                    has_x <= 1;
                    parse_idx <= parse_idx + 1;
                    state <= STATE_CHECK_POWER;
                end
                
                STATE_CHECK_POWER: begin
                    if (parse_idx < local_equation_length) begin
                        
                        if (current_char == 8'h5E) begin
                            state <= STATE_PARSE_POW_CHAR;
                        end else begin
                            current_power <= 1;
                            state <= STATE_STORE_TERM;
                        end
                    end else begin
                        current_power <= 1;
                        state <= STATE_STORE_TERM;
                    end
                end
                
                STATE_PARSE_POW_CHAR: begin
                    parse_idx <= parse_idx + 1;
                    current_power <= 0;
                    state <= STATE_PARSE_POW_DIGIT;
                end
                
                STATE_PARSE_POW_DIGIT: begin
                    if (parse_idx < local_equation_length) begin
                        
                        if (is_digit(current_char)) begin
                            current_power <= current_power * 10 + (current_char - 8'h30);
                            parse_idx <= parse_idx + 1;
                        end else begin
                            state <= STATE_STORE_TERM;
                        end
                    end else begin
                        state <= STATE_STORE_TERM;
                    end
                end
                
                STATE_STORE_TERM: begin
                    if (current_power <= 3) begin
                        coeff[current_power] <= coeff[current_power] + (current_coeff * current_sign);
                    end
                    
                    current_coeff <= 0;
                    current_sign <= 1;
                    current_power <= 0;
                    has_coefficient <= 0;
                    has_x <= 0;
                    
                    if (parse_idx < local_equation_length) begin
                        state <= STATE_PARSE_SIGN;
                    end else begin
                        state <= STATE_COMPLETE;
                    end
                end
                
                STATE_COMPLETE: begin
                    if (parse_error == ERR_NONE) begin
                        if (is_function) begin
                            parsed_graph_type <= detected_function;
                            parsed_coeff_a <= current_coeff[8:0];
                            parsed_coeff_b <= 0;
                            parsed_coeff_c <= 0;
                            parsed_coeff_d <= 0;
                        end else begin
                            if (coeff[3] != 0) begin
                                parsed_graph_type <= GRAPH_CUBIC;
                                parsed_coeff_a <= coeff[3][8:0];
                                parsed_coeff_b <= coeff[2][8:0];
                                parsed_coeff_c <= coeff[1][8:0];
                                parsed_coeff_d <= coeff[0][8:0];
                            end else if (coeff[2] != 0) begin
                                parsed_graph_type <= GRAPH_QUADRATIC;
                                parsed_coeff_a <= coeff[2][8:0];
                                parsed_coeff_b <= coeff[1][8:0];
                                parsed_coeff_c <= coeff[0][8:0];
                                parsed_coeff_d <= 0;
                            end else if (coeff[1] != 0) begin
                                parsed_graph_type <= GRAPH_LINEAR;
                                parsed_coeff_a <= coeff[1][8:0];
                                parsed_coeff_b <= coeff[0][8:0];
                                parsed_coeff_c <= 0;
                                parsed_coeff_d <= 0;
                            end else begin
                                parsed_graph_type <= GRAPH_LINEAR;
                                parsed_coeff_a <= 0;
                                parsed_coeff_b <= coeff[0][8:0];
                                parsed_coeff_c <= 0;
                                parsed_coeff_d <= 0;
                            end
                        end
                        
                        parse_valid <= 1;
                    end
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule