`timescale 1ns / 1ps

module shared_equation_buffer(
    input clk,
    input rst,
    
    // Multi-char inputs from key_to_ascii_converter
    input [7:0] ascii_char,
    input ascii_valid,
    input is_multichar,
    input [2:0] char_count,
    input [23:0] multichar_data,
    
    input grapher_submode,
    
    output reg [511:0] shared_equation_buffer,
    output reg [6:0] shared_equation_length,
    output reg shared_equation_complete
);

    // STATE MACHINE for multi-char writes
    localparam STATE_IDLE = 3'd0;
    localparam STATE_WRITE_1 = 3'd1;
    localparam STATE_WRITE_2 = 3'd2;
    localparam STATE_WRITE_3 = 3'd3;
    localparam STATE_DELETE_CHECK = 3'd4;

    reg [2:0] write_state;
    reg [2:0] chars_to_write;
    reg [2:0] chars_written;
    reg [23:0] char_data_buffer;
    reg [6:0] write_start_index;
    reg clear_next_cycle;

    // INPUT PIPELINE REGISTERS (for timing)
    reg [7:0] ascii_char_reg;
    reg ascii_valid_reg;
    reg is_multichar_reg;
    reg [2:0] char_count_reg;
    reg [23:0] multichar_data_reg;
    reg grapher_submode_reg;

    // Pipeline inputs to break long combinational paths
    always @(posedge clk) begin
        if (rst) begin
            ascii_char_reg <= 0;
            ascii_valid_reg <= 0;
            is_multichar_reg <= 0;
            char_count_reg <= 0;
            multichar_data_reg <= 0;
            grapher_submode_reg <= 0;
        end else begin
            ascii_char_reg <= ascii_char;
            ascii_valid_reg <= ascii_valid;
            is_multichar_reg <= is_multichar;
            char_count_reg <= char_count;
            multichar_data_reg <= multichar_data;
            grapher_submode_reg <= grapher_submode;
        end
    end

    // Character classification (registered inputs)
    wire is_digit_reg = (ascii_char_reg >= 8'h30 && ascii_char_reg <= 8'h39);
    wire is_minus_reg = (ascii_char_reg == 8'h2D);
    wire is_equal_reg = (ascii_char_reg == 8'h3D);
    wire is_clear_reg = (ascii_char_reg == 8'h43);
    wire is_delete_reg = (ascii_char_reg == 8'h44);
    wire is_dot_reg = (ascii_char_reg == 8'h2E);
    wire is_sqrt_reg = (ascii_char_reg == 8'hFB);
    wire is_pi_reg = (ascii_char_reg == 8'hE3);
    wire is_factorial_reg = (ascii_char_reg == 8'h21);
    wire is_x_reg = (ascii_char_reg == 8'h78);
    wire is_basic_op_reg = (ascii_char_reg == 8'h2B || ascii_char_reg == 8'h2A || 
                            ascii_char_reg == 8'h2F || ascii_char_reg == 8'h5E);
    wire is_paren_reg = (ascii_char_reg == 8'h28 || ascii_char_reg == 8'h29);
    wire is_func_char_reg = (ascii_char_reg == 8'h69 || ascii_char_reg == 8'h6E ||
                             ascii_char_reg == 8'h6F || ascii_char_reg == 8'h61 ||
                             ascii_char_reg == 8'h65 || ascii_char_reg == 8'h70 ||
                             ascii_char_reg == 8'h67 || ascii_char_reg == 8'h79 ||
                             ascii_char_reg == 8'h66 || ascii_char_reg == 8'h73 ||
                             ascii_char_reg == 8'h63 || ascii_char_reg == 8'h74 ||
                             ascii_char_reg == 8'h6C);
    wire is_space_reg = (ascii_char_reg == 8'h20);
    
    // Always allow all valid characters for storage (no blocking)
    wire char_valid_for_storage_reg = !is_multichar_reg && (is_digit_reg || is_minus_reg || is_dot_reg || is_x_reg || is_basic_op_reg || 
         is_paren_reg || is_func_char_reg || is_space_reg || is_sqrt_reg || is_pi_reg || is_factorial_reg);

    always @(posedge clk) begin
        if (rst) begin
            shared_equation_buffer <= 0;
            shared_equation_length <= 0;
            shared_equation_complete <= 0;
            clear_next_cycle <= 0;
            write_state <= STATE_IDLE;
            chars_to_write <= 0;
            chars_written <= 0;
            char_data_buffer <= 0;
            write_start_index <= 0;
        end else begin
            shared_equation_complete <= 0;

            // STATE MACHINE LOGIC
            case (write_state)
                STATE_IDLE: begin
                    if (clear_next_cycle) begin
                        shared_equation_length <= 0;
                        shared_equation_buffer <= 0;
                        clear_next_cycle <= 0;
                    end 
                    else if (ascii_valid_reg) begin
                        // Priority 1: Control characters
                        if (is_clear_reg) begin
                            shared_equation_length <= 0;
                            shared_equation_complete <= 0;
                            shared_equation_buffer <= 0;
                            clear_next_cycle <= 0;
                        end 
                        else if (is_delete_reg) begin
                            if (shared_equation_length > 0) begin
                                write_state <= STATE_DELETE_CHECK; // Go to the new state
                            end
                        end 
                        else if (is_equal_reg) begin
                            shared_equation_complete <= 1;
                            clear_next_cycle <= 1;
                        end
                        // Priority 1.5: Single-char function expansions (always enabled for display)
                        else if (!is_multichar_reg && ascii_char_reg == 8'h73 && shared_equation_length + 3 <= 64) begin  // 's' -> "sin"
                            write_state <= STATE_WRITE_1;
                            chars_to_write <= 3;
                            char_data_buffer <= {8'h6E, 8'h69, 8'h73};  // "sin"
                            write_start_index <= shared_equation_length;
                        end
                        else if (!is_multichar_reg && ascii_char_reg == 8'h63 && shared_equation_length + 3 <= 64) begin  // 'c' -> "cos"
                            write_state <= STATE_WRITE_1;
                            chars_to_write <= 3;
                            char_data_buffer <= {8'h73, 8'h6F, 8'h63};  // "cos"
                            write_start_index <= shared_equation_length;
                        end
                        else if (!is_multichar_reg && ascii_char_reg == 8'h74 && shared_equation_length + 3 <= 64) begin  // 't' -> "tan"
                            write_state <= STATE_WRITE_1;
                            chars_to_write <= 3;
                            char_data_buffer <= {8'h6E, 8'h61, 8'h74};  // "tan"
                            write_start_index <= shared_equation_length;
                        end
                        else if (!is_multichar_reg && ascii_char_reg == 8'h6C && shared_equation_length + 2 <= 64) begin  // 'l' -> "ln"
                            write_state <= STATE_WRITE_1;
                            chars_to_write <= 2;
                            char_data_buffer <= {8'h00, 8'h6E, 8'h6C};  // "ln"
                            write_start_index <= shared_equation_length;
                        end
                        // Priority 2: Multi-character functions (always enabled for display)
                        else if (is_multichar_reg && char_count_reg > 0) begin
                            if (shared_equation_length + char_count_reg <= 64) begin
                                write_state <= STATE_WRITE_1;
                                chars_to_write <= char_count_reg;
                                chars_written <= 0;
                                char_data_buffer <= multichar_data_reg;
                                write_start_index <= shared_equation_length;
                            end
                        end
                        // Priority 3: Valid storage characters (always allowed)
                        else if (char_valid_for_storage_reg) begin
                            if (shared_equation_length < 64) begin
                                shared_equation_buffer[shared_equation_length*8 +: 8] <= ascii_char_reg;
                                shared_equation_length <= shared_equation_length + 1;
                            end
                        end
                    end
                end

                STATE_WRITE_1: begin
                    shared_equation_buffer[write_start_index*8 +: 8] <= char_data_buffer[7:0];
                    chars_written <= 1;
                    
                    if (chars_to_write == 1) begin
                        shared_equation_length <= write_start_index + 1;
                        write_state <= STATE_IDLE;
                    end else begin
                        write_state <= STATE_WRITE_2;
                    end
                end

                STATE_WRITE_2: begin
                    shared_equation_buffer[(write_start_index+1)*8 +: 8] <= char_data_buffer[15:8];
                    chars_written <= 2;
                    
                    if (chars_to_write == 2) begin
                        shared_equation_length <= write_start_index + 2;
                        write_state <= STATE_IDLE;
                    end else begin
                        write_state <= STATE_WRITE_3;
                    end
                end

                STATE_WRITE_3: begin
                    shared_equation_buffer[(write_start_index+2)*8 +: 8] <= char_data_buffer[23:16];
                    chars_written <= 3;
                    shared_equation_length <= write_start_index + 3;
                    write_state <= STATE_IDLE;
                end

                STATE_DELETE_CHECK: begin
                    // Check for 3-char words (sin, cos, tan, exp)
                    if (shared_equation_length >= 3 && 
                       ((shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E && // "n"
                         shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h69 && // "i"
                         shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h73) || // "s"
                        (shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h73 && // "s"
                         shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h6F && // "o"
                         shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h63) || // "c"
                        (shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E && // "n"
                         shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h61 && // "a"
                         shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h74) || // "t"
                        (shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h70 && // "p"
                         shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h78 && // "x"
                         shared_equation_buffer[(shared_equation_length-3)*8 +: 8] == 8'h65)))  // "e"
                    begin
                        shared_equation_length <= shared_equation_length - 3;
                    end
                    // Check for 2-char words (ln)
                    else if (shared_equation_length >= 2 &&
                             (shared_equation_buffer[(shared_equation_length-1)*8 +: 8] == 8'h6E && // "n"
                              shared_equation_buffer[(shared_equation_length-2)*8 +: 8] == 8'h6C)) // "l"
                    begin
                        shared_equation_length <= shared_equation_length - 2;
                    end
                    // Default: delete 1 char
                    else begin
                        shared_equation_length <= shared_equation_length - 1; 
                    end
                    
                    write_state <= STATE_IDLE; // Go back to IDLE
                end

                default: write_state <= STATE_IDLE;
            endcase
        end
    end

endmodule